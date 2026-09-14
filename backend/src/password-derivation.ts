import { pbkdf2Async } from '@noble/hashes/pbkdf2.js';
import { sha256 } from '@noble/hashes/sha2.js';
// Workers native PBKDF2 rejects the existing 210,000-round hashes.
// Preserve the algorithm, work factor, salt encoding and pepper for existing users.
export function derivePassword(password:string,salt:string,pepper:string,iterations:number):Promise<Uint8Array> {
 const encoder=new TextEncoder();
 return pbkdf2Async(sha256,encoder.encode(`${password}.${pepper}`),encoder.encode(salt),{c:iterations,dkLen:32});
}
