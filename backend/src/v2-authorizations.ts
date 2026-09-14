import { ArchiveService } from './v2-archive';
import { base64, bytes, digest, fail, fields, str, uuid } from './secure-validation';
import { SecureDevices } from './secure-devices';
import type { SecureSession } from './secure-types';
import { validateKeyExpiry } from './product-service';
type Authorization={id:string;name:string;public_key:string;device_code_hash:string;user_code:string;expires_at:string;last_poll_at:string|null;source_id:string|null;grant_enc:string|null;grant_ciphertext:string|null;consumed_at:string|null};
export class SenderAuthorizationService {
 readonly devices:SecureDevices;
 constructor(readonly db:D1Database){this.devices=new SecureDevices(db);}
 async rate(scope:string,identity:string,limit:number){
  const bucket=Math.floor(Date.now()/60000),id=await digest(`${scope}.${identity}.${bucket}`);
  const row=await this.db.prepare('INSERT INTO v2_rate_limits VALUES (?,1,?) ON CONFLICT(id) DO UPDATE SET count=count+1 RETURNING count').bind(id,new Date((bucket+2)*60000).toISOString()).first<{count:number}>();
  if(!row||row.count>limit)fail(429,'rate_limited');
 }
 async create(input:Record<string,unknown>,ip:string){
  await this.rate('issue',ip,10);fields(input,['name','publicKey']);
  const name=str(input.name,80),key=str(input.publicKey);bytes(key,65);
  try{await crypto.subtle.importKey('raw',bytes(key,65),{name:'ECDH',namedCurve:'P-256'},false,[]);}catch{fail(400,'invalid_public_key');}
  const id=crypto.randomUUID(),code=base64(crypto.getRandomValues(new Uint8Array(32))),alphabet='ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  const userCode=Array.from(crypto.getRandomValues(new Uint8Array(8)),n=>alphabet[n%32]).join('');
  const expiry=new Date(Date.now()+600000).toISOString();
  await this.db.prepare('INSERT INTO v2_authorizations(id,name,public_key,device_code_hash,user_code,expires_at) VALUES (?,?,?,?,?,?)').bind(id,name,key,await digest(code),userCode,expiry).run();
  return {id,device_code:code,user_code:userCode,expires_at:expiry,interval:3};
 }
 async createAccount(session:SecureSession,input:Record<string,unknown>,ip:string){
  if(!session.user.emailVerifiedAt)fail(403,"email_verification_required");
  await this.rate('account-issue',session.user.id,5);
  const identity=await this.devices.identity(session.user.id);
  if(!identity)fail(409,'trusted_device_required');
  await new ArchiveService(this.db).require(session.user.id);
  const result=await this.create(input,ip);
  await this.db.prepare('UPDATE v2_authorizations SET account_user_id=? WHERE id=?').bind(session.user.id,result.id).run();
  return {...result,user_id:session.user.id,identity_public_key:identity};
 }
 async pendingAccount(session:SecureSession){
  await this.devices.bound(session);
  await this.rate('account-pending',session.user.id,30);
  return {authorizations:(await this.db.prepare('SELECT id,name,public_key,expires_at FROM v2_authorizations WHERE account_user_id=? AND expires_at>? AND source_id IS NULL AND consumed_at IS NULL ORDER BY expires_at LIMIT 10').bind(session.user.id,new Date().toISOString()).all()).results};
 }
 async lookup(session:SecureSession,code:string){
  await this.devices.bound(session);await this.rate('lookup',session.user.id,30);
  const row=await this.db.prepare('SELECT id,name,public_key,expires_at FROM v2_authorizations WHERE (account_user_id IS NULL OR account_user_id=?) AND user_code=? AND expires_at>? AND consumed_at IS NULL AND source_id IS NULL').bind(session.user.id,code.toUpperCase(),new Date().toISOString()).first();
  if(!row)fail(404,'authorization_not_found');
  return {authorization:row,archive:await new ArchiveService(this.db).require(session.user.id)};
 }
 async approve(session:SecureSession,id:string,input:Record<string,unknown>){
  await this.devices.bound(session);fields(input,['sourceId','enc','ciphertext','expiresAt']);uuid(input.sourceId);bytes(input.enc,65);bytes(input.ciphertext,16,8192);
  const expiry=validateKeyExpiry(input.expiresAt??null);
  const source=await this.db.prepare("SELECT s.public_key FROM secure_sources s JOIN sources p ON p.id=s.source_id WHERE s.source_id=? AND s.user_id=? AND p.status='active'").bind(input.sourceId,session.user.id).first<{public_key:string}>();
  if(!source)fail(403,'invalid_source');
  const results=await this.db.batch([
   this.db.prepare('UPDATE v2_authorizations SET source_id=?,grant_enc=?,grant_ciphertext=? WHERE id=? AND public_key=? AND expires_at>? AND (account_user_id IS NULL OR account_user_id=?) AND source_id IS NULL AND consumed_at IS NULL').bind(input.sourceId,input.enc,input.ciphertext,id,source.public_key,new Date().toISOString(),session.user.id),
   this.db.prepare('UPDATE source_keys SET expires_at=? WHERE source_id=? AND user_id=? AND revoked_at IS NULL AND changes()=1 AND EXISTS(SELECT 1 FROM v2_authorizations WHERE id=? AND source_id=? AND grant_enc=? AND grant_ciphertext=? AND consumed_at IS NULL)').bind(expiry,input.sourceId,session.user.id,id,input.sourceId,input.enc,input.ciphertext)
  ]);
  if(!results[0].meta.changes)fail(409,'authorization_unavailable');
 }
 async token(id:string,input:Record<string,unknown>,ip:string){
  await this.rate('poll',ip,60);fields(input,['deviceCode']);bytes(input.deviceCode,32);
  const now=new Date().toISOString(),hash=await digest(input.deviceCode as string);
  const row=await this.db.prepare('SELECT * FROM v2_authorizations WHERE id=? AND device_code_hash=? AND expires_at>? AND consumed_at IS NULL').bind(id,hash,now).first<Authorization>();
  if(!row)fail(401,'authorization_expired');
  const claimed=await this.db.prepare('UPDATE v2_authorizations SET last_poll_at=? WHERE id=? AND device_code_hash=? AND consumed_at IS NULL AND (last_poll_at IS NULL OR last_poll_at<=?)').bind(now,id,hash,new Date(Date.now()-3000).toISOString()).run();
  if(!claimed.meta.changes)fail(429,'slow_down');
  if(!row.grant_enc)return {status:'pending'};
  const consumed=await this.db.prepare('UPDATE v2_authorizations SET consumed_at=?,grant_enc=NULL,grant_ciphertext=NULL WHERE id=? AND consumed_at IS NULL').bind(now,id).run();
  if(!consumed.meta.changes)fail(401,'authorization_consumed');
  return {status:'approved',grant:{enc:row.grant_enc,ciphertext:row.grant_ciphertext}};
 }
 async senders(session:SecureSession){await this.devices.bound(session);return {senders:(await this.db.prepare('SELECT p.id,p.name,s.public_key,p.created_at,p.status FROM sources p JOIN secure_sources s ON s.source_id=p.id WHERE p.user_id=? ORDER BY p.created_at DESC').bind(session.user.id).all()).results};}
 async revoke(session:SecureSession,id:string){
  await this.devices.bound(session);
  const source=await this.db.prepare('SELECT id FROM sources WHERE id=? AND user_id=?').bind(id,session.user.id).first();if(!source)fail(404,'source_not_found');
  await this.db.batch([this.db.prepare("UPDATE sources SET status='revoked',updated_at=? WHERE id=? AND user_id=?").bind(new Date().toISOString(),id,session.user.id),this.db.prepare('UPDATE source_keys SET revoked_at=? WHERE source_id=? AND user_id=?').bind(new Date().toISOString(),id,session.user.id)]);
 }
}
