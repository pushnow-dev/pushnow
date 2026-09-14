import { SenderAbuseGuard } from "./sender-abuse";
import { decryptToken, harmonyPushConfigured, pushConfigured, sendAPNs, sendHarmonyPush } from './secure-push';
import { previewPayload } from './v2-messages';
import type { MessageRow } from './v2-message-store';
type Due={message_id:string;device_id:string;attempts:number};
type Delivery=MessageRow&{device_id:string;token_encrypted:string|null;environment:string;platform:string};
export async function deliverArchiveMessages(env:Env){
 const now=new Date().toISOString(),rows=(await env.DB.prepare("SELECT message_id,device_id,attempts FROM v2_deliveries WHERE status IN ('pending','retry','blocked','sending') AND next_attempt_at<=? AND (lease_until IS NULL OR lease_until<?) LIMIT 50").bind(now,now).all<Due>()).results;
 for(const candidate of rows){
  const lease=crypto.randomUUID(),claim=await env.DB.prepare("UPDATE v2_deliveries SET lease_id=?,lease_until=?,status='sending' WHERE message_id=? AND device_id=? AND status IN ('pending','retry','blocked','sending') AND next_attempt_at<=? AND (lease_until IS NULL OR lease_until<?)").bind(lease,new Date(Date.now()+60000).toISOString(),candidate.message_id,candidate.device_id,now,now).run();if(!claim.meta.changes)continue;
  const finish=async(status:string,reason:string|null)=>{await env.DB.prepare('UPDATE v2_deliveries SET status=?,last_error=?,attempts=attempts+1,next_attempt_at=?,lease_id=NULL,lease_until=NULL,accepted_at=? WHERE message_id=? AND device_id=? AND lease_id=?').bind(status,reason,new Date(Date.now()+Math.min(3600000,30000*2**Math.min(candidate.attempts,7))).toISOString(),status==='accepted'?new Date().toISOString():null,candidate.message_id,candidate.device_id,lease).run();};
  const row=await env.DB.prepare(`SELECT m.*,d.device_id,p.token_encrypted,p.environment,v.platform FROM v2_deliveries d JOIN v2_messages m ON m.id=d.message_id JOIN secure_devices v ON v.id=d.device_id AND v.user_id=m.user_id JOIN sources s ON s.id=m.source_id JOIN users u ON u.id=m.user_id LEFT JOIN secure_push_tokens p ON p.device_id=v.id
   WHERE d.message_id=? AND d.device_id=? AND m.deleted_at IS NULL AND (m.read_at IS NULL OR m.scheduled_at IS NOT NULL) AND v.status='active' AND v.notifications_enabled=1 AND s.status='active' AND u.deletion_requested_at IS NULL AND EXISTS(SELECT 1 FROM sessions x WHERE x.user_id=m.user_id AND x.device_id=v.id AND x.revoked_at IS NULL AND x.refresh_expires_at>?)`).bind(candidate.message_id,candidate.device_id,now).first<Delivery>();
  if(!row){await finish('suppressed','delivery_not_eligible');continue;}
  if(row.source_key_id){
   const key=await env.DB.prepare('SELECT id FROM source_keys WHERE id=? AND user_id=? AND source_id=? AND revoked_at IS NULL AND (expires_at IS NULL OR expires_at>?)').bind(row.source_key_id,row.user_id,row.source_id,new Date().toISOString()).first();
   if(!key){await finish('suppressed','source_key_not_active');continue;}
  }
  const expiry=row.expires_at??new Date(Date.parse(row.created_at)+30*86400000).toISOString();if(expiry<=new Date().toISOString()){await finish('expired','transport_expired');continue;}
  if(row.scheduled_at&&row.scheduled_at>new Date().toISOString()){
   await env.DB.prepare("UPDATE v2_deliveries SET status='pending',next_attempt_at=?,lease_id=NULL,lease_until=NULL WHERE message_id=? AND device_id=? AND lease_id=?").bind(row.scheduled_at,candidate.message_id,candidate.device_id,lease).run();continue;
  }
  if(!row.token_encrypted){await finish('blocked','push_token_pending');continue;}
  if(row.platform==='harmony'?!harmonyPushConfigured(env):!pushConfigured(env)){await finish('blocked','push_not_configured');continue;}
  if(row.source_key_id) {
   try { await new SenderAbuseGuard(env.DB,env).assertKeyActive(row.user_id,row.source_key_id); }
   catch(error) { if(error instanceof Error && 'retryAfterSeconds' in error){await finish('retry','sender_key_suspended');continue;} throw error; }
  }
  const guard=new SenderAbuseGuard(env.DB,env);
  if(!await guard.reserveUserNotification(row.user_id)){await finish('retry','user_notification_rate_limited');continue;}
  try{
   const token=await decryptToken(row.token_encrypted,row.device_id,env.PUSH_TOKEN_ENCRYPTION_KEY),payload=previewPayload({message_id:row.id,user_id:row.user_id,source_id:row.source_id,archive_id:row.archive_id,enc:row.preview_enc!,ciphertext:row.preview_ciphertext!,source_public_key:row.source_public_key!,source_certificate:row.source_certificate!,created_at:row.created_at},row.device_id,row.sound);
   const result=row.platform==='harmony'?await sendHarmonyPush(env,token,payload,expiry):await sendAPNs(env,token,row.environment,payload,expiry);
   if(result.status===200)await finish('accepted',null);
   else if(result.reason==='Unregistered'||result.reason==='BadDeviceToken'){await env.DB.prepare('DELETE FROM secure_push_tokens WHERE device_id=? AND token_encrypted=?').bind(row.device_id,row.token_encrypted).run();await finish('failed',result.reason);}
   else await finish(result.status===429||result.status>=500?'retry':'blocked',result.reason);
  }catch{await finish('retry','push_transport_error');}
 }
}
