import test from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { decryptForTest } from '../src/crypto.js';
import { prepareMessage, recipients, submitMessage, validateConfig } from '../src/client.js';
import { agreementKey, fixture } from './fixtures.js';

const content = { title: 'Encrypted reminder', body: 'Private payload: \u4f60\u597d' };
function metadata(f, m, device) {
  return { user_id: f.config.user_id, source_id: f.config.source_id, device_id: device.id,
    message_id: m.message_id, expires_at: m.expires_at };
}

test('two devices decrypt distinct authenticated envelopes; fresh randomness every encryption', async () => {
  const f = await fixture();
  const m = await prepareMessage(f.config, f.devices, content);
  const again = await prepareMessage(f.config, f.devices, content);
  assert.notEqual(m.envelopes[0].enc, m.envelopes[1].enc);
  assert.notEqual(m.envelopes[0].ciphertext, again.envelopes[0].ciphertext);
  for (let i = 0; i < 2; i++) {
    assert.deepEqual(await decryptForTest(f.privateKeys[i], f.sender.publicKey, m.envelopes[i], metadata(f, m, f.devices[i])), content);
  }
  assert(!JSON.stringify(m).includes(content.title));
  assert(!JSON.stringify(m).includes(content.body));
});

test('wrong recipient, sender, account, message ID, expiry and modified ciphertext reject', async () => {
  const f = await fixture();
  const m = await prepareMessage(f.config, f.devices, content);
  const envelope = m.envelopes[0];
  const aad = metadata(f, m, f.devices[0]);
  await assert.rejects(decryptForTest(f.privateKeys[1], f.sender.publicKey, envelope, aad));
  await assert.rejects(decryptForTest(f.privateKeys[0], agreementKey().publicKey, envelope, aad));
  for (const field of ['user_id', 'device_id', 'source_id', 'message_id', 'expires_at']) {
    await assert.rejects(decryptForTest(f.privateKeys[0], f.sender.publicKey, envelope, { ...aad, [field]: 'changed' }));
  }
  const changed = Buffer.from(envelope.ciphertext, 'base64');
  changed[0] ^= 1;
  await assert.rejects(decryptForTest(f.privateKeys[0], f.sender.publicKey,
    { ...envelope, ciphertext: changed.toString('base64') }, aad));
});

test('directory validates root pin, source private key and each signed user/device binding', async () => {
  const f = await fixture();
  const get = (directory) => async () => new Response(JSON.stringify(directory));
  assert.equal((await recipients(f.config, get(f.directory))).length, 2);
  await assert.rejects(recipients(f.config, get({ ...f.directory, identity_public_key: agreementKey().publicKey })));
  await assert.rejects(recipients({ ...f.config, sender_private_key: agreementKey().privateKey }, get(f.directory)));
  for (const patch of [{ user_id: randomUUID() }, { id: randomUUID() }, { public_key: agreementKey().publicKey }, { status: 'revoked' }]) {
    await assert.rejects(recipients(f.config, get({ ...f.directory, devices: [{ ...f.devices[0], ...patch }] })));
  }
});

test('notification choice defaults to enabled, supports explicit subset, rejects unknown devices', async () => {
  const f = await fixture();
  f.devices[1].notifications_enabled = false;
  assert.equal((await prepareMessage(f.config, f.devices, content)).envelopes.length, 1);
  const m = await prepareMessage(f.config, f.devices, content, { deviceIds: [f.devices[1].id] });
  assert.equal(m.envelopes[0].device_id, f.devices[1].id);
  await assert.rejects(prepareMessage(f.config, f.devices, content, { deviceIds: [randomUUID()] }));
  await assert.rejects(prepareMessage(f.config, f.devices, { title: 'x', body: 'x'.repeat(3000) }));
});

test('transport sends only ciphertext with idempotent ID and refuses redirects/insecure remote URL', async () => {
  const f = await fixture();
  const m = await prepareMessage(f.config, f.devices, content);
  await submitMessage(f.config, m, async (url, options) => {
    assert.equal(url.pathname, '/v1/secure/messages');
    assert.equal(options.redirect, 'error');
    assert.equal(options.headers['idempotency-key'], m.message_id);
    assert(!options.body.includes('Private payload'));
    return new Response('{}');
  });
  assert.throws(() => validateConfig({ ...f.config, api_url: 'http://example.com' }));
  assert.throws(() => validateConfig({ ...f.config, api_url: 'https://user:secret@example.com' }));
});
