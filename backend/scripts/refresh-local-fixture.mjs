import { writeFileSync } from 'node:fs';
// Only the fixed disposable localhost account is supported by this QA helper.
const response=await fetch('http://127.0.0.1:8799/v1/auth/password/login',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({email:'secure-test@example.com',password:'LocalSecure2026'})});
if(!response.ok)throw new Error(`Fixture login failed: ${response.status}`);
const auth=await response.json();
writeFileSync('/tmp/pushnow-secure-qa-session.json',JSON.stringify({session:{userID:auth.user.id,email:auth.user.email,isVerified:true,hasPassword:true},accessToken:auth.access_token,refreshToken:auth.refresh_token}),{mode:0o600});
console.log('Local QA session snapshot refreshed; no credentials printed.');
