import { afterAll,beforeAll,describe,expect,it } from 'vitest';
import { Miniflare,convertV4MiniflareOptions } from 'miniflare';
import { readFileSync,readdirSync } from 'node:fs';
import { ArchiveService } from '../src/v2-archive';
import { AttachmentService } from '../src/v2-attachments';
import { archiveRoute } from '../src/v2-routes';
import { secureRoute } from '../src/secure-routes';
import { EmailAuthService } from '../src/auth-service';
import { ProductService } from '../src/product-service';
import { D1ProductStore } from '../src/product-store';
import { D1AuthStore } from '../src/store';
import { SecureDevices } from '../src/secure-devices';
import { SecureMessages } from '../src/secure-messages';
import { base64 } from '../src/secure-validation';
import { hashSecret } from '../src/crypto';
import { deliverArchiveMessages } from '../src/v2-delivery';
import type { SecureSession } from '../src/secure-types';
const mf=new Miniflare(convertV4MiniflareOptions({name:'v2test',modules:true,script:'export default{fetch(){return new Response("ok")}}',d1Databases:['DB'],r2Buckets:['SECURE_BLOBS'],compatibilityDate:'2026-09-12'}));
let db:D1Database,env:Env,auth:EmailAuthService,product:ProductService;
const pepper='v2-test',now=new Date().toISOString();
async function pair(){const keys=await crypto.subtle.generateKey({name:'ECDSA',namedCurve:'P-256'},true,['sign','verify']);return {...keys,public:base64(new Uint8Array(await crypto.subtle.exportKey('raw',keys.publicKey)))};}
async function sign(key:CryptoKey,text:string){return base64(new Uint8Array(await crypto.subtle.sign({name:'ECDSA',hash:'SHA-256'},key,new TextEncoder().encode(text))));}
async function account(user:string=crypto.randomUUID(),identity?:Awaited<ReturnType<typeof pair>>){
 const access=crypto.randomUUID(),sessionId=crypto.randomUUID(),id=crypto.randomUUID(),keys=await pair(),root=identity??await pair(),future=new Date(Date.now()+86400000).toISOString();
 await db.prepare('INSERT OR IGNORE INTO users(id,email,email_hash,email_verified_at,created_at,updated_at) VALUES (?,?,?,?,?,?)').bind(user,`${user}@example.com`,user,now,now,now).run();
 await db.prepare('INSERT INTO sessions(id,user_id,access_token_hash,refresh_token_hash,expires_at,refresh_expires_at,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)').bind(sessionId,user,await hashSecret(access,pepper),crypto.randomUUID(),future,future,now,now).run();
 const session=await auth.authenticate(access),devices=new SecureDevices(db),challenge=(await devices.challenge(session)).challenge;
 const certificate=await sign(root.privateKey,`pushnow-device-v1\n${user}\n${id}\n${keys.public}`);
 await devices.register(session,{deviceId:id,name:'Phone',platform:'ios',publicKey:keys.public,challenge,proof:await sign(keys.privateKey,`pushnow-register-v1\n${user}\n${id}\n${keys.public}\n${challenge}`),identityPublicKey:root.public,certificate});
 session.session.deviceId=id;
 return {access,session,root,keys,id,certificate};
}
async function source(owner:Awaited<ReturnType<typeof account>>,keys?:Awaited<ReturnType<typeof pair>>){
 const key=keys??await pair(),record=await product.createSource(owner.session.user.id,{name:'Sender'}),credential=(await product.createSourceKey(owner.session.user.id,record.id,{})).sourceKey;
 await new SecureMessages(db,product).setup(owner.session,record.id,{publicKey:key.public,certificate:await sign(owner.root.privateKey,`pushnow-source-v1\n${owner.session.user.id}\n${record.id}\n${key.public}`)});
 return {id:record.id,key,credential};
}
async function call(path:string,method='GET',token?:string,input?:unknown,raw=false){
 const headers:Record<string,string>={};if(token)headers.authorization=token.startsWith('Attachment ')?token:`Bearer ${token}`;
 if(!raw)headers['content-type']='application/json';
 if(path==='/v2/messages'&&method==='POST')headers['idempotency-key']=(input as {message_id:string}).message_id;
 const request=new Request(`http://localhost${path}`,{method,headers,body:input===undefined?undefined:raw?input as BodyInit:JSON.stringify(input)});
 try{return await archiveRoute(request,env,auth,product,{});}catch(error){const e=error as {status?:number;code?:string};return new Response(JSON.stringify({code:e.code}),{status:e.status??500});}
}
beforeAll(async()=>{
 db=await mf.getD1Database('DB') as unknown as D1Database;const bucket=await mf.getR2Bucket('SECURE_BLOBS') as unknown as R2Bucket;
 for(const name of readdirSync(new URL('../migrations/',import.meta.url)).sort())for(const sql of readFileSync(new URL(`../migrations/${name}`,import.meta.url),'utf8').split(';').map(s=>s.trim()).filter(Boolean))await db.prepare(sql).run();
 env={DB:db,SECURE_BLOBS:bucket,AUTH_TOKEN_PEPPER:pepper} as Env;
 product=new ProductService(new D1ProductStore(db),{authTokenPepper:pepper});
 auth=new EmailAuthService(new D1AuthStore(db),{sendVerificationEmail:async()=>{throw new Error('unused');}},{appBaseURL:'http://localhost',authEmailFrom:'test@example.com',authTokenPepper:pepper,accessTokenTTLSeconds:900,refreshTokenTTLSeconds:86400,authCodeTTLSeconds:600});
},60000);
afterAll(()=>mf.dispose(),60000);
describe('v2 HTTP routes with real D1 and R2',{timeout:30000},()=>{
 it('automates only account-bound authorizations and rejects cross-account approval',async()=>{
  const owner=await account(),foreign=await account(),archive=await pair(),id=crypto.randomUUID();
  await new ArchiveService(db).initialize(owner.session,{id,publicKey:archive.public,certificate:await sign(owner.root.privateKey,`pushnow-archive-v1\n${owner.session.user.id}\n${id}\n${archive.public}`)});
  const key=await pair();
  await db.prepare('UPDATE sessions SET device_id=NULL WHERE id=?').bind(owner.session.session.id).run();
  const issued=await call('/v2/account-authorizations','POST',owner.access,{name:'Browser',public_key:key.public});
  expect(issued.status).toBe(201);
  const request=await issued.json() as {id:string;user_code:string;device_code:string;user_id:string};
  expect(request.user_id).toBe(owner.session.user.id);
  expect((await call('/v2/account-authorizations/pending','GET',owner.access)).status).toBe(403);
  await db.prepare('UPDATE sessions SET device_id=? WHERE id=?').bind(owner.id,owner.session.session.id).run();
  const pending=await (await call('/v2/account-authorizations/pending','GET',owner.access)).json() as {authorizations:{id:string}[]};
  expect(pending.authorizations.map(x=>x.id)).toContain(request.id);
  const other=await (await call('/v2/account-authorizations/pending','GET',foreign.access)).json() as {authorizations:unknown[]};
  expect(other.authorizations).toHaveLength(0);
  expect((await call(`/v2/authorizations/lookup?code=${request.user_code}`,'GET',foreign.access)).status).toBe(404);
  const wrong=await source(foreign,key),right=await source(owner,key),grant={enc:key.public,ciphertext:base64(new Uint8Array(64))};
  expect((await call(`/v2/authorizations/${request.id}/approve`,'POST',foreign.access,{source_id:wrong.id,...grant})).status).toBe(409);
  expect((await call(`/v2/authorizations/${request.id}/approve`,'POST',owner.access,{source_id:right.id,...grant})).status).toBe(204);
  expect((await (await call(`/v2/authorizations/${request.id}/token`,'POST',undefined,{device_code:request.device_code})).json() as {status:string}).status).toBe('approved');
 });
 it('keeps a stable device record, refreshes metadata and prevents user device removal',async()=>{
  const owner=await account(),foreign=await account(),devices=new SecureDevices(db);
  await devices.update(owner.session.user.id,owner.id,{name:'My phone'});
  const challenge=(await devices.challenge(owner.session)).challenge;
  const registered=await devices.register(owner.session,{deviceId:owner.id,name:'Default name',platform:'ios',
   publicKey:owner.keys.public,challenge,proof:await sign(owner.keys.privateKey,`pushnow-register-v1\n${owner.session.user.id}\n${owner.id}\n${owner.keys.public}\n${challenge}`),
   systemVersion:'18.4',appVersion:'1.0.1',model:'iPhone'});
  expect(registered.device).toMatchObject({id:owner.id,name:'My phone',system_version:'18.4',app_version:'1.0.1',model:'iPhone'});
  expect((await devices.list(owner.session.user.id)).devices).toHaveLength(1);
  await expect(devices.get(foreign.session.user.id,owner.id)).rejects.toMatchObject({status:404});
  const response=await secureRoute(new Request(`https://api.test/v1/secure/devices/${owner.id}`,{method:'DELETE',headers:{authorization:`Bearer ${owner.access}`}}),env,auth,product,{});
  expect(response.status).toBe(405);
  expect((await devices.get(owner.session.user.id,owner.id)).status).toBe('active');
 });
 it('stores shared retained history and encrypted blobs, deletes idempotently with tombstones',async()=>{
  const first=await account(),second=await account(first.session.user.id,first.root),foreign=await account();
  await new SecureDevices(db).approve(first.session,second.id,{certificate:second.certificate,approval:{enc:second.keys.public,ciphertext:base64(new Uint8Array(64))}});
  await new SecureDevices(db).update(first.session.user.id,second.id,{notificationsEnabled:false});
  const archive=await pair(),archiveId=crypto.randomUUID();
  const archiveBody={id:archiveId,public_key:archive.public,certificate:await sign(first.root.privateKey,`pushnow-archive-v1\n${first.session.user.id}\n${archiveId}\n${archive.public}`)};
  expect((await call('/v2/archive','POST',first.access,archiveBody)).status).toBe(200);
  expect((await call('/v2/archive','POST',first.access,{...archiveBody,certificate:base64(new Uint8Array(64))})).status).toBe(403);
  const invalidPoint=base64(new Uint8Array(65));
  expect((await call('/v2/archive','POST',first.access,{id:archiveId,public_key:invalidPoint,certificate:await sign(first.root.privateKey,`pushnow-archive-v1\n${first.session.user.id}\n${archiveId}\n${invalidPoint}`)})).status).toBe(400);
  expect((await call(`/v2/archive/grants/${second.id}`,'POST',first.access,{enc:archive.public,ciphertext:base64(new Uint8Array(64))})).status).toBe(204);
  expect((await call(`/v2/archive/grants/${second.id}`,'GET',first.access)).status).toBe(403);
  expect((await call(`/v2/archive/grants/${second.id}`,'GET',second.access)).status).toBe(200);
  const sender=await source(first),attachment=crypto.randomUUID(),readToken=crypto.randomUUID().replace(/-/g,'')+'abcdefghijk',content=new Uint8Array(32);
  expect((await call('/v2/recipients','GET',sender.credential)).status).toBe(200);
  expect((await call('/v2/attachments','POST',sender.credential,{id:attachment,size:32,read_token:readToken})).status).toBe(201);
  expect((await call(`/v2/attachments/${attachment}`,'PUT',sender.credential,new Uint8Array(33),true)).status).toBe(413);
  expect((await call(`/v2/attachments/${attachment}`,'PUT',sender.credential,content,true)).status).toBe(204);
  expect((await call(`/v2/attachments/${attachment}`,'GET',`Attachment ${readToken}`)).status).toBe(404);
  const message={message_id:crypto.randomUUID(),archive_id:archiveId,enc:archive.public,ciphertext:base64(new Uint8Array(128)),preview:{enc:archive.public,ciphertext:base64(new Uint8Array(32))},attachment_ids:[attachment]};
  const concurrent=await Promise.all([call('/v2/messages','POST',sender.credential,message),call('/v2/messages','POST',sender.credential,message)]);
  expect(concurrent.map(r=>r.status).sort()).toEqual([200,201]);
  expect((await db.prepare('SELECT count(*) AS n FROM v2_deliveries WHERE message_id=?').bind(message.message_id).first<{n:number}>())?.n).toBe(1);
  expect((await call(`/v2/attachments/${attachment}`,'PUT',sender.credential,content,true)).status).toBe(204);
  expect((await call(`/v2/attachments/${attachment}`,'PUT',sender.credential,new Uint8Array(32).fill(1),true)).status).toBe(409);
  expect(new Uint8Array(await (await call(`/v2/attachments/${attachment}`,'GET',`Attachment ${readToken}`)).arrayBuffer())).toEqual(content);
  expect((await call(`/v2/attachments/${attachment}`,'GET',`Attachment ${'z'.repeat(43)}`)).status).toBe(404);
  expect((await call(`/v2/attachments/${attachment}`,'GET',foreign.access)).status).toBe(404);
  expect((await call('/v2/messages','GET',sender.credential)).status).toBe(401);
  expect((await call(`/v2/messages/${message.message_id}`,'GET',second.access)).status).toBe(200);
  expect((await call(`/v2/messages/${message.message_id}`,'GET',foreign.access)).status).toBe(404);
  expect((await call(`/v2/messages/${message.message_id}/read`,'POST',second.access)).status).toBe(204);
  await db.prepare('UPDATE v2_messages SET created_at=? WHERE id=?').bind('2020-01-01T00:00:00.000Z',message.message_id).run();
  expect((await call(`/v2/messages/${message.message_id}`,'GET',first.access)).status).toBe(200);
  const other={...message,message_id:crypto.randomUUID(),attachment_ids:[],notify_device_ids:[]};
  expect((await call('/v2/messages','POST',sender.credential,{...other,message_id:crypto.randomUUID(),notify_device_ids:[foreign.id]})).status).toBe(403);
  expect((await call('/v2/messages','POST',sender.credential,other)).status).toBe(201);
  const page=await (await call('/v2/messages?limit=1','GET',first.access)).json() as {next_cursor:string;messages:unknown[]};expect(page.messages).toHaveLength(1);expect(page.next_cursor).toBeTruthy();
  expect((await call(`/v2/messages?limit=1&cursor=${encodeURIComponent(page.next_cursor)}`,'GET',second.access)).status).toBe(200);
  expect((await call(`/v2/messages/${message.message_id}`,'DELETE',first.access)).status).toBe(204);
  expect((await call(`/v2/messages/${message.message_id}`,'DELETE',second.access)).status).toBe(204);
  expect((await call('/v2/messages','POST',sender.credential,message)).status).toBe(410);
  expect((await call(`/v2/attachments/${attachment}`,'GET',`Attachment ${readToken}`)).status).toBe(404);
  expect((await env.SECURE_BLOBS!.list()).objects).toHaveLength(0);
  expect((await db.prepare('SELECT used_bytes FROM v2_storage WHERE user_id=?').bind(first.session.user.id).first<{used_bytes:number}>())?.used_bytes).toBe(0);
  expect((await (await call('/v2/deletions','GET',second.access)).json() as {deleted_ids:string[]}).deleted_ids).toContain(message.message_id);
  expect((await call('/v2/logout','POST',sender.credential)).status).toBe(204);
  expect((await call('/v2/recipients','GET',sender.credential)).status).toBe(401);
  await db.prepare('INSERT INTO v2_deliveries(message_id,device_id,next_attempt_at) VALUES (?,?,?)').bind(other.message_id,first.id,now).run();
  await deliverArchiveMessages(env);
  expect((await db.prepare('SELECT status FROM v2_deliveries WHERE message_id=?').bind(other.message_id).first<{status:string}>())?.status).toBe('suppressed');
 });
 it('consumes authorization grants once and enforces polling identity and interval',async()=>{
  const owner=await account(),archive=await pair(),id=crypto.randomUUID();
  await new ArchiveService(db).initialize(owner.session,{id,publicKey:archive.public,certificate:await sign(owner.root.privateKey,`pushnow-archive-v1\n${owner.session.user.id}\n${id}\n${archive.public}`)});
  const senderKeys=await pair();const issued=await (await call('/v2/authorizations','POST',undefined,{name:'CLI',public_key:senderKeys.public})).json() as {id:string;device_code:string;user_code:string};
  expect((await call(`/v2/authorizations/${issued.id}/token`,'POST',undefined,{device_code:base64(new Uint8Array(32))})).status).toBe(401);
  expect((await call(`/v2/authorizations/${issued.id}/token`,'POST',undefined,{device_code:issued.device_code})).status).toBe(200);
  expect((await call(`/v2/authorizations/${issued.id}/token`,'POST',undefined,{device_code:issued.device_code})).status).toBe(429);
  expect((await call(`/v2/authorizations/lookup?code=${issued.user_code}`,'GET',owner.access)).status).toBe(200);
  const sender=await source(owner,senderKeys);
  expect((await call(`/v2/authorizations/${issued.id}/approve`,'POST',owner.access,{source_id:sender.id,enc:archive.public,ciphertext:base64(new Uint8Array(64))})).status).toBe(204);
  await db.prepare('UPDATE v2_authorizations SET last_poll_at=NULL WHERE id=?').bind(issued.id).run();
  const grants=await Promise.all([call(`/v2/authorizations/${issued.id}/token`,'POST',undefined,{device_code:issued.device_code}),call(`/v2/authorizations/${issued.id}/token`,'POST',undefined,{device_code:issued.device_code})]);
  expect(grants.filter(r=>r.status===200)).toHaveLength(1);
  expect((await db.prepare('SELECT grant_ciphertext FROM v2_authorizations WHERE id=?').bind(issued.id).first<{grant_ciphertext:string|null}>())?.grant_ciphertext).toBeNull();
 });
 it('reserves aggregate storage atomically and expires orphans without affecting account history',async()=>{
  const owner=await account(),sender=await source(owner),files=new AttachmentService(db,env.SECURE_BLOBS);
  const ids=Array.from({length:6},()=>crypto.randomUUID());
  const reservations=await Promise.all(ids.map(id=>call('/v2/attachments','POST',sender.credential,{id,size:20*1024*1024,read_token:'a'.repeat(43)})));
  expect(reservations.filter(r=>r.status===201)).toHaveLength(5);expect(reservations.filter(r=>r.status===402)).toHaveLength(1);
  expect((await db.prepare('SELECT COUNT(*) AS n FROM v2_attachments WHERE user_id=?').bind(owner.session.user.id).first<{n:number}>())?.n).toBe(5);
  await db.prepare("UPDATE v2_attachments SET expires_at='2020-01-01T00:00:00.000Z' WHERE user_id=?").bind(owner.session.user.id).run();await files.cleanOrphans();
  expect((await db.prepare('SELECT used_bytes FROM v2_storage WHERE user_id=?').bind(owner.session.user.id).first<{used_bytes:number}>())?.used_bytes).toBe(0);
 });
});
