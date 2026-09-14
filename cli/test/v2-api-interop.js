import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { readFile, readdir } from 'node:fs/promises';
import { createHash, createECDH, randomUUID, randomBytes, webcrypto } from 'node:crypto';
import { fixtureV2, openV2 } from './v2-fixtures.js';
import { suite, bytes, base64, decode, certificateText } from '../src/crypto.js';
import { beginLogin, finishLogin, revokeSender } from '../src/v2-auth.js';
import { recipientsV2, uploadAttachment, prepareMessageV2, submitMessageV2 } from '../src/v2-client.js';

const backend = fileURLToPath(new URL('../../backend/', import.meta.url));
const require = createRequire(`${backend}package.json`);
const { Miniflare, convertV4MiniflareOptions } = require('miniflare');
const { build } = require('esbuild');
const bundled = await build({ entryPoints: [`${backend}src/index.ts`], bundle: true,
  format: 'esm', platform: 'neutral', external: ['cloudflare:*'], write: false });
const pepper = 'ephemeral-v2-api-only';
const hash = value => createHash('sha256').update(`${value}.${pepper}`).digest('hex');
const mf = new Miniflare(convertV4MiniflareOptions({ name: 'v2-api-interop', host: '127.0.0.1', port: 0,
  modules: true, script: bundled.outputFiles[0].text, d1Databases: ['DB'], r2Buckets: ['SECURE_BLOBS'],
  compatibilityDate: '2026-09-12', compatibilityFlags: ['nodejs_compat'],
  bindings: { AUTH_TOKEN_PEPPER: pepper, PUSH_TOKEN_ENCRYPTION_KEY: randomBytes(32).toString('base64'),
    APP_BASE_URL: 'http://localhost', AUTH_EMAIL_FROM: 'test@example.com', CORS_ORIGINS: 'http://localhost',
    ACCESS_TOKEN_TTL_SECONDS: '900', REFRESH_TOKEN_TTL_SECONDS: '2592000', AUTH_CODE_TTL_SECONDS: '600' } }));
