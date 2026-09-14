import { revenueCatIdentity,revenueCatPrefix } from './revenuecat-identity';
import { fail, uuid } from './secure-validation';
import { fetchSubscriber,type VerifiedSubscriber } from './revenuecat-client';
type SyncState={last_event_ms:number;last_snapshot_ms:number;lease_id:string|null;transfer_blocked:number};
export class RevenueCatSync {
 constructor(readonly env:Env,readonly fetchCustomer:(identity:string)=>Promise<VerifiedSubscriber>=identity=>fetchSubscriber(env,identity)){}
 async user(identity:unknown):Promise<string>{
  const prefix=revenueCatPrefix(this.env.REVENUECAT_ENVIRONMENT);
  if(typeof identity!=='string'||!identity.startsWith(prefix))fail(400,'invalid_revenuecat_identity');
  const id=uuid(identity.slice(prefix.length));if(id!==id.toLowerCase())fail(400,'invalid_revenuecat_identity');
  const user=await this.env.DB.prepare('SELECT id FROM users WHERE id=? AND revenuecat_app_user_id=? AND deletion_requested_at IS NULL').bind(id,identity).first<{id:string}>();
  if(!user)fail(404,'revenuecat_user_not_found');return user.id;
 }
 async reconcile(user:string,eventMs?:number):Promise<void>{
  const identity=revenueCatIdentity(user,this.env.REVENUECAT_ENVIRONMENT);if(await this.user(identity)!==user)fail(403,'wrong_revenuecat_user');
  const db=this.env.DB,previous=await db.prepare('SELECT * FROM revenuecat_sync WHERE user_id=?').bind(user).first<SyncState>();
  if(previous?.transfer_blocked)fail(409,'transfer_reconciliation_required');
  if(eventMs!==undefined&&previous&&eventMs<previous.last_event_ms)return;
  const lease=crypto.randomUUID(),now=new Date().toISOString();
  const claimed=await db.prepare(`INSERT INTO revenuecat_sync(user_id,lease_id,lease_until) VALUES (?,?,?) ON CONFLICT(user_id) DO UPDATE SET lease_id=excluded.lease_id,lease_until=excluded.lease_until WHERE transfer_blocked=0 AND (lease_id IS NULL OR lease_until<?)`).bind(user,lease,new Date(Date.now()+30000).toISOString(),now).run();
  if(!claimed.meta.changes)fail(503,'revenuecat_sync_busy');
  try{
   const snapshot=await this.fetchCustomer(identity);
   const state=await db.prepare('SELECT * FROM revenuecat_sync WHERE user_id=?').bind(user).first<SyncState>();
   if(state?.lease_id!==lease||state.transfer_blocked)fail(503,'revenuecat_sync_superseded');
   if(snapshot.snapshotMs<state.last_snapshot_ms)fail(503,'revenuecat_stale_snapshot');
   if(eventMs!==undefined&&eventMs<state.last_event_ms)return;
   const active=snapshot.entitlements.filter(e=>e.expiresAt>now),highest=active.find(e=>e.plan==='pro')??active.find(e=>e.plan==='plus');
   const applied=await db.batch([
    db.prepare('DELETE FROM revenuecat_entitlement_states WHERE user_id=? AND EXISTS(SELECT 1 FROM revenuecat_sync WHERE user_id=? AND lease_id=? AND transfer_blocked=0)').bind(user,user,lease),
    ...active.map(e=>db.prepare('INSERT INTO revenuecat_entitlement_states SELECT ?,?,?,?,?,? FROM revenuecat_sync WHERE user_id=? AND lease_id=? AND transfer_blocked=0').bind(user,e.plan,e.plan,e.product,e.expiresAt,now,user,lease)),
    db.prepare(`INSERT INTO entitlements(user_id,plan,source,revenuecat_entitlement_id,revenuecat_product_id,expires_at,updated_at) SELECT ?,?,'revenuecat',?,?,?,? FROM revenuecat_sync WHERE user_id=? AND lease_id=? AND transfer_blocked=0 ON CONFLICT(user_id) DO UPDATE SET plan=excluded.plan,source=excluded.source,revenuecat_entitlement_id=excluded.revenuecat_entitlement_id,revenuecat_product_id=excluded.revenuecat_product_id,expires_at=excluded.expires_at,updated_at=excluded.updated_at`).bind(user,highest?.plan??'free',highest?.plan??null,highest?.product??null,highest?.expiresAt??null,now,user,lease),
    db.prepare('UPDATE revenuecat_sync SET last_event_ms=MAX(last_event_ms,?),last_snapshot_ms=?,lease_id=NULL,lease_until=NULL WHERE user_id=? AND lease_id=? AND transfer_blocked=0').bind(eventMs??0,snapshot.snapshotMs,user,lease)
   ]);
   if(!applied.at(-1)?.meta.changes)fail(503,'revenuecat_sync_superseded');
  }finally{await db.prepare('UPDATE revenuecat_sync SET lease_id=NULL,lease_until=NULL WHERE user_id=? AND lease_id=?').bind(user,lease).run();}
 }
 async quarantineTransfer(identities:unknown[],eventMs:number){
  const users:string[]=[];
  for(const identity of identities){
   if(typeof identity==='string'&&identity.startsWith('$RCAnonymousID:'))continue;
   try{users.push(await this.user(identity));}catch(error){if((error as {status?:number}).status!==404)throw error;}
  }
  if(!users.length)return;
  const now=new Date().toISOString();
  await this.env.DB.batch([...new Set(users)].flatMap(user=>[
   this.env.DB.prepare('INSERT INTO revenuecat_sync(user_id,last_event_ms,transfer_blocked) VALUES (?,?,1) ON CONFLICT(user_id) DO UPDATE SET last_event_ms=MAX(last_event_ms,excluded.last_event_ms),transfer_blocked=1,lease_id=NULL,lease_until=NULL').bind(user,eventMs),
   this.env.DB.prepare('DELETE FROM revenuecat_entitlement_states WHERE user_id=?').bind(user),
   this.env.DB.prepare(`INSERT INTO entitlements(user_id,plan,source,updated_at) VALUES (?,'free','revenuecat',?) ON CONFLICT(user_id) DO UPDATE SET plan='free',source='revenuecat',expires_at=NULL,revenuecat_entitlement_id=NULL,revenuecat_product_id=NULL,updated_at=excluded.updated_at`).bind(user,now)
  ]));
 }
}
