# Multi-device encrypted notification readiness

Date: 2026-09-12. This change introduces an encrypted path; existing plaintext
history is not retroactively encrypted.

Later same-day follow-up: production was backed up, additive migration 0005 and
the current Worker were deployed, a separate push-token storage key was configured,
and the physical iPhone registered an encrypted sandbox push token. The historical
readback below describes the earlier implementation stage. Current evidence and
remaining APNs provider blockers are in `docs/qa/17-real-device-settings-push.md`.

## Design

Account login manages device ownership; each account/installation has an independent
P256 recipient private key. A pinned account signing identity certifies recipients
and sender public keys. Additional phones require trusted-device fingerprint
approval. Account signing material transfers only inside recipient-encrypted HPKE.

The sender uses RFC 9180 Auth HPKE (P256/HKDF-SHA256/AES256-GCM) separately for each
selected approved device. Worker/D1/APNs receive opaque ciphertext and necessary
device/account/timing metadata. Device names and notification preferences are
editable independently of key identity. Logout removes the installation's routing
token and bound sessions; revocation prevents future routing and enrollment under
the old device identity.

Telegram's ordinary multi-device Cloud Chats are not the E2EE model used here.
The decision and primary sources are in
`docs/engineering/16-e2ee-protocol-research.md`; exact wire/signature formats are in
`docs/engineering/16-e2ee-contract.md`.

## Local verification

- Backend typecheck, tests with real disposable D1, and Worker dry-run bundle.
- CLI negative-case cryptography tests and independent two-device encryption.
- Native CryptoKit/Node interoperability in both directions, including actual
  app decryption and encrypted device approval code.
- Full Worker HTTP/CLI two-device integration, including challenge replay,
  pending approval, foreign-account isolation, rename, notification preferences,
  opaque persistence, duplicate submission and one-device logout.
- Simulator-specific build, UI, Keychain and native race-test evidence is tracked
  in `docs/qa/16-ios-e2ee.md`. Do not infer real APNs receipt from these checks.
- Native serial XCTest: 8 passed, including 3 delayed authentication response
  regressions after logout and concurrent automatic refresh sharing one request;
  signed app and embedded extension built successfully.
- Backend: 18 tests passed, including expired-access logout using its valid refresh
  credential, device unbinding and rejection of mixed-session credentials.
- Actual Simulator UI exported a sender configuration, the CLI submitted a
  device-targeted encrypted message through the isolated API, and the app inbox
  displayed its exact decrypted title and body. Screenshot:
  `docs/qa/evidence/e2ee/inbox-decrypted-zh.png`. This was inbox delivery, not APNs.

Detailed reports: `docs/qa/16-backend-e2ee.md`,
`docs/qa/16-cli-encryption-validation.md`, `docs/qa/16-api-interop.md`, and
`docs/qa/16-e2ee-security-review.md`.

## Production readback and blockers

Read-only `npx wrangler secret list` against the configured `jizhi-api` worker
returned only `AUTH_TOKEN_PEPPER`. No secret values were read or printed.
The new push path still requires these production settings:

- `PUSH_TOKEN_ENCRYPTION_KEY`: separate random 32-byte Base64 storage key.
- `APNS_PRIVATE_KEY`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_TOPIC`: app-specific
  Apple provider credentials/configuration, never Bark's or another app's keys.

Migration `0004_secure_notifications.sql` and the new Worker have not been applied
or deployed to production in this task. Migration clears old unverified device
bindings; upgraded clients re-register with possession proofs. Production release
must coordinate this migration, Worker, app extension signing and client rollout.

`devicectl list devices` showed one connected iPhone 15 Pro, but no signed
two-physical-device APNs delivery/decryption acceptance was performed. These
settings and device-visible tests remain the boundary before claiming live push.
No production message, email, database migration, or external communication was
sent during this implementation.

## Security and product boundaries

- Static-key HPKE is not a Double Ratchet and does not claim forward secrecy,
  post-compromise recovery or post-quantum protection.
- Signed recipient certificates prevent a relay inventing new device keys, but
  revocation freshness/availability still depends on the backend. A formerly
  trusted device cannot be forced to forget already-received content.
- Losing every trusted device without a separately designed encrypted recovery
  backup loses the ability to approve devices/decrypt old content. Email reset
  never silently resets the account trust anchor.
- Encrypted message expiry is at most 30 days. The inbox currently exposes the
  newest 100 unexpired envelopes; pagination and encrypted attachment storage are
  not included. Notification expansion decrypts locally; private URL fetching is
  not automatic.
