import assert from 'node:assert/strict';
import { test } from 'node:test';
import fs from 'node:fs';
import vm from 'node:vm';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const ts = require('../../backend/node_modules/typescript');
const source = fs.readFileSync(new URL('../entry/src/main/ets/services/SecureDeviceEnrollmentService.ets', import.meta.url), 'utf8').replace(/^import .*;\n/gm, '');
const compiled = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS } }).outputText;
function fixture() {
  const vault = new Map();
  const legacy = new Map();
  const session = { verified: true, userID: 'user', accessToken: 'token' };
  const device = { id: 'device', user_id: 'user', public_key: 'device-public', status: 'active', certificate: 'certificate', name: 'Harmony', platform: 'harmony' };
  const remote = { identity: 'root-public', device };
  let keyNumber = 0;
  const crypto = {
    async generateKey() { keyNumber++; return { privateKey: `private-${keyNumber}`, publicKey: 'device-public' }; },
    async sign() { return 'signature'; }, async verify() {},
    async importLegacy(publicDer, privateDer) { return { publicKey: publicDer, privateKey: privateDer }; },
    text(kind, user, id, key) { return `${kind}:${user}:${id}:${key}`; },
    async open() { return JSON.stringify({ identity_private_key: 'root-private' }); }
  };
  const context = { exports: {}, SecureKey: class { privateKey = ''; publicKey = ''; }, SecureDevice: class {},
    HARMONY_PLATFORM: 'harmony', secureCrypto: crypto, deviceInfo: { marketName: 'Test', productModel: 'Test', osFullName: 'HarmonyOS' },
    bundleManager: { BundleFlag: { GET_BUNDLE_INFO_DEFAULT: 0 }, getBundleInfoForSelfSync() { return { versionName: '0.1.0' }; } },
    deviceService: { deviceId: 'device', async activateUserDevice() {}, async restoreUserDevice(user, id) { this.deviceId = id; } },
    preferences: { async getPreferences() { return { getSync(key, fallback) { return legacy.get(key) ?? fallback; },
      async clear() { legacy.clear(); }, async flush() {} }; } },
    secureStorage: { async initialize() {}, async read(key) { return vault.get(key) ?? ''; },
      async write(key, value) { vault.set(key, value); } },
    apiClient: {
      async get(path) { if (path.endsWith('device-challenge')) return { challenge: 'challenge' };
        if (path.endsWith('/approval')) return { approval: { enc: 'enc', ciphertext: 'ciphertext' } };
        return { identity_public_key: remote.identity, devices: [remote.device] }; },
      async post() { return { identity_public_key: remote.identity, device: remote.device }; }
    }, Error, JSON, String, encodeURIComponent };
  vm.runInNewContext(compiled, context);
  return { service: context.exports.secureDeviceEnrollmentService, vault, legacy, remote, session, context };
}

test('snake-case enrollment succeeds, pins root before trust, accepts verified pairing', async () => {
  const f = fixture(); await f.service.initialize({});
  f.remote.device.status = 'pending';
  const pending = await f.service.enroll(f.session);
  assert.equal(pending.publicKey, 'device-public');
  assert.equal(f.service.identityPublicKey(), 'root-public');
  assert.equal(f.service.identityEstablished(), false);
  f.remote.device.status = 'active';
  await f.service.acceptApproval(f.session);
  assert.equal(f.service.identityEstablished(), true);
  assert.equal(f.service.identityPrivateKey(), 'root-private');
});

test('pending pinned root cannot be replaced by server directory or approval', async () => {
  const f = fixture(); await f.service.initialize({});
  f.remote.device.status = 'pending'; await f.service.enroll(f.session);
  f.remote.identity = 'attacker-root';
  await assert.rejects(f.service.enroll(f.session), /identity_changed/);
  f.remote.device.status = 'active';
  await assert.rejects(f.service.acceptApproval(f.session), /device_approval_pending/);
  assert.equal(f.service.identityPrivateKey(), '');
});

test('legacy identity is vaulted before plaintext removal and only matching account imports it', async () => {
  const f = fixture();
  f.legacy.set('devicePublicDer', 'device-public'); f.legacy.set('devicePrivateDer', 'device-private');
  f.legacy.set('identityPublicDer', 'root-public'); f.legacy.set('identityPrivateDer', 'root-private');
  await f.service.initialize({});
  assert.equal(f.legacy.size, 0); assert.ok(f.vault.get('legacy-device-keys'));
  f.remote.device.id = 'legacy-device';
  await f.service.enroll(f.session);
  assert.equal(f.context.deviceService.deviceId, 'legacy-device');
  assert.equal(f.service.identityPrivateKey(), 'root-private');
  assert.equal(f.service.identityEstablished(), true);
  f.service.clear(); f.remote.identity = 'other-root'; f.remote.device.user_id = 'other';
  await f.service.activate({ ...f.session, userID: 'other' });
  assert.equal(f.service.identityPrivateKey(), '');
  assert.ok(f.vault.get('legacy-device-keys'));
});

test('session clear while awaiting challenge aborts enrollment before registration', async () => {
  const f = fixture(); await f.service.initialize({});
  const original = f.context.apiClient.get;
  f.context.apiClient.get = async path => {
    if (path.endsWith('device-challenge')) f.service.clear();
    return original(path);
  };
  let writes = 0; f.context.apiClient.post = async () => { writes++; };
  await assert.rejects(f.service.enroll(f.session), /session_changed/);
  assert.equal(writes, 0);
});
