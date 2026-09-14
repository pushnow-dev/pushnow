import { afterEach, expect, it, vi } from 'vitest';
import { readJsonBody } from '../src/http';
import { sendAPNs } from '../src/secure-push';

afterEach(()=>vi.unstubAllGlobals());
it('enforces actual streamed JSON limits even without content-length',async()=>{
 const request=new Request('http://localhost',{method:'POST',body:JSON.stringify({body:'a'.repeat(70000)})});
 await expect(readJsonBody(request)).rejects.toMatchObject({status:413});
 const larger=new Request('http://localhost',{method:'POST',body:JSON.stringify({body:'a'.repeat(70000)})});
 expect(await readJsonBody(larger,131072)).toHaveProperty('body');
});
it('retains APNs reason codes without echoing arbitrary provider content',async()=>{
 const pair=await crypto.subtle.generateKey({name:'ECDSA',namedCurve:'P-256'},true,['sign','verify']);
 const pem=btoa(String.fromCharCode(...new Uint8Array(await crypto.subtle.exportKey('pkcs8',pair.privateKey))));
 const env={APNS_PRIVATE_KEY:pem,APNS_KEY_ID:'test',APNS_TEAM_ID:'test',APNS_TOPIC:'test.app',PUSH_TOKEN_ENCRYPTION_KEY:'configured'} as Env;
 vi.stubGlobal('fetch',vi.fn().mockResolvedValue(new Response(JSON.stringify({reason:'DeviceTokenNotForTopic'}),{status:400})));
 expect(await sendAPNs(env,'test','sandbox',{},new Date().toISOString())).toEqual({status:400,reason:'DeviceTokenNotForTopic'});
 vi.stubGlobal('fetch',vi.fn().mockResolvedValue(new Response(JSON.stringify({reason:'sensitive-untrusted-content'}),{status:400})));
 expect((await sendAPNs(env,'test','sandbox',{},new Date().toISOString())).reason).toBe('apns_400');
});
