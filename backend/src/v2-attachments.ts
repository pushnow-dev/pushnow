import { digest, fail, fields, uuid } from './secure-validation';
export type SourceOwner={user_id:string;source_id:string};
export type Attachment={id:string;user_id:string;source_id:string;size:number;object_key:string;read_token_hash:string;status:string;content_hash:string|null;message_id:string|null;expires_at:string};
declare global {interface Env {SECURE_BLOBS?:R2Bucket;}}
export class AttachmentService {
 constructor(readonly db:D1Database,readonly bucket?:R2Bucket){}
 requireBucket(){if(!this.bucket)fail(503,'encrypted_storage_not_configured');return this.bucket;}
 async reserve(source:SourceOwner,input:Record<string,unknown>){
  this.requireBucket();fields(input,['id','size','readToken']);const id=uuid(input.id),size=input.size;
  if(typeof size!=='number'||!Number.isSafeInteger(size)||size<17||size>20*1024*1024)fail(413,'attachment_size_exceeded');
  if(typeof input.readToken!=='string'||!/^[A-Za-z0-9_-]{43}$/.test(input.readToken))fail(400,'invalid_read_token');
  const tokenHash=await digest(input.readToken);
  const existing=await this.db.prepare('SELECT * FROM v2_attachments WHERE id=?').bind(id).first<Attachment>();
  if(existing){if(existing.user_id!==source.user_id||existing.source_id!==source.source_id||existing.size!==size||existing.read_token_hash!==tokenHash||existing.status==='deleted')fail(409,'attachment_conflict');return {id};}
  try{await this.db.batch([
   this.db.prepare("INSERT INTO v2_attachments(id,user_id,source_id,size,object_key,read_token_hash,status,expires_at) VALUES (?,?,?,?,?,?,'reserved',?)").bind(id,source.user_id,source.source_id,size,crypto.randomUUID(),tokenHash,new Date(Date.now()+86400000).toISOString()),
   this.db.prepare('INSERT INTO v2_storage VALUES (?,?) ON CONFLICT(user_id) DO UPDATE SET used_bytes=used_bytes+excluded.used_bytes').bind(source.user_id,size)
  ]);}catch(error){
   const race=await this.db.prepare('SELECT * FROM v2_attachments WHERE id=?').bind(id).first<Attachment>();
   if(race){if(race.user_id===source.user_id&&race.source_id===source.source_id&&race.size===size&&race.read_token_hash===tokenHash&&race.status!=='deleted')return {id};fail(409,'attachment_conflict');}
   if(error instanceof Error&&error.message.includes('used_bytes'))fail(402,'storage_quota_exceeded');throw error;
  }
  return {id};
 }
 async put(source:SourceOwner,id:string,request:Request){
  const bucket=this.requireBucket(),row=await this.db.prepare('SELECT * FROM v2_attachments WHERE id=? AND user_id=? AND source_id=?').bind(id,source.user_id,source.source_id).first<Attachment>();
  if(!row||(row.status!=='committed'&&row.expires_at<=new Date().toISOString())||!['reserved','uploaded','committed'].includes(row.status))fail(404,'attachment_not_uploadable');
  if(!request.body)fail(400,'empty_attachment');
  const declared=request.headers.get('content-length');if(declared&&Number(declared)!==row.size)fail(413,'attachment_size_mismatch');
  const reader=request.body.getReader(),chunks:Uint8Array[]=[];let length=0;
  while(true){const {done,value}=await reader.read();if(done)break;length+=value.length;if(length>row.size){await reader.cancel();fail(413,'attachment_size_mismatch');}chunks.push(value);}
  if(length!==row.size)fail(413,'attachment_size_mismatch');
  const content=new Uint8Array(length);let offset=0;for(const chunk of chunks){content.set(chunk,offset);offset+=chunk.length;}
  const hash=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',content)),n=>n.toString(16).padStart(2,'0')).join('');
  if(row.status==='uploaded'||row.status==='committed'){if(row.content_hash!==hash)fail(409,'attachment_immutable');return;}
  const claim=await this.db.prepare("UPDATE v2_attachments SET status='uploading' WHERE id=? AND status='reserved'").bind(id).run();if(!claim.meta.changes)fail(409,'upload_in_progress');
  try{
   await bucket.put(row.object_key,content,{httpMetadata:{contentType:'application/octet-stream'}});
   const saved=await this.db.prepare("UPDATE v2_attachments SET status='uploaded',content_hash=? WHERE id=? AND status='uploading'").bind(hash,id).run();
   if(!saved.meta.changes){await bucket.delete(row.object_key);fail(409,'upload_expired');}
  }catch(error){await this.db.prepare("UPDATE v2_attachments SET status='reserved' WHERE id=? AND status='uploading'").bind(id).run();throw error;}
 }
 async download(id:string,user:string|null,readToken:string|null){
  const row=await this.db.prepare("SELECT a.* FROM v2_attachments a JOIN v2_messages m ON m.id=a.message_id WHERE a.id=? AND a.status='committed' AND m.deleted_at IS NULL").bind(id).first<Attachment>();
  if(!row||(user!==row.user_id&&(!readToken||await digest(readToken)!==row.read_token_hash)))fail(404,'attachment_not_found');
  const object=await this.requireBucket().get(row.object_key);if(!object)fail(404,'attachment_not_found');
  return new Response(object.body,{headers:{'content-type':'application/octet-stream','content-length':String(object.size),'cache-control':'private, no-store'}});
 }
 async cleanOrphans(){
  const rows=await this.db.prepare("SELECT * FROM v2_attachments WHERE status IN ('reserved','uploading','uploaded') AND expires_at<=? LIMIT 100").bind(new Date().toISOString()).all<Attachment>();
  for(const row of rows.results){await this.db.batch([
   this.db.prepare("INSERT OR IGNORE INTO v2_blob_deletions SELECT object_key,? FROM v2_attachments WHERE id=? AND status IN ('reserved','uploading','uploaded')").bind(new Date().toISOString(),row.id),
   this.db.prepare("UPDATE v2_storage SET used_bytes=used_bytes-COALESCE((SELECT size FROM v2_attachments WHERE id=? AND status IN ('reserved','uploading','uploaded')),0) WHERE user_id=?").bind(row.id,row.user_id),
   this.db.prepare("UPDATE v2_attachments SET status='deleted',read_token_hash='' WHERE id=? AND status IN ('reserved','uploading','uploaded')").bind(row.id)
  ]);}
  await this.deleteQueued();
 }
 async deleteQueued(){
  if(!this.bucket)return;
  const rows=await this.db.prepare('SELECT object_key FROM v2_blob_deletions LIMIT 100').all<{object_key:string}>();
  for(const {object_key:key} of rows.results){try{await this.bucket.delete(key);await this.db.prepare('DELETE FROM v2_blob_deletions WHERE object_key=?').bind(key).run();}catch{/* Retry persisted deletion on the next cron tick. */}}
 }
}
