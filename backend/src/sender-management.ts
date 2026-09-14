import type { EmailAuthService } from './auth-service';
import { AuthHttpError } from './crypto';
import { bearerToken, emptyResponse, jsonResponse, readJsonBody } from './http';
import { validateKeyExpiry } from './product-service';

const keyColumns = `k.id,k.source_id,s.name AS source_name,k.key_prefix,k.scopes,
 k.created_at,k.last_used_at,k.expires_at,k.revoked_at,
 (SELECT suspended_until FROM sender_security_state sec WHERE sec.key_id=k.id AND sec.user_id=k.user_id) AS suspended_until`;
type KeyMetadata = {id:string;source_id:string;source_name:string;key_prefix:string;scopes:string;
 created_at:string;last_used_at:string|null;expires_at:string|null;revoked_at:string|null};
type MessageMetadata = {id:string;source_id:string;source_key_id:string|null;source_name:string;
 created_at:string;scheduled_at?:string|null;expires_at?:string|null;read_at:string|null};
type DeliveryMetadata = {device_id:string;device_name:string;status:string;last_error:string|null;attempts:number;accepted_at:string|null};

export class SenderManagement {
 constructor(private readonly db:D1Database) {}

 async keys(userID:string, sourceID:string|null = null) {
  const rows=await this.db.prepare(`SELECT ${keyColumns} FROM source_keys k
   JOIN sources s ON s.id=k.source_id AND s.user_id=k.user_id
   WHERE k.user_id=? AND (? IS NULL OR k.source_id=?) ORDER BY k.created_at DESC,k.id DESC`)
   .bind(userID,sourceID,sourceID).all<KeyMetadata>();
  return {keys:rows.results.map(row=>({...row,scopes:JSON.parse(row.scopes) as string[]}))};
 }

 async expiry(userID:string,id:string,value:unknown) {
  const expiry=validateKeyExpiry(value);
  const result=await this.db.prepare('UPDATE source_keys SET expires_at=? WHERE id=? AND user_id=?')
   .bind(expiry,id,userID).run();
  if(!result.meta.changes) throw new AuthHttpError(404,'key_not_found','Key not found');
  const row=await this.db.prepare(`SELECT ${keyColumns} FROM source_keys k JOIN sources s ON s.id=k.source_id AND s.user_id=k.user_id WHERE k.id=? AND k.user_id=?`)
   .bind(id,userID).first<KeyMetadata>();
  return {key:row ? {...row,scopes:JSON.parse(row.scopes) as string[]} : null};
 }

 async revoke(userID:string,id:string) {
  const result=await this.db.prepare('UPDATE source_keys SET revoked_at=COALESCE(revoked_at,?) WHERE id=? AND user_id=?')
   .bind(new Date().toISOString(),id,userID).run();
  if(!result.meta.changes) throw new AuthHttpError(404,'key_not_found','Key not found');
 }

 async logs(userID:string,params:URLSearchParams) {
  const rawLimit=params.get('limit')??'50';
  if(!/^\d+$/.test(rawLimit)||Number(rawLimit)<1||Number(rawLimit)>100) throw new AuthHttpError(400,'invalid_limit','limit must be between 1 and 100');
  const limit=Number(rawLimit),values: (string|number)[]=[userID];
  let where='m.user_id=?';
  for(const [parameter,column] of [['key_id','source_key_id'],['source_id','source_id']]) {
   const value=params.get(parameter);
   if(value){where+=` AND m.${column}=?`;values.push(value);}
  }
  const cursor=params.get('cursor');
  if(cursor) {
   let position:unknown;
   try{position=JSON.parse(atob(cursor));}catch{throw new AuthHttpError(400,'invalid_cursor','Invalid cursor');}
   if(!Array.isArray(position)||position.length!==2||typeof position[0]!=='string'||!Number.isFinite(Date.parse(position[0]))||typeof position[1]!=='string'||position[1].length>128) throw new AuthHttpError(400,'invalid_cursor','Invalid cursor');
   where+=' AND (m.created_at<? OR (m.created_at=? AND m.id<?))';
   values.push(position[0],position[0],position[1]);
  }
  // m.* permits rolling integration with the independent scheduling migration.
  // Only the explicit metadata projection below is returned to clients.
  const rows=await this.db.prepare(`SELECT m.*,s.name AS source_name FROM v2_messages m
   JOIN sources s ON s.id=m.source_id AND s.user_id=m.user_id
   WHERE ${where} ORDER BY m.created_at DESC,m.id DESC LIMIT ?`).bind(...values,limit+1).all<MessageMetadata>();
  const page=rows.results.slice(0,limit),logs=[];
  const byMessage=new Map<string,DeliveryMetadata[]>();
  // Keep each query below D1's bind limit without one query per message.
  for(let offset=0;offset<page.length;offset+=90) {
   const ids=page.slice(offset,offset+90).map(message=>message.id);
   const deliveries=await this.db.prepare(`SELECT d.message_id,d.device_id,v.name AS device_name,d.status,d.last_error,d.attempts,d.accepted_at
    FROM v2_deliveries d JOIN secure_devices v ON v.id=d.device_id
    WHERE v.user_id=? AND d.message_id IN (${ids.map(()=>'?').join(',')}) ORDER BY d.device_id`)
    .bind(userID,...ids).all<DeliveryMetadata & {message_id:string}>();
   for(const {message_id,...delivery} of deliveries.results) {
    const entries=byMessage.get(message_id)??[];entries.push(delivery);byMessage.set(message_id,entries);
   }
  }
  for(const message of page) {
   logs.push({message_id:message.id,source_id:message.source_id,key_id:message.source_key_id,
    source_name:message.source_name,created_at:message.created_at,scheduled_at:message.scheduled_at??null,
    expires_at:message.expires_at??null,read_at:message.read_at,deliveries:byMessage.get(message.id)??[]});
  }
  const last=page.at(-1);
  return {logs,next_cursor:rows.results.length>limit&&last?btoa(JSON.stringify([last.created_at,last.id])):null};
 }
}

export async function managementRoute(request:Request,env:Env,auth:EmailAuthService,headers:HeadersInit):Promise<Response|null> {
 const url=new URL(request.url),path=url.pathname,method=request.method;
 const key=/^\/v2\/keys\/([^/]+)$/.exec(path);
 if(!((path==='/v2/keys'||path==='/v2/logs')&&method==='GET')&&!(key&&(method==='PATCH'||method==='DELETE')))return null;
 const session=await auth.authenticate(bearerToken(request));
 if(!session.user.emailVerifiedAt) throw new AuthHttpError(403,'email_verification_required','Verify your email first');
 const service=new SenderManagement(env.DB);
 if(path==='/v2/keys'&&method==='GET')return jsonResponse(await service.keys(session.user.id,url.searchParams.get('source_id')),200,headers);
 if(path==='/v2/logs'&&method==='GET')return jsonResponse(await service.logs(session.user.id,url.searchParams),200,headers);
 if(key&&method==='PATCH') {
  const body=await readJsonBody(request);
  if(!body||(!Object.hasOwn(body,'expires_at')&&!Object.hasOwn(body,'expiresAt'))||Object.keys(body).length!==1) throw new AuthHttpError(400,'invalid_request','Provide expires_at only');
  return jsonResponse(await service.expiry(session.user.id,key[1],Object.hasOwn(body,'expires_at')?body.expires_at:body.expiresAt),200,headers);
 }
 if(key&&method==='DELETE'){await service.revoke(session.user.id,key[1]);return emptyResponse(204,headers);}
 return null;
}
