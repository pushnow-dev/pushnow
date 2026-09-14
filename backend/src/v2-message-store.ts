import type { SecureSession } from './secure-types';
import { SecureDevices } from './secure-devices';
import { AttachmentService } from './v2-attachments';
import { fail } from './secure-validation';
import type { NotificationSound } from './v2-sound';
export type MessageRow={source_kind?:string|null;source_name?:string|null;source_type?:string|null;id:string;user_id:string;source_id:string;archive_id:string;request_hash:string;enc:string|null;ciphertext:string|null;preview_enc:string|null;preview_ciphertext:string|null;source_public_key:string|null;source_certificate:string|null;created_at:string;read_at:string|null;deleted_at:string|null;scheduled_at?:string|null;expires_at?:string|null;source_key_id?:string|null;sound?:NotificationSound|null};
export function apiMessage(row:MessageRow){return {source_kind:row.source_kind??'unknown',source_name:row.source_name??null,source_type:row.source_type??null,message_id:row.id,user_id:row.user_id,source_id:row.source_id,archive_id:row.archive_id,enc:row.enc,ciphertext:row.ciphertext,preview:{enc:row.preview_enc,ciphertext:row.preview_ciphertext},source_public_key:row.source_public_key,source_certificate:row.source_certificate,created_at:row.created_at,read_at:row.read_at,scheduled_at:row.scheduled_at??null,expires_at:row.expires_at??new Date(Date.parse(row.created_at)+30*86400000).toISOString(),sound:row.sound??'default'};}
function parseCursor(value:string|null):[string,string]|null{
 if(!value)return null;
 try{const parsed=JSON.parse(atob(value));if(!Array.isArray(parsed)||parsed.length!==2||parsed.some(v=>typeof v!=='string'||v.length>64))fail(400,'invalid_cursor');return parsed as [string,string];}catch{fail(400,'invalid_cursor');}
}
export class MessageHistory {
 readonly devices:SecureDevices;
 constructor(readonly db:D1Database,readonly bucket?:R2Bucket){this.devices=new SecureDevices(db);}
 async get(session:SecureSession,id:string){await this.devices.bound(session);const row=await this.db.prepare('SELECT v2_messages.*,(SELECT name FROM sources WHERE sources.id=v2_messages.source_id AND sources.user_id=v2_messages.user_id) AS source_name,(SELECT source_type FROM sources WHERE sources.id=v2_messages.source_id AND sources.user_id=v2_messages.user_id) AS source_type FROM v2_messages WHERE id=? AND user_id=? AND deleted_at IS NULL').bind(id,session.user.id).first<MessageRow>();if(!row)fail(404,'message_not_found');return {message:apiMessage(row)};}
 async list(session:SecureSession,cursor:string|null,limitInput:string|null,deletions=false){
  await this.devices.bound(session);const limit=limitInput===null?50:Number(limitInput);if(!Number.isInteger(limit)||limit<1||limit>100)fail(400,'invalid_limit');
  const after=parseCursor(cursor),column=deletions?'deleted_at':'created_at',direction=deletions?'>':'<';
  const clauses=['user_id=?',deletions?'deleted_at IS NOT NULL':'deleted_at IS NULL'];const args:unknown[]=[session.user.id];
  if(after){clauses.push(`(${column}${direction}? OR (${column}=? AND id${direction}?))`);args.push(after[0],after[0],after[1]);}
  const rows=(await this.db.prepare(`SELECT v2_messages.*,(SELECT name FROM sources WHERE sources.id=v2_messages.source_id AND sources.user_id=v2_messages.user_id) AS source_name,(SELECT source_type FROM sources WHERE sources.id=v2_messages.source_id AND sources.user_id=v2_messages.user_id) AS source_type FROM v2_messages WHERE ${clauses.join(' AND ')} ORDER BY ${column} ${deletions?'ASC':'DESC'},id ${deletions?'ASC':'DESC'} LIMIT ?`).bind(...args,limit+1).all<MessageRow>()).results;
  const more=rows.length>limit,page=rows.slice(0,limit),last=page.at(-1);
  const next=more&&last?btoa(JSON.stringify([deletions?last.deleted_at:last.created_at,last.id])):null;
  if(deletions)return {deleted_ids:page.map(m=>m.id),next_cursor:next};
  const deleted=(await this.db.prepare('SELECT id FROM v2_messages WHERE user_id=? AND deleted_at IS NOT NULL ORDER BY deleted_at DESC LIMIT 100').bind(session.user.id).all<{id:string}>()).results.map(r=>r.id);
  return {messages:page.map(apiMessage),next_cursor:next,deleted_ids:deleted};
 }
 // History is visible immediately. Read suppresses immediate pushes, but an explicit
 // scheduled_at remains a requested reminder and still delivers at its due time.
 async read(session:SecureSession,id:string){await this.devices.bound(session);const result=await this.db.prepare('UPDATE v2_messages SET read_at=COALESCE(read_at,?) WHERE id=? AND user_id=? AND deleted_at IS NULL').bind(new Date().toISOString(),id,session.user.id).run();if(!result.meta.changes)fail(404,'message_not_found');}
 async delete(session:SecureSession,id:string){
  await this.devices.bound(session);const owned=await this.db.prepare('SELECT id FROM v2_messages WHERE id=? AND user_id=?').bind(id,session.user.id).first();if(!owned)fail(404,'message_not_found');
  const now=new Date().toISOString();
  await this.db.batch([
   this.db.prepare("INSERT OR IGNORE INTO v2_blob_deletions SELECT object_key,? FROM v2_attachments WHERE message_id=? AND user_id=? AND status='committed'").bind(now,id,session.user.id),
   this.db.prepare("UPDATE v2_storage SET used_bytes=used_bytes-COALESCE((SELECT SUM(size) FROM v2_attachments WHERE message_id=? AND user_id=? AND status='committed'),0) WHERE user_id=?").bind(id,session.user.id,session.user.id),
   this.db.prepare("UPDATE v2_attachments SET status='deleted',content_hash=NULL,read_token_hash='' WHERE message_id=? AND user_id=?").bind(id,session.user.id),
   this.db.prepare("UPDATE v2_messages SET deleted_at=COALESCE(deleted_at,?),enc=NULL,ciphertext=NULL,preview_enc=NULL,preview_ciphertext=NULL,source_public_key=NULL,source_certificate=NULL WHERE id=? AND user_id=?").bind(now,id,session.user.id),
   this.db.prepare("UPDATE v2_deliveries SET status='deleted',lease_id=NULL,lease_until=NULL WHERE message_id=?").bind(id)
  ]);
  await new AttachmentService(this.db,this.bucket).deleteQueued();
 }
}
