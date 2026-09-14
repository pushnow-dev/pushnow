import { SenderAbuseGuard } from "./sender-abuse";
import { decryptToken, harmonyPushConfigured, pushConfigured, securePayload, sendAPNs, sendHarmonyPush } from './secure-push';
type Due={message_id:string;device_id:string;attempts:number};
type Delivery=Due & {user_id:string;source_id:string;expires_at:string;created_at:string;enc:string;ciphertext:string;source_public_key:string;source_certificate:string;token_encrypted:string;environment:string;platform:string};
export async function deliverSecureMessages(env:Env) {
 const now=new Date().toISOString();
 const due=await env.DB.prepare(`SELECT message_id,device_id,attempts FROM secure_deliveries WHERE status IN ('pending','retry','blocked','sending') AND next_attempt_at<=? AND (lease_until IS NULL OR lease_until<?) LIMIT 50`).bind(now,now).all<Due>();
 for(const candidate of due.results) {
  const lease=crypto.randomUUID();
  const claimed=await env.DB.prepare("UPDATE secure_deliveries SET status='sending',lease_id=?,lease_until=? WHERE message_id=? AND device_id=? AND status IN ('pending','retry','blocked','sending') AND (lease_until IS NULL OR lease_until<?)").bind(lease,new Date(Date.now()+60000).toISOString(),candidate.message_id,candidate.device_id,now).run();
  if(!claimed.meta.changes) continue;
  const finish=async(status:string,error:string|null,accepted:string|null=null)=>{
   await env.DB.prepare('UPDATE secure_deliveries SET status=?,last_error=?,accepted_at=?,attempts=attempts+1,next_attempt_at=?,lease_until=NULL,lease_id=NULL WHERE message_id=? AND device_id=? AND lease_id=?').bind(status,error,accepted,new Date(Date.now()+Math.min(3600000,30000*2**Math.min(candidate.attempts,7))).toISOString(),candidate.message_id,candidate.device_id,lease).run();
  };
  // This read is immediately before sending; authorization is not snapshotted at ingest.
  const row=await env.DB.prepare(`SELECT m.id AS message_id,m.user_id,m.source_id,m.expires_at,m.created_at,d.device_id,d.enc,d.ciphertext,s.public_key AS source_public_key,s.certificate AS source_certificate,p.token_encrypted,p.environment,v.platform
   FROM secure_deliveries d JOIN secure_messages m ON m.id=d.message_id JOIN secure_devices v ON v.id=d.device_id AND v.user_id=m.user_id
   JOIN secure_sources s ON s.source_id=m.source_id AND s.user_id=m.user_id JOIN sources src ON src.id=m.source_id
   JOIN users u ON u.id=m.user_id LEFT JOIN secure_push_tokens p ON p.device_id=v.id
   WHERE d.message_id=? AND d.device_id=? AND d.acknowledged_at IS NULL AND v.status='active' AND v.notifications_enabled=1
   AND src.status='active' AND u.deletion_requested_at IS NULL AND m.expires_at>? AND m.scheduled_at<=?
   AND EXISTS (SELECT 1 FROM sessions x WHERE x.user_id=m.user_id AND x.device_id=v.id AND x.revoked_at IS NULL AND x.refresh_expires_at>?)`).bind(candidate.message_id,candidate.device_id,now,now,now).first<Delivery>();
  if(!row){await finish('suppressed','delivery_not_eligible');continue;}
  if(!row.token_encrypted){await finish('blocked','push_token_pending');continue;}
  if(row.platform==='ios'&&!pushConfigured(env)){await finish('blocked','apns_not_configured');continue;}
  if(row.platform==='harmony'&&!harmonyPushConfigured(env)){await finish('blocked','harmony_push_not_configured');continue;}
  const paused=await env.DB.prepare(`SELECT sec.key_id FROM sender_security_state sec JOIN source_keys k ON k.id=sec.key_id
   WHERE k.source_id=? AND k.user_id=? AND sec.suspended_until>? LIMIT 1`).bind(row.source_id,row.user_id,Date.now()).first();
  if(paused){await finish('retry','sender_key_suspended');continue;}
  const guard=new SenderAbuseGuard(env.DB,env);
  if(!await guard.reserveUserNotification(row.user_id)){await finish('retry','user_notification_rate_limited');continue;}
  try {
   const token=await decryptToken(row.token_encrypted,row.device_id,env.PUSH_TOKEN_ENCRYPTION_KEY);
   const {token_encrypted,environment,platform,...envelope}=row;
   const result=platform==='harmony'
    ? await sendHarmonyPush(env,token,securePayload(envelope),row.expires_at)
    : await sendAPNs(env,token,environment,securePayload(envelope),row.expires_at);
   if(result.status===200) await finish('accepted',null,new Date().toISOString());
   else if(result.reason==='Unregistered' || result.reason==='BadDeviceToken'){
    await env.DB.prepare('DELETE FROM secure_push_tokens WHERE device_id=? AND token_encrypted=?').bind(row.device_id,row.token_encrypted).run();
    await finish('failed',result.reason);
   } else await finish(result.status===429||result.status>=500?'retry':'blocked',result.reason);
  } catch {await finish('retry','push_transport_error');}
 }
}
export async function cleanupExpiredSecureMessages(db:D1Database,now=new Date().toISOString()) {
 const expired=await db.prepare('SELECT id FROM secure_messages WHERE expires_at<=? ORDER BY expires_at LIMIT 100').bind(now).all<{id:string}>();
 if(!expired.results.length) return;
 // Child and parent deletion share a transaction; daily usage remains an aggregate.
 await db.batch(expired.results.flatMap(({id})=>[
  db.prepare('DELETE FROM secure_deliveries WHERE message_id=?').bind(id),
  db.prepare('DELETE FROM secure_messages WHERE id=? AND expires_at<=?').bind(id,now)
 ]));
}
