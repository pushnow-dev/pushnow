import { AuthHttpError } from './crypto';

type AbuseConfig = {
 keyRequestsPerMinute: number;
 suspensionSeconds: number;
 userNotificationsPerMinute: number;
 emailCooldownSeconds: number;
 emailsPerDay: number;
};
export type KeyDecision = { suspendedUntil: number; newlySuspended: boolean };
const minute = 60_000, day = 86_400_000;
export class SenderRateLimitError extends AuthHttpError {
 constructor(code: string, readonly retryAfterSeconds: number) {
  super(429, code, code === 'sender_key_suspended'
   ? 'This key is temporarily suspended because of unusual sending activity.'
   : 'Too many notifications for this account. Try again later.');
 }
}
function positive(value: string | undefined, fallback: number) {
 const parsed = Number(value);
 return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
}
export function senderAbuseConfig(env: Partial<Env>): AbuseConfig {
 return {
  keyRequestsPerMinute: positive(env.SENDER_KEY_REQUESTS_PER_MINUTE, 60),
  suspensionSeconds: positive(env.SENDER_KEY_SUSPENSION_SECONDS, 900),
  userNotificationsPerMinute: positive(env.SENDER_USER_NOTIFICATIONS_PER_MINUTE, 20),
  emailCooldownSeconds: positive(env.SENDER_SECURITY_EMAIL_COOLDOWN_SECONDS, 3600),
  emailsPerDay: positive(env.SENDER_SECURITY_EMAILS_PER_DAY, 3),
 };
}

/** Every reservation is one atomic SQLite statement, or a transactional D1 batch.
 * Never use a read/count followed by an unconditional insert for these limits. */
