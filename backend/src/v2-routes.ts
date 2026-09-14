import { checkSenderRequest } from "./sender-abuse-request";
import type { EmailAuthService } from './auth-service';
import type { ProductService } from './product-service';
import { bearerToken, emptyResponse, jsonResponse, readJsonBody } from './http';
import { SecureMessages } from './secure-messages';
import { SecureDevices } from './secure-devices';
import { ArchiveService } from './v2-archive';
import { SenderAuthorizationService } from './v2-authorizations';
import { AttachmentService } from './v2-attachments';
import { MessageIngest } from './v2-messages';
import { MessageHistory } from './v2-message-store';
import { deliverArchiveMessages } from './v2-delivery';
import { managementRoute } from './sender-management';
export async function archiveRoute(request:Request,env:Env,auth:EmailAuthService,product:ProductService,headers:HeadersInit,ctx?:ExecutionContext){
 const managed=await managementRoute(request,env,auth,headers);if(managed)return managed;
 const url=new URL(request.url),path=url.pathname,method=request.method,ip=request.headers.get('cf-connecting-ip')??'local';
 const authorizations=new SenderAuthorizationService(env.DB),archive=new ArchiveService(env.DB),files=new AttachmentService(env.DB,env.SECURE_BLOBS),history=new MessageHistory(env.DB,env.SECURE_BLOBS),secure=new SecureMessages(env.DB,product);
 const body=()=>readJsonBody(request),source=()=>secure.source(bearerToken(request));
 if(path==='/v2/account-authorizations'&&method==='POST')return jsonResponse(await authorizations.createAccount(await auth.authenticate(bearerToken(request)),await body()??{},ip),201,headers);
 if(path==='/v2/authorizations'&&method==='POST')return jsonResponse(await authorizations.create(await body()??{},ip),201,headers);
 const token=/^\/v2\/authorizations\/([^/]+)\/token$/.exec(path);
 if(token&&method==='POST')return jsonResponse(await authorizations.token(token[1],await body()??{},ip),200,headers);
 if(path==='/v2/recipients'&&method==='GET'){const credential=bearerToken(request),directory=await secure.recipients(credential);return jsonResponse({...directory,archive:await archive.require(directory.user_id)},200,headers);}
 if(path==='/v2/logout'&&method==='POST'){const current=await source();await env.DB.batch([env.DB.prepare("UPDATE sources SET status='revoked',updated_at=? WHERE id=? AND user_id=?").bind(new Date().toISOString(),current.source_id,current.user_id),env.DB.prepare('UPDATE source_keys SET revoked_at=? WHERE source_id=? AND user_id=?').bind(new Date().toISOString(),current.source_id,current.user_id)]);return emptyResponse(204,headers);}
 if(path==='/v2/attachments'&&method==='POST')return jsonResponse(await files.reserve(await source(),await body()??{}),201,headers);
 const attachment=/^\/v2\/attachments\/([^/]+)$/.exec(path);
 if(attachment&&method==='PUT'){await files.put(await source(),attachment[1],request);return emptyResponse(204,headers);}
 if(attachment&&method==='GET'&&request.headers.get('authorization')?.startsWith('Attachment '))return files.download(attachment[1],null,request.headers.get('authorization')!.slice(11));
 if(path==='/v2/messages'&&method==='POST'){
  await checkSenderRequest(env,product,bearerToken(request),ctx);
  const result=await new MessageIngest(env.DB,product).ingest(await source(),request.headers.get('idempotency-key')??'',await readJsonBody(request,512*1024)??{});
  if(ctx)ctx.waitUntil(deliverArchiveMessages(env));return jsonResponse(result,result.deduplicated?200:201,headers);
 }
 const session=await auth.authenticate(bearerToken(request));await new SecureDevices(env.DB).bound(session);
 if(path==='/v2/account-authorizations/pending'&&method==='GET')return jsonResponse(await authorizations.pendingAccount(session),200,headers);
 if(attachment&&method==='GET')return files.download(attachment[1],session.user.id,null);
 if(path==='/v2/archive'&&method==='GET')return jsonResponse({archive:await archive.get(session.user.id)},200,headers);
 if(path==='/v2/archive'&&method==='POST')return jsonResponse(await archive.initialize(session,await body()??{}),200,headers);
 const grant=/^\/v2\/archive\/grants\/([^/]+)$/.exec(path);
 if(grant&&method==='GET')return jsonResponse(await archive.readGrant(session,grant[1]),200,headers);
 if(grant&&method==='POST'){await archive.grant(session,grant[1],await body()??{});return emptyResponse(204,headers);}
 if(path==='/v2/authorizations/lookup'&&method==='GET')return jsonResponse(await authorizations.lookup(session,url.searchParams.get('code')??''),200,headers);
 const approve=/^\/v2\/authorizations\/([^/]+)\/approve$/.exec(path);
 if(approve&&method==='POST'){await authorizations.approve(session,approve[1],await body()??{});return emptyResponse(204,headers);}
 if(path==='/v2/senders'&&method==='GET')return jsonResponse(await authorizations.senders(session),200,headers);
 const sender=/^\/v2\/senders\/([^/]+)$/.exec(path);
 if(sender&&method==='DELETE'){await authorizations.revoke(session,sender[1]);return emptyResponse(204,headers);}
 if(path==='/v2/messages'&&method==='GET')return jsonResponse(await history.list(session,url.searchParams.get('cursor'),url.searchParams.get('limit')),200,headers);
 if(path==='/v2/deletions'&&method==='GET')return jsonResponse(await history.list(session,url.searchParams.get('cursor'),url.searchParams.get('limit'),true),200,headers);
 const message=/^\/v2\/messages\/([^/]+)(?:\/(read))?$/.exec(path);
 if(message&&!message[2]&&method==='GET')return jsonResponse(await history.get(session,message[1]),200,headers);
 if(message&&!message[2]&&method==='DELETE'){await history.delete(session,message[1]);return emptyResponse(204,headers);}
 if(message&&message[2]&&method==='POST'){await history.read(session,message[1]);return emptyResponse(204,headers);}
 return jsonResponse({code:'not_found'},404,headers);
}
