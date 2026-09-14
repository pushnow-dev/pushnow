# CLI and SDK v2

Implementation: account-archive Auth HPKE, separate full/preview encryption,
sender-generated key and once-code authorization, required account fingerprint
verification after encrypted grant receipt, OS credential storage, local AES-GCM
attachment encryption, HTTP upload, notification target selection and self-revoking
logout. Legacy `--config` sender behavior remains available.

Source modules are split across `cli/src/v2-{auth,http,crypto,client,command}.js`,
`credentials.js`, and public `sdk.js`. macOS uses `cli/native/keychain.swift` with
stdin/stdout credentials and no secret process arguments. Other platforms use
mode-600 file storage in a private directory. Tests do not touch real saved CLI
credentials or production resources.

## Validation results

- `cd cli && npm test`: final run exit 0, all 10 tests passed, including mandatory
  account-root verification and rejection when the expected fingerprint is wrong.
- `node cli/test/v2-api-interop.js`: coordinator's final run exit 0, all four HTTP
  groups passed using the real Worker handler, ephemeral D1 and R2. The initial
  test expected the wrong consumed-grant status; corrected to actual 401 before
  this successful rerun. No backend behavior was weakened for this assertion.
- `node cli/test/v2-interop.js`: exit 0, standalone Node/CryptoKit bidirectional
  message/preview and AES-GCM attachment checks passed; production `SecureV2Crypto`
  full/preview/archive/account validation and attachment tamper checks also passed.
- `node cli/test/keychain-interop.js`: exit 0, actual macOS Keychain write, update,
  read and delete passed in a random test service namespace. Existing CLI credential
  service was not touched. Disposable item and test binary removed afterward.
- `node cli/test/interop.js`: exit 0, retained v1 two-device bidirectional HPKE,
  production Swift decryption, approval transfer and invalid-message rejection.

## Coverage and limits

Tests ran sequentially to avoid competing with the iOS build. HTTP harness covers
phone-approved CLI grant, encrypted R2 upload and attachment capability, archive
message/preview decrypt, idempotency, foreign-account rejection, a new device's
encrypted identity/archive transfer and history, shared read/delete state,
tombstone protection, deleted capability denial, and sender logout revocation.

The native compiler initially stalled under Rosetta. The shared native invocation
helper now detects Apple Silicon independently of Node's translated architecture
and invokes Swift natively through `arch -arm64`; native tests then completed.
No APNs delivery or recipient-visible app behavior is claimed by CLI test results.

## Trust boundary

The phone compares the CLI's public-key fingerprint, and the CLI compares the
account identity fingerprint with the trusted phone. Both are required against
an active relay: an HPKE Base grant alone is not authenticated. SDK `finishLogin`
requires `expectedIdentityFingerprint` or a user-verifying `confirmIdentity`
callback and will not silently save/return an unknown root. The account archive
key is static; no ratcheting forward-secrecy claim is made.

## Live Simulator authorization

The iOS QA agent read the full account fingerprint from the Simulator Devices UI.
`cli/test/live-simulator-qa.js` issued a new code and sender key; the agent compared
the complete sender fingerprint on the phone and approved it in the sender screen.
The SDK consumed the encrypted grant only after matching the separately supplied
phone account fingerprint. Login exited 0. This exercised the actual phone UI and
localhost:8799 authorization routes, not direct private-key injection.

Credentials used only `/tmp/pushnow-qa-v2-live` private QA storage. No default CLI
Keychain credential was read or overwritten. The same SDK then uploaded encrypted
Markdown, image and icon attachments, and submitted text plus a link in message
`0ff11c50-f61a-42d8-9313-b809581af4dc`. Send exited 0. The iOS QA agent subsequently
verified actual Simulator rendering: custom inbox icon, complete two-paragraph
body, link and three attachments; Markdown title/list and PNG QuickLook image both
opened successfully. Native evidence is in [20-ios-v2.md](20-ios-v2.md) and
`evidence/v2/`; after refresh the deleted inbox was also confirmed empty in
`evidence/v2/deleted-inbox.png`.

The agent then deleted this exact message through the UI. Running
`node cli/test/live-simulator-qa.js check-deleted /tmp/pushnow-qa-v2-live` exited 0:
the original encrypted outbox retry was rejected (409/410 assertion), and all three
attachment capabilities returned 404. This verifies persisted deletion protection,
not just dismissal of the detail screen.

The initial installed build retained a cached inbox row until refresh. The iOS
agent added read/delete change notifications and installed the final build. A fresh
text message `a57ae08f-cdd2-4e30-bb2d-21c040f3bb74` was sent through the same isolated
SDK authorization, then deleted through the UI. The inbox became empty immediately,
without refresh or tab switching (`evidence/v2/deleted-immediate-final.png`).
`check-text-deleted` then exited 0: retrying this final encrypted outbox was refused.
The original cached-row finding is therefore closed with both UI and HTTP evidence.
This local QA does not claim APNs notification delivery or production deployment.
