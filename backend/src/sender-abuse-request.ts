import { SenderAbuseGuard } from './sender-abuse';
import type { ProductService } from './product-service';
/** Authenticate before counting. Persist an alert before rejecting the request. */
export async function checkSenderRequest(env:Env, product:ProductService, token:string, ctx?:ExecutionContext) {
 const session=await product.authenticateSourceKey(token);
 const guard=new SenderAbuseGuard(env.DB,env);
 const decision=await guard.checkKey(session.key.userId,session.key.id);
 if(decision.newlySuspended) {
  if(ctx)ctx.waitUntil(guard.deliverSecurityEmails(env));
 }
 guard.assertDecision(decision);
}
