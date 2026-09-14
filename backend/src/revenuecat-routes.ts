import { revenueCatIdentity } from './revenuecat-identity';
import type { EmailAuthService } from './auth-service';
import type { ProductService } from './product-service';
import { bearerToken,jsonResponse,readJsonBody } from './http';
import { constantTimeEqualHex,hashSecret } from './crypto';
import { digest,fail,fields,str } from './secure-validation';
import { RevenueCatSync } from './revenuecat-sync';
export async function revenuecatWebhook(request:Request,env:Env,headers:HeadersInit,sync=new RevenueCatSync(env)){
 if(!env.REVENUECAT_WEBHOOK_SECRET||env.REVENUECAT_WEBHOOK_SECRET.length<32||!env.REVENUECAT_APP_ID)fail(503,'revenuecat_webhook_not_configured');
 const supplied=request.headers.get('authorization')??'';
 if(!constantTimeEqualHex(await hashSecret(supplied,'webhook'),await hashSecret(`Bearer ${env.REVENUECAT_WEBHOOK_SECRET}`,'webhook')))fail(401,'invalid_webhook_authorization');
 const body=await readJsonBody(request),event=body?.event as Record<string,unknown>;
 if(!event||typeof event!=='object')fail(400,'invalid_webhook');
 const id=str(event.id,200),type=str(event.type,80),eventMs=event.eventTimestampMs;
 if(event.appId!==env.REVENUECAT_APP_ID||event.environment!==(env.REVENUECAT_ENVIRONMENT??'PRODUCTION'))fail(400,'wrong_revenuecat_app_environment');
 if(typeof eventMs!=='number'||!Number.isSafeInteger(eventMs)||eventMs<=0||eventMs>Date.now()+300000)fail(400,'invalid_event_timestamp');
 const hash=await digest(JSON.stringify(event)),existing=await env.DB.prepare('SELECT payload_hash,status FROM revenuecat_events WHERE id=?').bind(id).first<{payload_hash:string;status:string}>();
 if(existing){if(existing.payload_hash!==hash)fail(409,'event_id_conflict');if(existing.status==='processed')return jsonResponse({status:'duplicate'},200,headers);}
 await env.DB.prepare("INSERT INTO revenuecat_events VALUES (?,?,?,'pending',?) ON CONFLICT(id) DO NOTHING").bind(id,hash,eventMs,new Date().toISOString()).run();
 const saved=await env.DB.prepare('SELECT payload_hash FROM revenuecat_events WHERE id=?').bind(id).first<{payload_hash:string}>();
 if(saved?.payload_hash!==hash)fail(409,'event_id_conflict');
 if(type==='TRANSFER'){
  if(!Array.isArray(event.transferredFrom)||!Array.isArray(event.transferredTo)||event.transferredFrom.length+event.transferredTo.length>100)fail(400,'invalid_transfer');
  await sync.quarantineTransfer([...event.transferredFrom,...event.transferredTo],eventMs);
 }else if(type!=='TEST'){
  const user=await sync.user(event.appUserId);await sync.reconcile(user,eventMs);
 }
 await env.DB.prepare("UPDATE revenuecat_events SET status='processed' WHERE id=? AND payload_hash=?").bind(id,hash).run();
 return jsonResponse({status:type==='TRANSFER'?'transfer_review_required':'processed'},200,headers);
}
export async function reconcileMembership(request:Request,env:Env,auth:EmailAuthService,product:ProductService,headers:HeadersInit){
 const session=await auth.authenticate(bearerToken(request));fields(await readJsonBody(request)??{},[]);
 if(session.user.revenuecatAppUserId!==revenueCatIdentity(session.user.id,env.REVENUECAT_ENVIRONMENT))fail(409,'revenuecat_identity_mismatch');
 await new RevenueCatSync(env).reconcile(session.user.id);
 return jsonResponse({membership:await product.getMembershipStatus(session.user.id)},200,headers);
}
