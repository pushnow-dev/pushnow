import { fail } from './secure-validation';
export type VerifiedEntitlement={plan:'plus'|'pro';product:string;expiresAt:string};
export type VerifiedSubscriber={snapshotMs:number;entitlements:VerifiedEntitlement[]};
declare global {interface Env {REVENUECAT_SUBSCRIBER_API_KEY?:string;REVENUECAT_WEBHOOK_SECRET?:string;REVENUECAT_APP_ID?:string;REVENUECAT_ENVIRONMENT?:'PRODUCTION'|'SANDBOX';}}
const products={plus:new Set(['com.createitv.pushnow.plus.monthly','com.createitv.pushnow.plus.yearly']),pro:new Set(['com.createitv.pushnow.pro.monthly','com.createitv.pushnow.pro.yearly'])};
function date(value:unknown):number{return typeof value==='string'&&Number.isFinite(Date.parse(value))?Date.parse(value):0;}
export function parseSubscriber(body:unknown,environment:'PRODUCTION'|'SANDBOX',now=Date.now()):VerifiedSubscriber{
 const data=body as {request_date_ms?:unknown;subscriber?:{entitlements?:Record<string,Record<string,unknown>>;subscriptions?:Record<string,Record<string,unknown>>}};
 if(!data||typeof data.request_date_ms!=='number'||!Number.isSafeInteger(data.request_date_ms)||Math.abs(data.request_date_ms-now)>300000||!data.subscriber||!data.subscriber.entitlements||!data.subscriber.subscriptions)fail(502,'revenuecat_invalid_response');
 const result:VerifiedEntitlement[]=[];
 for(const plan of ['plus','pro'] as const){
  const entitlement=data.subscriber.entitlements[plan];if(!entitlement)continue;
  const product=entitlement.product_identifier;if(typeof product!=='string'||!products[plan].has(product))continue;
  const subscription=data.subscriber.subscriptions[product];if(!subscription||subscription.store!=='app_store'||subscription.is_sandbox!==(environment==='SANDBOX')||subscription.refunded_at)continue;
  const expiration=Math.min(Math.max(date(entitlement.expires_date),date(entitlement.grace_period_expires_date)),Math.max(date(subscription.expires_date),date(subscription.grace_period_expires_date)));
  if(expiration>now)result.push({plan,product,expiresAt:new Date(expiration).toISOString()});
 }
 return {snapshotMs:data.request_date_ms,entitlements:result};
}
export async function fetchSubscriber(env:Env,identity:string):Promise<VerifiedSubscriber>{
 if(!env.REVENUECAT_SUBSCRIBER_API_KEY)fail(503,'revenuecat_not_configured');
 let response:Response;
 try{response=await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(identity)}`,{headers:{authorization:`Bearer ${env.REVENUECAT_SUBSCRIBER_API_KEY}`},signal:AbortSignal.timeout(12000)});}catch{fail(502,'revenuecat_unavailable');}
 if(!response.ok)fail(502,'revenuecat_unavailable');
 let body:unknown;try{body=await response.json();}catch{fail(502,'revenuecat_invalid_response');}
 const original=(body as {subscriber?:{original_app_user_id?:unknown}})?.subscriber?.original_app_user_id;
 // V1 cannot prove ownership of an anonymous-origin customer's named aliases.
 if(original!==identity)fail(409,'revenuecat_identity_alias_conflict');
 return parseSubscriber(body,env.REVENUECAT_ENVIRONMENT??'PRODUCTION');
}
