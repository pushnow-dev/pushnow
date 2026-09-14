import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash, createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
const require=createRequire(import.meta.url),ts=require('../../backend/node_modules/typescript');
function fixture() {
 const user='user',source='source',plain=Buffer.from('encrypted markdown\n你好'),key=randomBytes(32),nonce=randomBytes(12);
 const attachment={id:'11111111-1111-4111-8111-111111111111',name:'readme.md',mime:'text/markdown',size:plain.length,
  key:key.toString('base64'),nonce:nonce.toString('base64'),sha256:createHash('sha256').update(plain).digest('hex'),read_token:'unused'};
 const cipher=createCipheriv('aes-256-gcm',key,nonce);cipher.setAAD(Buffer.from(JSON.stringify([2,'attachment',user,source,attachment.id])));
 let encrypted=Buffer.concat([cipher.update(plain),cipher.final(),cipher.getAuthTag()]);let requested=0;
 const auth={generation:1,current:{verified:true,userID:user},requireAccessToken:async()=> 'access'};
 const imports={
  '@kit.NetworkKit':{http:{RequestMethod:{GET:'GET'},HttpDataType:{ARRAY_BUFFER:2},createHttp:()=>({destroy(){},request:async(_url,options)=>{
   requested++;assert.equal(options.header.Authorization,'Bearer access');return {responseCode:200,result:Uint8Array.from(encrypted).buffer};
  }})}},
  '@kit.CryptoArchitectureKit':{cryptoFramework:{createMd:()=>{const hash=createHash('sha256');return {update:async blob=>hash.update(blob.data),digest:async()=>({data:hash.digest()})};}}},
  './AppConfig':{API_BASE_URL:'https://test.invalid'},'./AuthService':{authService:auth},
  './SecureCrypto':{secureCrypto:{decode:value=>Buffer.from(value,'base64'),utf8:value=>new TextDecoder('utf-8',{fatal:true}).decode(value),
   aesOpen:async(key,nonce,value,aad)=>{const decipher=createDecipheriv('aes-256-gcm',key,nonce);decipher.setAAD(Buffer.from(aad));decipher.setAuthTag(value.slice(-16));return Buffer.concat([decipher.update(value.slice(0,-16)),decipher.final()]);}}},
  '@kit.ImageKit':{image:{}},'@kit.CoreFileKit':{fileIo:{},picker:{}}
 };
 const text=readFileSync(new URL('../entry/src/main/ets/services/SecureAttachmentService.ets',import.meta.url),'utf8');
 const js=ts.transpileModule(text,{compilerOptions:{target:ts.ScriptTarget.ES2022,module:ts.ModuleKind.CommonJS}}).outputText,exports={};
 new Function('require','exports',js)(id=>{if(!(id in imports))throw Error(id);return imports[id];},exports);
 return {service:exports.secureAttachmentService,attachment,user,source,auth,plain,setEncrypted:value=>encrypted=value,requested:()=>requested};
}
test('encrypted attachment authenticates AAD and validates exact plaintext length and SHA256',async()=>{
 const f=fixture();assert.deepEqual(Buffer.from(await f.service.bytes(f.attachment,f.user,f.source)),f.plain);
});
test('attachment rejects wrong account before network access',async()=>{
 const f=fixture();await assert.rejects(f.service.bytes(f.attachment,'foreign',f.source),/session_changed/);assert.equal(f.requested(),0);
});
test('attachment rejects another source, truncated ciphertext and manifest digest tampering',async()=>{
 let f=fixture();await assert.rejects(f.service.bytes(f.attachment,f.user,'other'));
 f=fixture();f.setEncrypted(Buffer.alloc(16));await assert.rejects(f.service.bytes(f.attachment,f.user,f.source),/size_mismatch/);
 f=fixture();f.attachment.sha256='0'.repeat(64);await assert.rejects(f.service.bytes(f.attachment,f.user,f.source),/integrity_failed/);
});
