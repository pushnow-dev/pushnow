import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { readFile, readdir } from 'node:fs/promises';
import { createHash, createECDH, randomUUID, randomBytes, webcrypto } from 'node:crypto';
import { fixture } from './fixtures.js';
import { suite, bytes, base64, decode, certificateText, decryptForTest } from '../src/crypto.js';
import { recipients, prepareMessage, submitMessage } from '../src/client.js';

const backend = fileURLToPath(new URL('../../backend/', import.meta.url));
const require = createRequire(`${backend}package.json`);
const { Miniflare, convertV4MiniflareOptions } = require('miniflare');
const { build } = require('esbuild');
const bundled = await build({ entryPoints: [`${backend}src/index.ts`], bundle: true,
  format: 'esm', platform: 'neutral', external: ['cloudflare:*'], write: false });
const pepper = 'ephemeral-http-interop-only';
const hash = value => createHash('sha256').update(`${value}.${pepper}`).digest('hex');
const mf = new Miniflare(convertV4MiniflareOptions({ name: 'api-interop', host: '127.0.0.1', port: 0,
  modules: true, script: bundled.outputFiles[0].text, d1Databases: ['DB'],
  compatibilityDate: '2026-09-12', compatibilityFlags: ['nodejs_compat'],
  bindings: { AUTH_TOKEN_PEPPER: pepper, PUSH_TOKEN_ENCRYPTION_KEY: randomBytes(32).toString('base64'),
    APP_BASE_URL: 'http://localhost', AUTH_EMAIL_FROM: 'test@example.com', CORS_ORIGINS: 'http://localhost',
    ACCESS_TOKEN_TTL_SECONDS: '900', REFRESH_TOKEN_TTL_SECONDS: '2592000', AUTH_CODE_TTL_SECONDS: '600' } }));
