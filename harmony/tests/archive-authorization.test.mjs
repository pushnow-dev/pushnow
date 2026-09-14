import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
const require = createRequire(import.meta.url);
const ts = require('../../backend/node_modules/typescript');
function load(name, imports) {
 const source = readFileSync(new URL(`../entry/src/main/ets/services/${name}.ets`, import.meta.url), 'utf8');
 const js = ts.transpileModule(source, {compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.CommonJS}}).outputText;
 const exports = {};
 new Function('require','exports',js)(id => {if (!(id in imports)) throw Error(id); return imports[id];},exports);
 return exports;
}
function fixture() {
 const saved = new Map(), calls=[];
 const auth={generation:1,current:{userID:'user',verified:true},requireAccessToken:async()=> 'access'};
 const enrollment={userId:'user',identityEstablished:()=>true,identityPrivateKey:()=> 'root-secret',identityPublicKey:()=> 'root',
  keys:()=>({privateKey:'device-secret',publicKey:'device'}),archiveTransfer:undefined};
 const crypto={generateKey:async()=>({privateKey:'archive-secret',publicKey:'archive'}),
  text:(...args)=>args.join(':'),sign:async(key,text)=>`${key}|${text}`,
  verify:async(signature,text,key)=> { if(signature!==`${key}-secret|${text}`)throw Error('bad-signature');},
  open:async(_secret,_public,grant,_info,aad)=> {assert.equal(grant.aad,aad);return grant.clear;},
  seal:async(publicKey,clear,info,aad)=>({enc:publicKey,ciphertext:JSON.stringify({clear,info,aad})})};
 let remote=null, loseResponse=false;
 const api={get:async(path)=>{calls.push(['GET',path]);if(path==='/v2/archive')return {archive:remote};throw Error(`unknown:${path}`);},
  post:async(path,body)=>{calls.push(['POST',path,body]); if(path==='/v2/archive'){remote=body;if(loseResponse)throw Error('network');return {archive:remote};}return {};}};
 const storage={read:async key=>saved.get(key)??'',write:async(key,value)=>saved.set(key,value),remove:async key=>saved.delete(key)};
 const imports={'@kit.CryptoArchitectureKit':{cryptoFramework:{createRandom:()=>({generateRandomSync:size=>({data:randomBytes(size)})})}},
  './ApiClient':{apiClient:api},'./AuthService':{authService:auth},'./SecureCrypto':{secureCrypto:crypto},
  './SecureDeviceEnrollmentService':{secureDeviceEnrollmentService:enrollment},'./SecureStorage':{secureStorage:storage},
  './DeviceService':{deviceService:{deviceId:'device-id'}}};
 const service=new (load('SecureArchiveService',imports).SecureArchiveService)();
 return {service,imports,saved,calls,auth,api,crypto,enrollment,remote(value){remote=value;},lose(){loseResponse=true;}};
}
test('first archive creation recovers a lost server response without changing account key',async()=>{
 const f=fixture();f.lose();const first=await f.service.ensure();const second=await f.service.ensure();
 assert.deepEqual(first,second);assert.ok(f.saved.has('archive:user'));assert.equal(f.saved.has('archive-provisional:user'),false);
 assert.equal(f.calls.filter(([method])=>method==='POST').length,1);
});
test('pinned archive substitution is rejected even with valid account certificate',async()=>{
 const f=fixture();await f.service.ensure();f.remote({id:'replacement',public_key:'archive',certificate:'root-secret|archive:user:replacement:archive'});
 await assert.rejects(f.service.ensure(),/archive_identity_changed/);
});
test('transferred archive private key must match signed public key',async()=>{
 const f=fixture();const first=await f.service.ensure();f.saved.clear();f.enrollment.archiveTransfer={archiveId:first.archive.id,archivePrivateKey:'wrong'};
 await assert.rejects(f.service.ensure(),/bad-signature/);assert.equal(f.saved.has('archive:user'),false);
});
test('logout during archive lookup cannot save or expose old account history',async()=>{
 const f=fixture();f.api.get=async()=>{f.auth.generation++;f.auth.current.verified=false;return {archive:null};};
 await assert.rejects(f.service.ensure(),/trusted_device_required/);assert.equal(f.saved.size,0);
});
test('archive grants reject foreign device before encryption or HTTP writes',async()=>{
 const f=fixture();await assert.rejects(f.service.grant({userId:'other',status:'active'}),/invalid_device/);assert.equal(f.calls.length,0);
});
test('sender authorization requires current lookup and explicit fingerprint confirmation; encrypted grant contains only public archive',async()=>{
 const f=fixture();const archive=await f.service.ensure();const req={id:'request',name:'Agent',public_key:'sender',expires_at:new Date(Date.now()+60000).toISOString()};
 f.api.get=async path=> path.includes('lookup')?{authorization:req}:{senders:[]};
 f.api.post=async(path,body)=>{f.calls.push(['POST',path,body]);return path==='/v1/sources'?{source:{id:'source'}}:path.endsWith('/keys')?{source_key:'source-token'}:{};};
 f.api.put=async(path,body)=>{f.calls.push(['PUT',path,body]);return {};};
 const imports={...f.imports,'./AppConfig':{API_BASE_URL:'https://test.invalid'},'./SecureArchiveService':{secureArchiveService:{ensure:async()=>archive}}};
 const sender=new (load('SenderAuthorizationService',imports).SenderAuthorizationService)();
 await assert.rejects(sender.approve(req,true),/fingerprint_confirmation/);
 await sender.lookup('ABCD-EFGH');await assert.rejects(sender.approve(req,false),/fingerprint_confirmation/);
 await sender.approve(req,true);
 const setup=f.calls.findIndex(c=>c[0]==='PUT');const key=f.calls.findIndex(c=>c[1].endsWith('/keys'));assert.ok(setup<key);
 const approval=f.calls.find(c=>c[1].endsWith('/approve'))[2];const envelope=JSON.parse(approval.ciphertext),clear=JSON.parse(envelope.clear);
 assert.equal(clear.source_key,'source-token');assert.equal(clear.archive.public_key,'archive');assert.equal(clear.archive.privateKey,undefined);
 assert.equal(envelope.info,'pushnow-sender-grant-v2');assert.equal(envelope.aad,'[2,"sender-grant","request","sender"]');
 await assert.rejects(sender.approve(req,true),/fingerprint_confirmation/);
});
