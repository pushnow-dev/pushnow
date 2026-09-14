// Runs the unchanged ArkTS protocol implementation with a Node adapter for
// CryptoFramework primitives. This proves wire compatibility, not device APIs.
import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import vm from 'node:vm';
import { createRequire } from 'node:module';
import * as nodeCrypto from 'node:crypto';
const require = createRequire(import.meta.url);
const ts = require('../../backend/node_modules/typescript');
const { CipherSuite, DhkemP256HkdfSha256, HkdfSha256, Aes256Gcm } =
  await import('../../sdk/typescript/node_modules/@hpke/core/esm/mod.js');
const suite = new CipherSuite({ kem: new DhkemP256HkdfSha256(), kdf: new HkdfSha256(), aead: new Aes256Gcm() });
const b64 = bytes => Buffer.from(bytes).toString('base64');
const bytes = value => new TextEncoder().encode(value);
function wrapKey(key) {
  return { key, getEncoded: () => ({ data: new Uint8Array(key.export({ format: 'der', type: key.type === 'private' ? 'pkcs8' : 'spki' })) }),
    getAsyKeySpec: () => BigInt(`0x${Buffer.from(key.export({ format: 'jwk' }).d, 'base64url').toString('hex')}`) };
}
const crypto = {
  AsyKeySpecItem: { ECC_SK_BN: 208 }, CryptoMode: { ENCRYPT_MODE: 0, DECRYPT_MODE: 1 },
  createAsyKeyGenerator: () => ({
    async generateKeyPair() { const pair = nodeCrypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
      return { pubKey: wrapKey(pair.publicKey), priKey: wrapKey(pair.privateKey) }; },
    async convertKey(pub, pri) { return {
      pubKey: pub ? wrapKey(nodeCrypto.createPublicKey({ key: Buffer.from(pub.data), type: 'spki', format: 'der' })) : null,
      priKey: pri ? wrapKey(nodeCrypto.createPrivateKey({ key: Buffer.from(pri.data), type: 'pkcs8', format: 'der' })) : null }; }
  }),
  createSign: () => { let key; return { async init(k) { key = k.key; }, async sign(data) {
    return { data: new Uint8Array(nodeCrypto.sign('sha256', data.data, key)) }; } }; },
  createVerify: () => { let key; return { async init(k) { key = k.key; }, async verify(data, signature) {
    return nodeCrypto.verify('sha256', data.data, key, signature.data); } }; },
  createKeyAgreement: () => ({ async generateSecret(pri, pub) {
    return { data: new Uint8Array(nodeCrypto.diffieHellman({ privateKey: pri.key, publicKey: pub.key })) }; } }),
  createSymKeyGenerator: () => ({ async convertKey(value) { return value.data; } }),
  createMac: () => { let mac; return { async init(key) { mac = nodeCrypto.createHmac('sha256', key); },
    async update(data) { mac.update(data.data); }, async doFinal() { return { data: new Uint8Array(mac.digest()) }; } }; },
  createMd: () => { const md = nodeCrypto.createHash('sha256'); return { async update(data) { md.update(data.data); },
    async digest() { return { data: new Uint8Array(md.digest()) }; } }; },
  createCipher: () => { let cipher, decrypt; return {
    async init(mode, key, params) { decrypt = mode === 1;
      cipher = decrypt ? nodeCrypto.createDecipheriv('aes-256-gcm', key, params.iv.data) : nodeCrypto.createCipheriv('aes-256-gcm', key, params.iv.data);
      cipher.setAAD(params.aad.data); if (decrypt) cipher.setAuthTag(params.authTag.data); },
    async doFinal(data) { const output = Buffer.concat([cipher.update(data.data), cipher.final()]);
      return { data: new Uint8Array(decrypt ? output : Buffer.concat([output, cipher.getAuthTag()])) }; }
  }; }
};
const util = {
  TextEncoder: class { encodeInto(text) { return bytes(text); } },
  TextDecoder: { create: () => ({ decodeWithStream: value => new TextDecoder('utf-8', { fatal: true }).decode(value) }) },
  Base64Helper: class { encodeToStringSync(value) { return b64(value); } decodeSync(value) { return new Uint8Array(Buffer.from(value, 'base64')); } }
};
const source = fs.readFileSync(new URL('../entry/src/main/ets/services/SecureCrypto.ets', import.meta.url), 'utf8')
  .replace(/^import .*;\n/gm, '');
