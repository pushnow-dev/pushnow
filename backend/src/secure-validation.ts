import { AuthHttpError } from './crypto';

export function fail(status: number, code: string): never { throw new AuthHttpError(status, code, code); }
export function str(value: unknown, max = 200): string {
  if (typeof value !== 'string' || !value.trim() || value.length > max) fail(400, 'invalid_field');
  return value;
}
export function uuid(value: unknown): string {
  const result = str(value, 36);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(result)) fail(400, 'invalid_id');
  return result;
}
export function bytes(value: unknown, min: number, max = min): Uint8Array<ArrayBuffer> {
  const encoded = str(value, Math.ceil(max / 3) * 4);
  try {
    const decoded = Uint8Array.from(atob(encoded), c => c.charCodeAt(0));
    if (decoded.length < min || decoded.length > max || base64(decoded) !== encoded) fail(400, 'invalid_encoding');
    return decoded;
  } catch { return fail(400, 'invalid_encoding'); }
}
export function base64(value: Uint8Array): string { return btoa(String.fromCharCode(...value)); }
export async function verify(publicKey: unknown, signature: unknown, content: string): Promise<void> {
  try {
    const key = await crypto.subtle.importKey('raw', bytes(publicKey, 65), { name: 'ECDSA', namedCurve: 'P-256' }, false, ['verify']);
    if (!await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, key, bytes(signature, 64), new TextEncoder().encode(content))) fail(403, 'invalid_signature');
  } catch { fail(403, 'invalid_signature'); }
}
export function fields(input: Record<string, unknown>, allowed: string[]): void {
  if (Object.keys(input).some(key => !allowed.includes(key))) fail(400, 'unexpected_field');
}
export async function digest(value: string): Promise<string> {
  return base64(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))));
}
