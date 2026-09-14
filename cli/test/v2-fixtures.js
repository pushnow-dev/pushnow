import { createECDH, randomUUID, webcrypto } from 'node:crypto';
import { fixture, agreementKey } from './fixtures.js';
import { base64, bytes, certificateText, decode, suite } from '../src/crypto.js';
import { v2AAD } from '../src/v2-crypto.js';

export async function fixtureV2() {
  const f = await fixture(), archiveKey = agreementKey(), id = randomUUID();
  const ec = createECDH('prime256v1'); ec.setPrivateKey(decode(f.identityPrivateKey)); const pub = ec.getPublicKey();
  const identity = await webcrypto.subtle.importKey('jwk', { kty: 'EC', crv: 'P-256',
    d: decode(f.identityPrivateKey).toString('base64url'), x: pub.subarray(1, 33).toString('base64url'),
    y: pub.subarray(33).toString('base64url') }, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const certificate = base64(await webcrypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, identity,
    bytes(certificateText('archive', f.config.user_id, id, archiveKey.publicKey))));
  f.archiveKey = archiveKey;
  f.config.archive = { id, public_key: archiveKey.publicKey, certificate };
  f.directory.archive = f.config.archive;
  return f;
}

export async function openV2(f, message, purpose = 'message') {
  const envelope = purpose === 'preview' ? message.preview : message;
  const recipient = await suite.createRecipientContext({ recipientKey: await suite.kem.deserializePrivateKey(decode(f.archiveKey.privateKey)),
    senderPublicKey: await suite.kem.deserializePublicKey(decode(f.sender.publicKey)),
    enc: decode(envelope.enc), info: bytes('pushnow-v2') });
  return JSON.parse(Buffer.from(await recipient.open(decode(envelope.ciphertext),
    v2AAD(purpose, f.config, message.message_id, message.archive_id))).toString('utf8'));
}