const compiled = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS } }).outputText;
const context = { exports: {}, crypto, util, Uint8Array, Array, Error, BigInt, parseInt };
vm.runInNewContext(compiled, context);
const secure = context.exports.secureCrypto;

async function hpkeKey(key) { return suite.kem.deserializePrivateKey(Buffer.from(key.privateKey, 'base64')); }
async function hpkePublic(key) { return suite.kem.deserializePublicKey(Buffer.from(key.publicKey, 'base64')); }

test('P256 registration/certificate signatures match WebCrypto raw representation', async () => {
  const identity = await secure.generateKey();
  const text = secure.text('device', 'account', 'device', identity.publicKey);
  const signature = await secure.sign(identity.privateKey, text);
  assert.equal(Buffer.from(signature, 'base64').length, 64);
  const publicKey = await nodeCrypto.webcrypto.subtle.importKey('raw', Buffer.from(identity.publicKey, 'base64'),
    { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
  assert.ok(await nodeCrypto.webcrypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, publicKey, Buffer.from(signature, 'base64'), bytes(text)));
  await secure.verify(signature, text, identity.publicKey);
  await assert.rejects(secure.verify(signature, `${text}!`, identity.publicKey));
});

test('Harmony base HPKE grants open in the SDK and SDK grants open in Harmony', async () => {
  const device = await secure.generateKey();
  for (const info of ['pushnow-approval-v1', 'pushnow-archive-grant-v2', 'pushnow-sender-grant-v2']) {
    const aad = JSON.stringify([2, 'grant', 'user', 'device', 'archive']);
    const plaintext = JSON.stringify({ identity_private_key: 'root', title: '跨平台 🔐' });
    const grant = await secure.seal(device.publicKey, plaintext, info, aad);
    const recipient = await suite.createRecipientContext({ recipientKey: await hpkeKey(device),
      enc: Buffer.from(grant.enc, 'base64'), info: bytes(info) });
    assert.equal(new TextDecoder().decode(await recipient.open(Buffer.from(grant.ciphertext, 'base64'), bytes(aad))), plaintext);
    const sender = await suite.createSenderContext({ recipientPublicKey: await hpkePublic(device), info: bytes(info) });
    const sdkGrant = { enc: b64(sender.enc), ciphertext: b64(await sender.seal(bytes(plaintext), bytes(aad))) };
    assert.equal(await secure.open(device.privateKey, device.publicKey, sdkGrant, info, aad), plaintext);
    await assert.rejects(secure.open(device.privateKey, device.publicKey, sdkGrant, info, `${aad}!`));
  }
});

test('authenticated v1/v2 SDK messages decrypt; wrong sender, purpose, recipient and ciphertext fail', async () => {
  const archive = await secure.generateKey();
  const source = await secure.generateKey();
  const other = await secure.generateKey();
  for (const info of ['pushnow-message-v1', 'pushnow-v2']) {
    const aad = JSON.stringify([2, 'message', 'user', 'source', 'message', 'archive']);
    const sender = await suite.createSenderContext({ recipientPublicKey: await hpkePublic(archive), senderKey: await hpkeKey(source), info: bytes(info) });
    const grant = { enc: b64(sender.enc), ciphertext: b64(await sender.seal(bytes('secure message'), bytes(aad))) };
    assert.equal(await secure.open(archive.privateKey, archive.publicKey, grant, info, aad, source.publicKey), 'secure message');
    await assert.rejects(secure.open(archive.privateKey, archive.publicKey, grant, info, aad, other.publicKey));
    await assert.rejects(secure.open(archive.privateKey, archive.publicKey, grant, `${info}!`, aad, source.publicKey));
    await assert.rejects(secure.open(other.privateKey, other.publicKey, grant, info, aad, source.publicKey));
    const bad = Buffer.from(grant.ciphertext, 'base64'); bad[0] ^= 1;
    await assert.rejects(secure.open(archive.privateKey, archive.publicKey, { enc: grant.enc, ciphertext: b64(bad) }, info, aad, source.publicKey));
  }
});

test('legacy PKCS8 conversion retains the same raw identity', async () => {
  const pair = nodeCrypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  const key = await secure.importLegacy(b64(pair.publicKey.export({ format: 'der', type: 'spki' })),
    b64(pair.privateKey.export({ format: 'der', type: 'pkcs8' })));
  assert.equal(key.privateKey, b64(Buffer.from(pair.privateKey.export({ format: 'jwk' }).d, 'base64url')));
  await secure.verify(await secure.sign(key.privateKey, 'migration'), 'migration', key.publicKey);
});
