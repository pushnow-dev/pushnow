# Encrypted API integration result

Date: 2026-09-12. Command from repository root: `node cli/test/api-interop.js`.

Result: exit 0; all six integration groups passed.

The executable bundles the actual `backend/src/index.ts` Worker with the backend's installed esbuild, starts an ephemeral Miniflare D1 database, applies all SQL migrations and dispatches HTTP requests through the real handler. Node sender uses the real CLI recipients/prepare/submit/HPKE functions. Temporary users, hashed session tokens and source credentials exist only in this disposable fixture; no production bindings are loaded and credentials are not printed. Runtime is disposed in `finally`.

Verified:

1. Invalid bearer rejected; device registration challenge is session-bound and cannot be reused. First signed device becomes active.
2. Second device starts pending and cannot fetch messages; first device certifies it and uploads an encrypted identity package. Only the bound second device fetches the package and its HPKE recipient decrypts the intended identity secret.
3. CLI checks the real snake_case directory and submits two independently encrypted envelopes through actual routes. Both bound sessions fetch only their envelope and decrypt the same private content; the other device private key fails. Repeating the exact HTTP ingest is idempotent.
4. Foreign account cannot rename the first account's device or fetch messages without its own registration. Renaming preserves usable identity; disabling phone two makes default CLI targeting select only phone one.
5. An unregistered recipient is refused. Opaque tables contain no test plaintext title and the legacy items table remains empty.
6. Logout rejects phone one's subsequent inbox fetch, while phone two remains authenticated and can still fetch its envelope.

This is JavaScript sender-to-Worker HTTP and JavaScript receiver integration, not the separate native Swift cryptographic interoperability test. It does not exercise password/email login because authenticated sessions are seeded, does not invoke cron/APNs, and does not prove device-visible delivery. Native crypto, auth race tests and Simulator evidence are reported separately.

An initial run exposed a random leading-zero scalar length issue in the shared test fixture; its owner fixed scalar padding. The harness also normalizes fixture scalars. The successful run above occurred after the harness normalization; this does not imply production key generation was faulty.
