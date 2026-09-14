# Account browser connection and sender safety

## Scope

Web account sessions automatically start an account-bound browser sender request. The browser generates the agreement private key locally. An updated, signed-in trusted iPhone app automatically signs only requests returned by its account-scoped pending endpoint. The browser pins the account identity received through the authenticated service and verifies the resulting grant and recipient directory. Legacy CLI fingerprint verification remains available.

First connection requires an updated trusted phone running the app. Existing installed clients cannot perform the new automatic exchange. This is not an offline password-derived decryption or server-held account private-key design.

Browser configuration is retained in tab session storage and cleared at sign-out. Failed validation of a paused/revoked cached key does not silently create another key. Explicit reconnect and switching accounts are handled separately.

## Server enforcement

- More than 60 message requests per rolling minute pauses that key for 900 seconds.
- Paused requests receive 429 and Retry-After.
- Actual v1/v2 push transport attempts share a per-user rolling limit of 20 per minute, across keys and devices; excess deliveries remain queued.
- v2 delivery checks the original transport key, including revocation, expiration and suspension. Legacy v1 delivery conservatively delays a source while any associated key is paused.
- Security mail is queued durably and limited per account to one per rolling hour and three per rolling 24 hours, including bounded retry attempts.
- Key list exposes suspension deadline; existing account-scoped revoke remains available.

## Validation log

- Backend TypeScript check passed.
- Full backend regression: 95 passed; the 75-concurrent-request D1 test exceeded its original five-second timeout under concurrent Xcode load. Final focused sender-safety follow-up: 5 passed, including concurrent limits and atomic rollback on outbox failure.
- Account-scoped authorization regression passed: foreign-account lookup/approval rejection and own-account grant consumption.
- Key management regression: 4 passed.
- Web Astro check passed; final production build generated 127 pages after connection-race fixes.
- Browser computer-use connection became unavailable; no final browser click-through evidence claimed.
- iPhone 16 Pro (iOS 18.4): `AccountFlowUITests/testAutomaticAccountSender` passed in 35.908 seconds. Password login, trusted-phone automatic grant signing, SDK grant verification and discovery of one device passed without manual code/fingerprint entry. Unsigned simulator builds failed Keychain writes; ad-hoc signed simulator build passed without weakening storage. Log: `/tmp/pushnow-auto-signed18.log`. All further simulator operations are restricted to iOS 18.4.
- Follow-up encrypted send used the same automatically authorized SDK configuration. On iOS 18.4, the app home and message detail displayed the decrypted title and private message body. Native UI evidence: `evidence/account-auto/ios18-decrypted-inbox.png` and corresponding detail capture. This is separate from the passing automatic-authorization XCTest.
- Production D1 additive migrations 0008–0013 applied and read back with no pending migrations. Backend deployed as `9ac19129-16ff-4610-a624-956c15be53c0`; health returned 200 and unauthenticated account authorization returned 401.
- After the iOS 18.4 test passed, web deployed as `8675e083-d3b8-4e39-b798-315f3632a2f5`. Live dashboard and sender JS returned 200; automatic connection code and account endpoint were present, and the old fingerprint form was absent.
- Actual security-mail inbox delivery is unverified; durable queue and retry behavior are covered by tests.