export class SenderAbuseGuard {
 private readonly config: AbuseConfig;
 constructor(private readonly db: D1Database, env: Partial<Env> = {}, private readonly clock = Date.now) {
  this.config = senderAbuseConfig(env);
 }
 async checkKey(userID: string, keyID: string): Promise<KeyDecision> {
  const now = this.clock(), event = crypto.randomUUID(), mailEvent = crypto.randomUUID();
  const result = await this.db.batch([
   this.db.prepare("DELETE FROM sender_security_events WHERE key_id=? AND kind='key_request' AND occurred_at<=?")
    .bind(keyID, now - minute),
   this.db.prepare(`INSERT INTO sender_security_events(id,user_id,key_id,kind,occurred_at)
    SELECT ?,?,?,'key_request',? WHERE NOT EXISTS
    (SELECT 1 FROM sender_security_state WHERE key_id=? AND suspended_until>?)`)
    .bind(event, userID, keyID, now, keyID, now),
   this.db.prepare(`INSERT INTO sender_security_state(key_id,user_id,suspended_until,suspension_event_id)
    SELECT ?,?,?,? WHERE (SELECT COUNT(*) FROM sender_security_events
     WHERE key_id=? AND kind='key_request' AND occurred_at>?)>?
    ON CONFLICT(key_id) DO UPDATE SET suspended_until=excluded.suspended_until,
     suspension_event_id=excluded.suspension_event_id WHERE sender_security_state.suspended_until<=?`)
    .bind(keyID, userID, now + this.config.suspensionSeconds * 1000, event,
     keyID, now - minute, this.config.keyRequestsPerMinute, now),
   this.db.prepare('SELECT suspended_until,suspension_event_id FROM sender_security_state WHERE key_id=? AND user_id=?')
    .bind(keyID, userID),
   // The suspension, email rate reservation, and durable outbox commit together.
   this.emailReservation(userID, mailEvent, 'email', event),
   this.db.prepare(`INSERT INTO sender_security_mail(id,user_id,suspended_until,created_at,next_attempt_at)
    SELECT ?,user_id,suspended_until,?,? FROM sender_security_state
    WHERE key_id=? AND suspension_event_id=? AND EXISTS
    (SELECT 1 FROM sender_security_events WHERE id=? AND kind='email')`)
    .bind(mailEvent, now, now, keyID, event, mailEvent),
  ]);
  const state = result[3].results[0] as {suspended_until: number; suspension_event_id: string} | undefined;
  return { suspendedUntil: state?.suspended_until ?? 0, newlySuspended: state?.suspension_event_id === event };
 }
 async assertKeyActive(userID: string, keyID: string) {
  const state = await this.db.prepare('SELECT suspended_until FROM sender_security_state WHERE key_id=? AND user_id=?')
   .bind(keyID, userID).first<{suspended_until: number}>();
  this.assertDecision({suspendedUntil: state?.suspended_until ?? 0, newlySuspended: false});
 }
 assertDecision(decision: KeyDecision) {
  if (decision.suspendedUntil > this.clock())
   throw new SenderRateLimitError('sender_key_suspended', Math.max(1, Math.ceil((decision.suspendedUntil - this.clock()) / 1000)));
 }
 /** Reserve immediately before a transport attempt, including scheduled delivery.
  * A false result means defer; do not discard the queued message. */
 async reserveUserNotification(userID: string): Promise<boolean> {
  const now = this.clock();
  await this.db.prepare("DELETE FROM sender_security_events WHERE user_id=? AND kind='notification' AND occurred_at<=?")
   .bind(userID, now - minute).run();
  const result = await this.db.prepare(`INSERT INTO sender_security_events(id,user_id,kind,occurred_at)
   SELECT ?,?,'notification',? WHERE (SELECT COUNT(*) FROM sender_security_events
   WHERE user_id=? AND kind='notification' AND occurred_at>?)<?`)
   .bind(crypto.randomUUID(), userID, now, userID, now - minute, this.config.userNotificationsPerMinute).run();
  return result.meta.changes === 1;
 }
 private emailReservation(userID: string, event: string, kind: 'email' | 'email_attempt', suspensionEvent: string | null = null) {
  const now = this.clock();
  return this.db.prepare(`INSERT INTO sender_security_events(id,user_id,kind,occurred_at)
   SELECT ?,?,?,? WHERE NOT EXISTS(SELECT 1 FROM sender_security_events
   WHERE user_id=? AND kind=? AND occurred_at>?) AND (SELECT COUNT(*)
   FROM sender_security_events WHERE user_id=? AND kind=? AND occurred_at>?)<?
   AND (? IS NULL OR EXISTS(SELECT 1 FROM sender_security_state WHERE user_id=? AND suspension_event_id=?))`)
   .bind(event, userID, kind, now, userID, kind, now - this.config.emailCooldownSeconds * 1000,
    userID, kind, now - day, this.config.emailsPerDay, suspensionEvent, userID, suspensionEvent);
 }
 async reserveSecurityEmail(userID: string): Promise<boolean> {
  const result = await this.emailReservation(userID, crypto.randomUUID(), 'email').run();
  return result.meta.changes === 1;
 }
 /** Mail attempts have an independent rolling limit, so retries and delayed
  * outbox jobs cannot exceed the user's hourly/daily email caps. */
 async deliverSecurityEmails(env: Env): Promise<void> {
  const now = this.clock();
  const rows = (await this.db.prepare(`SELECT id,user_id,suspended_until FROM sender_security_mail
   WHERE sent_at IS NULL AND next_attempt_at<=? AND (lease_until IS NULL OR lease_until<=?)
   ORDER BY next_attempt_at LIMIT 20`).bind(now, now).all<{id: string; user_id: string; suspended_until: number}>()).results;
  for (const row of rows) {
   const lease = crypto.randomUUID();
   const claimed = await this.db.prepare(`UPDATE sender_security_mail SET lease_id=?,lease_until=?
    WHERE id=? AND sent_at IS NULL AND next_attempt_at<=? AND (lease_until IS NULL OR lease_until<=?)`)
    .bind(lease, now + minute, row.id, now, now).run();
   if (!claimed.meta.changes) continue;
   const finish = async (sent: boolean, retryAt: number) => this.db.prepare(`UPDATE sender_security_mail
    SET sent_at=?,next_attempt_at=?,lease_id=NULL,lease_until=NULL WHERE id=? AND lease_id=?`)
    .bind(sent ? this.clock() : null, retryAt, row.id, lease).run();
   const user = await this.db.prepare("SELECT email FROM users WHERE id=? AND email_verified_at IS NOT NULL AND email_verified_at!='' AND deletion_requested_at IS NULL")
    .bind(row.user_id).first<{email: string}>();
   if (!user) { await finish(true, now); continue; }
   const allowed = await this.emailReservation(row.user_id, crypto.randomUUID(), 'email_attempt').run();
   if (!allowed.meta.changes) { await finish(false, now + this.config.emailCooldownSeconds * 1000); continue; }
   await this.db.prepare('UPDATE sender_security_mail SET attempts=attempts+1 WHERE id=? AND lease_id=?')
    .bind(row.id, lease).run();
   try {
    await env.EMAIL.send({
     to: user.email, from: env.AUTH_EMAIL_FROM, subject: 'PushNow security alert: sending key paused',
     text: `Unusually frequent sending requests were detected for a key on your PushNow account.\n\nThe key was temporarily paused until ${new Date(row.suspended_until).toISOString()}.\n\nIf this was not expected, sign in to PushNow and revoke the key from your dashboard. Review any scripts using your keys before sending again.\n\nhttps://pushnow.dev/dashboard/\n\nSecurity emails are limited to protect your inbox.`,
    });
    await finish(true, now);
   } catch {
    await finish(false, now + this.config.emailCooldownSeconds * 1000);
   }
  }
  await this.db.prepare('DELETE FROM sender_security_events WHERE occurred_at<=?').bind(now - day).run();
 }

}
declare global {
 interface Env {
  SENDER_KEY_REQUESTS_PER_MINUTE?: string;
  SENDER_KEY_SUSPENSION_SECONDS?: string;
  SENDER_USER_NOTIFICATIONS_PER_MINUTE?: string;
  SENDER_SECURITY_EMAIL_COOLDOWN_SECONDS?: string;
  SENDER_SECURITY_EMAILS_PER_DAY?: string;
 }
}
