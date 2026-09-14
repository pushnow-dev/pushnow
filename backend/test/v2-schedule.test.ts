import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { readFileSync, readdirSync } from 'node:fs';
import { MessageIngest, type SourceSnapshot } from '../src/v2-messages';
import { apiMessage, MessageHistory, type MessageRow } from '../src/v2-message-store';
import { deliverArchiveMessages } from '../src/v2-delivery';
import { base64, digest } from '../src/secure-validation';
import type { ProductService } from '../src/product-service';
import type { SecureSession } from '../src/secure-types';
import { sendAPNs, sendHarmonyPush } from '../src/secure-push';

vi.mock('../src/secure-push', () => ({
 decryptToken: vi.fn(async () => 'test-token'), pushConfigured: () => true,
 harmonyPushConfigured: () => true, sendHarmonyPush: vi.fn(async () => ({ status: 200 })),
 sendAPNs: vi.fn(async () => ({ status: 200 })),
}));
const mf = new Miniflare(convertV4MiniflareOptions({ name: 'schedule-test', modules: true,
 script: 'export default{fetch(){return new Response("ok")}}', d1Databases: ['DB'], compatibilityDate: '2026-09-12' }));
let db: D1Database;
const start = Date.parse('2026-09-13T10:00:00.000Z');
const iso = (delta = 0) => new Date(start + delta).toISOString();
const product = { getMembershipStatus: async () => ({ dailyNotificationLimit: null }) } as unknown as ProductService;
beforeAll(async () => {
 db = await mf.getD1Database('DB') as unknown as D1Database;
 for (const name of readdirSync(new URL('../migrations/', import.meta.url)).sort()) {
  for (const sql of readFileSync(new URL(`../migrations/${name}`, import.meta.url), 'utf8').split(';').map(s => s.trim()).filter(Boolean)) await db.prepare(sql).run();
 }
}, 60000);
afterEach(() => { vi.useRealTimers(); vi.clearAllMocks(); });
afterAll(() => mf.dispose(), 60000);

async function fixture() {
 vi.useFakeTimers({ toFake: ['Date'] }); vi.setSystemTime(start);
 // Keep each case isolated without resetting a database that other suites own.
 await db.prepare('DELETE FROM v2_deliveries').run();
 const user = crypto.randomUUID(), sourceID = crypto.randomUUID(), keyID = crypto.randomUUID(), archiveID = crypto.randomUUID();
 await db.prepare('INSERT INTO users(id,email,email_hash,email_verified_at,created_at,updated_at) VALUES (?,?,?,?,?,?)').bind(user, `${user}@test.invalid`, user, iso(), iso(), iso()).run();
 await db.prepare('INSERT INTO sources(id,user_id,name,source_type,created_at,updated_at) VALUES (?,?,?,?,?,?)').bind(sourceID, user, 'SDK', 'api', iso(), iso()).run();
 await db.prepare('INSERT INTO source_keys(id,source_id,user_id,key_prefix,key_hash,scopes,created_at) VALUES (?,?,?,?,?,?,?)').bind(keyID, sourceID, user, keyID, keyID, '[]', iso()).run();
 await db.prepare('INSERT INTO v2_archives VALUES (?,?,?,?,?)').bind(user, archiveID, 'public', 'certificate', iso()).run();
 const devices = [crypto.randomUUID(), crypto.randomUUID()];
 for (const device of devices) {
  await db.prepare("INSERT INTO secure_devices(id,user_id,name,platform,public_key,certificate,status,last_seen_at,created_at) VALUES (?,?,'Phone','ios','public','certificate','active',?,?)").bind(device, user, iso(), iso()).run();
  await db.prepare("INSERT INTO secure_push_tokens(device_id,environment,token_hash,token_encrypted,updated_at) VALUES (?,'sandbox',?,'encrypted',?)").bind(device, device, iso()).run();
  await db.prepare('INSERT INTO sessions(id,user_id,access_token_hash,refresh_token_hash,expires_at,refresh_expires_at,created_at,updated_at,device_id) VALUES (?,?,?,?,?,?,?,?,?)').bind(device, user, device, device, iso(40*86400000), iso(40*86400000), iso(), iso(), device).run();
 }
 const source: SourceSnapshot = { user_id: user, source_id: sourceID, key_id: keyID, public_key: 'public', certificate: 'certificate' };
 const message = { messageId: crypto.randomUUID(), archiveId: archiveID, enc: base64(new Uint8Array(65)), ciphertext: base64(new Uint8Array(32)), preview: { enc: base64(new Uint8Array(65)), ciphertext: base64(new Uint8Array(32)) }, attachmentIds: [] };
 const ingest = (extra: Record<string, unknown> = {}, sender = source) => new MessageIngest(db, product).ingest(sender, message.messageId, { ...message, ...extra });
 const row = () => db.prepare('SELECT * FROM v2_messages WHERE id=?').bind(message.messageId).first<MessageRow>();
 const deliveries = () => db.prepare('SELECT * FROM v2_deliveries WHERE message_id=?').bind(message.messageId).all<{status:string;attempts:number;next_attempt_at:string;last_error:string}>();
 return { source, message, devices, ingest, row, deliveries };
}
const deliver = () => deliverArchiveMessages({ DB: db } as Env);

