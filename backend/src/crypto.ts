import { derivePassword } from './password-derivation';
const encoder = new TextEncoder();

export class AuthHttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string
  ) {
    super(message);
  }
}

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export function assertValidEmail(email: string): void {
  if (email.length < 3 || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new AuthHttpError(400, "invalid_email", "请输入有效邮箱");
  }
}

export async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(input));
  return [...new Uint8Array(digest)].map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

export async function hashSecret(value: string, pepper: string): Promise<string> {
  return sha256Hex(`${value}.${pepper}`);
}

export function createPasswordSalt(): string {
  const bytes = new Uint8Array(16);
  crypto.getRandomValues(bytes);
  return bytesToBase64URL(bytes);
}

export async function hashPassword(password: string, salt: string, pepper: string): Promise<string> {
  const iterations = 210_000;
  const bits = await derivePassword(password, salt, pepper, iterations);
  return `pbkdf2_sha256$${iterations}$${salt}$${bytesToBase64URL(new Uint8Array(bits))}`;
}

export async function verifyPassword(password: string, encodedHash: string, pepper: string): Promise<boolean> {
  const parts = encodedHash.split("$");
  if (parts.length !== 4 || parts[0] !== "pbkdf2_sha256") {
    return false;
  }
  const [, iterationsText, salt, expected] = parts;
  const iterations = Number(iterationsText);
  if (!Number.isSafeInteger(iterations) || iterations < 100_000 || iterations > 1_000_000) {
    return false;
  }
  const bits = await derivePassword(password, salt, pepper, iterations);
  return constantTimeEqualString(bytesToBase64URL(new Uint8Array(bits)), expected);
}

export async function hashEmail(email: string, pepper: string): Promise<string> {
  return sha256Hex(`email.${email}.${pepper}`);
}

export function createNumericCode(): string {
  const bytes = new Uint32Array(1);
  crypto.getRandomValues(bytes);
  return String(bytes[0] % 1_000_000).padStart(6, "0");
}

export function createOpaqueToken(prefix: string): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  const encoded = btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
  return `${prefix}_${encoded}`;
}

export function constantTimeEqualHex(left: string, right: string): boolean {
  if (left.length !== right.length || left.length % 2 !== 0) {
    return false;
  }
  const leftBytes = hexToBytes(left);
  const rightBytes = hexToBytes(right);
  let diff = 0;
  for (let index = 0; index < leftBytes.length; index += 1) {
    diff |= leftBytes[index] ^ rightBytes[index];
  }
  return diff === 0;
}

export function constantTimeEqualString(left: string, right: string): boolean {
  const max = Math.max(left.length, right.length);
  let diff = left.length ^ right.length;
  for (let index = 0; index < max; index += 1) {
    diff |= (left.charCodeAt(index) || 0) ^ (right.charCodeAt(index) || 0);
  }
  return diff === 0;
}

export function addSeconds(date: Date, seconds: number): string {
  return new Date(date.getTime() + seconds * 1000).toISOString();
}

export function parsePositiveSeconds(value: string | undefined, fallback: number): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function hexToBytes(value: string): Uint8Array {
  const bytes = new Uint8Array(value.length / 2);
  for (let index = 0; index < bytes.length; index += 1) {
    bytes[index] = Number.parseInt(value.slice(index * 2, index * 2 + 2), 16);
  }
  return bytes;
}

function bytesToBase64URL(bytes: Uint8Array): string {
  return btoa(String.fromCharCode(...bytes))
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "");
}
