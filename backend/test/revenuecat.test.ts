import { beforeAll,afterAll,describe,it,expect,vi } from 'vitest';
import { Miniflare,convertV4MiniflareOptions } from 'miniflare';
import { readdirSync,readFileSync } from 'node:fs';
import { RevenueCatSync } from '../src/revenuecat-sync';
import { fetchSubscriber,parseSubscriber,type VerifiedSubscriber } from '../src/revenuecat-client';
import { revenuecatWebhook,reconcileMembership } from '../src/revenuecat-routes';
import { D1ProductStore } from '../src/product-store';
import { ProductService } from '../src/product-service';
import type { EmailAuthService } from '../src/auth-service';
const mf=new Miniflare(convertV4MiniflareOptions({name:'revenuecat-test',modules:true,script:'export default{fetch(){return new Response("ok")}}',d1Databases:['DB'],compatibilityDate:'2026-09-12'}));
let db:D1Database,env:Env;const now=Date.now(),plus='com.createitv.pushnow.plus.monthly',pro='com.createitv.pushnow.pro.monthly';
async function user(){const id=crypto.randomUUID(),time=new Date().toISOString();await db.prepare('INSERT INTO users(id,email,email_hash,email_verified_at,created_at,updated_at,revenuecat_app_user_id) VALUES (?,?,?,?,?,?,?)').bind(id,`${id}@example.com`,id,time,time,time,`jizhi_${id}`).run();return id;}
function snapshot(plan:'free'|'plus'|'pro',snapshotMs=Date.now()):VerifiedSubscriber{return {snapshotMs,entitlements:plan==='free'?[]:[{plan,product:plan==='plus'?plus:pro,expiresAt:new Date(Date.now()+86400000).toISOString()}]};}
function event(user:string,type='RENEWAL',ms=now){return {id:crypto.randomUUID(),type,event_timestamp_ms:ms,app_id:'app-test',environment:'PRODUCTION',app_user_id:`jizhi_${user}`};}
function request(event:unknown,secret=env.REVENUECAT_WEBHOOK_SECRET){return new Request('https://api.example.com/v1/webhooks/revenuecat',{method:'POST',headers:{authorization:`Bearer ${secret}`,'content-type':'application/json'},body:JSON.stringify({event})});}
beforeAll(async()=>{db=await mf.getD1Database('DB') as unknown as D1Database;for(const name of readdirSync(new URL('../migrations/',import.meta.url)).sort())for(const sql of readFileSync(new URL(`../migrations/${name}`,import.meta.url),'utf8').split(';').map(s=>s.trim()).filter(Boolean))await db.prepare(sql).run();env={DB:db,REVENUECAT_WEBHOOK_SECRET:'test-secret-'.repeat(4),REVENUECAT_APP_ID:'app-test',REVENUECAT_ENVIRONMENT:'PRODUCTION'} as Env;},60000);
afterAll(()=>mf.dispose(),60000);
describe('RevenueCat authoritative membership bridge',{timeout:30000},()=>{
 it('isolates sandbox customer identities and applies only sandbox snapshots to sandbox users',async()=>{
  const id=await user(),sandbox={...env,REVENUECAT_ENVIRONMENT:'SANDBOX' as const};
  await db.prepare('UPDATE users SET revenuecat_app_user_id=? WHERE id=?').bind(`jizhi_sandbox_${id}`,id).run();
  const fetcher=vi.fn(async()=>snapshot('plus')),sync=new RevenueCatSync(sandbox,fetcher);
  await expect(sync.user(`jizhi_${id}`)).rejects.toMatchObject({code:'invalid_revenuecat_identity'});
  await expect(new RevenueCatSync(env).user(`jizhi_sandbox_${id}`)).rejects.toMatchObject({status:400});
  await sync.reconcile(id);
  expect(fetcher).toHaveBeenCalledWith(`jizhi_sandbox_${id}`);
  expect((await new ProductService(new D1ProductStore(db),{authTokenPepper:'test'}).getMembershipStatus(id)).plan).toBe('plus');
 });
 it('uses only the official server lookup and rejects another named account alias',async()=>{
  const id=await user(),identity=`jizhi_${id}`;
  const response={request_date_ms:Date.now(),subscriber:{original_app_user_id:`jizhi_${crypto.randomUUID()}`,entitlements:{},subscriptions:{}}};
  const mock=vi.fn(async(_url:string)=>new Response(JSON.stringify(response),{status:200}));vi.stubGlobal('fetch',mock);
  try{
   await expect(fetchSubscriber({...env,REVENUECAT_SUBSCRIBER_API_KEY:'test-server-secret'},identity)).rejects.toMatchObject({code:'revenuecat_identity_alias_conflict'});
   response.subscriber.original_app_user_id='$RCAnonymousID:test';
   await expect(fetchSubscriber({...env,REVENUECAT_SUBSCRIBER_API_KEY:'test-server-secret'},identity)).rejects.toMatchObject({code:'revenuecat_identity_alias_conflict'});
   response.subscriber.original_app_user_id=identity;
   expect((await fetchSubscriber({...env,REVENUECAT_SUBSCRIBER_API_KEY:'test-server-secret'},identity)).entitlements).toEqual([]);
   expect(mock.mock.calls[0]?.[0]).toBe(`https://api.revenuecat.com/v1/subscribers/${identity}`);
  }finally{vi.unstubAllGlobals();}
 });
 it('derives exact active entitlements with expiry, grace, refund and environment checks',()=>{
  const future=new Date(now+86400000).toISOString(),past=new Date(now-1000).toISOString();
  const body={request_date_ms:now,subscriber:{entitlements:{plus:{product_identifier:plus,expires_date:future},pro:{product_identifier:pro,expires_date:past,grace_period_expires_date:future}},subscriptions:{[plus]:{store:'app_store',is_sandbox:false,expires_date:future},[pro]:{store:'app_store',is_sandbox:false,expires_date:past,grace_period_expires_date:future,refunded_at:null as string|null}}}};
  expect(parseSubscriber(body,'PRODUCTION',now).entitlements.map(e=>e.plan)).toEqual(['plus','pro']);
  expect(parseSubscriber(body,'SANDBOX',now).entitlements).toEqual([]);
  body.subscriber.subscriptions[pro].refunded_at=past;
  expect(parseSubscriber(body,'PRODUCTION',now).entitlements.map(e=>e.plan)).toEqual(['plus']);
  expect(()=>parseSubscriber({...body,request_date_ms:now-400000},'PRODUCTION',now)).toThrow();
 });
 it('rejects forged, wrong-environment and malformed identities before any entitlement grant',async()=>{
  const id=await user(),fetcher=vi.fn(async()=>snapshot('pro')),sync=new RevenueCatSync(env,fetcher);
  await expect(revenuecatWebhook(request(event(id),'wrong'),env,{},sync)).rejects.toMatchObject({status:401});
  await expect(revenuecatWebhook(request({...event(id),environment:'SANDBOX'}),env,{},sync)).rejects.toMatchObject({code:'wrong_revenuecat_app_environment'});
  await expect(revenuecatWebhook(request({...event(id),app_user_id:'jizhi_not-a-uuid'}),env,{},sync)).rejects.toMatchObject({status:400});
  await expect(sync.user(id)).rejects.toMatchObject({status:400});
  expect(fetcher).not.toHaveBeenCalled();
  expect(await db.prepare('SELECT * FROM entitlements WHERE user_id=?').bind(id).first()).toBeNull();
 });
 it('deduplicates events and ignores older purchase events after a newer revocation',async()=>{
  const id=await user(),fetcher=vi.fn(async()=>snapshot('pro')),sync=new RevenueCatSync(env,fetcher),initial=event(id,'INITIAL_PURCHASE',now-1000);
  expect((await revenuecatWebhook(request(initial),env,{},sync)).status).toBe(200);
  expect((await revenuecatWebhook(request(initial),env,{},sync)).status).toBe(200);expect(fetcher).toHaveBeenCalledTimes(1);
  expect((await new ProductService(new D1ProductStore(db),{authTokenPepper:'test'}).getMembershipStatus(id)).dailyNotificationLimit).toBeNull();
  fetcher.mockImplementation(async()=>snapshot('free'));
  await revenuecatWebhook(request(event(id,'EXPIRATION',now)),env,{},sync);
  fetcher.mockImplementation(async()=>snapshot('pro'));
  await revenuecatWebhook(request(event(id,'RENEWAL',now-500)),env,{},sync);
  expect(fetcher).toHaveBeenCalledTimes(2);
  expect((await new ProductService(new D1ProductStore(db),{authTokenPepper:'test'}).getMembershipStatus(id)).plan).toBe('free');
  await revenuecatWebhook(request(event(id,'RENEWAL',now)),env,{},sync);
  expect(fetcher).toHaveBeenCalledTimes(3);
 });
 it('keeps Plus as fallback after overlapping Pro expires and serializes concurrent sync',async()=>{
  const base=Date.now(),id=await user(),sync=new RevenueCatSync(env,async()=>({snapshotMs:Date.now(),entitlements:[{plan:'plus',product:plus,expiresAt:new Date(base+86400000).toISOString()},{plan:'pro',product:pro,expiresAt:new Date(base+60000).toISOString()}]}));
  await sync.reconcile(id);
  expect((await new D1ProductStore(db).getMembershipPlan(id,new Date(base).toISOString()))?.plan).toBe('pro');
  expect((await new D1ProductStore(db).getMembershipPlan(id,new Date(base+120000).toISOString()))?.plan).toBe('plus');
  let release!:(value:VerifiedSubscriber)=>void;const pending=new Promise<VerifiedSubscriber>(resolve=>release=resolve),slow=new RevenueCatSync(env,()=>pending);
  const started=slow.reconcile(id);await vi.waitFor(async()=>expect((await db.prepare('SELECT lease_id FROM revenuecat_sync WHERE user_id=?').bind(id).first<{lease_id:string}>())?.lease_id).toBeTruthy());
  await expect(sync.reconcile(id)).rejects.toMatchObject({code:'revenuecat_sync_busy'});release(snapshot('plus'));await started;
 });
 it('quarantines transfer accounts and prevents self reconciliation from restoring transferred privileges',async()=>{
  const from=await user(),to=await user(),sync=new RevenueCatSync(env,async()=>snapshot('pro'));
  await sync.reconcile(from,now+1000);await sync.reconcile(to,now+1000);
  const transfer={...event(from,'TRANSFER'),transferred_from:[`jizhi_${from}`],transferred_to:[`jizhi_${to}`]};
  expect((await revenuecatWebhook(request(transfer),env,{},sync)).status).toBe(200);
  for(const id of [from,to]){expect((await new ProductService(new D1ProductStore(db),{authTokenPepper:'test'}).getMembershipStatus(id)).plan).toBe('free');await expect(sync.reconcile(id)).rejects.toMatchObject({code:'transfer_reconciliation_required'});}
 });
 it('reconciliation rejects client-selected user or plan and missing server credentials fail closed',async()=>{
  const id=await user(),auth={authenticate:async()=>({user:{id,revenuecatAppUserId:`jizhi_${id}`}})} as unknown as EmailAuthService;
  const req=new Request('https://api.example.com/v1/me/plan/reconcile',{method:'POST',headers:{authorization:'Bearer login'},body:JSON.stringify({user_id:crypto.randomUUID(),plan:'pro'})});
  await expect(reconcileMembership(req,env,auth,new ProductService(new D1ProductStore(db),{authTokenPepper:'test'}),{})).rejects.toMatchObject({code:'unexpected_field'});
  await expect(new RevenueCatSync(env).reconcile(id)).rejects.toMatchObject({code:'revenuecat_not_configured'});
  expect(await db.prepare('SELECT * FROM entitlements WHERE user_id=?').bind(id).first()).toBeNull();
 });
 it('processes snake_case cancellation, refund and expiry using authoritative subscription state',async()=>{
  const id=await user(),future=new Date(Date.now()+86400000).toISOString();
  const subscription={store:'app_store',is_sandbox:false,expires_date:future,unsubscribe_detected_at:new Date().toISOString(),refunded_at:null as string|null};
  const body={request_date_ms:Date.now(),subscriber:{entitlements:{plus:{product_identifier:plus,expires_date:future}},subscriptions:{[plus]:subscription}}};
  const sync=new RevenueCatSync(env,async()=>parseSubscriber({...body,request_date_ms:Date.now()},'PRODUCTION'));
  const product=new ProductService(new D1ProductStore(db),{authTokenPepper:'test'});
  await revenuecatWebhook(request({...event(id,'CANCELLATION'),cancel_reason:'UNSUBSCRIBE',entitlement_ids:['pro']}),env,{},sync);
  expect((await product.getMembershipStatus(id)).dailyNotificationLimit).toBe(500);
  subscription.refunded_at=new Date().toISOString();
  await revenuecatWebhook(request({...event(id,'CANCELLATION',now+1),cancel_reason:'CUSTOMER_SUPPORT'}),env,{},sync);
  expect((await product.getMembershipStatus(id)).plan).toBe('free');
  subscription.refunded_at=null;subscription.expires_date=new Date(Date.now()-1000).toISOString();
  await revenuecatWebhook(request(event(id,'EXPIRATION',now+2)),env,{},sync);
  expect((await product.getMembershipStatus(id)).plan).toBe('free');
 });
 it('reconciles only the authenticated owner and never grants sandbox subscriptions in production',async()=>{
  const id=await user(),other=await user(),identity=`jizhi_${id}`,future=new Date(Date.now()+86400000).toISOString();
  const body={request_date_ms:Date.now(),subscriber:{original_app_user_id:identity,entitlements:{pro:{product_identifier:pro,expires_date:future}},subscriptions:{[pro]:{store:'app_store',is_sandbox:true,expires_date:future}}}};
  const fetcher=vi.fn(async(_url:string)=>new Response(JSON.stringify({...body,request_date_ms:Date.now()})));vi.stubGlobal('fetch',fetcher);
  const auth={authenticate:async()=>({user:{id,revenuecatAppUserId:identity}})} as unknown as EmailAuthService;
  const product=new ProductService(new D1ProductStore(db),{authTokenPepper:'test'});
  const req=()=>new Request('https://api.example.com/v1/me/plan/reconcile',{method:'POST',headers:{authorization:'Bearer login'},body:'{}'});
  try{
   const response=await reconcileMembership(req(),{...env,REVENUECAT_SUBSCRIBER_API_KEY:'test-public-key'},auth,product,{});
   expect((await response.json() as {membership:{plan:string}}).membership.plan).toBe('free');
   expect(fetcher.mock.calls[0]?.[0]).toBe(`https://api.revenuecat.com/v1/subscribers/${identity}`);
   body.subscriber.subscriptions[pro].is_sandbox=false;
   await reconcileMembership(req(),{...env,REVENUECAT_SUBSCRIBER_API_KEY:'test-public-key'},auth,product,{});
   expect((await product.getMembershipStatus(id)).plan).toBe('pro');
   expect((await product.getMembershipStatus(other)).plan).toBe('free');
   const wrongAuth={authenticate:async()=>({user:{id,revenuecatAppUserId:`jizhi_${other}`}})} as unknown as EmailAuthService;
   await expect(reconcileMembership(req(),env,wrongAuth,product,{})).rejects.toMatchObject({code:'revenuecat_identity_mismatch'});
  }finally{vi.unstubAllGlobals();}
 });
});
