# Account browser authorization verification

Date: 2026-09-13

## Result

`AccountFlowUITests/testAutomaticAccountSender` passed on **iPhone 16 Pro, iOS 18.4** (38EEDBF7-0D38-4496-A62C-1D5CA5D8CCD2), 1 test / 0 failures, 35.908 seconds. The app logged into a disposable loopback fixture with email/password, initialized its local secure identity/archive, automatically approved the same-account browser request, and the TypeScript SDK finished authorization with one recognized phone. No short code, fingerprint, or approval button was used.

The fixture uses the real backend routes, D1, R2, and captured email transport. This is local end-to-end evidence, not an installed customer-device upgrade or production delivery claim.

## Encrypted delivery acceptance

Using the already authorized SDK fixture (without resetting the account), sent message `9ae530fe-b060-49ed-bbc2-772a159d580a`. The iOS 18.4 Home list visibly decrypted its title **Automatic browser encryption verified** and body **Private SDK message body**. Opening the row showed the same full plaintext in the detail page. CUA accessibility and screenshots confirmed recipient-visible content, beyond the API acceptance response.

- `evidence/account-auto/ios18-decrypted-inbox.png`
- `evidence/account-auto/ios18-decrypted-detail.png`

## Evidence

- `evidence/account-auto/ios18-automatic-test.log`
- `evidence/account-auto/ios18-authorized.png`
- Result bundle: `/tmp/pushnow-account-auth-build/Logs/Test/Test-JiZhi-2026.09.13_12-15-36-+0800.xcresult`
- Backend focused test: `npm test -- --run test/v2-integration.test.ts -t 'automates only'` — 1 passed, 4 skipped; account binding, cross-account lookup/approval rejection, and grant consumption tested against D1.
- SDK `npm run build` and backend TypeScript check passed.

## Simulator signing requirement

The first simulator artifact was built with `CODE_SIGNING_ALLOWED=NO`. It launched but password sign-in showed `Secure storage is unavailable`. Rebuilding for the same iOS 18.4 simulator with `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- ONLY_ACTIVE_ARCH=YES` restored the app's simulated signing entitlements and passed the full flow. No Keychain or encryption logic was weakened.

The simulator test runner initially reused its old installed test binary after incremental compilation; reinstalling only the generated test runner refreshed it. The successful run used the updated password-login fixture test.

## Reproduction

1. Run `node test/simulator-server.mjs` with working directory `backend`.
2. Build for testing with Xcode using the iOS 18.4 device above, `-jobs 2`, `ONLY_ACTIVE_ARCH=YES`, and ad hoc simulator signing.
3. Run only `JiZhiUITests/AccountFlowUITests/testAutomaticAccountSender`. Its setup creates the disposable local account through captured verification mail before signing in on the phone.

The test fixture remains on port 8799 for browser QA. Do not expose its `/__qa/` endpoints publicly.

## Release limitation

The production app must include the new foreground account-request monitor before automatic first connection works. Existing installed apps do not process these requests. An upgraded trusted phone must be online with the app open for first authorization; afterward the browser retains its own sender credentials. No phone private key is exported to the browser or server.
