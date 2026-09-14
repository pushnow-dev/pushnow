import { cryptoFramework as crypto } from '@kit.CryptoArchitectureKit';
import util from '@ohos.util';

export class SecureKey {
  publicKey: string = '';
  privateKey: string = '';
}
export class SecureGrant {
  enc: string = '';
  ciphertext: string = '';
}

// RFC 9180: DHKEM(P-256, HKDF-SHA256), HKDF-SHA256, AES-256-GCM.
// One-shot messages use sequence number zero, matching CryptoKit HPKE.
export class SecureCrypto {
  bytes(text: string): Uint8Array { return new util.TextEncoder().encodeInto(text); }
  encode(data: Uint8Array): string { return new util.Base64Helper().encodeToStringSync(data); }
  decode(text: string): Uint8Array { return new util.Base64Helper().decodeSync(text); }
  utf8(data: Uint8Array): string {
    return util.TextDecoder.create('utf-8', { fatal: true }).decodeWithStream(data);
  }
  concat(parts: Uint8Array[]): Uint8Array {
    let size = 0;
    parts.forEach(part => { size += part.length; });
    const output = new Uint8Array(size);
    let offset = 0;
    parts.forEach(part => { output.set(part, offset); offset += part.length; });
    return output;
  }
  text(kind: string, user: string, id: string, key: string): string {
    return `pushnow-${kind}-v1\n${user}\n${id}\n${key}`;
  }
  private hex(value: string): Uint8Array {
    const output = new Uint8Array(value.length / 2);
    for (let i = 0; i < output.length; i++) output[i] = parseInt(value.slice(i * 2, i * 2 + 2), 16);
    return output;
  }
  private publicDer(publicKey: string): Uint8Array {
    const raw = this.decode(publicKey);
    if (raw.length !== 65 || raw[0] !== 4) throw new Error('invalid_p256_public_key');
    return this.concat([this.hex('3059301306072a8648ce3d020106082a8648ce3d030107034200'), raw]);
  }
  private privateDer(privateKey: string): Uint8Array {
    const raw = this.decode(privateKey);
    if (raw.length !== 32) throw new Error('invalid_p256_private_key');
    return this.concat([this.hex('3041020100301306072a8648ce3d020106082a8648ce3d030107042730250201010420'), raw]);
  }
  private async keyPair(privateKey: string, publicKey?: string): Promise<crypto.KeyPair> {
    return crypto.createAsyKeyGenerator('ECC256').convertKey(
      publicKey ? { data: this.publicDer(publicKey) } : null, { data: this.privateDer(privateKey) });
  }
  async generateKey(): Promise<SecureKey> {
    const pair = await crypto.createAsyKeyGenerator('ECC256').generateKeyPair();
    const publicDer = pair.pubKey.getEncoded().data;
    const scalar = pair.priKey.getAsyKeySpec(crypto.AsyKeySpecItem.ECC_SK_BN) as bigint;
    const key = new SecureKey();
    key.publicKey = this.encode(publicDer.slice(publicDer.length - 65));
    key.privateKey = this.encode(this.hex(scalar.toString(16).padStart(64, '0')));
    return key;
  }
  async importLegacy(publicDer: string, privateDer: string): Promise<SecureKey> {
    const pair = await crypto.createAsyKeyGenerator('ECC256').convertKey(
      { data: this.decode(publicDer) }, { data: this.decode(privateDer) });
    const scalar = pair.priKey.getAsyKeySpec(crypto.AsyKeySpecItem.ECC_SK_BN) as bigint;
    const encoded = pair.pubKey.getEncoded().data;
    const key = new SecureKey();
    key.publicKey = this.encode(encoded.slice(encoded.length - 65));
    key.privateKey = this.encode(this.hex(scalar.toString(16).padStart(64, '0')));
    return key;
  }
  async sign(privateKey: string, content: string): Promise<string> {
    const pair = await this.keyPair(privateKey);
    const signer = crypto.createSign('ECC|SHA256');
    await signer.init(pair.priKey);
    const der = (await signer.sign({ data: this.bytes(content) })).data;
    if (der.length === 64) return this.encode(der);
    if (der[0] !== 0x30 || der[2] !== 2) throw new Error('invalid_signature');
    const rLength = der[3];
    const sOffset = 4 + rLength;
    if (der[sOffset] !== 2) throw new Error('invalid_signature');
    const r = der.slice(4, sOffset);
    const s = der.slice(sOffset + 2, sOffset + 2 + der[sOffset + 1]);
    const raw = new Uint8Array(64);
    const rBytes = r.length === 33 && r[0] === 0 ? r.slice(1) : r;
    const sBytes = s.length === 33 && s[0] === 0 ? s.slice(1) : s;
    if (rBytes.length > 32 || sBytes.length > 32) throw new Error('invalid_signature');
    raw.set(rBytes, 32 - rBytes.length);
    raw.set(sBytes, 64 - sBytes.length);
    return this.encode(raw);
  }
  private integer(raw: Uint8Array): Uint8Array {
    let start = 0;
    while (start < raw.length - 1 && raw[start] === 0) start++;
    const bytes = raw.slice(start);
    const value = bytes[0] >= 128 ? this.concat([new Uint8Array([0]), bytes]) : bytes;
    return this.concat([new Uint8Array([2, value.length]), value]);
  }
  async verify(signature: string, content: string, publicKey: string): Promise<void> {
    const raw = this.decode(signature);
    if (raw.length !== 64) throw new Error('invalid_signature');
    const body = this.concat([this.integer(raw.slice(0, 32)), this.integer(raw.slice(32))]);
    const der = this.concat([new Uint8Array([0x30, body.length]), body]);
    const pair = await crypto.createAsyKeyGenerator('ECC256').convertKey({ data: this.publicDer(publicKey) }, null);
    const verifier = crypto.createVerify('ECC|SHA256');
    await verifier.init(pair.pubKey);
    if (!await verifier.verify({ data: this.bytes(content) }, { data: der })) throw new Error('certificate_invalid');
  }
  async fingerprint(publicKey: string): Promise<string> {
    const md = crypto.createMd('SHA256');
    await md.update({ data: this.decode(publicKey) });
    return Array.from((await md.digest()).data).map(value => value.toString(16).padStart(2, '0')).join('');
  }
  async digest(content: string): Promise<string> {
    const md = crypto.createMd('SHA256');
    await md.update({ data: this.bytes(content) });
    return Array.from((await md.digest()).data).map(value => value.toString(16).padStart(2, '0')).join('');
  }
  private async dh(privateKey: string, publicKey: string): Promise<Uint8Array> {
    const own = await this.keyPair(privateKey);
    const peer = await crypto.createAsyKeyGenerator('ECC256').convertKey({ data: this.publicDer(publicKey) }, null);
    return (await crypto.createKeyAgreement('ECC256').generateSecret(own.priKey, peer.pubKey)).data;
  }
  private async hmac(key: Uint8Array, data: Uint8Array): Promise<Uint8Array> {
    const sym = await crypto.createSymKeyGenerator('HMAC').convertKey({ data: key.length ? key : new Uint8Array(32) });
    const mac = crypto.createMac('SHA256');
    await mac.init(sym);
    await mac.update({ data });
    return (await mac.doFinal()).data;
  }
  private suite(kem: boolean): Uint8Array {
    return kem ? this.concat([this.bytes('KEM'), new Uint8Array([0, 16])]) :
      this.concat([this.bytes('HPKE'), new Uint8Array([0, 16, 0, 1, 0, 2])]);
  }
  private async extract(salt: Uint8Array, label: string, ikm: Uint8Array, kem: boolean): Promise<Uint8Array> {
    return this.hmac(salt, this.concat([this.bytes('HPKE-v1'), this.suite(kem), this.bytes(label), ikm]));
  }
  private async expand(prk: Uint8Array, label: string, info: Uint8Array, length: number, kem: boolean): Promise<Uint8Array> {
    const labeled = this.concat([new Uint8Array([length >> 8, length & 255]), this.bytes('HPKE-v1'),
      this.suite(kem), this.bytes(label), info]);
    return (await this.hmac(prk, this.concat([labeled, new Uint8Array([1])]))).slice(0, length);
  }
  private async context(dh: Uint8Array, kemContext: Uint8Array, info: string, mode: number): Promise<HpkeContext> {
    const empty = new Uint8Array(0);
    const eae = await this.extract(empty, 'eae_prk', dh, true);
    const shared = await this.expand(eae, 'shared_secret', kemContext, 32, true);
    const pskHash = await this.extract(empty, 'psk_id_hash', empty, false);
    const infoHash = await this.extract(empty, 'info_hash', this.bytes(info), false);
    const context = this.concat([new Uint8Array([mode]), pskHash, infoHash]);
    const secret = await this.extract(shared, 'secret', empty, false);
    const result = new HpkeContext();
    result.key = await this.expand(secret, 'key', context, 32, false);
    result.nonce = await this.expand(secret, 'base_nonce', context, 12, false);
    return result;
  }
  async aesOpen(key: Uint8Array, nonce: Uint8Array, encrypted: Uint8Array, aad: string): Promise<Uint8Array> {
    if (encrypted.length < 16 || key.length !== 32 || nonce.length !== 12) throw new Error('invalid_ciphertext');
    const sym = await crypto.createSymKeyGenerator('AES256').convertKey({ data: key });
    const params: crypto.GcmParamsSpec = { algName: 'GcmParamsSpec', iv: { data: nonce },
      aad: { data: this.bytes(aad) }, authTag: { data: encrypted.slice(-16) } };
    const cipher = crypto.createCipher('AES256|GCM|NoPadding');
    await cipher.init(crypto.CryptoMode.DECRYPT_MODE, sym, params);
    return (await cipher.doFinal({ data: encrypted.slice(0, -16) })).data;
  }
  async open(privateKey: string, publicKey: string, grant: SecureGrant, info: string, aad: string,
    senderPublicKey?: string): Promise<string> {
    let dh = await this.dh(privateKey, grant.enc);
    let kem = this.concat([this.decode(grant.enc), this.decode(publicKey)]);
    if (senderPublicKey) {
      dh = this.concat([dh, await this.dh(privateKey, senderPublicKey)]);
      kem = this.concat([kem, this.decode(senderPublicKey)]);
    }
    const ctx = await this.context(dh, kem, info, senderPublicKey ? 2 : 0);
    return this.utf8(await this.aesOpen(ctx.key, ctx.nonce, this.decode(grant.ciphertext), aad));
  }
  async seal(publicKey: string, plaintext: string, info: string, aad: string): Promise<SecureGrant> {
    const ephemeral = await this.generateKey();
    const ctx = await this.context(await this.dh(ephemeral.privateKey, publicKey),
      this.concat([this.decode(ephemeral.publicKey), this.decode(publicKey)]), info, 0);
    const sym = await crypto.createSymKeyGenerator('AES256').convertKey({ data: ctx.key });
    const params: crypto.GcmParamsSpec = { algName: 'GcmParamsSpec', iv: { data: ctx.nonce },
      aad: { data: this.bytes(aad) }, authTag: { data: new Uint8Array(16) } };
    const cipher = crypto.createCipher('AES256|GCM|NoPadding');
    await cipher.init(crypto.CryptoMode.ENCRYPT_MODE, sym, params);
    const ciphertext = (await cipher.doFinal({ data: this.bytes(plaintext) })).data;
    const grant = new SecureGrant();
    grant.enc = ephemeral.publicKey;
    // CryptoFramework returns ciphertext followed by its 16-byte GCM tag.
    grant.ciphertext = this.encode(ciphertext);
    return grant;
  }
}
class HpkeContext {
  key: Uint8Array = new Uint8Array();
  nonce: Uint8Array = new Uint8Array();
}
export const secureCrypto = new SecureCrypto();
