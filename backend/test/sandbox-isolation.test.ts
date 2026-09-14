import { describe,expect,it } from 'vitest';
import { readFileSync } from 'node:fs';
import { parseSubscriber } from '../src/revenuecat-client';
const read=(name:string)=>JSON.parse(readFileSync(new URL(`../${name}`,import.meta.url),'utf8'));
describe('deployed sandbox isolation',()=>{
 it('binds a separate database, private bucket, hostname and payment environment',()=>{
  const production=read('wrangler.jsonc'),sandbox=read('wrangler.sandbox.jsonc');
  expect(production.vars.REVENUECAT_ENVIRONMENT).toBe('PRODUCTION');
  expect(sandbox.vars.REVENUECAT_ENVIRONMENT).toBe('SANDBOX');
  expect(sandbox.name).not.toBe(production.name);
  expect(sandbox.d1_databases[0].database_id).not.toBe(production.d1_databases[0].database_id);
  expect(sandbox.r2_buckets[0].bucket_name).not.toBe(production.r2_buckets[0].bucket_name);
  expect(sandbox.routes).toEqual([{pattern:'sandbox-api.pushnow.dev',custom_domain:true}]);
 });
 it('never grants sandbox purchases in production, or paid production purchases in sandbox',()=>{
  const now=Date.now(),expires=new Date(now+60000).toISOString(),product='com.createitv.pushnow.plus.monthly';
  const body={request_date_ms:now,subscriber:{entitlements:{plus:{product_identifier:product,expires_date:expires}},subscriptions:{[product]:{store:'app_store',is_sandbox:true,expires_date:expires}}}};
  expect(parseSubscriber(body,'PRODUCTION',now).entitlements).toEqual([]);
  expect(parseSubscriber(body,'SANDBOX',now).entitlements[0]?.plan).toBe('plus');
  body.subscriber.subscriptions[product].is_sandbox=false;
  expect(parseSubscriber(body,'SANDBOX',now).entitlements).toEqual([]);
  expect(parseSubscriber(body,'PRODUCTION',now).entitlements[0]?.plan).toBe('plus');
 });
});
