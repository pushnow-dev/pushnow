import {afterAll,beforeAll,describe,expect,it} from 'vitest';
import {Miniflare,convertV4MiniflareOptions} from 'miniflare';
import {readFileSync,readdirSync} from 'node:fs';
import {SenderManagement,managementRoute} from '../src/sender-management';
import {ProductService} from '../src/product-service';
import {D1ProductStore, type ProductStore} from '../src/product-store';
import {EmailAuthService} from '../src/auth-service';
import {D1AuthStore} from '../src/store';
import {SecureMessages} from '../src/secure-messages';
import {hashSecret} from '../src/crypto';

const mf=new Miniflare(convertV4MiniflareOptions({name:'sender-management',modules:true,script:'export default{fetch(){return new Response("ok")}}',d1Databases:['DB'],compatibilityDate:'2026-09-12'}));
let db:D1Database,product:ProductService,auth:EmailAuthService,service:SenderManagement;
const pepper='sender-test',now=new Date().toISOString(),future=new Date(Date.now()+86400000).toISOString();
async function owner(){
 const id=crypto.randomUUID(),access=crypto.randomUUID();
 await db.prepare('INSERT INTO users(id,email,email_hash,email_verified_at,created_at,updated_at) VALUES (?,?,?,?,?,?)').bind(id,`${id}@example.com`,id,now,now,now).run();
 await db.prepare('INSERT INTO sessions(id,user_id,access_token_hash,refresh_token_hash,expires_at,refresh_expires_at,created_at,updated_at) VALUES (?,?,?,?,?,?,?,?)').bind(crypto.randomUUID(),id,await hashSecret(access,pepper),crypto.randomUUID(),future,future,now,now).run();
 const source=await product.createSource(id,{name:'CLI'}),key=await product.createSourceKey(id,source.id,{});
 return {id,access,source,key};
}
async function call(access:string,path:string,method='GET',body?:unknown){
 try{return (await managementRoute(new Request(`https://test${path}`,{method,headers:{authorization:`Bearer ${access}`},body:body===undefined?undefined:JSON.stringify(body)}),{DB:db} as Env,auth,{}))??new Response(null,{status:404});}
 catch(error){const e=error as {status:number;code:string};return new Response(JSON.stringify({code:e.code}),{status:e.status??500});}
}
beforeAll(async()=>{
 db=await mf.getD1Database('DB') as unknown as D1Database;
 for(const file of readdirSync(new URL('../migrations/',import.meta.url)).filter(f=>f.endsWith('.sql')).sort())
  for(const sql of readFileSync(new URL(`../migrations/${file}`,import.meta.url),'utf8').split(';').map(s=>s.trim()).filter(Boolean))await db.prepare(sql).run();
 product=new ProductService(new D1ProductStore(db),{authTokenPepper:pepper});service=new SenderManagement(db);
 auth=new EmailAuthService(new D1AuthStore(db),{sendVerificationEmail:async()=>'unused'},{appBaseURL:'https://test',authEmailFrom:'test@example.com',authTokenPepper:pepper,accessTokenTTLSeconds:900,refreshTokenTTLSeconds:86400,authCodeTTLSeconds:600});
},60000);
afterAll(()=>mf.dispose(),60000);
describe('sender management with real D1',()=>{
 it('leaves unmatched routes to the parent without authenticating',async()=>{
  expect(await managementRoute(new Request('https://test/v2/messages'),{DB:db} as Env,auth,{})).toBeNull();
 });
 it('allows verified web sessions and exposes metadata only with account-scoped mutations',async()=>{
  const a=await owner(),b=await owner();
  const response=await call(a.access,'/v2/keys'),text=await response.text();
  expect(response.status).toBe(200);expect(JSON.parse(text).keys).toHaveLength(1);
  expect(text).not.toContain(a.key.sourceKey);expect(text).not.toContain('key_hash');expect(text).not.toContain(b.key.record.id);
  expect((await call(b.access,`/v2/keys/${a.key.record.id}`,'PATCH',{expires_at:future})).status).toBe(404);
  expect((await call(b.access,`/v2/keys/${a.key.record.id}`,'DELETE')).status).toBe(404);
  expect((await call(a.access,`/v2/keys/${a.key.record.id}`,'PATCH',{expires_at:future})).status).toBe(200);
  expect((await service.keys(a.id)).keys[0].expires_at).toBe(future);
  expect((await call(a.access,`/v2/keys/${a.key.record.id}`,'PATCH',{expires_at:null})).status).toBe(200);
  expect((await service.keys(a.id)).keys[0].expires_at).toBeNull();
  for(const value of ['2020-01-01T00:00:00Z','garbage',false,'2099-02-30T00:00:00Z'])expect((await call(a.access,`/v2/keys/${a.key.record.id}`,'PATCH',{expires_at:value})).status).toBe(400);
  expect((await call(a.access,`/v2/keys/${a.key.record.id}`,'PATCH',{})).status).toBe(400);
  const second=await product.createSourceKey(a.id,a.source.id,{});
  expect((await call(a.access,`/v2/keys/${a.key.record.id}`,'DELETE')).status).toBe(204);
  await expect(product.authenticateSourceKey(a.key.sourceKey)).rejects.toMatchObject({status:401});
  await expect(product.authenticateSourceKey(second.sourceKey)).resolves.toMatchObject({source:{id:a.source.id}});
  expect((await call('invalid','/v2/keys')).status).toBe(401);
  await db.prepare("UPDATE users SET email_verified_at='' WHERE id=?").bind(a.id).run();
  expect((await call(a.access,'/v2/keys')).status).toBe(403);
 });
 it('persists expiry, rejects expired credentials even with an unfiltered test store, and returns authenticated key id',async()=>{
  const a=await owner(),key=await product.createSourceKey(a.id,a.source.id,{expiresAt:future});
  expect((await product.authenticateSourceKey(key.sourceKey)).key.expiresAt).toBe(future);
  const expired=new ProductService(new D1ProductStore(db),{authTokenPepper:pepper},()=>new Date(future));
  await expect(expired.authenticateSourceKey(key.sourceKey)).rejects.toMatchObject({code:'invalid_source_key'});
  const store={findActiveSourceKeyByPrefix:async()=>({...key.record,expiresAt:now})} as unknown as ProductStore;
  await expect(new ProductService(store,{authTokenPepper:pepper}).authenticateSourceKey(key.sourceKey)).rejects.toMatchObject({status:401});
  await expect(product.createSourceKey(a.id,a.source.id,{expiresAt:now})).rejects.toMatchObject({status:400});
  await db.prepare('INSERT INTO secure_sources(source_id,user_id,public_key,certificate) VALUES (?,?,?,?)').bind(a.source.id,a.id,'public','certificate').run();
  expect(await new SecureMessages(db,product).source(key.sourceKey)).toMatchObject({key_id:key.record.id,source_id:a.source.id});
 });
 it('paginates tied timestamps, filters keys and sources, and never returns message payloads',async()=>{
  const a=await owner(),b=await owner(),device=crypto.randomUUID();
  await db.prepare("INSERT INTO secure_devices(id,user_id,name,platform,public_key,status,last_seen_at,created_at) VALUES (?,?,?,'ios','public','active',?,?)").bind(device,a.id,'My iPhone',now,now).run();
  const ids:string[]=[];
  for(const who of [a,a,b]){
   const id=crypto.randomUUID();ids.push(id);
   await db.prepare('INSERT INTO v2_messages(id,user_id,source_id,source_key_id,archive_id,request_hash,ciphertext,created_at) VALUES (?,?,?,?,?,?,?,?)').bind(id,who.id,who.source.id,who.key.record.id,'archive','hash','PRIVATE_PAYLOAD',now).run();
  }
  await db.prepare("INSERT INTO v2_deliveries(message_id,device_id,status,next_attempt_at,attempts,accepted_at) VALUES (?,?,'accepted',?,1,?)").bind(ids[0],device,now,now).run();
  const page=await service.logs(a.id,new URLSearchParams('limit=1'));
  expect(page.logs).toHaveLength(1);expect(page.next_cursor).toBeTruthy();
  const next=await service.logs(a.id,new URLSearchParams({limit:'1',cursor:page.next_cursor!}));
  expect(next.logs).toHaveLength(1);expect(next.next_cursor).toBeNull();expect(next.logs[0].message_id).not.toBe(page.logs[0].message_id);
  const result=await service.logs(a.id,new URLSearchParams({key_id:a.key.record.id,source_id:a.source.id}));
  expect(result.logs).toHaveLength(2);expect(JSON.stringify(result)).not.toContain('PRIVATE_PAYLOAD');expect(JSON.stringify(result)).not.toContain('ciphertext');
  expect(result.logs.find(m=>m.message_id===ids[0])?.deliveries[0]).toMatchObject({device_name:'My iPhone',status:'accepted',attempts:1});
  expect((await service.logs(a.id,new URLSearchParams({key_id:b.key.record.id}))).logs).toEqual([]);
  expect((await call(a.access,'/v2/logs?cursor=bad')).status).toBe(400);
  expect((await call(a.access,'/v2/logs?limit=101')).status).toBe(400);
  expect((await call(a.access,'/v2/logs')).status).toBe(200);
  await db.prepare('UPDATE v2_messages SET source_key_id=NULL WHERE id=?').bind(ids[0]).run();
  const legacy=await service.logs(a.id,new URLSearchParams());
  expect(legacy.logs.find(m=>m.message_id===ids[0])?.key_id).toBeNull();
  expect((await service.logs(a.id,new URLSearchParams({key_id:a.key.record.id}))).logs).toHaveLength(1);
 });
});
