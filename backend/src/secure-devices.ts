import { base64, bytes, digest, fail, fields, str, uuid, verify } from './secure-validation';
import { publicDevice, type Device, type SecureSession } from './secure-types';

export class SecureDevices {
 constructor(readonly db: D1Database) {}
 async challenge(session: SecureSession) {
  const challenge=base64(crypto.getRandomValues(new Uint8Array(32)));
  await this.db.prepare('INSERT INTO secure_registration_challenges VALUES (?,?,?) ON CONFLICT(session_id) DO UPDATE SET challenge_hash=excluded.challenge_hash,expires_at=excluded.expires_at').bind(session.session.id,await digest(challenge),new Date(Date.now()+300000).toISOString()).run();
  return {challenge};
 }
 async identity(user: string): Promise<string | null> {
  return (await this.db.prepare('SELECT public_key FROM secure_identities WHERE user_id=?').bind(user).first<{public_key:string}>())?.public_key ?? null;
 }
 async get(user: string, id: string): Promise<Device> {
  const device = await this.db.prepare('SELECT * FROM secure_devices WHERE user_id=? AND id=?').bind(user,id).first<Device>();
  if (!device) fail(404,'device_not_found');
  return device;
 }
 async bound(session: SecureSession, active = true): Promise<Device> {
  if (!session.session.deviceId) fail(403,'device_registration_required');
  const device = await this.get(session.user.id, session.session.deviceId);
  if (device.status === 'revoked' || (active && device.status !== 'active')) fail(403,'device_not_approved');
  return device;
 }
 async list(user: string) {
  const rows = await this.db.prepare('SELECT * FROM secure_devices WHERE user_id=? ORDER BY created_at').bind(user).all<Device>();
  return { identity_public_key: await this.identity(user), devices: rows.results.map(publicDevice) };
 }
 async register(session: SecureSession, input: Record<string,unknown>) {
  fields(input,['deviceId','name','platform','publicKey','proof','identityPublicKey','certificate','challenge','systemVersion','appVersion','model']);
  const systemVersion=input.systemVersion===undefined?null:str(input.systemVersion,80);
  const appVersion=input.appVersion===undefined?null:str(input.appVersion,80);
  const model=input.model===undefined?null:str(input.model,100);
  const id=uuid(input.deviceId), user=session.user.id, key=str(input.publicKey), now=new Date().toISOString();
  bytes(key,65);
  bytes(input.challenge,32);
  await verify(key,input.proof,`pushnow-register-v1\n${user}\n${id}\n${key}\n${input.challenge}`);
  const consumed=await this.db.prepare('DELETE FROM secure_registration_challenges WHERE session_id=? AND challenge_hash=? AND expires_at>?').bind(session.session.id,await digest(input.challenge as string),now).run();
  if(!consumed.meta.changes) fail(403,'registration_challenge_expired');
  let device = await this.db.prepare('SELECT * FROM secure_devices WHERE id=?').bind(id).first<Device>();
  let identity = await this.identity(user);
  if (device) {
   if (device.user_id !== user || device.public_key !== key || device.status === 'revoked') fail(409,'device_identity_conflict');
  } else {
   const name=str(input.name,80), platform=str(input.platform,30);
   if (!identity) {
    identity=str(input.identityPublicKey);
    await verify(identity,input.certificate,`pushnow-device-v1\n${user}\n${id}\n${key}`);
    // The unique identity insert and first device creation must commit together.
    await this.db.batch([
     this.db.prepare('INSERT INTO secure_identities VALUES (?,?,?)').bind(user,identity,now),
     this.db.prepare("INSERT INTO secure_devices(id,user_id,name,platform,public_key,certificate,status,last_seen_at,created_at) VALUES (?,?,?,?,?,?,'active',?,?)").bind(id,user,name,platform,key,input.certificate,now,now)
    ]);
   } else {
    await this.db.prepare("INSERT INTO secure_devices(id,user_id,name,platform,public_key,status,last_seen_at,created_at) VALUES (?,?,?,?,?,'pending',?,?)").bind(id,user,name,platform,key,now,now).run();
   }
   device=await this.get(user,id);
  }
  await this.db.batch([
   this.db.prepare('UPDATE sessions SET device_id=?,updated_at=? WHERE id=? AND user_id=? AND revoked_at IS NULL').bind(id,now,session.session.id,user),
   this.db.prepare('UPDATE secure_devices SET last_seen_at=?,system_version=COALESCE(?,system_version),app_version=COALESCE(?,app_version),model=COALESCE(?,model) WHERE id=? AND user_id=?').bind(now,systemVersion,appVersion,model,id,user)
  ]);
  return {device:publicDevice(await this.get(user,id)),identity_public_key:identity};
 }
 async update(user: string,id: string,input:Record<string,unknown>) {
  fields(input,['name','notificationsEnabled']);
  const device=await this.get(user,id);
  if (device.status==='revoked') fail(409,'device_revoked');
  const name=input.name===undefined?device.name:str(input.name,80);
  if (input.notificationsEnabled!==undefined && typeof input.notificationsEnabled!=='boolean') fail(400,'invalid_preference');
  const enabled=input.notificationsEnabled===undefined?device.notifications_enabled:Number(input.notificationsEnabled);
  await this.db.prepare('UPDATE secure_devices SET name=?,notifications_enabled=? WHERE user_id=? AND id=?').bind(name,enabled,user,id).run();
  return {device:publicDevice(await this.get(user,id))};
 }
 async revoke(user:string,id:string) {
  await this.get(user,id);
  await this.db.batch([
   this.db.prepare("UPDATE secure_devices SET status='revoked',notifications_enabled=0,approval_enc=NULL,approval_ciphertext=NULL WHERE user_id=? AND id=?").bind(user,id),
   this.db.prepare('UPDATE sessions SET revoked_at=? WHERE user_id=? AND device_id=?').bind(new Date().toISOString(),user,id),
   this.db.prepare('DELETE FROM secure_push_tokens WHERE device_id=?').bind(id)
  ]);
 }
 async approve(session:SecureSession,id:string,input:Record<string,unknown>) {
  await this.bound(session);
  fields(input,['certificate','approval']);
  const device=await this.get(session.user.id,id);
  if(device.status!=='pending') fail(409,'device_not_pending');
  await verify(await this.identity(session.user.id),input.certificate,`pushnow-device-v1\n${session.user.id}\n${id}\n${device.public_key}`);
  const approval=input.approval as Record<string,unknown>;
  if(!approval || typeof approval!=='object') fail(400,'invalid_approval');
  fields(approval,['enc','ciphertext']);bytes(approval.enc,65);bytes(approval.ciphertext,16,1024);
  await this.db.prepare("UPDATE secure_devices SET status='active',certificate=?,approval_enc=?,approval_ciphertext=? WHERE id=? AND user_id=? AND status='pending'").bind(input.certificate,approval.enc,approval.ciphertext,id,session.user.id).run();
  return {device:publicDevice(await this.get(session.user.id,id))};
 }
 async approval(session:SecureSession,id:string) {
  const device=await this.bound(session,false);
  if(device.id!==id) fail(403,'wrong_device');
  return {approval:device.approval_enc?{enc:device.approval_enc,ciphertext:device.approval_ciphertext}:null};
 }
 async logout(session:SecureSession) {
  if(!session.session.deviceId) return;
  await this.db.batch([
   this.db.prepare('DELETE FROM secure_push_tokens WHERE device_id=? AND device_id IN (SELECT id FROM secure_devices WHERE user_id=?)').bind(session.session.deviceId,session.user.id),
   this.db.prepare('UPDATE sessions SET revoked_at=? WHERE device_id=? AND user_id=?').bind(new Date().toISOString(),session.session.deviceId,session.user.id)
  ]);
 }
}
