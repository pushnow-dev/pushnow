import { base64, fail } from './secure-validation';

// HarmonyOS NEXT V3 uses service-account PS256 JWTs, not HMS Android OAuth tokens.
export function harmonyPushConfigured(env: Env) {
 return Boolean(env.PUSH_TOKEN_ENCRYPTION_KEY && env.HARMONY_PUSH_PRIVATE_KEY &&
  env.HARMONY_PUSH_KEY_ID && env.HARMONY_PUSH_SUB_ACCOUNT && env.HARMONY_PUSH_PROJECT_ID);
}
function url64(value: Uint8Array) {
 return base64(value).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}
export async function harmonyAuthorization(env: Env) {
 const encode = (value: unknown) => url64(new TextEncoder().encode(JSON.stringify(value)));
 const iat = Math.floor(Date.now() / 1000);
 const unsigned = `${encode({ alg: 'PS256', typ: 'JWT', kid: env.HARMONY_PUSH_KEY_ID })}.${encode({
  iss: env.HARMONY_PUSH_SUB_ACCOUNT, aud: 'https://oauth-login.cloud.huawei.com/oauth2/v3/token', iat, exp: iat + 3600,
 })}`;
 const pem = env.HARMONY_PUSH_PRIVATE_KEY!.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
 const key = await crypto.subtle.importKey('pkcs8', Uint8Array.from(atob(pem), c => c.charCodeAt(0)),
  { name: 'RSA-PSS', hash: 'SHA-256' }, false, ['sign']);
 const signature = await crypto.subtle.sign({ name: 'RSA-PSS', saltLength: 32 }, key, new TextEncoder().encode(unsigned));
 return `${unsigned}.${url64(new Uint8Array(signature))}`;
}

export async function sendHarmonyPush(env: Env, token: string, payload: unknown, expires: string) {
 if (!harmonyPushConfigured(env)) fail(503, 'harmony_push_not_configured');
 // Normal notifications wake archive sync. Only routing IDs reach Huawei; never content or APNs alerts.
 const secure = payload as { secure_v2?: unknown; secure?: unknown };
 const envelope = (secure?.secure_v2 ?? secure?.secure) as { message_id?: unknown; device_id?: unknown } | undefined;
 if (typeof envelope?.message_id !== 'string' || envelope.message_id.length > 64) return { status: 400, reason: 'invalid_secure_payload' };
 const data = { message_id: envelope.message_id,
  ...(typeof envelope.device_id === 'string' && envelope.device_id.length <= 64 ? { device_id: envelope.device_id } : {}),
  protocol: secure.secure_v2 ? 'secure_v2' : 'secure' }; 
 const remaining = Math.floor((Date.parse(expires) - Date.now()) / 1000);
 if (!Number.isFinite(remaining) || remaining <= 0) return { status: 410, reason: 'transport_expired' };
 const message = {
  payload: { notification: {
   title: 'PushNow', body: 'You have a new encrypted reminder.',
   clickAction: { actionType: 0, data },
  } },
  pushOptions: { ttl: Math.min(1296000, remaining), testMessage: env.HARMONY_PUSH_TEST_MESSAGE === 'true' },
 };
 // Huawei's 4096-byte limit explicitly excludes recipient tokens.
 if (new TextEncoder().encode(JSON.stringify(message)).length > 4096) return { status: 413, reason: 'PayloadTooLarge' };
 const body = JSON.stringify({ ...message, target: { token: [token] } });
 const response = await fetch(`https://push-api.cloud.huawei.com/v3/${encodeURIComponent(env.HARMONY_PUSH_PROJECT_ID!)}/messages:send`, {
  method: 'POST', headers: { authorization: `Bearer ${await harmonyAuthorization(env)}`,
   'content-type': 'application/json; charset=UTF-8', 'push-type': '0' },
  body, signal: AbortSignal.timeout(15000),
 });
 const result = await response.json().catch(() => null) as { code?: unknown } | null;
 const code = typeof result?.code === 'string' && /^\d{8}$/.test(result.code) ? result.code : `http_${response.status}`;
 if (response.ok && code === '80000000') return { status: 200, reason: 'accepted' };
 if (code === '80300007') return { status: 400, reason: 'BadDeviceToken' };
 if (code === '80300008') return { status: 413, reason: 'PayloadTooLarge' };
 if (code === '80300029') return { status: 429, reason: `harmony_${code}` };
 if (code === '81000001') return { status: 503, reason: `harmony_${code}` };
 // Provider text may include tokens or customer content; retain only numeric error codes.
 return { status: response.ok ? 400 : response.status, reason: `harmony_${code}` };
}
