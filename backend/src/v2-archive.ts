import { SecureDevices } from './secure-devices';
import type { SecureSession } from './secure-types';
import { bytes, fail, fields, str, uuid, verify } from './secure-validation';
export type Archive={id:string;public_key:string;certificate:string};
export class ArchiveService {
 readonly devices:SecureDevices;
 constructor(readonly db:D1Database){this.devices=new SecureDevices(db);}
 async get(user:string):Promise<Archive|null>{return this.db.prepare('SELECT id,public_key,certificate FROM v2_archives WHERE user_id=?').bind(user).first<Archive>();}
 async require(user:string){const archive=await this.get(user);if(!archive)fail(409,'archive_required');return archive;}
 async initialize(session:SecureSession,input:Record<string,unknown>){
  await this.devices.bound(session);fields(input,['id','publicKey','certificate']);
  const id=uuid(input.id),key=str(input.publicKey);bytes(key,65);
  try{await crypto.subtle.importKey('raw',bytes(key,65),{name:'ECDH',namedCurve:'P-256'},false,[]);}catch{fail(400,'invalid_public_key');}
  await verify(await this.devices.identity(session.user.id),input.certificate,`pushnow-archive-v1\n${session.user.id}\n${id}\n${key}`);
  await this.db.prepare('INSERT INTO v2_archives VALUES (?,?,?,?,?) ON CONFLICT(user_id) DO NOTHING').bind(session.user.id,id,key,input.certificate,new Date().toISOString()).run();
  const saved=await this.require(session.user.id);
  if(saved.id!==id||saved.public_key!==key)fail(409,'archive_immutable');
  return {archive:saved};
 }
 async grant(session:SecureSession,target:string,input:Record<string,unknown>){
  await this.devices.bound(session);await this.require(session.user.id);
  const device=await this.devices.get(session.user.id,target);if(device.status!=='active')fail(403,'device_not_approved');
  fields(input,['enc','ciphertext']);bytes(input.enc,65);bytes(input.ciphertext,16,1024);
  await this.db.prepare('INSERT INTO v2_archive_grants VALUES (?,?,?,?) ON CONFLICT(device_id) DO UPDATE SET enc=excluded.enc,ciphertext=excluded.ciphertext').bind(target,session.user.id,input.enc,input.ciphertext).run();
 }
 async readGrant(session:SecureSession,target:string){
  const device=await this.devices.bound(session);if(device.id!==target)fail(403,'wrong_device');
  return {grant:await this.db.prepare('SELECT enc,ciphertext FROM v2_archive_grants WHERE device_id=? AND user_id=?').bind(target,session.user.id).first()};
 }
}
