import { Miniflare, convertV4MiniflareOptions } from 'miniflare';
import { build } from 'esbuild';
import { createHash, pbkdf2Sync, randomBytes, randomUUID } from 'node:crypto';
import { readFileSync, readdirSync, writeFileSync } from 'node:fs';

// Disposable, localhost-only fixture. Never loads production bindings or secrets.
const result=await build({entryPoints:['src/index.ts'],bundle:true,format:'esm',platform:'neutral',external:['cloudflare:*'],write:false});
const pepper='local-fixture-only',email='secure-test@example.com',password='LocalSecure2026';
const mf=new Miniflare(convertV4MiniflareOptions({name:'fixture',host:'127.0.0.1',port:8799,modules:true,script:result.outputFiles[0].text,d1Databases:['DB'],r2Buckets:['SECURE_BLOBS'],compatibilityDate:'2026-09-12',compatibilityFlags:['nodejs_compat'],bindings:{AUTH_TOKEN_PEPPER:pepper,PUSH_TOKEN_ENCRYPTION_KEY:randomBytes(32).toString('base64'),APP_BASE_URL:'http://127.0.0.1:8799',AUTH_EMAIL_FROM:'test@example.com',CORS_ORIGINS:'http://127.0.0.1:8799',ACCESS_TOKEN_TTL_SECONDS:'900',REFRESH_TOKEN_TTL_SECONDS:'2592000',AUTH_CODE_TTL_SECONDS:'600'}}));
const db=await mf.getD1Database('DB');
for(const name of readdirSync('migrations').sort()) {
 for(const statement of readFileSync(`migrations/${name}`,'utf8').split(';').map(s=>s.trim()).filter(Boolean)) await db.prepare(statement).run();
}
const salt=randomBytes(16).toString('base64url'),now=new Date().toISOString();
const passwordHash=`pbkdf2_sha256$210000$${salt}$${pbkdf2Sync(`${password}.${pepper}`,salt,210000,32,'sha256').toString('base64url')}`;
await db.prepare('INSERT INTO users(id,email,email_hash,email_verified_at,created_at,updated_at,password_hash,password_set_at) VALUES (?,?,?,?,?,?,?,?)').bind(randomUUID(),email,createHash('sha256').update(`email.${email}.${pepper}`).digest('hex'),now,now,now,passwordHash,now).run();
const login=await mf.dispatchFetch('http://localhost/v1/auth/password/login',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email,password})});
if(!login.ok) throw new Error(`Fixture login failed: ${login.status}`);
const auth=await login.json();
writeFileSync('/tmp/pushnow-secure-qa-session.json',JSON.stringify({session:{userID:auth.user.id,email:auth.user.email,isVerified:true,hasPassword:true},accessToken:auth.access_token,refreshToken:auth.refresh_token}),{mode:0o600});
console.log(`Disposable v2 D1/R2 fixture ready at http://127.0.0.1:8799, PID ${process.pid} (credentials documented in script; no production resources).`);
for(const signal of ['SIGINT','SIGTERM']) process.on(signal,async()=>{await mf.dispose();process.exit(0);});
