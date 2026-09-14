# v2 integration acceptance

## Verified automated checks

- Backend: `npm test -- --maxWorkers=1 --fileParallelism=false`, 6 suites,
  25 tests passed. Real local D1/R2 includes isolation, grants, attachment quota,
  immutable uploads, deletion, capabilities and sender revocation.
- CLI: 10 tests passed. Actual macOS Keychain isolated CRUD passed.
- `node cli/test/v2-api-interop.js`: all four HTTP groups passed, including an
  encrypted archive transfer to a newly approved device and shared history.
- Node and native production CryptoKit v2 interoperability passed; v1 native
  interoperability also passed. No production credentials used in these tests.
- iPhone 16 Pro / iOS 18.4 Simulator: 22 native tests passed, zero failures.
  Result: `/tmp/pushnow-v2-sim/Logs/Test/Test-JiZhi-2026.09.12_23-04-00-+0800.xcresult`.
- Worker deployment dry run passed with D1 and private R2 bindings.
- Two focused iOS workflow tests passed after the UI review: archive preparation
  before authorization lookup, and native Markdown heading/list/link/code parsing.

## Infrastructure preparation

Private R2 bucket `pushnow-secure-blobs` was created in APAC; Wrangler readback
confirmed public access through r2.dev is disabled. Existing database
backup was downloaded to a private temporary directory before any v2 migration.
Migration audit reported only additive `0006_account_archive.sql` pending.
No user accounts or legacy records were reset for preparation.

## Runtime verification in progress

Simulator UI pairing, rich content and deletion were checked against the
disposable local fixture at port 8799. Sender and account fingerprints were
compared through the real approval UI. The CLI sent encrypted text, a link,
Markdown, image and icon. The app rendered each; deletion denied old-message
retry and all three attachment capabilities. Root visually reviewed
`evidence/v2/rich-detail.png` and `evidence/v2/markdown-rendered.png`.

The first installed build retained a stale row after deletion. The final installed
Simulator build passed immediate deletion without refresh or tab switching:
`evidence/v2/deleted-immediate-final.png`. Subsequent HTTP retry was rejected.
The first authorization lookup also required manual archive initialization;
automatic preparation is now implemented and covered by the focused test.
This local flow is not production or APNs evidence.
## Production and physical device

- Applied additive migration `0006_account_archive.sql`, 14 statements succeeded.
- Deployed Worker version `4bb8a768-a1ba-48af-bb6f-849043a352b8` to
  `https://api.pushnow.dev`, with the private R2 binding and existing cron.
- Online `/health` returned 200. Unauthenticated `/v2/messages`, `/v2/archive`
  and `/v2/senders` each returned 401 `missing_bearer_token`.
- Final signed device build succeeded at
  `/tmp/pushnow-v2-real/Build/Products/Debug-iphoneos/JiZhi.app`.
- `devicectl` successfully installed `com.createitv.pushnow` on the connected
  iPhone 15 Pro, device `863FF34A-1D38-5EBF-8C8A-4F3EBFF8A6DB`.
- Launch was denied with `FBSOpenApplicationErrorDomain` code 7, reason `Locked`.
  iPhone Mirroring repeatedly reported that the phone could not be found and
  requested recent unlock, proximity, Wi-Fi and Bluetooth. User action is needed.
- No production v2 sender was approved or v2 notification sent. The default CLI
  credential store remained unauthorized. Prior v1 key exports were not used to
  bypass the new pairing workflow. The earlier confirmed v1 notification is not
  evidence of v2 recipient-visible delivery.
- Disposable local fixture process 78239 was stopped after successful Simulator
  testing. No build or local test server is intentionally left running.

## Compatibility limits

Existing v1 per-device messages remain readable on their original trusted device.
Automatic trusted-client re-encryption of v1 history is not implemented; do not
claim that a newly approved device can read historical v1 ciphertext. New v2
messages use the shared account archive. Expired legacy data cannot be restored.

For protocol/security limits see
[21-v2-security-flow.md](../engineering/21-v2-security-flow.md).
