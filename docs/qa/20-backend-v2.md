# Account archive v2 backend

## Scope and files

Implemented additive migration `backend/migrations/0006_account_archive.sql` and split modules `v2-archive.ts`, `v2-authorizations.ts`, `v2-attachments.ts`, `v2-message-store.ts`, `v2-messages.ts`, `v2-delivery.ts`, `v2-routes.ts`. `index.ts` routes v2 and schedules delivery, orphan cleanup and authorization expiry. `wrangler.jsonc` binds private `SECURE_BLOBS` to `pushnow-secure-blobs`. Tests live in `backend/test/v2-integration.test.ts`.

Existing v1 data, applied migrations 0001-0005, routing, APNs and concurrent Harmony push code were preserved. No production migration, Worker deployment or secret mutation was performed for v2 by this subtask.

## Behavior

- An active cryptographically bound device initializes an immutable account archive key with an identity certificate. P256 points are imported and validated. Archive grants are account-scoped, approved-target-only and readable only by the target installation.
- Sender authorization uses an opaque random device code stored only as a hash, an eight-character human code, ten-minute expiry, per-IP/per-user limits and a three-second poll interval. Approval requires a same-account source with the exact requester public key. Grant ciphertext is consumed and erased once. Source logout and account sender management revoke credentials; delivery checks source status again.
- R2 stores opaque ciphertext under random object keys. Attachment reservations enforce 20 MiB per blob and an atomic 100 MiB account attachment-ciphertext quota, including pending reservations. This is an attachment quota, not a claim that all D1 manifest storage is capped at 100 MiB. Full message ciphertext is separately limited to 256 KiB and daily send quota applies.
- Attachment upload enforces the actual byte count, cannot overwrite committed ciphertext, and permits exact-content retry. A source cannot upload another source's reservation. A hashed attachment capability grants access only to that single committed blob with a live parent message; it grants no listing or account access. Capability values exist only in encrypted client content and source requests, never in stored plaintext.
- Message ingest verifies archive ownership, attachment ownership/readiness and notification targets. Missing targets select active notification-enabled devices; explicit empty targets retain account history without push. Disabled devices never receive a push, but all active account devices can read shared retained history.
- Idempotency and daily quota are transactional with message, attachment commitment and delivery creation. The source public key/certificate are snapshotted per message. Full body and attachment secrets are never placed in notification payloads.
- History has cursor pagination and shared read state. Deletion is idempotent for an owned ID, clears manifest/preview ciphertext, cancels delivery, frees attachment quota once, persists a tombstone and queues physical R2 deletion. Capability access stops immediately at the tombstone even if physical R2 deletion needs retry. Deleted message IDs cannot be resurrected by ingest retry.
- Message history has indefinite retention. The 30-day push retry horizon does not delete v2 history. A separate paginated deletion feed supports offline cache removal.
- APNs/Harmony dispatch sends only the v2 encrypted preview, checks final payload size and rechecks device/account/source/session status. Ingest triggers background dispatch and cron supplies retries. Queue/API/APNs success does not establish device-visible receipt.

## Validation evidence

- TypeScript `npm run check`: passed after the final changes.
- First isolated `npx vitest run test/v2-integration.test.ts`: 3 tests passed using real local Miniflare D1 and R2, through actual `archiveRoute` HTTP request/response handling. These covered account/device isolation, archive grants, retained history, source authorization, attachment reserve/upload/capability download, committed overwrite rejection, shared read state, cursor pagination, idempotency, deletion/tombstones, storage release, source revocation and orphan cleanup.
- Additional checks were then added for a correctly signed invalid P256 point, concurrent six-file quota reservations, foreign notification targets, wrong capability and revoked-source delivery suppression.
- An initial parallel full-suite attempt timed out in both Miniflare setup hooks under machine overload. The coordinator then ran `npm test -- --maxWorkers=1 --fileParallelism=false`: all 6 suites and 25 tests passed in 51.10 seconds, including the latest negative cases. No further test rerun was needed.

## Runtime limits and remaining verification

- A process crash while an upload is marked `uploading` leaves that reservation unavailable until the 24-hour orphan cleanup. Caught upload failures reset the reservation immediately. A future upload lease protocol could improve crash recovery; a new attachment ID can currently retry within remaining quota.
- The 100 MiB quota covers attachment ciphertext reservations. D1 manifest capacity relies on the 256 KiB per-message limit and daily message quota, with no silent history purge.
- R2 deletion retries are durable but not synchronous guarantees when the storage service is unavailable. API access is denied immediately after message deletion.
- Root/CLI/iOS integration should verify actual HPKE grants, full-message decryption, attachment hash verification and rich notification rendering. Backend tests intentionally treat encrypted payloads as opaque and cannot establish these client-side properties.
- Production migration 0006 and deployment require coordinator review. Signed iOS/Harmony device notification delivery remains separate acceptance evidence.

## Disposable Simulator fixture

- Launch from `backend/`: `node scripts/local-secure-fixture.mjs`. It binds only `http://127.0.0.1:8799`, builds the current Worker, creates fresh local D1/R2, applies all local migrations, and performs a normal password login for the fixed disposable test account documented in that script.
- Private Simulator login snapshot: `/tmp/pushnow-secure-qa-session.json`, mode 0600. Refresh it after token rotation with `node scripts/refresh-local-fixture.mjs`; this performs another normal localhost-only login and does not print tokens.
- No device identity, archive private key, source key or message is injected. The App enrolls and initializes archive keys through real APIs, approves the CLI code, and receives actual CLI-encrypted content and attachments.
- Fixture instance started for this QA: PID `78239`, execution session `88708`. Coordinator owns shutdown after iOS/CLI acceptance. These identifiers are temporary and cease to apply after the process stops. This server never loads production credentials, resources or email/APNs bindings.