let checks = 0;
const pass = label => { checks++; console.log(`PASS ${label}`); };
try {
  const db = await mf.getD1Database('DB');
  for (const name of (await readdir(`${backend}migrations`)).filter(n => n.endsWith('.sql')).sort()) {
    for (const sql of (await readFile(`${backend}migrations/${name}`, 'utf8')).split(';').map(s => s.trim()).filter(Boolean)) {
      await db.prepare(sql).run();
    }
  }
  const f = await fixture(), now = new Date().toISOString();
  const scalar = value => Buffer.from(decode(value).toString('hex').padStart(64, '0'), 'hex').toString('base64');
  f.privateKeys = f.privateKeys.map(scalar);
  f.config.sender_private_key = scalar(f.config.sender_private_key);
  async function session(user, suffix) {
    await db.prepare('INSERT OR IGNORE INTO users(id,email,email_hash,email_verified_at,created_at,updated_at) VALUES (?,?,?,?,?,?)')
      .bind(user, `${user}@example.com`, hash(user), now, now, now).run();
    const access = `test-access-${suffix}-${randomUUID()}`, refresh = `test-refresh-${suffix}-${randomUUID()}`;
    await db.prepare('INSERT INTO sessions(id,user_id,access_token_hash,refresh_token_hash,expires_at,refresh_expires_at,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)')
      .bind(randomUUID(), user, hash(access), hash(refresh), new Date(Date.now() + 3600000).toISOString(),
        new Date(Date.now() + 86400000).toISOString(), now, now).run();
    return access;
  }
  const tokens = [await session(f.config.user_id, 'one'), await session(f.config.user_id, 'two')];
  const foreign = await session(randomUUID(), 'foreign');
  const fetcher = (url, options) => mf.dispatchFetch(url, options);
  async function request(token, method, path, body, expected = 200) {
    const response = await fetcher(`http://localhost${path}`, { method,
      headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
      ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
    assert.equal(response.status, expected, `${method} ${path} status`);
    return response.status === 204 ? null : response.json();
  }
  async function signingKey(raw) {
    const key = createECDH('prime256v1'); key.setPrivateKey(decode(raw, 32));
    const pub = key.getPublicKey();
    return webcrypto.subtle.importKey('jwk', { kty: 'EC', crv: 'P-256',
      d: decode(raw).toString('base64url'), x: pub.subarray(1, 33).toString('base64url'),
      y: pub.subarray(33).toString('base64url') }, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  }
  async function registration(i) {
    const d = f.devices[i];
    const { challenge } = await request(tokens[i], 'GET', '/v1/secure/device-challenge');
    const proof = base64(await webcrypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' },
      await signingKey(f.privateKeys[i]), bytes(`${certificateText('register', d.user_id, d.id, d.public_key)}\n${challenge}`)));
    return { device_id: d.id, public_key: d.public_key, platform: 'ios', name: d.name, challenge, proof,
      ...(i === 0 ? { identity_public_key: f.config.identity_public_key, certificate: d.certificate } : {}) };
  }
  await request('invalid', 'GET', '/v1/secure/devices', undefined, 401);
  const first = await registration(0);
  await request(tokens[1], 'POST', '/v1/secure/devices', first, 403);
  const registered = await request(tokens[0], 'POST', '/v1/secure/devices', first);
  assert.equal(registered.device.status, 'active');
  await request(tokens[0], 'POST', '/v1/secure/devices', first, 403);
  pass('HTTP auth and one-use session-bound proof');
  const second = await request(tokens[1], 'POST', '/v1/secure/devices', await registration(1));
  assert.equal(second.device.status, 'pending');
  await request(tokens[1], 'GET', '/v1/secure/messages', undefined, 403);
  const approvalSender = await suite.createSenderContext({ recipientPublicKey: await suite.kem.deserializePublicKey(decode(f.devices[1].public_key)), info: bytes('pushnow-approval-v1') });
  const approval = { enc: base64(approvalSender.enc), ciphertext: base64(await approvalSender.seal(
    bytes(JSON.stringify({ identity_private_key: f.identityPrivateKey })),
    bytes(certificateText('approval', f.config.user_id, f.devices[1].id, f.devices[1].public_key)))) };
  await request(tokens[0], 'POST', `/v1/secure/devices/${f.devices[1].id}/approve`, { certificate: f.devices[1].certificate, approval });
  assert.deepEqual((await request(tokens[1], 'GET', `/v1/secure/devices/${f.devices[1].id}/approval`)).approval, approval);
  const approvalRecipient = await suite.createRecipientContext({ recipientKey: await suite.kem.deserializePrivateKey(decode(f.privateKeys[1])),
    enc: decode(approval.enc), info: bytes('pushnow-approval-v1') });
  const approvedSecret = JSON.parse(Buffer.from(await approvalRecipient.open(decode(approval.ciphertext),
    bytes(certificateText('approval', f.config.user_id, f.devices[1].id, f.devices[1].public_key)))).toString('utf8'));
  assert.equal(approvedSecret.identity_private_key, f.identityPrivateKey);
  await request(tokens[0], 'GET', `/v1/secure/devices/${f.devices[1].id}/approval`, undefined, 403);
  pass('second phone pending, certified approval, device-bound approval fetch');
  await db.prepare('INSERT INTO sources(id,user_id,name,source_type,created_at,updated_at) VALUES (?,?,?,?,?,?)')
    .bind(f.config.source_id, f.config.user_id, 'Test sender', 'agent', now, now).run();
  await db.prepare('INSERT INTO source_keys(id,source_id,user_id,key_prefix,key_hash,scopes,created_at) VALUES (?,?,?,?,?,?,?)')
    .bind(randomUUID(), f.config.source_id, f.config.user_id, f.config.source_key.slice(0, 18), hash(f.config.source_key), JSON.stringify(['items:write']), now).run();
  await request(tokens[0], 'PUT', `/v1/secure/sources/${f.config.source_id}`, { public_key: f.sender.publicKey, certificate: f.directory.source_certificate });
  const config = { ...f.config, api_url: 'http://localhost' };
  const devices = await recipients(config, fetcher);
  assert.equal(devices.length, 2);
  const plaintext = { title: 'Private integration reminder', body: 'Both selected phones only' };
  const message = await prepareMessage(config, devices, plaintext);
  await submitMessage(config, message, fetcher);
  const duplicate = await submitMessage(config, message, fetcher);
  assert.equal(duplicate.deduplicated, true);
  for (let i = 0; i < 2; i++) {
    const inbox = await request(tokens[i], 'GET', '/v1/secure/messages');
    assert.equal(inbox.messages.length, 1);
    const envelope = inbox.messages[0];
    assert.equal(envelope.device_id, f.devices[i].id);
    assert.deepEqual(await decryptForTest(f.privateKeys[i], f.sender.publicKey, envelope, envelope), plaintext);
    await assert.rejects(decryptForTest(f.privateKeys[1 - i], f.sender.publicKey, envelope, envelope));
  }
  pass('CLI real-route snake_case ingest, idempotency, independent recipient decrypt and wrong-device rejection');
  await request(foreign, 'PATCH', `/v1/secure/devices/${f.devices[0].id}`, { name: 'Unauthorized' }, 404);
  await request(foreign, 'GET', '/v1/secure/messages', undefined, 403);
  await request(tokens[0], 'PATCH', `/v1/secure/devices/${f.devices[1].id}`, { name: 'Work phone', notifications_enabled: false });
  const updated = await recipients(config, fetcher);
  assert.equal(updated.find(d => d.id === f.devices[1].id).name, 'Work phone');
  const selected = await prepareMessage(config, updated, plaintext);
  assert.deepEqual(selected.envelopes.map(e => e.device_id), [f.devices[0].id]);
  pass('foreign account isolation, rename and default notification targeting');
  const bad = { ...message, message_id: randomUUID(), envelopes: [{ ...message.envelopes[0], device_id: randomUUID() }] };
  await assert.rejects(submitMessage(config, bad, fetcher));
  const rows = await db.prepare('SELECT * FROM secure_messages').all();
  const deliveries = await db.prepare('SELECT * FROM secure_deliveries').all();
  assert.ok(!JSON.stringify([rows.results, deliveries.results]).includes(plaintext.title));
  assert.equal((await db.prepare('SELECT count(*) AS n FROM items').first()).n, 0);
  pass('unregistered target refused and no parallel plaintext item persistence');
  await request(tokens[0], 'POST', '/v1/auth/logout', {}, 204);
  await request(tokens[0], 'GET', '/v1/secure/messages', undefined, 401);
  assert.equal((await request(tokens[1], 'GET', '/v1/secure/messages')).messages.length, 1);
  pass('logout revokes only bound phone access; second phone remains authenticated');
  console.log(`API interop complete: ${checks} groups passed; no APNs or production network used.`);
} finally { await mf.dispose(); }
