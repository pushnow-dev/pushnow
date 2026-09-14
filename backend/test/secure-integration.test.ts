import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { readFileSync, readdirSync } from 'node:fs';
import { SecureDevices } from '../src/secure-devices';
import { SecureMessages } from '../src/secure-messages';
import { ProductService } from '../src/product-service';
import { D1ProductStore } from '../src/product-store';
import { D1AuthStore } from '../src/store';
import { base64 } from '../src/secure-validation';
import { decryptToken, encryptToken, registerPush, sendHarmonyPush } from '../src/secure-push';
import { cleanupExpiredSecureMessages, deliverSecureMessages } from '../src/secure-delivery';
import type { SecureSession } from '../src/secure-types';
import { EmailAuthService } from '../src/auth-service';
import { createPasswordSalt, hashPassword, hashEmail, hashSecret } from '../src/crypto';

const mf=new Miniflare(convertV4MiniflareOptions({name:'test',modules:true,script:'export default {fetch(){return new Response("ok")}}',d1Databases:['DB','UPGRADE_DB'],compatibilityDate:'2026-09-12'}));
let db:D1Database,devices:SecureDevices,messages:SecureMessages,product:ProductService;
const storage=base64(crypto.getRandomValues(new Uint8Array(32)));
const now=new Date().toISOString();
async function keys() {
 const key=await crypto.subtle.generateKey({name:'ECDSA',namedCurve:'P-256'},true,['sign','verify']);
 return {key,publicKey:base64(new Uint8Array(await crypto.subtle.exportKey('raw',key.publicKey)))};
}
async function sign(key:CryptoKey,text:string) {
 return base64(new Uint8Array(await crypto.subtle.sign({name:'ECDSA',hash:'SHA-256'},key,new TextEncoder().encode(text))));
}
async function session(user:string=crypto.randomUUID()):Promise<SecureSession> {
 await db.prepare('INSERT OR IGNORE INTO users(id,email,email_hash,email_verified_at,created_at,updated_at) VALUES (?,?,?,?,?,?)').bind(user,`${user}@example.com`,user,now,now,now).run();
 const id=crypto.randomUUID(),expiry=new Date(Date.now()+86400000).toISOString();
 await db.prepare('INSERT INTO sessions(id,user_id,access_token_hash,refresh_token_hash,expires_at,refresh_expires_at,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)').bind(id,user,id,`${id}r`,expiry,expiry,now,now).run();
 const store=new D1AuthStore(db);
 return {user:(await store.findUserByID(user))!,session:(await store.findSessionByAccessHash(id))!};
}
async function enroll(s:SecureSession,root?:Awaited<ReturnType<typeof keys>>,platform='ios') {
 const pair=await keys(),identity=root??await keys(),id=crypto.randomUUID();
 const certificate=await sign(identity.key.privateKey,`pushnow-device-v1\n${s.user.id}\n${id}\n${pair.publicKey}`);
 const {challenge}=await devices.challenge(s);
 const input={deviceId:id,name:platform==='harmony'?'Harmony phone':'Test phone',platform,publicKey:pair.publicKey,challenge,proof:await sign(pair.key.privateKey,`pushnow-register-v1\n${s.user.id}\n${id}\n${pair.publicKey}\n${challenge}`),identityPublicKey:identity.publicKey,certificate};
 const result=await devices.register(s,input);s.session.deviceId=id;
 return {pair,identity,id,input,result};
}
beforeAll(async()=>{
 db=await mf.getD1Database('DB') as unknown as D1Database;
 for(const name of readdirSync(new URL('../migrations/',import.meta.url)).sort()) {
  const sql=readFileSync(new URL(`../migrations/${name}`,import.meta.url),'utf8');
  for(const statement of sql.split(';').map(s=>s.trim()).filter(Boolean)) await db.prepare(statement).run();
 }
 devices=new SecureDevices(db);product=new ProductService(new D1ProductStore(db),{authTokenPepper:'test-pepper'});messages=new SecureMessages(db,product);
},60000);
afterAll(()=>mf.dispose(),60000);
describe('real D1 encrypted notification isolation',{timeout:30000},()=>{
 it('marks read idempotently without acknowledging and isolates owners and device delivery access',async()=>{
  const s=await session(),device=await enroll(s),foreign=await session();await enroll(foreign);
  const sameOwner=await session(s.user.id);const second=await enroll(sameOwner,device.identity);
  await db.prepare("UPDATE secure_devices SET status='active' WHERE id=?").bind(second.id).run();
  const source=crypto.randomUUID(),id=crypto.randomUUID(),expiry=new Date(Date.now()+86400000).toISOString();
  await db.prepare('INSERT INTO sources(id,user_id,name,source_type,created_at,updated_at) VALUES (?,?,?, ?,?,?)').bind(source,s.user.id,'Read test','agent',now,now).run();
  await db.prepare('INSERT INTO secure_sources VALUES (?,?,?,?)').bind(source,s.user.id,'public','certificate').run();
  await db.prepare('INSERT INTO secure_messages(id,user_id,source_id,request_hash,expires_at,scheduled_at,created_at) VALUES (?,?,?,?,?,?,?)').bind(id,s.user.id,source,'hash',expiry,now,now).run();
  await db.prepare('INSERT INTO secure_deliveries(message_id,device_id,enc,ciphertext,next_attempt_at) VALUES (?,?,?,?,?)').bind(id,device.id,'enc','ciphertext',now).run();
  expect((await messages.inbox(s)).messages[0]).toMatchObject({read_at:null,source_kind:'unknown',source_name:'Read test',source_type:'agent'});
  await expect(messages.read(foreign,id)).rejects.toMatchObject({code:'message_not_found'});
  await expect(messages.read(sameOwner,id)).rejects.toMatchObject({code:'message_not_found'});
  await messages.read(s,id);
  const first=(await messages.inbox(s)).messages[0].read_at;
  expect(typeof first).toBe('string');
  await messages.read(s,id);
  expect((await messages.inbox(s)).messages[0].read_at).toBe(first);
  expect((await db.prepare('SELECT acknowledged_at FROM secure_deliveries WHERE message_id=?').bind(id).first())?.acknowledged_at).toBeNull();
  await messages.ack(s,id);
  expect((await messages.inbox(s)).messages[0].read_at).toBe(first);
 });
 it('upgrades deployed 0004 additively without clearing existing device bindings or ciphertext',async()=>{
  const upgrade=await mf.getD1Database('UPGRADE_DB') as unknown as D1Database;
  for(const name of readdirSync(new URL('../migrations/',import.meta.url)).filter(n=>n<'0005').sort()) {
   for(const statement of readFileSync(new URL(`../migrations/${name}`,import.meta.url),'utf8').split(';').map(s=>s.trim()).filter(Boolean)) await upgrade.prepare(statement).run();
  }
  await upgrade.batch([
   upgrade.prepare("INSERT INTO users(id,email,email_hash,email_verified_at,created_at,updated_at) VALUES ('user','u@example.com','hash',?,?,?)").bind(now,now,now),
   upgrade.prepare("INSERT INTO secure_devices(id,user_id,name,platform,public_key,status,last_seen_at,created_at) VALUES ('device','user','Phone','ios','public','active',?,?)").bind(now,now),
   upgrade.prepare("INSERT INTO sessions(id,user_id,access_token_hash,refresh_token_hash,device_id,expires_at,refresh_expires_at,created_at,updated_at) VALUES ('session','user','access','refresh','device',?,?,?,?)").bind(now,now,now,now),
   upgrade.prepare("INSERT INTO sources(id,user_id,name,source_type,created_at,updated_at) VALUES ('source','user','Agent','agent',?,?)").bind(now,now),
   upgrade.prepare("INSERT INTO secure_messages VALUES ('message','user','source','request',?,?,?)").bind(now,now,now),
   upgrade.prepare("INSERT INTO secure_deliveries(message_id,device_id,enc,ciphertext,next_attempt_at) VALUES ('message','device','enc','opaque-ciphertext',?)").bind(now)
  ]);
  for(const statement of readFileSync(new URL('../migrations/0005_secure_enrollment_quota.sql',import.meta.url),'utf8').split(';').map(s=>s.trim()).filter(Boolean)) await upgrade.prepare(statement).run();
  expect((await upgrade.prepare("SELECT device_id FROM sessions WHERE id='session'").first<{device_id:string}>())?.device_id).toBe('device');
  expect((await upgrade.prepare("SELECT ciphertext FROM secure_deliveries WHERE message_id='message'").first<{ciphertext:string}>())?.ciphertext).toBe('opaque-ciphertext');
  expect((await upgrade.prepare("SELECT quota_remaining FROM secure_messages WHERE id='message'").first<{quota_remaining:number}>())?.quota_remaining).toBe(0);
  await expect(upgrade.prepare("UPDATE secure_messages SET quota_remaining=-1 WHERE id='message'").run()).rejects.toThrow();
  await upgrade.prepare("INSERT INTO secure_registration_challenges VALUES ('session','challenge',?)").bind(now).run();
 });
 it('allows logout with expired access and valid refresh, without crossing session boundaries',async()=>{
  const s=await session(),first=await enroll(s),other=await session(s.user.id),pepper='test-pepper';
  const access=crypto.randomUUID(),refresh=crypto.randomUUID(),otherRefresh=crypto.randomUUID();
  await db.prepare('UPDATE sessions SET access_token_hash=?,refresh_token_hash=?,expires_at=? WHERE id=?').bind(await hashSecret(access,pepper),await hashSecret(refresh,pepper),'2020-01-01T00:00:00.000Z',s.session.id).run();
  await db.prepare('UPDATE sessions SET refresh_token_hash=? WHERE id=?').bind(await hashSecret(otherRefresh,pepper),other.session.id).run();
  const auth=new EmailAuthService(new D1AuthStore(db),{sendVerificationEmail:async()=>{throw new Error('unused');}},{appBaseURL:'http://localhost',authEmailFrom:'test@example.com',authTokenPepper:pepper,accessTokenTTLSeconds:900,refreshTokenTTLSeconds:2592000,authCodeTTLSeconds:600});
  await expect(auth.authenticate(access)).rejects.toMatchObject({code:'session_expired'});
  await expect(auth.authenticateLogout(access,otherRefresh)).rejects.toMatchObject({code:'session_mismatch'});
  const current=await auth.authenticateLogout(access,refresh);
  expect(current.session.id).toBe(s.session.id);
  const env={DB:db,AUTH_TOKEN_PEPPER:pepper,PUSH_TOKEN_ENCRYPTION_KEY:storage} as Env;
  await registerPush(env,current,first.id,{token:'ef'.repeat(32),environment:'sandbox'});
  await devices.logout(current);await auth.logout(current.session.id,refresh);
  expect(await db.prepare('SELECT * FROM secure_push_tokens WHERE device_id=?').bind(first.id).first()).toBeNull();
  await expect(auth.authenticateLogout(undefined,refresh)).rejects.toMatchObject({code:'session_expired'});
  expect((await auth.authenticateLogout(undefined,otherRefresh)).session.id).toBe(other.session.id);
  await db.prepare('UPDATE sessions SET refresh_expires_at=? WHERE id=?').bind('2020-01-01T00:00:00.000Z',other.session.id).run();
  await expect(auth.authenticateLogout(undefined,otherRefresh)).rejects.toMatchObject({code:'session_expired'});
 });
 it('does not trust login device IDs or replay registration proofs across sessions',async()=>{
  const s=await session(),first=await enroll(s),other=await session(s.user.id);
  await expect(devices.register(other,first.input)).rejects.toMatchObject({code:'registration_challenge_expired'});
  const password='TestPassword42',pepper='test-pepper';
  await db.prepare('UPDATE users SET email_hash=?,password_hash=? WHERE id=?').bind(await hashEmail(s.user.email,pepper),await hashPassword(password,createPasswordSalt(),pepper),s.user.id).run();
  const auth=new EmailAuthService(new D1AuthStore(db),{sendVerificationEmail:async()=>{throw new Error('unused');}},{appBaseURL:'http://localhost',authEmailFrom:'test@example.com',authTokenPepper:pepper,accessTokenTTLSeconds:900,refreshTokenTTLSeconds:2592000,authCodeTTLSeconds:600});
  const login=await auth.loginWithPassword({email:s.user.email,password,client:{deviceId:first.id}});
  const authenticated=await auth.authenticate(login.accessToken);
  expect(authenticated.session.deviceId).toBeNull();
  await expect(devices.bound(authenticated)).rejects.toMatchObject({code:'device_registration_required'});
 });
 it('registers first trusted device, keeps later devices pending, verifies ownership and immutable keys',async()=>{
  const s=await session(),first=await enroll(s),secondSession=await session(s.user.id),second=await enroll(secondSession,first.identity,'harmony');
  expect(first.result.device.status).toBe('active');expect(second.result.device.status).toBe('pending');
  await expect(devices.bound(secondSession)).rejects.toMatchObject({code:'device_not_approved'});
  await expect(registerPush({DB:db,AUTH_TOKEN_PEPPER:'test-pepper',PUSH_TOKEN_ENCRYPTION_KEY:storage} as Env,secondSession,second.id,{token:'harmony_push_token_abcdefghijklmnopqrstuvwxyz',environment:'production'})).rejects.toMatchObject({code:'device_not_approved'});
  await expect(devices.register(s,{...first.input,proof:base64(new Uint8Array(64))})).rejects.toMatchObject({code:'invalid_signature'});
  await expect(devices.get((await session()).user.id,first.id)).rejects.toMatchObject({code:'device_not_found'});
  await devices.approve(s,second.id,{certificate:second.input.certificate,approval:{enc:second.pair.publicKey,ciphertext:base64(new Uint8Array(64))}});
  expect((await devices.bound(secondSession)).status).toBe('active');
  await devices.update(s.user.id,second.id,{name:'Work phone',notificationsEnabled:false});
  expect((await devices.get(s.user.id,second.id)).public_key).toBe(second.pair.publicKey);
  await expect(devices.approval(s,second.id)).rejects.toMatchObject({code:'wrong_device'});
  await devices.revoke(s.user.id,second.id);
  expect(await new D1AuthStore(db).findSessionByAccessHash(secondSession.session.accessTokenHash)).toBeNull();
  await expect(devices.register(secondSession,second.input)).rejects.toMatchObject({code:'registration_challenge_expired'});
 });
 it('encrypts device tokens with independent storage key and binds ciphertext to installation',async()=>{
  const token='ab'.repeat(32),encrypted=await encryptToken(token,'device',storage);
  const longToken='h'.repeat(4096);
  expect(await decryptToken(await encryptToken(longToken,'device',storage),'device',storage)).toBe(longToken);
  expect(encrypted).not.toContain(token);expect(await decryptToken(encrypted,'device',storage)).toBe(token);
  await expect(decryptToken(encrypted,'other',storage)).rejects.toThrow();
  await expect(encryptToken(token,'device')).rejects.toMatchObject({code:'push_storage_not_configured'});
 });
 it('sends Harmony Push Kit payload through Huawei V3 server API',async()=>{
  const calls: {url:string; init?:RequestInit}[] = [];
  const fetchMock=vi.spyOn(globalThis,'fetch').mockImplementation(async(input:RequestInfo|URL,init?:RequestInit)=>{
   const url=String(input);calls.push({url,init});
   if(url.includes('/v3/project-123/messages:send')) return new Response(JSON.stringify({code:'80000000',msg:'Success',requestId:'request-1'}),{status:200,headers:{'content-type':'application/json'}});
   return new Response(JSON.stringify({code:'404'}),{status:404,headers:{'content-type':'application/json'}});
  });
  try {
   const pair=await crypto.subtle.generateKey({name:'RSA-PSS',modulusLength:2048,publicExponent:new Uint8Array([1,0,1]),hash:'SHA-256'},true,['sign','verify']);
   const privateKey=base64(new Uint8Array(await crypto.subtle.exportKey('pkcs8',pair.privateKey)));
   const env={DB:db,AUTH_TOKEN_PEPPER:'test-pepper',PUSH_TOKEN_ENCRYPTION_KEY:storage,HARMONY_PUSH_PRIVATE_KEY:privateKey,HARMONY_PUSH_KEY_ID:'key-123',HARMONY_PUSH_SUB_ACCOUNT:'account-123',HARMONY_PUSH_PROJECT_ID:'project-123'} as Env;
   const result=await sendHarmonyPush(env,'harmony_push_token_abcdefghijklmnopqrstuvwxyz',{secure:{message_id:'message'}},new Date(Date.now()+3600000).toISOString());
   expect(result).toEqual({status:200,reason:'accepted'});
   expect(calls.map(call=>call.url)).toEqual(['https://push-api.cloud.huawei.com/v3/project-123/messages:send']);
   const body=JSON.parse(String(calls[0].init?.body));
   expect(body.target.token).toEqual(['harmony_push_token_abcdefghijklmnopqrstuvwxyz']);
   expect(body.payload.notification.clickAction.data).toEqual({message_id:'message',protocol:'secure'});
   expect(body.payload.notification.title).toBe('PushNow');
   expect(body.message).toBeUndefined();
   expect(new Headers(calls[0].init?.headers).get('push-type')).toBe('0');
   const jwt=new Headers(calls[0].init?.headers).get('authorization')!.slice(7).split('.');
   const decode=(value:string)=>Uint8Array.from(atob(value.replace(/-/g,'+').replace(/_/g,'/')),c=>c.charCodeAt(0));
   expect(JSON.parse(new TextDecoder().decode(decode(jwt[0])))).toEqual({alg:'PS256',typ:'JWT',kid:'key-123'});
   const claims=JSON.parse(new TextDecoder().decode(decode(jwt[1])));
   expect(claims).toMatchObject({iss:'account-123',aud:'https://oauth-login.cloud.huawei.com/oauth2/v3/token'});
   expect(claims.exp-claims.iat).toBe(3600);
   expect(await crypto.subtle.verify({name:'RSA-PSS',saltLength:32},pair.publicKey,decode(jwt[2]),new TextEncoder().encode(`${jwt[0]}.${jwt[1]}`))).toBe(true);
  } finally {
   fetchMock.mockRestore();
  }
 });
 it('returns approved iOS and Harmony recipients for source-side targeting',async()=>{
  const s=await session(),first=await enroll(s),secondSession=await session(s.user.id),second=await enroll(secondSession,first.identity,'harmony');
  const source=await product.createSource(s.user.id,{name:'Targeting Agent'}),sourceKeys=await keys();
  const sourceKey=(await product.createSourceKey(s.user.id,source.id,{})).sourceKey;
  await messages.setup(s,source.id,{publicKey:sourceKeys.publicKey,certificate:await sign(first.identity.key.privateKey,`pushnow-source-v1\n${s.user.id}\n${source.id}\n${sourceKeys.publicKey}`)});
  const pendingRecipients=await messages.recipients(sourceKey);
  expect(pendingRecipients.devices.map(device=>device.id)).toEqual([first.id]);
  expect(pendingRecipients.devices[0].platform).toBe('ios');
  await devices.approve(s,second.id,{certificate:second.input.certificate,approval:{enc:second.pair.publicKey,ciphertext:base64(new Uint8Array(64))}});
  const approvedRecipients=await messages.recipients(sourceKey);
  expect(approvedRecipients.devices.map(device=>device.platform).sort()).toEqual(['harmony','ios']);
  expect(approvedRecipients.devices.map(device=>device.public_key).sort()).toEqual([first.pair.publicKey,second.pair.publicKey].sort());
 });
 it('rejects plaintext downgrade and foreign/pending targets, stores atomically, gates each device inbox',async()=>{
  const s=await session(),first=await enroll(s),secondSession=await session(s.user.id),second=await enroll(secondSession,first.identity,'harmony');
  const foreign=await enroll(await session());
  const source=await product.createSource(s.user.id,{name:'Agent'}),sourceKeys=await keys();
  const sourceKey=(await product.createSourceKey(s.user.id,source.id,{})).sourceKey;
  await messages.setup(s,source.id,{publicKey:sourceKeys.publicKey,certificate:await sign(first.identity.key.privateKey,`pushnow-source-v1\n${s.user.id}\n${source.id}\n${sourceKeys.publicKey}`)});
  await expect(product.ingestItem(sourceKey,'plain',{title:'secret'})).rejects.toMatchObject({code:'encryption_required'});
  const id=crypto.randomUUID(),input={messageId:id,expiresAt:new Date(Date.now()+3600000).toISOString(),envelopes:[{deviceId:first.id,enc:first.pair.publicKey,ciphertext:base64(new Uint8Array(32))}]};
  await expect(messages.ingest(sourceKey,id,{...input,envelopes:[{...input.envelopes[0],deviceId:foreign.id}]})).rejects.toMatchObject({code:'device_not_found'});
  await expect(messages.ingest(sourceKey,id,{...input,envelopes:[{...input.envelopes[0],deviceId:second.id}]})).rejects.toMatchObject({code:'target_not_approved'});
  await devices.approve(s,second.id,{certificate:second.input.certificate,approval:{enc:second.pair.publicKey,ciphertext:base64(new Uint8Array(64))}});
  input.envelopes.push({...input.envelopes[0],deviceId:second.id});
  const concurrent=await Promise.all([messages.ingest(sourceKey,id,input),messages.ingest(sourceKey,id,input)]);
  expect(concurrent.filter(r=>!r.deduplicated)).toHaveLength(1);
  expect((await product.getMembershipStatus(s.user.id)).usedToday).toBe(1);
  expect((await db.prepare('SELECT count(*) AS n FROM secure_deliveries WHERE message_id=?').bind(id).first<{n:number}>())?.n).toBe(2);
  await expect(messages.ingest(sourceKey,id,{...input,envelopes:[{...input.envelopes[0],ciphertext:base64(new Uint8Array(33))}]})).rejects.toMatchObject({code:'message_id_conflict'});
  expect((await messages.inbox(s)).messages.map(m=>m.device_id)).toEqual([first.id]);
  expect((await messages.inbox(secondSession)).messages.map(m=>m.device_id)).toEqual([second.id]);
  const harmonyOnlyID=crypto.randomUUID();
  const harmonyOnly={...input,messageId:harmonyOnlyID,envelopes:[{...input.envelopes[0],deviceId:second.id}]};
  await messages.ingest(sourceKey,harmonyOnlyID,harmonyOnly);
  expect((await db.prepare('SELECT count(*) AS n FROM secure_deliveries WHERE message_id=?').bind(harmonyOnlyID).first<{n:number}>())?.n).toBe(1);
  expect((await db.prepare('SELECT device_id FROM secure_deliveries WHERE message_id=?').bind(harmonyOnlyID).first<{device_id:string}>())?.device_id).toBe(second.id);
  await messages.ack(s,id);expect((await messages.inbox(s)).messages).toHaveLength(1);
  const env={DB:db,AUTH_TOKEN_PEPPER:'test-pepper',PUSH_TOKEN_ENCRYPTION_KEY:storage} as Env;
  await registerPush(env,secondSession,second.id,{token:'harmony_push_token_abcdefghijklmnopqrstuvwxyz',environment:'production'});
  await deliverSecureMessages(env);
  expect((await db.prepare('SELECT last_error FROM secure_deliveries WHERE message_id=? AND device_id=?').bind(id,second.id).first<{last_error:string}>())?.last_error).toBe('harmony_push_not_configured');
  await devices.update(s.user.id,second.id,{notificationsEnabled:false});
  const mutedID=crypto.randomUUID();
  await messages.ingest(sourceKey,mutedID,{...input,messageId:mutedID});
  await deliverSecureMessages(env);
  expect((await db.prepare('SELECT status,last_error FROM secure_deliveries WHERE message_id=? AND device_id=?').bind(mutedID,second.id).first<{status:string;last_error:string}>())).toEqual({status:'suppressed',last_error:'delivery_not_eligible'});
  await devices.logout(secondSession);
  expect(await db.prepare('SELECT * FROM secure_push_tokens WHERE device_id=?').bind(second.id).first()).toBeNull();
  const quotaID=crypto.randomUUID();
  await db.prepare('UPDATE usage_counters SET used_count=50 WHERE user_id=?').bind(s.user.id).run();
  await expect(messages.ingest(sourceKey,quotaID,{...input,messageId:quotaID})).rejects.toMatchObject({code:'quota_exceeded'});
  expect(await db.prepare('SELECT id FROM secure_messages WHERE id=?').bind(quotaID).first()).toBeNull();
  expect((await product.getMembershipStatus(s.user.id)).usedToday).toBe(50);
  await db.prepare('UPDATE secure_messages SET expires_at=? WHERE id=?').bind('2020-01-01T00:00:00.000Z',id).run();
  await cleanupExpiredSecureMessages(db);
  expect(await db.prepare('SELECT id FROM secure_messages WHERE id=?').bind(id).first()).toBeNull();
  expect((await db.prepare('SELECT count(*) AS n FROM secure_deliveries WHERE message_id=?').bind(id).first<{n:number}>())?.n).toBe(0);
  expect((await product.getMembershipStatus(s.user.id)).usedToday).toBe(50);
 });
});
