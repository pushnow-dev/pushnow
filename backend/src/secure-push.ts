import { hashSecret } from './crypto';
import { SecureDevices } from './secure-devices';
import { publicDevice, type SecureSession } from './secure-types';
import { base64, bytes, fail, fields, str } from './secure-validation';

async function storageKey(secret?:string) {
 if(!secret) fail(503,'push_storage_not_configured');
 return crypto.subtle.importKey('raw',bytes(secret,32),{name:'AES-GCM'},false,['encrypt','decrypt']);
}
export async function encryptToken(token:string,device:string,secret?:string) {
 const nonce=crypto.getRandomValues(new Uint8Array(12));
 const encrypted=await crypto.subtle.encrypt({name:'AES-GCM',iv:nonce,additionalData:new TextEncoder().encode(device)},await storageKey(secret),new TextEncoder().encode(token));
 return `${base64(nonce)}.${base64(new Uint8Array(encrypted))}`;
}
export async function decryptToken(value:string,device:string,secret?:string) {
 const [nonce,ciphertext]=value.split('.');
 const plain=await crypto.subtle.decrypt({name:'AES-GCM',iv:bytes(nonce,12),additionalData:new TextEncoder().encode(device)},await storageKey(secret),bytes(ciphertext,16,4112));
 return new TextDecoder().decode(plain);
}
export async function registerPush(env:Env,session:SecureSession,id:string,input:Record<string,unknown>) {
 const devices=new SecureDevices(env.DB),device=await devices.bound(session);
 if(device.id!==id) fail(403,'wrong_device');
 fields(input,['token','environment','appVersion']);
 const token=str(input.token,device.platform==='harmony'?4096:512);
 const normalized=device.platform==='ios'?token.toLowerCase():token;
 if(device.platform==='ios' && (!/^[a-f0-9]{64,512}$/.test(normalized)||normalized.length%2)) fail(400,'invalid_push_token');
 if(device.platform==='harmony' && !/^[A-Za-z0-9:_./+=-]{16,4096}$/.test(normalized)) fail(400,'invalid_push_token');
 if(input.environment!=='sandbox'&&input.environment!=='production') fail(400,'invalid_push_environment');
 const hash=await hashSecret(`${input.environment}.${device.platform}.${normalized}`,env.AUTH_TOKEN_PEPPER);
 const encrypted=await encryptToken(normalized,id,env.PUSH_TOKEN_ENCRYPTION_KEY);
 await env.DB.batch([
  env.DB.prepare('DELETE FROM secure_push_tokens WHERE token_hash=? AND device_id<>?').bind(hash,id),
  env.DB.prepare(`INSERT INTO secure_push_tokens VALUES (?,?,?,?,?,?) ON CONFLICT(device_id) DO UPDATE SET environment=excluded.environment,token_hash=excluded.token_hash,token_encrypted=excluded.token_encrypted,app_version=excluded.app_version,updated_at=excluded.updated_at`).bind(id,input.environment,hash,encrypted,input.appVersion===undefined?null:str(input.appVersion,40),new Date().toISOString())
 ]);
 return {device:publicDevice(device)};
}
function url64(value:Uint8Array) {return base64(value).replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');}
export function pushConfigured(env:Env) {return Boolean(env.PUSH_TOKEN_ENCRYPTION_KEY&&env.APNS_PRIVATE_KEY&&env.APNS_KEY_ID&&env.APNS_TEAM_ID&&env.APNS_TOPIC);}
export { harmonyPushConfigured, sendHarmonyPush } from './harmony-push';
export async function sendAPNs(env:Env,token:string,environment:string,payload:unknown,expires:string) {
 if(!pushConfigured(env)) fail(503,'apns_not_configured');
 const encode=(value:unknown)=>url64(new TextEncoder().encode(JSON.stringify(value)));
 const unsigned=`${encode({alg:'ES256',kid:env.APNS_KEY_ID})}.${encode({iss:env.APNS_TEAM_ID,iat:Math.floor(Date.now()/1000)})}`;
 const pem=env.APNS_PRIVATE_KEY!.replace(/-----[^-]+-----/g,'').replace(/\s/g,'');
 const key=await crypto.subtle.importKey('pkcs8',Uint8Array.from(atob(pem),c=>c.charCodeAt(0)),{name:'ECDSA',namedCurve:'P-256'},false,['sign']);
 const signature=await crypto.subtle.sign({name:'ECDSA',hash:'SHA-256'},key,new TextEncoder().encode(unsigned));
 const host=environment==='sandbox'?'api.sandbox.push.apple.com':'api.push.apple.com';
 const body=JSON.stringify(payload);
 if(new TextEncoder().encode(body).length>4096) return {status:413,reason:'PayloadTooLarge'};
 const response=await fetch(`https://${host}/3/device/${token}`,{method:'POST',headers:{authorization:`bearer ${unsigned}.${url64(new Uint8Array(signature))}`,'apns-topic':env.APNS_TOPIC!,'apns-push-type':'alert','apns-priority':'10','apns-expiration':String(Math.floor(Date.parse(expires)/1000)),'content-type':'application/json'},body,signal:AbortSignal.timeout(15000)});
 const data=await response.json().catch(()=>null) as {reason?:unknown}|null;
 const known=['BadDeviceToken','Unregistered','DeviceTokenNotForTopic','PayloadTooLarge','ExpiredProviderToken','InvalidProviderToken','TooManyRequests','ServiceUnavailable','Shutdown'];
 const reason=typeof data?.reason==='string'&&known.includes(data.reason)?data.reason:`apns_${response.status}`;
 return {status:response.status,reason:response.status===200?'accepted':reason};
}
export function securePayload(envelope:unknown) {
 return {aps:{alert:{title:'PushNow',body:'You have a new encrypted reminder.'},'mutable-content':1,sound:'default'},secure:envelope};
}
