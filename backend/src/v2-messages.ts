import { sourceKind } from './message-source';
import { ArchiveService } from './v2-archive';
import { bytes, digest, fail, fields, uuid } from './secure-validation';
import type { ProductService } from './product-service';
import type { MessageRow } from './v2-message-store';
import { usageWindowFor } from './membership';
import { apnsSound, notificationSound, type NotificationSound } from './v2-sound';
export type SourceSnapshot={user_id:string;source_id:string;public_key:string;certificate:string;key_id?:string};
const thirtyDays=30*86400000;
function timestamp(value:unknown,field:string):string|undefined{
 if(value===undefined)return undefined;
 if(typeof value!=='string')fail(400,`invalid_${field}`);
 const match=/^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,3}))?(Z|[+-]\d{2}:\d{2})$/.exec(value);
 if(!match)fail(400,`invalid_${field}`);
 const local=`${match[1]}T${match[2]}:${match[3]}:${match[4]}.${(match[5]??'').padEnd(3,'0')}Z`;
 const parsed=Date.parse(value),localDate=Date.parse(local);
 if(!Number.isFinite(parsed)||!Number.isFinite(localDate)||new Date(localDate).toISOString()!==local||
  (match[6]!=='Z'&&(Number(match[6].slice(1,3))>23||Number(match[6].slice(4))>59)))fail(400,`invalid_${field}`);
 return new Date(parsed).toISOString();
}
export function previewPayload(message:{message_id:string;user_id:string;source_id:string;archive_id:string;enc:string;ciphertext:string;source_public_key:string;source_certificate:string;created_at:string},deviceId:string,sound?:NotificationSound|null){return {aps:{alert:{title:'PushNow',body:'You have a new encrypted reminder.'},'mutable-content':1,...apnsSound(sound)},secure_v2:{...message,device_id:deviceId}};}
export class MessageIngest {
 constructor(readonly db:D1Database,readonly product:ProductService){}
 async ingest(source:SourceSnapshot,idempotency:string,input:Record<string,unknown>){
  const kind=sourceKind(input.sourceKind);
  fields(input,['messageId','archiveId','enc','ciphertext','preview','attachmentIds','notifyDeviceIds','scheduledAt','expiresAt','sound','sourceKind']);
  const sound=notificationSound(input.sound);
  const scheduledAt=timestamp(input.scheduledAt,'scheduled_at'),expiresAt=timestamp(input.expiresAt,'expires_at');
  const id=uuid(input.messageId),archiveId=uuid(input.archiveId);if(id!==idempotency)fail(400,'idempotency_must_equal_message_id');
  const archive=await new ArchiveService(this.db).require(source.user_id);if(archive.id!==archiveId)fail(409,'wrong_archive');
  bytes(input.enc,65);bytes(input.ciphertext,16,256*1024);
  const preview=input.preview as Record<string,unknown>;if(!preview||typeof preview!=='object')fail(400,'invalid_preview');fields(preview,['enc','ciphertext']);bytes(preview.enc,65);bytes(preview.ciphertext,16,2400);
  if(!Array.isArray(input.attachmentIds)||input.attachmentIds.length>20)fail(400,'invalid_attachments');
  const attachments=input.attachmentIds.map(uuid).sort();if(new Set(attachments).size!==attachments.length)fail(400,'duplicate_attachment');
  let targets:string[]|null=null;
  if(input.notifyDeviceIds!==undefined){if(!Array.isArray(input.notifyDeviceIds)||input.notifyDeviceIds.length>100)fail(400,'invalid_targets');targets=input.notifyDeviceIds.map(uuid).sort();if(new Set(targets).size!==targets.length)fail(400,'duplicate_target');}
  // Omitted defaults must not change the legacy hash or drift on an outbox retry.
  const hash=await digest(JSON.stringify({id,archiveId,enc:input.enc,ciphertext:input.ciphertext,preview:{enc:preview.enc,ciphertext:preview.ciphertext},attachments,targets,...(scheduledAt===undefined?{}:{scheduledAt}),...(expiresAt===undefined?{}:{expiresAt}),...(sound===undefined?{}:{sound}),...(kind===undefined?{}:{sourceKind:kind})}));
  const duplicate=async()=>{const row=await this.db.prepare('SELECT * FROM v2_messages WHERE id=?').bind(id).first<MessageRow>();if(!row)return null;if(row.user_id!==source.user_id||row.source_id!==source.source_id||row.request_hash!==hash)fail(409,'message_id_conflict');if(row.deleted_at)fail(410,'message_deleted');return {message_id:id,deduplicated:true};};
  const existing=await duplicate();if(existing)return existing;
  const current=Date.now(),due=scheduledAt??new Date(current).toISOString();
  if(scheduledAt&&(Date.parse(scheduledAt)<=current||Date.parse(scheduledAt)>current+thirtyDays))fail(400,'invalid_scheduled_at');
  if(expiresAt&&(Date.parse(expiresAt)<=Date.parse(due)||Date.parse(expiresAt)>current+thirtyDays))fail(400,'invalid_expires_at');
  const devices=(await this.db.prepare("SELECT id,notifications_enabled FROM secure_devices WHERE user_id=? AND status='active' AND certificate IS NOT NULL").bind(source.user_id).all<{id:string;notifications_enabled:number}>()).results;
  if(targets?.some(target=>!devices.some(device=>device.id===target)))fail(403,'invalid_target');
  const selected=devices.filter(d=>d.notifications_enabled&&(targets===null||targets.includes(d.id))).map(d=>d.id);
  for(const attachment of attachments){const valid=await this.db.prepare("SELECT id FROM v2_attachments WHERE id=? AND user_id=? AND source_id=? AND status='uploaded' AND expires_at>?").bind(attachment,source.user_id,source.source_id,new Date().toISOString()).first();if(!valid)fail(400,'attachment_not_ready');}
  const now=new Date().toISOString(),payload=previewPayload({message_id:id,user_id:source.user_id,source_id:source.source_id,archive_id:archiveId,enc:preview.enc as string,ciphertext:preview.ciphertext as string,source_public_key:source.public_key,source_certificate:source.certificate,created_at:now},crypto.randomUUID(),sound);
  if(new TextEncoder().encode(JSON.stringify(payload)).length>4096)fail(413,'preview_too_large');
  const membership=await this.product.getMembershipStatus(source.user_id),window=usageWindowFor(new Date());
  const quota=membership.dailyNotificationLimit===null?[]:[this.db.prepare("INSERT INTO usage_counters VALUES (?,'notification_events',?,?,1,?) ON CONFLICT(user_id,feature_key,window_start) DO UPDATE SET used_count=used_count+1,updated_at=excluded.updated_at").bind(source.user_id,window.windowStart,window.windowEnd,now),this.db.prepare("UPDATE v2_messages SET quota_remaining=?-(SELECT used_count FROM usage_counters WHERE user_id=? AND feature_key='notification_events' AND window_start=?) WHERE id=?").bind(membership.dailyNotificationLimit,source.user_id,window.windowStart,id)];
  try{await this.db.batch([
   this.db.prepare('INSERT INTO v2_messages(id,user_id,source_id,archive_id,request_hash,enc,ciphertext,preview_enc,preview_ciphertext,source_public_key,source_certificate,created_at,scheduled_at,expires_at,source_key_id,sound,source_kind) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)').bind(id,source.user_id,source.source_id,archiveId,hash,input.enc,input.ciphertext,preview.enc,preview.ciphertext,source.public_key,source.certificate,now,scheduledAt??null,expiresAt??null,source.key_id??null,sound??null,kind??null),
   ...quota,
   ...attachments.flatMap(attachment=>[
    this.db.prepare("UPDATE v2_messages SET quota_remaining=CASE WHEN EXISTS(SELECT 1 FROM v2_attachments WHERE id=? AND user_id=? AND source_id=? AND status='uploaded') THEN quota_remaining ELSE -1 END WHERE id=?").bind(attachment,source.user_id,source.source_id,id),
    this.db.prepare("UPDATE v2_attachments SET status='committed',message_id=? WHERE id=? AND user_id=? AND source_id=? AND status='uploaded'").bind(id,attachment,source.user_id,source.source_id)
   ]),
   ...selected.map(device=>this.db.prepare('INSERT INTO v2_deliveries(message_id,device_id,next_attempt_at) VALUES (?,?,?)').bind(id,device,due))
  ]);}catch(error){const race=await duplicate();if(race)return race;if(error instanceof Error&&error.message.includes('quota_remaining'))fail(402,'quota_or_attachment_conflict');throw error;}
  return {message_id:id,deduplicated:false};
 }
}
