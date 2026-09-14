import { sourceKind } from './message-source';
import { SenderAbuseGuard } from "./sender-abuse";
import { ProductService } from './product-service';
import { SecureDevices } from './secure-devices';
import { publicDevice, type Device, type SecureSession } from './secure-types';
import { bytes, digest, fail, fields, str, uuid, verify } from './secure-validation';
import { securePayload } from './secure-push';
import { usageWindowFor } from './membership';

type SecureSource={source_id:string;user_id:string;public_key:string;certificate:string};
export class SecureMessages {
 readonly devices:SecureDevices;
 constructor(readonly db:D1Database,readonly product:ProductService){this.devices=new SecureDevices(db);}
 async source(token:string) {
  const session=await this.product.authenticateSourceKey(token);
  await new SenderAbuseGuard(this.db).assertKeyActive(session.key.userId,session.key.id);
  const user=await this.db.prepare('SELECT id FROM users WHERE id=? AND deletion_requested_at IS NULL').bind(session.key.userId).first();
  if(!user) fail(401,'account_inactive');
  const source=await this.db.prepare('SELECT * FROM secure_sources WHERE source_id=? AND user_id=?').bind(session.source.id,session.key.userId).first<SecureSource>();
  if(!source) fail(403,'source_encryption_not_configured');
  return {...source,key_id:session.key.id};
 }
 async setup(session:SecureSession,id:string,input:Record<string,unknown>) {
  await this.devices.bound(session);
  fields(input,['publicKey','certificate']);
  const source=await this.db.prepare("SELECT id FROM sources WHERE id=? AND user_id=? AND status='active'").bind(id,session.user.id).first();
  if(!source) fail(404,'source_not_found');
  const key=str(input.publicKey);bytes(key,65);
  await verify(await this.devices.identity(session.user.id),input.certificate,`pushnow-source-v1\n${session.user.id}\n${id}\n${key}`);
  await this.db.prepare('INSERT INTO secure_sources VALUES (?,?,?,?) ON CONFLICT(source_id) DO NOTHING').bind(id,session.user.id,key,input.certificate).run();
  const saved=await this.db.prepare('SELECT * FROM secure_sources WHERE source_id=?').bind(id).first<SecureSource>();
  if(saved?.public_key!==key || saved.certificate!==input.certificate) fail(409,'source_identity_immutable');
  return {source:saved};
 }
 async recipients(token:string) {
  const source=await this.source(token);
  const devices=await this.db.prepare("SELECT * FROM secure_devices WHERE user_id=? AND status='active' AND certificate IS NOT NULL").bind(source.user_id).all<Device>();
  return {user_id:source.user_id,source_id:source.source_id,identity_public_key:await this.devices.identity(source.user_id),source_public_key:source.public_key,source_certificate:source.certificate,devices:devices.results.map(publicDevice)};
 }
 async ingest(token:string,idempotency:string,input:Record<string,unknown>) {
  const source=await this.source(token);
  fields(input,['messageId','expiresAt','scheduledAt','envelopes','sourceKind']);
  const kind=sourceKind(input.sourceKind);
  const id=uuid(input.messageId);
  if(idempotency!==id) fail(400,'idempotency_must_equal_message_id');
  const expiry=str(input.expiresAt,30), scheduled=input.scheduledAt===undefined?null:str(input.scheduledAt,30), now=new Date();
  for(const date of [expiry,...(scheduled?[scheduled]:[])]) {
   if(!Number.isFinite(Date.parse(date)) || new Date(date).toISOString()!==date) fail(400,'invalid_timestamp');
  }
  if(Date.parse(expiry)<=now.getTime() || Date.parse(expiry)>now.getTime()+30*86400000 || (scheduled && Date.parse(scheduled)>=Date.parse(expiry))) fail(400,'invalid_schedule');
  if(!Array.isArray(input.envelopes)||input.envelopes.length<1||input.envelopes.length>32) fail(400,'invalid_targets');
  const envelopes=input.envelopes.map((entry:Record<string,unknown>)=>{
   if(!entry||typeof entry!=='object') fail(400,'invalid_envelope');
   fields(entry,['deviceId','enc','ciphertext']);uuid(entry.deviceId);bytes(entry.enc,65);bytes(entry.ciphertext,16,2400);
   return {deviceId:entry.deviceId as string,enc:entry.enc as string,ciphertext:entry.ciphertext as string};
  }).sort((a,b)=>a.deviceId.localeCompare(b.deviceId));
  if(new Set(envelopes.map(e=>e.deviceId)).size!==envelopes.length) fail(400,'duplicate_target');
  const hash=await digest(JSON.stringify({id,expiry,scheduled,envelopes,...(kind===undefined?{}:{sourceKind:kind})}));
  const existing=await this.db.prepare('SELECT request_hash,user_id,source_id FROM secure_messages WHERE id=?').bind(id).first<{request_hash:string;user_id:string;source_id:string}>();
  if(existing){
   if(existing.user_id!==source.user_id||existing.source_id!==source.source_id||existing.request_hash!==hash) fail(409,'message_id_conflict');
   return {message_id:id,deduplicated:true};
  }
  for(const envelope of envelopes){
   const device=await this.devices.get(source.user_id,envelope.deviceId);
   if(device.status!=='active'||!device.certificate) fail(403,'target_not_approved');
   const payload=securePayload({message_id:id,user_id:source.user_id,source_id:source.source_id,expires_at:expiry,created_at:now.toISOString(),device_id:envelope.deviceId,enc:envelope.enc,ciphertext:envelope.ciphertext,source_public_key:source.public_key,source_certificate:source.certificate});
   if(new TextEncoder().encode(JSON.stringify(payload)).length>4096) fail(413,'encrypted_payload_too_large');
  }
  const due=scheduled??now.toISOString();
  const membership=await this.product.getMembershipStatus(source.user_id),window=usageWindowFor(now);
  const quotaStatements=membership.dailyNotificationLimit===null?[]:[
   this.db.prepare(`INSERT INTO usage_counters(user_id,feature_key,window_start,window_end,used_count,updated_at) VALUES (?,'notification_events',?,?,1,?) ON CONFLICT(user_id,feature_key,window_start) DO UPDATE SET used_count=used_count+1,updated_at=excluded.updated_at`).bind(source.user_id,window.windowStart,window.windowEnd,now.toISOString()),
   this.db.prepare("UPDATE secure_messages SET quota_remaining=?-(SELECT used_count FROM usage_counters WHERE user_id=? AND feature_key='notification_events' AND window_start=?) WHERE id=?").bind(membership.dailyNotificationLimit,source.user_id,window.windowStart,id)
  ];
  // A plain INSERT makes a competing request roll back its complete batch.
  try {
   await this.db.batch([
    this.db.prepare('INSERT INTO secure_messages(id,user_id,source_id,request_hash,expires_at,scheduled_at,created_at,source_kind) VALUES (?,?,?,?,?,?,?,?)').bind(id,source.user_id,source.source_id,hash,expiry,due,now.toISOString(),kind??null),
    ...quotaStatements,
    ...envelopes.map(e=>this.db.prepare('INSERT INTO secure_deliveries(message_id,device_id,enc,ciphertext,next_attempt_at) VALUES (?,?,?,?,?)').bind(id,e.deviceId,e.enc,e.ciphertext,due))
   ]);
  } catch(error) {
   const duplicate=await this.db.prepare('SELECT request_hash,user_id,source_id FROM secure_messages WHERE id=?').bind(id).first<{request_hash:string;user_id:string;source_id:string}>();
   if(duplicate?.request_hash===hash && duplicate.user_id===source.user_id && duplicate.source_id===source.source_id) return {message_id:id,deduplicated:true};
   if(duplicate) fail(409,'message_id_conflict');
   if(error instanceof Error && error.message.includes('quota_remaining')) fail(402,'quota_exceeded');
   throw error;
  }
  return {message_id:id,deduplicated:false};
 }
 async inbox(session:SecureSession,id?:string) {
  const device=await this.devices.bound(session);
  const messages=await this.db.prepare(`SELECT m.id AS message_id,m.user_id,m.source_id,d.device_id,m.expires_at,d.enc,d.ciphertext,s.public_key AS source_public_key,s.certificate AS source_certificate,m.created_at,m.read_at,COALESCE(m.source_kind,'unknown') AS source_kind,p.name AS source_name,p.source_type
   FROM secure_deliveries d JOIN secure_messages m ON m.id=d.message_id JOIN secure_sources s ON s.source_id=m.source_id LEFT JOIN sources p ON p.id=m.source_id AND p.user_id=m.user_id
   WHERE d.device_id=? AND m.user_id=? AND m.expires_at>? AND m.scheduled_at<=? ${id?'AND m.id=?':''} ORDER BY m.created_at DESC LIMIT 100`).bind(device.id,session.user.id,new Date().toISOString(),new Date().toISOString(),...(id?[id]:[])).all();
  return {messages:messages.results};
 }
 async get(session:SecureSession,id:string) {
  const {messages}=await this.inbox(session,id);
  if(!messages.length)fail(404,'message_not_found');
  return {message:messages[0]};
 }
 async read(session:SecureSession,id:string) {
  const device=await this.devices.bound(session);
  const result=await this.db.prepare(`UPDATE secure_messages SET read_at=COALESCE(read_at,?) WHERE id=? AND user_id=?
   AND EXISTS (SELECT 1 FROM secure_deliveries WHERE message_id=secure_messages.id AND device_id=?)`).bind(new Date().toISOString(),id,session.user.id,device.id).run();
  if(!result.meta.changes) fail(404,'message_not_found');
 }
 async ack(session:SecureSession,id:string) {
  const device=await this.devices.bound(session);
  const result=await this.db.prepare('UPDATE secure_deliveries SET acknowledged_at=? WHERE message_id=? AND device_id=? AND message_id IN (SELECT id FROM secure_messages WHERE user_id=?)').bind(new Date().toISOString(),id,device.id,session.user.id).run();
  if(!result.meta.changes) fail(404,'message_not_found');
 }
}
