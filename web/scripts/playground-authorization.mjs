import assert from 'node:assert/strict';
import { createECDH, webcrypto, createHash } from 'node:crypto';
import { suite, bytes, base64, decode } from '../../cli/src/crypto.js';

// This signer exists only in disposable tests and represents the trusted approving phone.
export async function approveFixtureBrowser(backend, code) {
  const pending = await backend.db.prepare('SELECT id,public_key FROM v2_authorizations WHERE user_code=?').bind(code).first();
  assert(pending);
  async function call(method, path, body, status) {
    const response = await fetch(`${backend.apiURL}${path}`, { method,
      headers: { Authorization: `Bearer ${backend.session.accessToken}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    assert.equal(response.status, status, path);
    return status === 204 ? null : response.json();
  }
  const source = (await call('POST', '/v1/sources', { name: 'Browser authorized source' }, 201)).source;
  const key = await call('POST', `/v1/sources/${source.id}/keys`, {}, 201);
  const privateKey = decode(backend.fixture.identityPrivateKey);
  const ec = createECDH('prime256v1'); ec.setPrivateKey(privateKey);
  const pub = ec.getPublicKey();
  const identity = await webcrypto.subtle.importKey('jwk', { kty: 'EC', crv: 'P-256', d: privateKey.toString('base64url'),
    x: pub.subarray(1, 33).toString('base64url'), y: pub.subarray(33).toString('base64url') }, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const certificate = base64(await webcrypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, identity,
    bytes(`pushnow-source-v1\n${backend.config.user_id}\n${source.id}\n${pending.public_key}`)));
  await call('PUT', `/v1/secure/sources/${source.id}`, { public_key: pending.public_key, certificate }, 200);
  const sender = await suite.createSenderContext({ recipientPublicKey: await suite.kem.deserializePublicKey(decode(pending.public_key)), info: bytes('pushnow-sender-grant-v2') });
  const config = { api_url: backend.apiURL, user_id: backend.config.user_id, source_id: source.id, source_key: key.source_key,
    identity_public_key: backend.config.identity_public_key, archive: backend.config.archive };
  const ciphertext = base64(await sender.seal(bytes(JSON.stringify(config)), bytes(JSON.stringify([2, 'sender-grant', pending.id, pending.public_key]))));
  await call('POST', `/v2/authorizations/${pending.id}/approve`, { source_id: source.id, enc: base64(sender.enc), ciphertext }, 204);
  return { sourceId: source.id, fingerprint: createHash('sha256').update(decode(backend.config.identity_public_key)).digest('hex') };
}
