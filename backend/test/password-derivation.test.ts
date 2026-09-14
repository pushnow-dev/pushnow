import { describe,it,expect } from 'vitest';
import { pbkdf2Sync } from 'node:crypto';
import { hashPassword,verifyPassword } from '../src/crypto';
describe('existing password hash compatibility',()=>{
 it('preserves the encoded PBKDF2 hash and validates existing accounts',async()=>{
  const password='Test-Password-981',salt='test-existing-salt',pepper='test-pepper';
  const expected=`pbkdf2_sha256$210000$${salt}$${pbkdf2Sync(`${password}.${pepper}`,salt,210000,32,'sha256').toString('base64url')}`;
  expect(await hashPassword(password,salt,pepper)).toBe(expected);
  expect(await verifyPassword(password,expected,pepper)).toBe(true);
  expect(await verifyPassword('wrong',expected,pepper)).toBe(false);
 },15000);
 it('rejects malformed or unbounded work factors before hashing',async()=>{
  for(const factor of ['NaN','Infinity','100000.5','99999','1000001'])expect(await verifyPassword('password',`pbkdf2_sha256$${factor}$salt$value`,'pepper')).toBe(false);
 });
});
