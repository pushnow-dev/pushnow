import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const ts = require('../../backend/node_modules/typescript');
const source = readFileSync(new URL('../entry/src/main/ets/services/DeviceService.ets', import.meta.url), 'utf8');
const js = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS } }).outputText;
const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
async function fixture({ status = 'active', enabled = true, consent = true } = {}) {
 const puts = [], store = new Map([['installationId', id]]); let tokenCalls = 0;
 let onToken = async () => 'harmony-token-0123456789';
 class SecureDevice {}
 const imports = {
  '@kit.ArkData': { preferences: { getPreferences: async () => ({
   getSync: (key, fallback) => store.get(key) ?? fallback, putSync: (key, value) => store.set(key, value), flush: async () => {},
  }) } },
  '@kit.CryptoArchitectureKit': { cryptoFramework: {} },
  '@kit.PushKit': { pushService: { getToken: async () => { tokenCalls++; return onToken(); } } },
  '@kit.NotificationKit': { notificationManager: { requestEnableNotification: async () => {}, isNotificationEnabled: async () => consent } },
  '../models/JiZhiModels': { SecureDevice },
  './ApiClient': { apiClient: {
   get: async () => ({ devices: [{ id, user_id: 'user', name: 'Harmony', platform: 'harmony', status, notifications_enabled: enabled }] }),
   put: async (path, payload, token) => {
    // registerPush rejects fields outside this list, independent of snake/camel conversion.
    const wire = JSON.parse(JSON.stringify(payload));
    assert.deepEqual(Object.keys(wire).sort(), ['appVersion', 'environment', 'token']);
    puts.push({ path, wire, token });
   },
  } },
 };
 const exports = {};
 new Function('require', 'exports', js)(name => {
  assert.ok(name in imports, `Unexpected import ${name}`); return imports[name];
 }, exports);
 const device = new exports.DeviceService(); await device.initialize({});
 return { device, puts, tokenCalls: () => tokenCalls, onToken(fn) { onToken = fn; } };
}
test('secure registration and refresh use only backend accepted push fields', async () => {
 const f = await fixture();
 assert.equal(await f.device.registerSecurePush('access'), 'harmony-token-0123456789');
 await f.device.updatePushToken('access', 'rotated-harmony-token');
 assert.equal(f.puts.length, 2);
 assert.ok(f.puts.every(call => call.path === `/v1/secure/devices/${id}/push` && call.token === 'access'));
 assert.equal(f.puts[0].wire.environment, 'production');
 assert.equal(f.puts[1].wire.token, 'rotated-harmony-token');
});
test('pending or disabled devices and denied OS permission never obtain or bind tokens', async () => {
 for (const options of [{ status: 'pending' }, { enabled: false }, { consent: false }]) {
  const f = await fixture(options);
  await assert.rejects(f.device.registerSecurePush('access'), /device_not_approved|device_notifications_disabled|notification_permission_denied/);
  assert.equal(f.tokenCalls(), 0); assert.equal(f.puts.length, 0);
 }
});
test('device change during native token retrieval cannot bind to the new account', async () => {
 const f = await fixture();
 f.onToken(async () => { f.device.deviceId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'; return 'token'; });
 await assert.rejects(f.device.registerSecurePush('access'), /session_changed/);
 assert.equal(f.puts.length, 0);
});
