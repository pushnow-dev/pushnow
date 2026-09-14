// Exercises actual ArkTS service sources with only platform/storage/network adapters mocked.
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import assert from 'node:assert/strict';
const require = createRequire(import.meta.url);
const ts = require('../../backend/node_modules/typescript');
const services = new URL('../entry/src/main/ets/services/', import.meta.url);
function load(name, imports) {
 const source = readFileSync(new URL(`${name}.ets`, services), 'utf8');
 const js = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS } }).outputText;
 const exports = {};
 new Function('require', 'exports', js)(id => {
  if (!(id in imports)) throw new Error(`Unexpected import ${id}`);
  return imports[id];
 }, exports);
 return exports;
}
function deferred() {
 let resolve, reject;
 const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
 return { promise, resolve, reject };
}
function response(access = 'access-1', user = 'user-1', seconds = 3600) {
 return { access_token: access, refresh_token: `refresh-${access}`, expires_in_seconds: seconds,
  user: { id: user, email: `${user}@example.com`, email_verified_at: '2026-09-13T00:00:00Z' } };
}
async function fixture() {
 const calls = [], saved = new Map();
 let handler = async path => path.includes('/login') || path.includes('/verify') ? response() : {};
 const api = load('ApiClient', {
  './AppConfig': { API_BASE_URL: 'https://test.invalid' },
  '@kit.NetworkKit': { http: { RequestMethod: { GET: 'GET', POST: 'POST', PUT: 'PUT', DELETE: 'DELETE' },
   createHttp: () => ({ destroy() {}, async request(url, options) {
    const path = new URL(url).pathname, body = options.extraData ? JSON.parse(options.extraData) : undefined;
    calls.push({ path, body, header: options.header });
    const data = await handler(path, body, options.header);
    return { responseCode: 200, result: JSON.stringify(data) };
   } }),
  } },
 }).apiClient;
 class AuthSession { accessToken = ''; refreshToken = ''; userID = ''; email = ''; verified = false; }
 const auth = new (load('AuthService', {
  '../models/JiZhiModels': { AuthSession }, './ApiClient': { apiClient: api },
  '@kit.ArkData': { preferences: { getPreferences: async () => ({ getSync: (_key, fallback) => fallback, clear: async () => {}, flush: async () => {} }) } },
  './DeviceService': { deviceService: { deviceId: 'install', activateUserDevice: async () => {}, useInstallationDevice() {} } },
  './SecureDeviceEnrollmentService': { secureDeviceEnrollmentService: { clear() {} } },
  './SecureStorage': { secureStorage: { initialize: async () => {}, read: async key => saved.get(key) ?? '',
   write: async (key, value) => saved.set(key, value), remove: async key => saved.delete(key) } },
 }).AuthService)();
 await auth.initialize({});
 return { auth, api, calls, saved, handle(fn) { handler = fn; } };
}

test('parses snake_case login, persists secure session and sends Harmony client metadata', async () => {
 const f = await fixture();
 const session = await f.auth.loginWithPassword(' User@Example.com ', 'password');
 assert.equal(session.accessToken, 'access-1'); assert.equal(session.userID, 'user-1');
 assert.equal(session.verified, true);
 assert.equal(f.calls[0].body.email, 'user@example.com');
 assert.equal(f.calls[0].body.client.platform, 'harmony');
 assert.equal(JSON.parse(f.saved.get('auth-session')).session.refreshToken, 'refresh-access-1');
});
test('old captured token resolves across refresh and refresh is single flight', async () => {
 const f = await fixture(), gate = deferred();
 f.handle(async path => path.includes('/login') ? response('old', 'user-1', 1) : path.includes('/refresh') ? gate.promise : { ok: true });
 await f.auth.loginWithPassword('a@b.com', 'password');
 const requests = [f.api.get('/v2/messages', 'old'), f.api.get('/v2/devices', 'old')];
 await new Promise(resolve => setImmediate(resolve));
 assert.equal(f.calls.filter(c => c.path.includes('/refresh')).length, 1);
 gate.resolve(response('new'));
 await Promise.all(requests);
 await f.api.get('/v2/archive', 'old');
 assert.deepEqual(f.calls.filter(c => c.path.startsWith('/v2')).map(c => c.header.Authorization), ['Bearer new', 'Bearer new', 'Bearer new']);
});
test('logout during refresh never resurrects session and revokes rotated token', async () => {
 const f = await fixture(), gate = deferred();
 f.handle(async path => path.includes('/login') ? response('old', 'user-1', 1) : path.includes('/refresh') ? gate.promise : {});
 await f.auth.loginWithPassword('a@b.com', 'password');
 const refresh = f.auth.requireAccessToken();
 const rejected = assert.rejects(refresh, /session_changed/);
 await f.auth.logout();
 gate.resolve(response('rotated'));
 await rejected;
 assert.equal(f.auth.current.verified, false); assert.equal(f.saved.has('auth-session'), false);
 assert.ok(f.calls.some(c => c.path.endsWith('/logout') && c.body.refresh_token === 'refresh-rotated'));
});
test('new login refresh proceeds independently of old pending refresh', async () => {
 const f = await fixture(), oldGate = deferred(); let loginCount = 0;
 f.handle(async (path, body) => {
  if (path.includes('/login')) return ++loginCount === 1 ? response('old', 'user-1', 1) : response('second', 'user-2', 1);
  if (path.includes('/refresh')) return body.refresh_token === 'refresh-old' ? oldGate.promise : response('second-new', 'user-2');
  return {};
 });
 await f.auth.loginWithPassword('one@b.com', 'password');
 const old = f.auth.requireAccessToken(), rejected = assert.rejects(old, /session_changed/);
 await f.auth.logout(); await f.auth.loginWithPassword('two@b.com', 'password');
 assert.equal(await f.auth.requireAccessToken(), 'second-new');
 oldGate.resolve(response('old-rotated', 'user-1')); await rejected;
 assert.equal(f.auth.current.userID, 'user-2'); assert.equal(f.auth.current.accessToken, 'second-new');
 await assert.rejects(f.api.get('/v2/messages', 'old'), /session_changed/);
});
test('remote logout failure still clears local session and persisted credentials', async () => {
 const f = await fixture(); await f.auth.loginWithPassword('a@b.com', 'password');
 f.handle(async () => { throw new Error('offline'); });
 await assert.rejects(f.auth.logout(), /Signed out locally/);
 assert.equal(f.auth.current.verified, false); assert.equal(f.saved.has('auth-session'), false);
 await assert.rejects(f.auth.requireAccessToken(), /login_required/);
});
