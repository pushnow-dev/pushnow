import { build } from 'esbuild';
import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { readFileSync, readdirSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
import { createServer } from 'node:http';
import {beginAccountLogin, finishAccountLogin} from '../../sdk/typescript/dist/index.js';
import { beginLogin, finishLogin } from '../../cli/src/v2-auth.js';
import { recipientsV2, prepareMessageV2, submitMessageV2, uploadAttachment } from '../../cli/src/v2-client.js';

// Test-only loopback server: real auth/routes/D1/R2, with a captured mail transport.
const bundled = await build({ stdin: { contents: `
import worker from './src/index.ts';
import { deliverArchiveMessages } from './src/v2-delivery.ts';
export default { async fetch(request, env, ctx) {
 const url = new URL(request.url);
 if (url.pathname === '/__qa/mail') {
  const mail = await env.DB.prepare('SELECT body FROM qa_mail WHERE email=?').bind(url.searchParams.get('email')).first();
  return Response.json(mail ?? {});
 }
 if (url.pathname === '/__qa/tick' && request.method === 'POST') {
  await deliverArchiveMessages(env); return Response.json({scanned:true});
 }
 const EMAIL = { send: async input => {
  await env.DB.prepare('INSERT INTO qa_mail(email,body) VALUES (?,?) ON CONFLICT(email) DO UPDATE SET body=excluded.body').bind(input.to,input.text).run();
  return {messageId:crypto.randomUUID()};
 }};
 return worker.fetch(request, {...env,EMAIL}, ctx);
}};`, resolveDir: process.cwd(), sourcefile: 'qa-entry.ts', loader: 'ts' },
 bundle: true, format: 'esm', platform: 'neutral', external: ['cloudflare:*'], write: false });
const mf = new Miniflare(convertV4MiniflareOptions({ name: 'pushnow-simulator-qa',
 host: '127.0.0.1', port: 0, modules: true, script: bundled.outputFiles[0].text,
 d1Databases: ['DB'], r2Buckets: ['SECURE_BLOBS'], compatibilityDate: '2026-09-12',
 compatibilityFlags: ['nodejs_compat'], bindings: {
  AUTH_TOKEN_PEPPER: randomBytes(32).toString('hex'),
  PUSH_TOKEN_ENCRYPTION_KEY: randomBytes(32).toString('base64'),
  APP_BASE_URL: 'http://127.0.0.1:4325', AUTH_EMAIL_FROM: 'test@example.com',
  CORS_ORIGINS: 'http://127.0.0.1:4325,http://localhost:4325,http://127.0.0.1:4330',
  ACCESS_TOKEN_TTL_SECONDS: '3600', REFRESH_TOKEN_TTL_SECONDS: '2592000', AUTH_CODE_TTL_SECONDS: '600'
 } }));
const db = await mf.getD1Database('DB');
for (const file of readdirSync('migrations').filter(f => f.endsWith('.sql')).sort()) {
 for (const sql of readFileSync(`migrations/${file}`, 'utf8').split(';').map(s => s.trim()).filter(Boolean)) {
  await db.prepare(sql).run();
 }
}
await db.prepare('CREATE TABLE qa_mail(email TEXT PRIMARY KEY,body TEXT)').run();
await mf.ready;
let pending, config, state = {};
const origin = 'http://127.0.0.1:8799';
const server = createServer(async (req, res) => {
 try {
  const chunks = []; for await (const chunk of req) chunks.push(chunk);
  const raw = Buffer.concat(chunks), url = new URL(req.url, origin);
  const input = raw.length && url.pathname.startsWith('/__qa/') ? JSON.parse(raw.toString()) : {};
  let result;
  if (url.pathname === '/__qa/account-setup') {
   const post = async (path, body, token) => {
    const response = await fetch(origin + path, {method:'POST', headers:{'content-type':'application/json', ...(token ? {authorization:`Bearer ${token}`} : {})}, body:JSON.stringify(body)});
    if (!response.ok) throw new Error(`Fixture setup failed: ${response.status}`);
    return response.json();
   };
   await post('/v1/auth/email/start', {email:input.email});
   const mail = await (await fetch(`${origin}/__qa/mail?email=${encodeURIComponent(input.email)}`)).json();
   const session = await post('/v1/auth/email/verify', {email:input.email, code:mail.body.match(/[0-9]{6}/)[0]});
   await post('/v1/me/password', {password:input.password}, session.access_token);
   result = {ready:true};
  } else if (url.pathname === '/__qa/account-sender') {
   const login = await fetch(`${origin}/v1/auth/password/login`, {method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:input.email,password:input.password})});
   const session = await login.json();
   pending = await beginAccountLogin(origin, session.access_token, 'Automatic browser');
   result = {pending:true};
  } else if (url.pathname === '/__qa/account-finish') {
   config = await finishAccountLogin(pending);
   result = {authorized:true,devices:(await recipientsV2(config)).devices.length};
  } else if (url.pathname === '/__qa/sender') {
   pending = await beginLogin(origin, 'Simulator SDK');
   result = {code:pending.authorization.user_code,fingerprint:pending.fingerprint};
  } else if (url.pathname === '/__qa/finish') {
   config = await finishLogin(pending, {expectedIdentityFingerprint:input.fingerprint});
   result = {authorized:true};
  } else if (url.pathname === '/__qa/send') {
   const directory = await recipientsV2(config);
   const attachments = input.file ? [await uploadAttachment(config, Buffer.from('# Private attachment\n\nSimulator encrypted file.'), {name:'private.md',mime:'text/markdown'})] : [];
   const message = await prepareMessageV2(config, directory, {title:input.title??'Encrypted simulator message',body:'Private SDK message body',attachments,links:[]},
    {deviceIds:input.device_ids,scheduledAt:input.scheduled_at,expiresAt:input.expires_at});
   result = await submitMessageV2(config,message);
  } else if (url.pathname === '/__qa/state') {
   if (req.method === 'POST') state = {...state,...input}; result = state;
  } else {
   const response = await mf.dispatchFetch(url, {method:req.method,headers:req.headers,body:raw.length?raw:undefined});
   res.writeHead(response.status,Object.fromEntries(response.headers));res.end(Buffer.from(await response.arrayBuffer()));return;
  }
  res.writeHead(200,{'content-type':'application/json'});res.end(JSON.stringify(result));
 } catch(error) { res.writeHead(500,{'content-type':'application/json'});res.end(JSON.stringify({error:error.message})); }
});
server.listen(8799,'127.0.0.1',()=>console.log(`Simulator QA ready: ${origin}`));
for (const signal of ['SIGTERM', 'SIGINT']) process.on(signal, async () => { server.close(); await mf.dispose(); process.exit(0); });
