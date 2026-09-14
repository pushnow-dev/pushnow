import { afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { harmonyPushConfigured, sendHarmonyPush } from '../src/harmony-push';
import { base64 } from '../src/secure-validation';

let env: Env;
beforeAll(async () => {
 const pair = await crypto.subtle.generateKey({ name: 'RSA-PSS', modulusLength: 2048,
  publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, ['sign', 'verify']);
 env = { PUSH_TOKEN_ENCRYPTION_KEY: 'configured', HARMONY_PUSH_PROJECT_ID: 'project',
  HARMONY_PUSH_KEY_ID: 'key', HARMONY_PUSH_SUB_ACCOUNT: 'account',
  HARMONY_PUSH_PRIVATE_KEY: base64(new Uint8Array(await crypto.subtle.exportKey('pkcs8', pair.privateKey))) } as Env;
});
afterEach(() => vi.restoreAllMocks());
const expiry = () => new Date(Date.now() + 60000).toISOString();
const payload = { aps: { alert: { title: 'private title' } }, secure_v2: {
 message_id: 'message', device_id: 'device', ciphertext: 'encrypted-preview'.repeat(300),
} };
describe('HarmonyOS V3 privacy and failure handling', () => {
 it('sends routing IDs with generic content even for a large encrypted preview', async () => {
  const request = vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(JSON.stringify({ code: '80000000' })));
  expect(await sendHarmonyPush(env, 'token', payload, expiry())).toEqual({ status: 200, reason: 'accepted' });
  const body = JSON.parse(String(request.mock.calls[0][1]?.body));
  expect(body.payload.notification.clickAction.data).toEqual({ message_id: 'message', device_id: 'device', protocol: 'secure_v2' });
  expect(JSON.stringify(body)).not.toContain('private title');
  expect(JSON.stringify(body)).not.toContain('encrypted-preview');
  expect(body.pushOptions.testMessage).toBe(false);
 });
 it('does not send expired or non-secure payloads', async () => {
  const request = vi.spyOn(globalThis, 'fetch');
  expect(await sendHarmonyPush(env, 'token', payload, '2000-01-01T00:00:00Z')).toMatchObject({ status: 410 });
  expect(await sendHarmonyPush(env, 'token', { title: 'plaintext' }, expiry())).toMatchObject({ status: 400 });
  expect(request).not.toHaveBeenCalled();
 });
 it('sanitizes provider error text while preserving retryable HTTP status', async () => {
  vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(JSON.stringify({ code: 'secret-token', msg: 'private-content' }), { status: 503 }));
  expect(await sendHarmonyPush(env, 'token', payload, expiry())).toEqual({ status: 503, reason: 'harmony_http_503' });
 });
 it('does not consider legacy HMS credentials a configured Harmony provider', () => {
  expect(harmonyPushConfigured({ PUSH_TOKEN_ENCRYPTION_KEY: 'key', HARMONY_PUSH_PROJECT_ID: 'project' } as Env)).toBe(false);
  expect(harmonyPushConfigured(env)).toBe(true);
 });
 it('excludes recipient tokens from the 4096-byte message size limit', async () => {
  const request = vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(JSON.stringify({ code: '80000000' })));
  expect(await sendHarmonyPush(env, 'h'.repeat(4096), payload, expiry())).toMatchObject({ status: 200 });
  const body = String(request.mock.calls[0][1]?.body);
  expect(new TextEncoder().encode(body).length).toBeGreaterThan(4096);
  expect(JSON.parse(body).target.token[0]).toHaveLength(4096);
 });
 it.each([
  ['80300007', 400, 'BadDeviceToken'], ['80300008', 413, 'PayloadTooLarge'],
  ['80300029', 429, 'harmony_80300029'], ['81000001', 503, 'harmony_81000001'],
 ])('maps Huawei application code %s to delivery policy', async (code, status, reason) => {
  vi.spyOn(globalThis, 'fetch').mockResolvedValue(new Response(JSON.stringify({ code, msg: 'never retain token or provider text' })));
  expect(await sendHarmonyPush(env, 'token', payload, expiry())).toEqual({ status, reason });
 });
});
