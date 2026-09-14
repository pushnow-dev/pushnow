# E2EE implementation security review

Date: 2026-09-12. Scope: secure backend routes, iOS encryption/device/notification services and Node sender against `docs/engineering/16-e2ee-contract.md`. Read-only implementation review while other agents were editing. Locations describe the inspected snapshot and may move. Findings were sent immediately to coordinator; fixes require readback and targeted tests before closing.

## Findings

### Final coordinator verification

All findings below are historical descriptions of issues found and corrected during
implementation. No original P1/P2 finding remains open in the reviewed source.
The native serial XCTest run completed with `TEST SUCCEEDED`: 8 tests passed,
including delayed current-user, password-login and refresh responses returning
after logout and concurrent expired-token callers sharing one refresh request
(4 authentication tests, 0 failures). Evidence:
`/tmp/pushnow-e2ee-refresh-tests.log` and
`/tmp/pushnow-e2ee-signed/Logs/Test/Test-JiZhi-2026.09.12_21-23-36-+0800.xcresult`.
Backend/HTTP/CLI results are recorded in their companion QA reports. Native
enrollment race handling was source-reviewed; real physical-device APNs and
extension concurrency still require separate acceptance. This is an engineering
review, not an independent third-party cryptographic audit.

### Follow-up readback status

The coordinator requested a second source review after fixes. All five original findings below have implementation fixes in the current source; closure here means source-readback only, not an independently executed regression test.

- Enrollment/approval: `SecureDeviceService` now captures `auth.generation` and checks account/generation after each relevant request before activation. `SecureInbox` checks generation, user and active device after fetch. `AuthService.logout` now clears the local session before awaiting network. Both the enrollment continuation and auth-response races have source fixes; the auth-response regression tests passed as recorded above.
- Token DTO: `RegisterAPNsTokenRequest` now only includes token, environment and appVersion, matching backend fields.
- Replay: `SecureKeyStore.claimNotification` uses a separate Keychain item per account/device/message and atomic `SecItemAdd`; duplicate-item means refusal. NotificationService uses this claim before rendering. Entries currently have no cleanup; that is a retention/size consideration, not the original concurrent replay defect.
- APNs errors: `sendAPNs` parses an allowlisted reason; delivery deletes tokens only for `Unregistered` or `BadDeviceToken`.
- Payload size: ingestion constructs the complete shared `securePayload` and rejects serialized payloads over 4096 bytes before insertion.
- Registration: the API issues a random session-bound challenge and atomically deletes it by session/hash/expiry before binding. `EmailAuthService.createSession` sets `deviceId: null`; untrusted login client metadata no longer confers device trust. The only secure binding is proof-verified registration. Exercise login with another approved device ID as a regression.
- Casing: route `readJsonBody` converts snake_case into camelCase recursively; `jsonResponse` normalizes snake_case; Swift decoder uses convertFromSnakeCase. Current secure request/response casing aligns at the inspected boundary.

### P1 source-fixed: Auth request completion can restore a session after logout

`JiZhi/Services/Auth/AuthService.swift:133` starts refresh and line 135 unconditionally applies its later response. Unlike the now-guarded enrollment code, the request does not snapshot/check generation. Logout can clear the session while refresh is suspended; the late response calls `apply`, creates a fresh generation and restores session/tokens. Subsequent automatic enrollment can activate the previous account again. `loadCurrentUser` similarly writes a captured request's user after suspension. Login/verification responses should also be guarded against superseding logout/account transitions.

Fix generation checks around the auth requests themselves, and clear the active encryption account when changing authenticated accounts. Verify a suspended refresh response delivered after logout cannot restore any session or trigger enrollment. This finding was sent immediately to the coordinator and remains open until implementation readback.

Final source readback: `AuthService` now captures/checks request generation around email verification, password login, password updates, refresh and current-user fetch. `apply` clears active encryption account before applying the changed session. Source issue closed; the coordinator's delayed-response regression tests were pending execution at this review update. This reviewer separately ran `cli/test/api-interop.js`, passing six real Worker HTTP/crypto integration groups, as recorded in `16-api-interop.md`; that harness does not substitute for the native auth race tests.

### P1: Completed enrollment can reactivate an account after logout

