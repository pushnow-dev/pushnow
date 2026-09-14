import {afterAll,beforeAll,expect,it,vi} from 'vitest';
import {Miniflare,convertV4MiniflareOptions} from 'miniflare';
import {readFileSync,readdirSync} from 'node:fs';
import {SenderAbuseGuard} from '../src/sender-abuse';
const mf=new Miniflare(convertV4MiniflareOptions({name:'abuse',modules:true,script:'export default{fetch(){return new Response("ok")}}',d1Databases:['DB'],compatibilityDate:'2026-09-12'}));
let db:D1Database;
const start=Date.parse('2026-09-13T10:00:00Z');
async function owner(){
 const user=crypto.randomUUID(),key=crypto.randomUUID(),source=crypto.randomUUID(),now=new Date(start).toISOString();
 await db.prepare('INSERT INTO users(id,email,email_hash,email_verified_at,created_at,updated_at) VALUES (?,?,?,?,?,?)').bind(user,`${user}@example.com`,user,now,now,now).run();
 await db.prepare("INSERT INTO sources(id,user_id,name,source_type,status,created_at,updated_at) VALUES (?,?,'test','custom','active',?,?)").bind(source,user,now,now).run();
 await db.prepare("INSERT INTO source_keys(id,source_id,user_id,key_prefix,key_hash,scopes,created_at) VALUES (?,?,?,?,?,'[]',?)").bind(key,source,user,key,key,now).run();
 return {user,key};
}
beforeAll(async()=>{
 db=await mf.getD1Database('DB') as unknown as D1Database;
 for(const file of readdirSync(new URL('../migrations/',import.meta.url)).filter(f=>f.endsWith('.sql')).sort())
  for(const sql of readFileSync(new URL(`../migrations/${file}`,import.meta.url),'utf8').split(';').map(s=>s.trim()).filter(Boolean))await db.prepare(sql).run();
},60000);
afterAll(()=>mf.dispose(),60000);
it('atomically allows 60 requests then pauses once; retries do not extend pause',async()=>{
 const {user,key}=await owner();let time=start;const guard=new SenderAbuseGuard(db,{},()=>time);
 const results=await Promise.all(Array.from({length:75},()=>guard.checkKey(user,key)));
 expect(results.filter(x=>!x.suspendedUntil)).toHaveLength(60);
 expect(results.filter(x=>x.newlySuspended)).toHaveLength(1);
 expect((await db.prepare('SELECT id FROM sender_security_mail WHERE user_id=?').bind(user).all()).results).toHaveLength(1);
 await expect(guard.assertKeyActive(user,key)).rejects.toMatchObject({status:429,retryAfterSeconds:900});
 time+=60000;expect(await guard.checkKey(user,key)).toEqual({suspendedUntil:start+900000,newlySuspended:false});
 time=start+900000;await expect(guard.assertKeyActive(user,key)).resolves.toBeUndefined();
 expect((await guard.checkKey(user,key)).newlySuspended).toBe(false);
},30000);
it('atomically caps all account notifications at 20 per rolling minute',async()=>{
 const {user}=await owner(),other=await owner();let time=start;const guard=new SenderAbuseGuard(db,{},()=>time);
 expect((await Promise.all(Array.from({length:35},()=>guard.reserveUserNotification(user)))).filter(Boolean)).toHaveLength(20);
 expect(await guard.reserveUserNotification(other.user)).toBe(true);
 time+=59999;expect(await guard.reserveUserNotification(user)).toBe(false);
 time++;expect(await guard.reserveUserNotification(user)).toBe(true);
});
it('caps mail at one per rolling hour and three per rolling day, despite concurrency',async()=>{
 const {user}=await owner();let time=start;const guard=new SenderAbuseGuard(db,{},()=>time);
 expect((await Promise.all(Array.from({length:20},()=>guard.reserveSecurityEmail(user)))).filter(Boolean)).toHaveLength(1);
 time+=3599999;expect(await guard.reserveSecurityEmail(user)).toBe(false);
 time++;expect(await guard.reserveSecurityEmail(user)).toBe(true);
 time+=3600000;expect(await guard.reserveSecurityEmail(user)).toBe(true);
 time+=3600000;expect(await guard.reserveSecurityEmail(user)).toBe(false);
 time=start+86400000;expect(await guard.reserveSecurityEmail(user)).toBe(true);
});
it('durably retries failed email without keys, duplicate jobs, or concurrent sends',async()=>{
 const {user,key}=await owner();let time=start;const guard=new SenderAbuseGuard(db,{SENDER_KEY_REQUESTS_PER_MINUTE:'1'},()=>time);
 await db.prepare('UPDATE sender_security_mail SET sent_at=? WHERE sent_at IS NULL').bind(start).run();
 const send=vi.fn().mockRejectedValueOnce(new Error('provider')).mockResolvedValue({messageId:'ok'});
 const env={DB:db,EMAIL:{send},AUTH_EMAIL_FROM:'PushNow <login@pushnow.dev>'} as unknown as Env;
 await guard.checkKey(user,key);
 expect((await Promise.all(Array.from({length:10},()=>guard.checkKey(user,key)))).filter(x=>x.newlySuspended)).toHaveLength(1);
 expect((await db.prepare('SELECT id FROM sender_security_mail WHERE user_id=?').bind(user).all()).results).toHaveLength(1);
 await guard.deliverSecurityEmails(env);expect(send).toHaveBeenCalledTimes(1);
 expect(await db.prepare('SELECT sent_at,attempts FROM sender_security_mail WHERE user_id=?').bind(user).first()).toMatchObject({sent_at:null,attempts:1});
 await guard.deliverSecurityEmails(env);expect(send).toHaveBeenCalledTimes(1);
 time+=3600000;await Promise.all([guard.deliverSecurityEmails(env),guard.deliverSecurityEmails(env)]);
 expect(send).toHaveBeenCalledTimes(2);
 expect(await db.prepare('SELECT sent_at,attempts FROM sender_security_mail WHERE user_id=?').bind(user).first()).toMatchObject({sent_at:time,attempts:2});
 const content=JSON.stringify(send.mock.calls[1][0]);expect(content).not.toContain(key);expect(content).not.toContain('ciphertext');expect(content).toContain('https://pushnow.dev/dashboard/');
});

it('rolls back the suspension and email reservation if outbox insertion fails',async()=>{
 const {user,key}=await owner(),guard=new SenderAbuseGuard(db,{SENDER_KEY_REQUESTS_PER_MINUTE:'1'},()=>start);
 await guard.checkKey(user,key);
 await db.prepare("CREATE TRIGGER fail_security_mail BEFORE INSERT ON sender_security_mail BEGIN SELECT RAISE(ABORT, 'simulated_outbox_failure'); END").run();
 try {
  await expect(guard.checkKey(user,key)).rejects.toThrow('simulated_outbox_failure');
  expect(await db.prepare('SELECT key_id FROM sender_security_state WHERE key_id=?').bind(key).first()).toBeNull();
  expect((await db.prepare("SELECT id FROM sender_security_events WHERE user_id=? AND kind='email'").bind(user).all()).results).toHaveLength(0);
  expect((await db.prepare("SELECT id FROM sender_security_events WHERE key_id=? AND kind='key_request'").bind(key).all()).results).toHaveLength(1);
 } finally { await db.prepare('DROP TRIGGER fail_security_mail').run(); }
 expect((await guard.checkKey(user,key)).newlySuspended).toBe(true);
 expect((await db.prepare('SELECT id FROM sender_security_mail WHERE user_id=?').bind(user).all()).results).toHaveLength(1);
});
