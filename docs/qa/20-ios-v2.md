# iOS v2 encrypted history and sender authorization

## Implementation

- Production CryptoKit P256/HKDF-SHA256/AES256-GCM decrypts authenticated v2 message/preview envelopes and independently encrypted attachments. Source and archive certificates are verified against the pinned account identity. Attachment size, nonce, key length, AAD and SHA-256 are checked before rendering.
- The separate archive agreement private key is stored in the shared Keychain, not derived from the signing key. Provisional initialization is persisted before POST and reconciled against the immutable server record. Established pins are never silently replaced. Approved devices receive archive material in encrypted approval or explicit history grants.
- The default sender flow uses a one-time code, full sender fingerprint confirmation and a phone-visible account fingerprint for reciprocal CLI verification. Sender private keys remain on the sender. Existing v1 export code remains for compatibility, but is no longer the default entry.
- Shared v2 history is read in 50-record pages until complete. Read/deletion events update the visible list; deletion sync filters stale pages, purges temporary attachments and removes delivered notifications. Legacy v1 history remains readable only where its device private key is available. Automatic v1 re-encryption migration is NOT implemented.
- Native detail shows literal body text, safe HTTP(S) links, encrypted custom icons/images, native Markdown attachment rendering and QuickLook file/image previews. Foundation parses Markdown; headings, lists, code and inline styling are presented by small SwiftUI components. No remote HTML/JavaScript rendering is used.
- The notification extension accepts `secure_v2`, checks account/device/archive/source identity, atomically claims replay IDs and respects local tombstones. Images use a scoped attachment capability from the encrypted preview, a configured HTTPS API origin and no redirects. Login/refresh credentials are not shared with the extension. Validation failure stays generic; unavailable images do not disclose unverified bytes.
- Existing settings, six languages, device naming, appearance and About submenu remain. Unrelated concurrent brand changes were preserved.

## Verification

- Signed Simulator XCTest passed 22 tests in `/tmp/pushnow-v2-build.log`, including three new production-crypto tests for purpose/account binding, attachment tampering and archive grant binding.
- Subsequent Markdown Simulator build passed in `/tmp/pushnow-v2-markdown-build.log`.
- Two focused workflow tests passed in `/tmp/pushnow-v2-workflow-tests.log`: archive preparation before lookup, and native Markdown heading/list/link/code parsing. Together with the prior full run, 24 distinct XCTest cases passed.
- Real local Worker/D1/R2 fixture at `127.0.0.1:8799`, fresh non-production account, no production credentials. Device enrollment was performed by the app. Full account fingerprint was read from the Simulator UI and given to the real CLI verifier.
- The first lookup exposed an archive initialization dependency. Fixed lookup to ensure the archive before requesting authorization; continuing the installed build through its normal manual archive-sync control proved the remaining real authorization flow. A focused regression test covers preparation ordering.
- CLI code lookup, sender fingerprint comparison, explicit approval and reciprocal account fingerprint check succeeded. The CLI then sent an encrypted message with Markdown, image, icon and link. The Simulator actually displayed the decrypted content.
- Local QA message `0ff11c50-f61a-42d8-9313-b809581af4dc` was deleted through the UI. CLI confirmed old-message retries rejected and all three attachment capabilities returned 404. The old installed build retained a cached row until tab reload; an explicit history event fixes immediate removal in the final build.
- Final-build regression message `a57ae08f-cdd2-4e30-bb2d-21c040f3bb74` was opened and deleted through the UI. Returning to the inbox immediately showed no row, without manual refresh or tab navigation. The final build also waits for device enrollment before loading secure history and rechecks the auth epoch after final tombstone synchronization.
- The incremental signed physical-device build completed successfully in `/tmp/pushnow-v2-real-build.log`. Artifact: `/tmp/pushnow-v2-real/Build/Products/Debug-iphoneos/JiZhi.app`. The coordinator owns installation and physical notification acceptance.

## Visual Evidence

- `evidence/v2/sender-authorized.png`: approved sender listed.
- `evidence/v2/rich-detail.png`: decrypted icon, image, complete two-paragraph body, HTTP link and three attachments.
- `evidence/v2/markdown-rendered.png`: native heading and list rendering.
- `evidence/v2/image-preview.png`: actual authenticated image in QuickLook.
- `evidence/v2/deleted-inbox.png`: message absent after fresh history load.
- `evidence/v2/deleted-immediate-final.png`: final-build immediate deletion regression, no reload needed.

## Boundaries

No production migration/deployment or real-phone operation was performed by this agent. API acceptance and Simulator rendering do not establish APNs delivery, notification-extension execution on a locked physical phone, or a second physical device's history restoration. Those are separate coordinator-owned acceptance steps. Large Markdown parsing currently runs on the main actor; full history is paginated on the wire but accumulated in memory. These performance limits are not silent truncation or retention policies.

Native Markdown semantics reference: [Apple PresentationIntent](https://developer.apple.com/documentation/foundation/presentationintent).