`JiZhi/Services/Devices/SecureDeviceService.swift:25` captures account and token before network suspensions. At line 58 it activates that captured account without checking whether logout or account switching occurred during the requests. Approval acceptance has the same pattern at lines 71-76. `AuthService.logout` clears active-account before awaiting the logout request, but a previously running enrollment can write it back afterward. The extension can then decrypt delayed old-account notifications despite logout.

Fix: invalidate a session generation synchronously when logout begins; snapshot it and check after network suspension before saving/activating keys. Bind generation checks to all approval/enrollment continuations, not just account ID (logout and re-login may use the same account). Regression: suspend register/approval response, logout, resume response, verify active-account remains unset.

Related: `JiZhi/Repositories/SecureInbox.swift:8` captures keys before fetch and decrypts/returns after the await without checking session generation. A completed old-account fetch can populate UI after a switch. Guard completion and the consuming repository/UI assignment.

### P1: iOS token binding request fails backend strict-field validation

`JiZhi/Services/Notifications/PushRegistrationService.swift:205` constructs a request including `platform`; the request type at line 246 encodes it. `backend/src/secure-push.ts:26` only permits token, environment and appVersion. Therefore normal iOS token registration is rejected even when all credentials and encryption are valid. Remove platform from this endpoint's DTO or explicitly support it consistently. Verify actual encoded iOS request against route, not only handcrafted backend test JSON.

### P2: Replay protection is a non-atomic shared dictionary update

`NotificationServiceExtension/NotificationService.swift:27` reads a Keychain dictionary and line 32 writes the whole dictionary. Concurrent extension executions can both observe an absent message ID and both render it. Different messages can overwrite each other's entries, permitting later replay before expiry. Keychain individual operations do not make this read/modify/write atomic.

Fix with an atomic claim per message (unique shared SQLite insertion or a Keychain add-only claim with duplicate-item rejection). Do not turn this into a process-local lock. Exercise simultaneous identical and different deliveries; distinguish notification presentation deduplication from repeated legitimate inbox reads.

### P2: Every APNs HTTP 400 deletes the device token

`backend/src/secure-delivery.ts:29` deletes token registration for status 400 as well as 410. `backend/src/secure-push.ts:64` discards the provider reason. A malformed payload or topic/priority configuration can receive 400 without indicating an invalid device token, so one failed message removes a working device from later delivery.

Parse provider reason and invalidate only explicit token-invalid cases; preserve token on payload/configuration errors and report actionable blocked/failed state. Verify 400 BadDeviceToken versus 400 BadTopic or PayloadEmpty behave differently. This is a delivery reliability bug, not content disclosure.

### P2: Ciphertext size acceptance does not guarantee APNs payload fits

`backend/src/secure-messages.ts:48` accepts up to 2400 decoded ciphertext bytes; Base64 alone needs 3200 bytes. IDs, public key, certificate, encapsulated key, timestamps, JSON property names and APS alert can bring the complete envelope above 4096 bytes. `secure-push.ts` checks only at dispatch and returns 413, leaving an API-accepted message blocked without a workable retry.

Validate complete notification payload size using shared construction before accepting, reduce a proven bound, or use authenticated opaque-ID fetch for larger envelopes. Test the exact maximum accepted ciphertext and all serialized metadata.

## Already coordinated separately

The first inspected `SecureDevices.register` used a static proof over user/device/key and had no challenge endpoint. This was corrected with session-bound, expiring, one-use challenges. Backend tests and the real-route CLI harness verified atomic consumption, different-session rejection and reuse rejection. Login-supplied device IDs no longer establish secure bindings.

## Confirmed design limits, not new defects

CLI validates the pinned account root, source certificate and each recipient certificate, and authenticated HPKE binds source identity and recipient/account/message metadata. It does not blindly accept replacement roots. Signed static certificates cannot establish revocation freshness against a malicious server replaying previously authorized device records; the contract acknowledges that limitation. The implementation is not Signal-style ratcheting and does not provide forward secrecy after device private-key compromise.

Backend account/device queries generally constrain ownership, and source owner comes from its credential. No parallel plaintext message insert was found in the secure ingestion path. APNs receives generic text and an encrypted envelope. These are source observations, not dynamic proof or a complete security audit.

## Validation performed

Read the files above plus `secure-routes`, `secure-validation`, `SecureCrypto`, `SecureKeyStore`, sender crypto/client/main and auth integration. The initial review was read-only. The reviewer subsequently implemented and ran the disposable HTTP interoperability harness (six passing groups); the coordinator read back the native test success above. Real APNs verification remains separate.
