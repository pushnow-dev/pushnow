import type { SessionRecord, UserRecord } from './contracts';
export type SecureSession = { user: UserRecord; session: SessionRecord };
export type Device = {
 id: string; user_id: string; name: string; platform: string; public_key: string; certificate: string | null;
 status: 'pending' | 'active' | 'revoked'; notifications_enabled: number; last_seen_at: string; created_at: string;
 approval_enc: string | null; approval_ciphertext: string | null;
 system_version?: string | null; app_version?: string | null; model?: string | null;
};
export function publicDevice(device: Device) {
 const { approval_enc, approval_ciphertext, ...result } = device;
 return { ...result, notifications_enabled: Boolean(result.notifications_enabled) };
}
declare global {
 interface Env {
  PUSH_TOKEN_ENCRYPTION_KEY?: string;
  APNS_PRIVATE_KEY?: string;
  APNS_KEY_ID?: string;
  APNS_TEAM_ID?: string;
  APNS_TOPIC?: string;
  HARMONY_PUSH_PRIVATE_KEY?: string;
  HARMONY_PUSH_KEY_ID?: string;
  HARMONY_PUSH_SUB_ACCOUNT?: string;
  HARMONY_PUSH_TEST_MESSAGE?: string;
  HARMONY_PUSH_PROJECT_ID?: string;
 }
}