try {
  const db = await mf.getD1Database('DB');
  for (const name of (await readdir(`${backend}migrations`)).filter(n => n.endsWith('.sql')).sort()) {
    for (const sql of (await readFile(`${backend}migrations/${name}`, 'utf8')).split(';').map(s => s.trim()).filter(Boolean)) await db.prepare(sql).run();
  }
  const f = await fixtureV2(), now = new Date().toISOString();
  async function session(user) {
    await db.prepare('INSERT OR IGNORE INTO users(id,email,email_hash,email_verified_at,created_at,updated_at) VALUES (?,?,?,?,?,?)')
      .bind(user, `${user}@example.com`, hash(user), now, now, now).run();
    const access = `test-${randomUUID()}`;
    await db.prepare('INSERT INTO sessions(id,user_id,access_token_hash,refresh_token_hash,expires_at,refresh_expires_at,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)')
      .bind(randomUUID(), user, hash(access), hash(randomUUID()), new Date(Date.now() + 3600000).toISOString(),
        new Date(Date.now() + 86400000).toISOString(), now, now).run();
    return access;
  }
  const phone = await session(f.config.user_id), phone2 = await session(f.config.user_id), foreign = await session(randomUUID());
  const fetcher = (url, options) => mf.dispatchFetch(url, options);
  async function request(token, method, path, body, expected = 200) {
    const response = await fetcher(`http://localhost${path}`, { method,
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
    assert.equal(response.status, expected, `${method} ${path} status`);
    return response.status === 204 ? null : response.json();
  }
  async function sign(raw, text) {
    const ec = createECDH('prime256v1'); ec.setPrivateKey(decode(raw)); const pub = ec.getPublicKey();
    const key = await webcrypto.subtle.importKey('jwk', { kty: 'EC', crv: 'P-256', d: decode(raw).toString('base64url'),
      x: pub.subarray(1, 33).toString('base64url'), y: pub.subarray(33).toString('base64url') },
    { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
    return base64(await webcrypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, bytes(text)));
  }
  async function register(token, i) {
    const d = f.devices[i], { challenge } = await request(token, 'GET', '/v1/secure/device-challenge');
    return request(token, 'POST', '/v1/secure/devices', { device_id: d.id, name: d.name, platform: 'ios', public_key: d.public_key,
      challenge, proof: await sign(f.privateKeys[i], `${certificateText('register', d.user_id, d.id, d.public_key)}\n${challenge}`),
      ...(i === 0 ? { identity_public_key: f.config.identity_public_key, certificate: d.certificate } : {}) });
  }
  await register(phone, 0);
  await request(phone, 'POST', '/v2/archive', f.config.archive);
  const pending = await beginLogin('http://localhost', 'HTTP SDK sender', { fetcher });
  const lookup = await request(phone, 'GET', `/v2/authorizations/lookup?code=${pending.authorization.user_code}`);
  assert.equal(lookup.authorization.public_key, pending.key.publicKey);
  assert.equal(lookup.archive.id, f.config.archive.id);
  const source = await request(phone, 'POST', '/v1/sources', { name: 'HTTP SDK sender' }, 201);
  const sourceID = source.source.id;
  const createdKey = await request(phone, 'POST', `/v1/sources/${sourceID}/keys`, {}, 201);
  const sourceCertificate = await sign(f.identityPrivateKey, certificateText('source', f.config.user_id, sourceID, pending.key.publicKey));
  await request(phone, 'PUT', `/v1/secure/sources/${sourceID}`, { public_key: pending.key.publicKey, certificate: sourceCertificate });
  const grantConfig = { api_url: 'http://localhost', user_id: f.config.user_id, source_id: sourceID,
    source_key: createdKey.source_key, identity_public_key: f.config.identity_public_key, archive: f.config.archive };
  const sender = await suite.createSenderContext({ recipientPublicKey: await suite.kem.deserializePublicKey(decode(pending.key.publicKey)), info: bytes('pushnow-sender-grant-v2') });
  const grant = { enc: base64(sender.enc), ciphertext: base64(await sender.seal(bytes(JSON.stringify(grantConfig)),
    bytes(JSON.stringify([2, 'sender-grant', pending.authorization.id, pending.key.publicKey])))) };
  await request(phone, 'POST', `/v2/authorizations/${pending.authorization.id}/approve`, { source_id: sourceID, ...grant }, 204);
  const config = await finishLogin(pending, { fetcher, confirmIdentity: ({ fingerprint }) => fingerprint === createHash('sha256').update(decode(f.config.identity_public_key)).digest('hex') });
  assert.equal(config.sender_private_key, pending.key.privateKey);
  const reused = await fetcher(`http://localhost/v2/authorizations/${pending.authorization.id}/token`, { method: 'POST',
    headers: { 'content-type': 'application/json' }, body: JSON.stringify({ device_code: pending.authorization.device_code }) });
  assert.equal(reused.status, 401);
  console.log('PASS real HTTP authorization lookup, phone grant, CLI consumption and single-use protection');
  const attachment = await uploadAttachment(config, Buffer.from('Private HTTP attachment'), { name: 'private.txt', mime: 'text/plain' }, { fetcher });
  const directory = await recipientsV2(config, { fetcher });
  const full = { title: 'Private HTTP v2 title', body: 'Long body '.repeat(500), links: ['https://example.com'], attachments: [attachment] };
  const scheduledAt = new Date(Date.now() + 60000).toISOString();
  const expiresAt = new Date(Date.now() + 120000).toISOString();
  const message = await prepareMessageV2(config, directory, full, { deviceIds: [], scheduledAt, expiresAt, sound: 'chime' });
  await submitMessageV2(config, message, { fetcher });
  assert.equal((await submitMessageV2(config, message, { fetcher })).deduplicated, true);
  await assert.rejects(submitMessageV2(config, { ...message, sound: 'silent' }, { fetcher }), error => error.status === 409);
  const page = await request(phone, 'GET', '/v2/messages');
  assert.equal(page.messages.length, 1);
  assert.equal(page.messages[0].scheduled_at, scheduledAt);
  assert.equal(page.messages[0].expires_at, expiresAt);
  assert.equal(page.messages[0].sound, 'chime');
  const decryptFixture = { ...f, config, sender: { publicKey: pending.key.publicKey } };
  assert.deepEqual(await openV2(decryptFixture, page.messages[0]), full);
  assert.ok((await openV2(decryptFixture, page.messages[0], 'preview')).body.length < full.body.length);
  const blob = await fetcher(`http://localhost/v2/attachments/${attachment.id}`, { headers: { authorization: `Attachment ${attachment.read_token}` } });
  assert.equal(blob.status, 200);
  assert.ok(!Buffer.from(await blob.arrayBuffer()).includes(Buffer.from('Private HTTP attachment')));
  await request(foreign, 'GET', `/v2/messages/${message.message_id}`, undefined, 403);
  console.log('PASS real HTTP encrypted upload/R2 read capability, full archive message, preview, idempotency and foreign isolation');
  await register(phone2, 1);
  const deviceSender = await suite.createSenderContext({ recipientPublicKey: await suite.kem.deserializePublicKey(decode(f.devices[1].public_key)), info: bytes('pushnow-approval-v1') });
  const approvalAAD = bytes(certificateText('approval', config.user_id, f.devices[1].id, f.devices[1].public_key));
  const deviceApproval = { enc: base64(deviceSender.enc), ciphertext: base64(await deviceSender.seal(bytes(JSON.stringify({
    identity_private_key: f.identityPrivateKey, archive_id: config.archive.id, archive_private_key: f.archiveKey.privateKey })), approvalAAD)) };
  await request(phone, 'POST', `/v1/secure/devices/${f.devices[1].id}/approve`, { certificate: f.devices[1].certificate,
    approval: deviceApproval });
  const transferred = (await request(phone2, 'GET', `/v1/secure/devices/${f.devices[1].id}/approval`)).approval;
  const newPhone = await suite.createRecipientContext({ recipientKey: await suite.kem.deserializePrivateKey(decode(f.privateKeys[1])),
    enc: decode(transferred.enc), info: bytes('pushnow-approval-v1') });
  const secrets = JSON.parse(Buffer.from(await newPhone.open(decode(transferred.ciphertext), approvalAAD)).toString('utf8'));
  const newHistory = await request(phone2, 'GET', '/v2/messages');
  assert.equal(newHistory.messages.length, 1);
  assert.deepEqual(await openV2({ ...decryptFixture, archiveKey: { privateKey: secrets.archive_private_key } }, newHistory.messages[0]), full);
  await request(phone2, 'POST', `/v2/messages/${message.message_id}/read`, {}, 204);
  assert.ok((await request(phone, 'GET', `/v2/messages/${message.message_id}`)).message.read_at);
  await request(phone2, 'DELETE', `/v2/messages/${message.message_id}`, undefined, 204);
  assert.equal((await request(phone, 'GET', '/v2/messages')).messages.length, 0);
  assert.ok((await request(phone, 'GET', '/v2/deletions')).deleted_ids.includes(message.message_id));
  await assert.rejects(submitMessageV2(config, message, { fetcher }));
  assert.equal((await fetcher(`http://localhost/v2/attachments/${attachment.id}`, { headers: { authorization: `Attachment ${attachment.read_token}` } })).status, 404);
  console.log('PASS new approved device shared history/read/deletion, tombstone retry protection and blob capability removal');
  await revokeSender(config, { fetcher });
  await assert.rejects(recipientsV2(config, { fetcher }));
  console.log('PASS sender logout self-revokes real HTTP credentials; no production/APNs used');
} finally { await mf.dispose(); }
