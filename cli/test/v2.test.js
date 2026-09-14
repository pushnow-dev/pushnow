import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, stat } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { webcrypto } from 'node:crypto';
import { suite, bytes, base64, decode } from '../src/crypto.js';
import { encryptAttachment } from '../src/v2-crypto.js';
import { beginLogin, finishLogin, revokeSender } from '../src/v2-auth.js';
import { recipientsV2, prepareMessageV2, uploadAttachment } from '../src/v2-client.js';
import { credentialStore } from '../src/credentials.js';
import { fixtureV2, openV2 } from './v2-fixtures.js';

test('archive full message is preserved, preview bounded, disabled notification target becomes inbox only', async () => {
  const f = await fixtureV2(); f.devices[1].notifications_enabled = false;
  const full = { title: 'Private full content', body: 'Hello \u4f60\u597d '.repeat(1000), links: ['https://example.com'], attachments: [] };
  const message = await prepareMessageV2(f.config, f.directory, full, { deviceIds: [f.devices[1].id] });
  assert.deepEqual(message.notify_device_ids, []);
  assert.deepEqual(await openV2(f, message), full);
  assert.ok(Buffer.byteLength((await openV2(f, message, 'preview')).body) <= 700);
  assert.ok(!JSON.stringify(message).includes(full.title));
  await assert.rejects(openV2(f, { ...message, preview: message }, 'preview'));
  await assert.rejects(prepareMessageV2(f.config, { ...f.directory, archive: { ...f.config.archive, id: 'changed' } }, full));
});

test('attachment encryption authenticates account/source/id; upload never sends name or clear data', async () => {
  const f = await fixtureV2(), plaintext = Buffer.from('Confidential attachment');
  const encrypted = await encryptAttachment(f.config, plaintext, { name: 'private.txt', mime: 'text/plain' });
  const d = encrypted.descriptor;
  const key = await webcrypto.subtle.importKey('raw', decode(d.key), 'AES-GCM', false, ['decrypt']);
  const params = { name: 'AES-GCM', iv: decode(d.nonce), additionalData: bytes(JSON.stringify([2, 'attachment', f.config.user_id, f.config.source_id, d.id])) };
  assert.deepEqual(Buffer.from(await webcrypto.subtle.decrypt(params, key, encrypted.ciphertext)), plaintext);
  await assert.rejects(webcrypto.subtle.decrypt({ ...params, additionalData: bytes('other') }, key, encrypted.ciphertext));
  let n = 0;
  await uploadAttachment(f.config, plaintext, { name: 'private.txt' }, { fetcher: async (url, options) => {
    n++; assert.equal(options.redirect, 'error');
    if (n === 1) { const body = JSON.parse(options.body); assert.equal(typeof body.read_token, 'string'); assert.ok(!options.body.includes('private.txt')); return new Response('{}'); }
    assert.ok(!Buffer.from(options.body).includes(plaintext)); return new Response(null, { status: 204 });
  } });
  assert.equal(n, 2);
});

test('device authorization HPKE grant validates API/root archive and keeps source private key local', async () => {
  const f = await fixtureV2(); let wire;
  const pending = await beginLogin(f.config.api_url, 'Test client', { fetcher: async (_url, options) => {
    wire = JSON.parse(options.body);
    return new Response(JSON.stringify({ id: 'auth-test', user_code: 'ABCD2345', device_code: 'ephemeral',
      expires_at: new Date(Date.now() + 60000).toISOString(), interval: 3 }));
  } });
  assert.equal(Object.keys(wire).sort().join(','), 'name,public_key');
  const sender = await suite.createSenderContext({ recipientPublicKey: await suite.kem.deserializePublicKey(decode(wire.public_key)), info: bytes('pushnow-sender-grant-v2') });
  const { sender_private_key, ...grantConfig } = f.config;
  const grant = { enc: base64(sender.enc), ciphertext: base64(await sender.seal(bytes(JSON.stringify(grantConfig)),
    bytes(JSON.stringify([2, 'sender-grant', pending.authorization.id, wire.public_key])))) };
  const config = await finishLogin(pending, { confirmIdentity: () => true, fetcher: async () => new Response(JSON.stringify({ status: 'approved', grant })) });
  assert.equal(config.sender_private_key, pending.key.privateKey);
  assert.equal(config.archive.public_key, f.config.archive.public_key);
  await assert.rejects(finishLogin(pending, { fetcher: async () => new Response(JSON.stringify({ status: 'approved', grant })) }), /identity not confirmed/);
  await assert.rejects(finishLogin(pending, { expectedIdentityFingerprint: '0'.repeat(64),
    fetcher: async () => new Response(JSON.stringify({ status: 'approved', grant })) }), /identity not confirmed/);
  await assert.rejects(finishLogin({ ...pending, authorization: { ...pending.authorization, id: 'changed' } },
    { fetcher: async () => new Response(JSON.stringify({ status: 'approved', grant })) }));
  await revokeSender(config, { fetcher: async (url, options) => {
    assert.equal(url.pathname, '/v2/logout'); assert.equal(options.method, 'POST'); return new Response(null, { status: 204 });
  } });
});

test('v2 directory rejects root/source/archive substitutions', async () => {
  const f = await fixtureV2();
  const fetcher = directory => async () => new Response(JSON.stringify(directory));
  assert.equal((await recipientsV2(f.config, { fetcher: fetcher(f.directory) })).devices.length, 2);
  await assert.rejects(recipientsV2(f.config, { fetcher: fetcher({ ...f.directory, identity_public_key: f.sender.publicKey }) }));
  await assert.rejects(recipientsV2(f.config, { fetcher: fetcher({ ...f.directory, archive: { ...f.config.archive, public_key: f.sender.publicKey } }) }));
});

test('non-mac credential fallback is private, round-trips and deletes', async () => {
  const directory = await mkdtemp(join(tmpdir(), 'pushnow-credentials-test-'));
  try {
    const store = credentialStore({ platform: 'linux', directory });
    assert.equal(await store.read(), null);
    await store.write({ disposable: 'test-only' });
    assert.equal((await stat(join(directory, 'credentials.json'))).mode & 0o777, 0o600);
    assert.deepEqual(await store.read(), { disposable: 'test-only' });
    await store.delete(); assert.equal(await store.read(), null);
  } finally { await rm(directory, { recursive: true, force: true }); }
});

test('source kind is explicit metadata and absent for generic clients', async()=>{
 const f=await fixtureV2(),content={title:'Source',body:'Label'};
 assert.equal((await prepareMessageV2(f.config,f.directory,content)).source_kind,undefined);
 assert.equal((await prepareMessageV2(f.config,f.directory,content,{sourceKind:'cli'})).source_kind,'cli');
 await assert.rejects(prepareMessageV2(f.config,f.directory,content,{sourceKind:'invalid'}));
});
