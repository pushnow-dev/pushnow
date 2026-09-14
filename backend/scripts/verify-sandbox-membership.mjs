import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { build } from 'esbuild';
import { createHash, pbkdf2Sync, randomBytes } from 'node:crypto';
import { readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

// Real RevenueCat reads; all authentication and entitlement writes remain local.
process.chdir(fileURLToPath(new URL('../',import.meta.url)));
const credentials=JSON.parse(readFileSync(new URL('../../.secrets/revenuecat-worker.json',import.meta.url)));
const fixturePath=process.argv[2]??fileURLToPath(new URL('../../.secrets/sandbox-review-account.json',import.meta.url));
const fixture=JSON.parse(readFileSync(fixturePath));
const userID=fixture.user_id;
if(typeof userID!=='string'||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(userID))throw new Error('Fixture needs lowercase UUID user_id');
if(!credentials.REVENUECAT_SUBSCRIBER_API_KEY)throw new Error('Subscriber key unavailable');
const identity=`jizhi_sandbox_${userID}`;
const lookup=await fetch(`https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(identity)}`,{headers:{authorization:`Bearer ${credentials.REVENUECAT_SUBSCRIBER_API_KEY}`},signal:AbortSignal.timeout(12000)});
if(lookup.status!==200)throw new Error(`Existing RevenueCat customer required; lookup status ${lookup.status}`);
const customer=await lookup.json();
if(customer.subscriber?.original_app_user_id!==identity)throw new Error('Customer ownership conflict');
if(Math.abs(Date.now()-customer.request_date_ms)>300000)throw new Error('Stale RevenueCat snapshot');

const result=await build({absWorkingDir:fileURLToPath(new URL('../',import.meta.url)),entryPoints:['src/index.ts'],bundle:true,format:'esm',platform:'neutral',external:['cloudflare:*'],write:false});
const pepper=randomBytes(32).toString('hex'),password=randomBytes(24).toString('hex'),email='sandbox-fixture@example.com';
const mf=new Miniflare(convertV4MiniflareOptions({name:'sandbox-membership-only',host:'127.0.0.1',port:0,modules:true,script:result.outputFiles[0].text,d1Databases:['DB'],r2Buckets:['SECURE_BLOBS'],compatibilityDate:'2026-09-12',compatibilityFlags:['nodejs_compat'],bindings:{
 AUTH_TOKEN_PEPPER:pepper,PUSH_TOKEN_ENCRYPTION_KEY:randomBytes(32).toString('base64'),APP_BASE_URL:'http://localhost',AUTH_EMAIL_FROM:'test@example.com',CORS_ORIGINS:'http://localhost',ACCESS_TOKEN_TTL_SECONDS:'900',REFRESH_TOKEN_TTL_SECONDS:'2592000',AUTH_CODE_TTL_SECONDS:'600',REVENUECAT_ENVIRONMENT:'SANDBOX',REVENUECAT_SUBSCRIBER_API_KEY:credentials.REVENUECAT_SUBSCRIBER_API_KEY
}}));
try{
 const db=await mf.getD1Database('DB');
 for(const name of readdirSync('migrations').sort())for(const sql of readFileSync(`migrations/${name}`,'utf8').split(';').map(s=>s.trim()).filter(Boolean))await db.prepare(sql).run();
 const salt=randomBytes(16).toString('base64url'),now=new Date().toISOString();
 const passwordHash=`pbkdf2_sha256$210000$${salt}$${pbkdf2Sync(`${password}.${pepper}`,salt,210000,32,'sha256').toString('base64url')}`;
 await db.prepare('INSERT INTO users(id,email,email_hash,email_verified_at,created_at,updated_at,password_hash,password_set_at,revenuecat_app_user_id) VALUES (?,?,?,?,?,?,?,?,?)').bind(userID,email,createHash('sha256').update(`email.${email}.${pepper}`).digest('hex'),now,now,now,passwordHash,now,identity).run();
 const login=await mf.dispatchFetch('http://localhost/v1/auth/password/login',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email,password})});
 if(!login.ok)throw new Error(`Local login failed: ${login.status}`);
 const auth=await login.json();
 const response=await mf.dispatchFetch('http://localhost/v1/me/plan/reconcile',{method:'POST',headers:{authorization:`Bearer ${auth.access_token}`,'content-type':'application/json'},body:'{}'});
 const body=await response.json();
 if(!response.ok)throw new Error(`Local reconciliation failed: ${response.status} ${body.code??'unknown'}`);
 const row=await db.prepare('SELECT plan FROM entitlements WHERE user_id=?').bind(userID).first();
 if(row?.plan!==body.membership.plan)throw new Error('Local membership readback mismatch');
 console.log(JSON.stringify({environment:'SANDBOX',revenuecat_lookup_status:lookup.status,reconcile_status:response.status,plan:body.membership.plan,daily_notification_limit:body.membership.daily_notification_limit,local_d1_verified:true,paid_sandbox_access:body.membership.plan!=='free',production_writes:false}));
}finally{await mf.dispose();}
