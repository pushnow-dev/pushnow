import { createECDH, webcrypto, randomUUID } from 'node:crypto';
import { base64, bytes, certificateText } from '../src/crypto.js';

export function agreementKey() {
  const pair = createECDH('prime256v1');
  pair.generateKeys();
  const scalar = pair.getPrivateKey();
  const privateKey = Buffer.alloc(32);
  scalar.copy(privateKey, 32 - scalar.length);
  return { privateKey: base64(privateKey), publicKey: base64(pair.getPublicKey()) };
}

export async function fixture() {
  const root = await webcrypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const identity = base64(await webcrypto.subtle.exportKey('raw', root.publicKey));
  const sender = agreementKey();
  const user_id = randomUUID();
  const source_id = randomUUID();
  async function sign(kind, id, publicKey) {
    return base64(await webcrypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, root.privateKey,
      bytes(certificateText(kind, user_id, id, publicKey))));
  }
  const devices = [];
  const privateKeys = [];
  for (let i = 0; i < 2; i++) {
    const key = agreementKey();
    const id = randomUUID();
    privateKeys.push(key.privateKey);
    devices.push({ id, user_id, name: `Phone ${i + 1}`, platform: 'ios', public_key: key.publicKey,
      certificate: await sign('device', id, key.publicKey), status: 'active', notifications_enabled: true });
  }
  const source_certificate = await sign('source', source_id, sender.publicKey);
  const config = { api_url: 'https://api.example.test', user_id, source_id,
    source_key: 'test-source-credential', identity_public_key: identity, sender_private_key: sender.privateKey };
  const directory = { user_id, source_id, identity_public_key: identity,
    source_public_key: sender.publicKey, source_certificate, devices };
  const rootJWK = await webcrypto.subtle.exportKey('jwk', root.privateKey);
  return { config, directory, devices, privateKeys, sender,
    identityPrivateKey: Buffer.from(rootJWK.d, 'base64url').toString('base64') };
}
