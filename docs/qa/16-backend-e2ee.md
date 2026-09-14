# Secure notification backend verification

## Implemented

- Migration `0004_secure_notifications.sql`: immutable account identity, certified devices and sources, encrypted APNs tokens, opaque messages and delivery records. Migration clears historical unverified session device IDs. Additive migration `0005_secure_enrollment_quota.sql` adds session-bound enrollment challenges and the transactional quota guard without changing existing bindings.
- Enrollment requires a login, fresh five-minute one-use challenge and P256 proof. Login-supplied device IDs never establish a secure binding. First device initializes the account identity; subsequent devices remain pending until a trusted installation approves their certificate and encrypted identity transfer.
- Device rename and notification preferences are account-scoped. Revoke removes push tokens and revokes all bound sessions. Logout removes the current installation token and revokes its sessions without revoking the certificate, allowing later authenticated proof-based login. The logout endpoint alone accepts an active refresh token when access has expired; mixed credentials from different sessions are rejected, and expired/revoked refresh tokens cannot authenticate.
- Source public keys and certificates are immutable. Enabling encryption blocks the plaintext ingest endpoint. Source credentials determine the account; requests cannot choose a foreign account or unapproved target.
- Per-device ciphertext storage is atomic with idempotency and notification quota consumption. Duplicate IDs with different content fail. Quota failures roll back all envelopes and the usage increment. Secure messages never populate plaintext item/content-block tables.
- Final APNs payload size is checked before ingest. Streaming JSON limits apply even without Content-Length: 128 KiB for encrypted ingest, 64 KiB otherwise.
- Inbox returns only the cryptographically registered current device's envelopes; receipt acknowledgement suppresses future delivery but preserves unexpired inbox access.
- Ingest schedules immediate background dispatch; one-minute cron supplies retry safety. Both claim bounded leased batches, recheck account/source/device/session authorization, and send generic alerts plus the opaque envelope. States distinguish blocked, retry, suppressed, failed, APNs accepted, and device acknowledged. Missing tokens retry as blocked; disabled/revoked/expired recipients suppress push. Only explicit invalid-device reasons invalidate APNs tokens.
- Cron deletes at most 100 expired messages and their ciphertext envelopes per run, transactionally. Message expiry is at most 30 days after ingest; expiration immediately excludes inbox/delivery access, and storage cleanup follows in bounded batches. Aggregate quota counters do not contain message content.

## Validation

- `npm run check`: passed.
- `npm test`: 5 suites, 19 tests passed, including actual local Miniflare D1 (not a SQL mock). The 0004-to-0005 upgrade preserves existing bound sessions and ciphertext while enforcing the new quota constraint.
- D1 cases cover first/subsequent enrollment, forged proof, replay across sessions, login device-ID spoofing, owner isolation, pending approval, rename preserving keys, per-device inboxes, token AAD binding, revoke/logout, encrypted-source downgrade, foreign/pending message targets, concurrent idempotency, quota rollback, missing APNs configuration, and acknowledgement retention.
- HTTP cases cover bounded streaming input and APNs reason allowlisting.
- Disposable authenticated fixture: `cd backend && node scripts/local-secure-fixture.mjs`. Binds only `127.0.0.1:8799`, creates fresh local D1, and writes `/tmp/pushnow-secure-qa-session.json` with file mode 0600 for Simulator QA. Test credentials live only in the fixture script. No production resources, email sends or APNs credentials are loaded.

## Release prerequisites and limits

- Apply migrations through 0005 before deploying the new worker. Do not replay 0004 on an existing database.
- Set independent `PUSH_TOKEN_ENCRYPTION_KEY` (Base64 random 32 bytes), `APNS_PRIVATE_KEY` (Apple P8), `APNS_KEY_ID`, `APNS_TEAM_ID`, and `APNS_TOPIC` as worker secrets/config. Never put these in checked-in Wrangler vars. The storage key protects only routing tokens; it cannot decrypt message content. Rotate it with a token migration or force clients to re-register tokens.
- Signed physical-device APNs acceptance and device-visible decryption are not verified by local D1 tests or a successful worker bundle. Production schema/worker were subsequently updated as recorded below; no APNs/storage secrets were changed by this backend subtask.
- APNs is an at-least-once channel. A network disconnect after Apple accepts a request can cause retry duplicates; the client must deduplicate message IDs. Revocation cannot recall content already delivered, and an in-flight APNs request cannot be atomically canceled by a database update.
- The API returns at most the newest 100 unexpired envelopes per inbox response. Pagination remains future operational work. The protocol does not provide Signal-style ratcheting/forward secrecy; this backend only validates certificates and stores opaque HPKE data.

## Files

Backend additions: migrations 0004/0005; `secure-{validation,types,devices,messages,push,delivery,routes}.ts`; integration/HTTP tests; disposable fixture. Integration edits: auth session creation/logout route, plaintext source gate and store query, bounded JSON parser, cron trigger, development dependencies. Unrelated workspace changes were preserved.

## Production repair, 2026-09-12

- Read-only audit found deployed 0004 lacked the later enrollment challenge table and quota column. Legacy push-token records: 2, with 0 encrypted token values. Sources: 1 legacy, 0 secure. Secure devices/tokens: 0 each before repair. No token values were read or printed.
- Private pre-migration backup: `/tmp/pushnow-prod-before-17.gCR9MV/jizhi-production.sql` (17,675 bytes, directory 0700, file 0600). Treat this as private account data, not a shareable QA artifact.
- Verified only 0005 was pending, then applied only that additive migration. Existing legacy records and device/session bindings were not reset.
- Deployed Worker version `068b7de0-d9e6-4f12-9285-e46e6a1e2638`, including the one-minute cron trigger. `/health` returned 200/ok, `/readyz` returned 200/ready, and unauthenticated challenge access returned 401.
- Real-device enrollment, APNs credentials and recipient-visible notification verification remain separate follow-up evidence. Deployment health alone does not establish message delivery.