describe('v2 scheduled delivery with real D1', { timeout: 30000 }, () => {
 it.each([
  [undefined, 'default'], ['default', 'default'], ['silent', undefined], ['chime', 'pushnow-chime.wav'],
 ])('persists sound %s and uses it on delayed APNs delivery', async (sound, expected) => {
  const f = await fixture();
  const options = { scheduledAt: iso(60000), ...(sound === undefined ? {} : { sound }) };
  await f.ingest(options);
  expect(apiMessage((await f.row())!)).toMatchObject({ sound: sound ?? 'default' });
  expect(await f.ingest(options)).toMatchObject({ deduplicated: true });
  await expect(f.ingest({ ...options, sound: sound === 'silent' ? 'default' : 'silent' })).rejects.toMatchObject({ status: 409 });
  vi.setSystemTime(start + 60000); await deliver();
  expect(sendAPNs).toHaveBeenCalledTimes(2);
  const payload = vi.mocked(sendAPNs).mock.calls[0][3] as {aps: {sound?: string; alert: unknown}};
  expect(payload.aps.sound).toBe(expected);
  expect(payload.aps.alert).toBeDefined();
  if (sound === 'silent') expect(payload.aps).not.toHaveProperty('sound');
 });
 it.each(['', 'custom', '../chime.wav', 'critical', null, 1, {name:'chime'}])('rejects invalid sound %j before storing', async sound => {
  const f = await fixture();
  await expect(f.ingest({sound})).rejects.toMatchObject({status:400});
  expect(await f.row()).toBeNull();
 });
 it('shows scheduled history, sends to all devices at the due time and honors explicit APNs expiry', async () => {
  const f = await fixture(); await f.ingest({ scheduledAt: iso(60000), expiresAt: iso(120000) });
  expect(apiMessage((await f.row())!)).toMatchObject({ scheduled_at: iso(60000), expires_at: iso(120000) });
  expect((await f.row())!.source_key_id).toBe(f.source.key_id);
  await deliver(); expect(sendAPNs).not.toHaveBeenCalled();
  expect((await f.deliveries()).results.every(d => d.attempts === 0 && d.next_attempt_at === iso(60000))).toBe(true);
  vi.setSystemTime(start + 60000); await deliver();
  expect(sendAPNs).toHaveBeenCalledTimes(2);
  expect(vi.mocked(sendAPNs).mock.calls[0][4]).toBe(iso(120000));
  expect((await f.deliveries()).results.map(d => d.status)).toEqual(['accepted', 'accepted']);
 });
 it('routes encrypted v2 previews independently to iOS and Harmony and suppresses revoked Harmony sessions', async () => {
  const f = await fixture();
  await db.prepare("UPDATE secure_devices SET platform='harmony' WHERE id=?").bind(f.devices[1]).run();
  await f.ingest(); await deliver();
  expect(sendAPNs).toHaveBeenCalledTimes(1); expect(sendHarmonyPush).toHaveBeenCalledTimes(1);
  const payload = vi.mocked(sendHarmonyPush).mock.calls[0][2] as { secure_v2: { device_id: string; ciphertext: string } };
  expect(payload.secure_v2).toMatchObject({device_id:f.devices[1],ciphertext:f.message.preview.ciphertext});
  expect((await f.deliveries()).results.map(d=>d.status)).toEqual(['accepted','accepted']);
  vi.clearAllMocks();
  await db.prepare("UPDATE v2_deliveries SET status='pending',next_attempt_at=?").bind(iso()).run();
  await db.prepare('UPDATE sessions SET revoked_at=? WHERE device_id=?').bind(iso(),f.devices[1]).run();
  await deliver(); expect(sendHarmonyPush).not.toHaveBeenCalled(); expect(sendAPNs).toHaveBeenCalledTimes(1);
  expect((await f.deliveries()).results.map(d=>d.status).sort()).toEqual(['accepted','suppressed']);
 });
 it('clears an invalid Harmony token while retaining the iOS token and accepted delivery', async () => {
  const f = await fixture();
  await db.prepare("UPDATE secure_devices SET platform='harmony' WHERE id=?").bind(f.devices[1]).run();
  vi.mocked(sendHarmonyPush).mockResolvedValueOnce({status:400,reason:'BadDeviceToken'});
  await f.ingest(); await deliver();
  expect((await db.prepare('SELECT device_id FROM secure_push_tokens WHERE device_id=?').bind(f.devices[1]).first())).toBeNull();
  expect((await db.prepare('SELECT device_id FROM secure_push_tokens WHERE device_id=?').bind(f.devices[0]).first())).not.toBeNull();
  expect((await f.deliveries()).results.map(d=>d.status).sort()).toEqual(['accepted','failed']);
 });
 it('never sends early even if a delivery row accidentally becomes due', async () => {
  const f = await fixture(); await f.ingest({ scheduledAt: iso(60000) });
  await db.prepare('UPDATE v2_deliveries SET next_attempt_at=?').bind(iso()).run();
  await deliver(); expect(sendAPNs).not.toHaveBeenCalled();
  expect((await f.deliveries()).results.every(d => d.status === 'pending' && d.next_attempt_at === iso(60000))).toBe(true);
 });
 it('expires transport without deleting retained history', async () => {
  const f = await fixture(); await f.ingest({ scheduledAt: iso(60000), expiresAt: iso(120000) });
  vi.setSystemTime(start + 120000); await deliver();
  expect(sendAPNs).not.toHaveBeenCalled();
  expect((await f.deliveries()).results.every(d => d.status === 'expired')).toBe(true);
  expect((await f.row())!.ciphertext).toBe(f.message.ciphertext);
 });
 it('keeps legacy hashes and default expiry stable across retries', async () => {
  const f = await fixture(); const { key_id, ...legacySource } = f.source;
  await f.ingest({}, legacySource);
  expect((await f.row())!.source_key_id).toBeNull();
  const m = f.message;
  expect((await f.row())!.request_hash).toBe(await digest(JSON.stringify({ id: m.messageId, archiveId: m.archiveId, enc: m.enc, ciphertext: m.ciphertext, preview: m.preview, attachments: [], targets: null })));
  vi.setSystemTime(start + 31*86400000);
  expect(await f.ingest({}, legacySource)).toMatchObject({ deduplicated: true });
  await deliver(); expect(sendAPNs).not.toHaveBeenCalled();
  expect((await f.deliveries()).results.every(d => d.status === 'expired')).toBe(true);
 });
 it('deduplicates after schedule and expiry pass, but rejects a changed schedule', async () => {
  const f = await fixture(), options = { scheduledAt: iso(60000), expiresAt: iso(120000) };
  await f.ingest(options); vi.setSystemTime(start + 180000);
  expect(await f.ingest(options)).toMatchObject({ deduplicated: true });
  await expect(f.ingest({ ...options, scheduledAt: iso(61000) })).rejects.toMatchObject({ status: 409 });
 });
 it.each(['2026-09-14', '2026-09-14T10:00:00', '2026-02-30T10:00:00Z', '2026-09-14T24:00:00Z', '2026-09-14T10:00:00+24:00', '', null, 123])('rejects malformed timestamp %s', async value => {
  const f = await fixture();
  await expect(f.ingest({ scheduledAt: value })).rejects.toMatchObject({ status: 400 });
  await expect(f.ingest({ expiresAt: value })).rejects.toMatchObject({ status: 400 });
 });
 it('enforces future, 30-day and expiry-after-schedule boundaries and normalizes offsets', async () => {
  const f = await fixture();
  for (const extra of [{ scheduledAt: iso() }, { scheduledAt: iso(30*86400000+1) }, { expiresAt: iso() }, { expiresAt: iso(30*86400000+1) }, { scheduledAt: iso(60000), expiresAt: iso(60000) }]) {
   await expect(f.ingest(extra)).rejects.toMatchObject({ status: 400 });
  }
  await f.ingest({ scheduledAt: '2026-09-13T18:01:00+08:00', expiresAt: iso(30*86400000) });
  expect((await f.row())!.scheduled_at).toBe(iso(60000));
 });
 it.each(['revoked', 'expired', 'foreign'])('rechecks %s source keys at delivery', async state => {
  const f = await fixture(); await f.ingest({ scheduledAt: iso(60000) });
  if (state === 'revoked') await db.prepare('UPDATE source_keys SET revoked_at=? WHERE id=?').bind(iso(), f.source.key_id).run();
  if (state === 'expired') await db.prepare('UPDATE source_keys SET expires_at=? WHERE id=?').bind(iso(60000), f.source.key_id).run();
  if (state === 'foreign') {
   const foreign = crypto.randomUUID();
   await db.prepare("INSERT INTO sources(id,user_id,name,source_type,created_at,updated_at) VALUES (?,?,'Other','api',?,?)").bind(foreign, f.source.user_id, iso(), iso()).run();
   await db.prepare('UPDATE source_keys SET source_id=? WHERE id=?').bind(foreign, f.source.key_id).run();
  }
  vi.setSystemTime(start + 60000); await deliver();
  expect(sendAPNs).not.toHaveBeenCalled();
  expect((await f.deliveries()).results.every(d => d.last_error === 'source_key_not_active')).toBe(true);
 });
 it('reading before schedule keeps the explicitly requested reminder', async () => {
  const f = await fixture(); await f.ingest({ scheduledAt: iso(60000) });
  const history = new MessageHistory(db);
  await history.read({ user: { id: f.source.user_id }, session: { deviceId: f.devices[0] } } as SecureSession, f.message.messageId);
  expect((await f.row())!.read_at).toBe(iso());
  vi.setSystemTime(start + 60000); await deliver();
  expect(sendAPNs).toHaveBeenCalledTimes(2);
  expect((await f.deliveries()).results.every(d => d.status === 'accepted')).toBe(true);
 });
 it('respects selected devices, rejects unknown devices and supports inbox-only schedules', async () => {
  const f = await fixture();
  await expect(f.ingest({ notifyDeviceIds: [crypto.randomUUID()], scheduledAt: iso(60000) })).rejects.toMatchObject({ status: 403 });
  await f.ingest({ notifyDeviceIds: [f.devices[0]], scheduledAt: iso(60000) });
  expect((await f.deliveries()).results).toHaveLength(1);
  const second = { ...f.message, messageId: crypto.randomUUID(), notifyDeviceIds: [], scheduledAt: iso(60000) };
  await new MessageIngest(db, product).ingest(f.source, second.messageId, second);
  expect((await db.prepare('SELECT * FROM v2_deliveries WHERE message_id=?').bind(second.messageId).all()).results).toHaveLength(0);
 });
 it('still suppresses read immediate messages', async () => {
  const f = await fixture(); await f.ingest();
  await new MessageHistory(db).read({ user: { id: f.source.user_id }, session: { deviceId: f.devices[0] } } as SecureSession, f.message.messageId);
  await deliver(); expect(sendAPNs).not.toHaveBeenCalled();
  expect((await f.deliveries()).results.every(d => d.status === 'suppressed')).toBe(true);
 });
 it('stops retries at explicit expiry', async () => {
  const f = await fixture(); await f.ingest({ notifyDeviceIds: [f.devices[0]], scheduledAt: iso(60000), expiresAt: iso(90000) });
  vi.mocked(sendAPNs).mockResolvedValueOnce({ status: 503, reason: 'Unavailable' });
  vi.setSystemTime(start + 60000); await deliver();
  expect((await f.deliveries()).results[0].status).toBe('retry');
  vi.setSystemTime(start + 90000); await deliver();
  expect(sendAPNs).toHaveBeenCalledTimes(1);
  expect((await f.deliveries()).results[0].status).toBe('expired');
 });
});

it('preserves historical unknown source and validates explicit kinds and idempotency', async()=>{
 const f=await fixture();
 await expect(f.ingest({sourceKind:'made-up'})).rejects.toMatchObject({code:'invalid_source_kind'});
 await f.ingest();
 expect(apiMessage((await f.row())!).source_kind).toBe('unknown');
 const history=new MessageHistory(db);
 vi.spyOn(history.devices,'bound').mockResolvedValue({id:f.devices[0]} as never);
 const session={user:{id:f.source.user_id}} as SecureSession;
 expect((await history.get(session,f.message.messageId)).message).toMatchObject({source_kind:'unknown',source_name:'SDK',source_type:'api'});
 expect((await history.list(session,null,null)).messages?.[0]).toMatchObject({source_kind:'unknown',source_name:'SDK',source_type:'api'});
 await expect(f.ingest()).resolves.toMatchObject({deduplicated:true});
 await expect(f.ingest({sourceKind:'web'})).rejects.toMatchObject({code:'message_id_conflict'});
 for(const kind of ['web','cli','api','subscription']) {
  const next=await fixture();await next.ingest({sourceKind:kind});
  expect(apiMessage((await next.row())!).source_kind).toBe(kind);
 }
});
