import { checkSenderRequest } from "./sender-abuse-request";
import type { EmailAuthService } from './auth-service';
import { bearerToken, emptyResponse, jsonResponse, readJsonBody } from './http';
import type { ProductService } from './product-service';
import { SecureDevices } from './secure-devices';
import { SecureMessages } from './secure-messages';
import { registerPush } from './secure-push';
import { deliverSecureMessages } from './secure-delivery';
import { publicDevice } from './secure-types';

export async function secureRoute(request:Request,env:Env,auth:EmailAuthService,product:ProductService,headers:HeadersInit,ctx?:ExecutionContext) {
 const path=new URL(request.url).pathname,method=request.method;
 const devices=new SecureDevices(env.DB),messages=new SecureMessages(env.DB,product);
 const credential=()=>request.headers.get('x-jizhi-source-key')??bearerToken(request);
 if(path==='/v1/secure/recipients'&&method==='GET') return jsonResponse(await messages.recipients(credential()),200,headers);
 if(path==='/v1/secure/messages'&&method==='POST') {
  await checkSenderRequest(env,product,credential(),ctx);
  const result=await messages.ingest(credential(),request.headers.get('idempotency-key')??'',await readJsonBody(request,131072)??{});
  if(ctx) ctx.waitUntil(deliverSecureMessages(env));
  return jsonResponse(result,result.deduplicated?200:201,headers);
 }
 const session=await auth.authenticate(bearerToken(request));
 if(path==='/v1/secure/device-challenge'&&method==='GET') return jsonResponse(await devices.challenge(session),200,headers);
 if(path==='/v1/secure/devices'&&method==='GET') return jsonResponse(await devices.list(session.user.id),200,headers);
 if(path==='/v1/secure/devices'&&method==='POST') return jsonResponse(await devices.register(session,await readJsonBody(request)??{}),200,headers);
 if(path==='/v1/secure/messages'&&method==='GET') return jsonResponse(await messages.inbox(session),200,headers);
 const device=/^\/v1\/secure\/devices\/([^/]+)(?:\/(approve|approval|push))?$/.exec(path);
 if(device) {
  const id=decodeURIComponent(device[1]),action=device[2];
  if(!action&&method==='PATCH') return jsonResponse(await devices.update(session.user.id,id,await readJsonBody(request)??{}),200,headers);
  if(!action&&method==='GET') return jsonResponse({device:publicDevice(await devices.get(session.user.id,id))},200,headers);
  if(!action&&method==='DELETE') return jsonResponse({code:'device_removal_not_supported'},405,headers);
  if(action==='approve'&&method==='POST') return jsonResponse(await devices.approve(session,id,await readJsonBody(request)??{}),200,headers);
  if(action==='approval'&&method==='GET') return jsonResponse(await devices.approval(session,id),200,headers);
  if(action==='push'&&method==='PUT') return jsonResponse(await registerPush(env,session,id,await readJsonBody(request)??{}),200,headers);
 }
 const source=/^\/v1\/secure\/sources\/([^/]+)$/.exec(path);
 if(source&&method==='PUT') return jsonResponse(await messages.setup(session,decodeURIComponent(source[1]),await readJsonBody(request)??{}),200,headers);
 const detail=/^\/v1\/secure\/messages\/([^/]+)$/.exec(path);
 if(detail&&method==='GET')return jsonResponse(await messages.get(session,decodeURIComponent(detail[1])),200,headers);
 const read=/^\/v1\/secure\/messages\/([^/]+)\/read$/.exec(path);
 if(read&&method==='POST'){await messages.read(session,decodeURIComponent(read[1]));return emptyResponse(204,headers);}
 const ack=/^\/v1\/secure\/messages\/([^/]+)\/ack$/.exec(path);
 if(ack&&method==='POST'){await messages.ack(session,decodeURIComponent(ack[1]));return emptyResponse(204,headers);}
 return jsonResponse({code:'not_found'},404,headers);
}
