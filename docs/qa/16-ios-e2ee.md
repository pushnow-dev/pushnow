# iOS account-bound encrypted notifications

## Implemented boundaries

- Native CryptoKit RFC 9180 authenticated HPKE P256/HKDF-SHA256/AES256-GCM; exact wire expiry strings preserved in AAD.
- Device keys, pinned identity and account identity private key stored in a shared Keychain access group with `AfterFirstUnlockThisDeviceOnly` accessibility. Main app and embedded Notification Service Extension declare the same group.
- First installation initializes the account identity; additional installations remain pending until fingerprint approval. Approval transfers the account signing key inside HPKE Base encryption, checks its public identity and device certificate before activation.
- Re-enrollment of a revoked installation creates a fresh installation key and ID, retains established identity pin, and requires approval. Only an explicitly provisional identity from a failed first initialization can be discarded after another device wins initialization.
- Single-flight enrollment per AuthService prevents local registration challenge races. Registration proof includes a server-issued single-use challenge.
- Account/device list identifies the current installation, supports rename, notification preference and revocation. New source creation defaults to encrypted sender configuration export as JSON using ShareLink.
- Encrypted inbox messages are decrypted locally; invalid ciphertext fails visibly. Existing legacy inbox data remains readable and is not retroactively encrypted. The sender supplies encrypted content plus public `scheduled_at` metadata; the backend dispatches the scheduled ciphertext. The legacy in-app reminder editor is not used for encrypted messages.
- Logout clears local authentication and extension active account before sending logout to the server. Auth epoch checks reject stale login, refresh, profile, enrollment, approval, source export and inbox completions.
- The notification extension starts from a generic alert, checks account, device, source certificate, HPKE authentication and expiry, then atomically claims the message ID in Keychain before displaying plaintext. Duplicate or invalid delivery keeps generic text. It does not fetch external URLs.
- New device-management/error/notification texts have English, Simplified Chinese, Japanese, Korean, Spanish and German localizations. Extension includes the shared string catalog.

## Local verification

- Xcode Simulator build succeeded with the embedded extension. Unsigned builds cannot validate shared Keychain access (`errSecMissingEntitlement`); use the signed/ad-hoc Simulator build.
- Actual iPhone 16 Pro / iOS 18.4 runtime connected to an isolated Miniflare API on localhost using a synthetic account.
- Real UI enrollment created an active device, displayed its device and account fingerprints, and marked it current.
- Real UI rename changed the device name to `QAiPhone`; the backend agent independently verified the saved name through API readback.
- Real UI notification toggle changed to disabled; independent API readback confirmed `notifications_enabled: false` without revocation.
- Debug-only localhost configuration/session injection is scoped to `localhost`/`127.0.0.1` and is excluded from Release builds. No test credential is included in this repository.
- Serial XCTest execution on the same iPhone 16 Pro / iOS 18.4 passed all 8 tests, including 3 delayed-response regressions proving refresh, profile load and password login cannot restore a logged-out session, and concurrent expired-token requests sharing one refresh while preserving the auth epoch. Log: `/tmp/pushnow-e2ee-refresh-tests.log`. Initial parallel runner was interrupted due to slow Simulator startup; the clean serial run completed successfully.
- Actual UI created `EncryptedQA`, signed and registered its sender key, and exported a JSON configuration via ShareLink to local Simulator Files. The CLI used this exact exported configuration, explicitly targeted the notifications-disabled device, and submitted message `2aa6849a-f1bb-4fec-9d50-71867a412d60`. The running iOS inbox displayed decrypted title `Encrypted delivery verified` and body `Only this approved device can decrypt this local QA message.`
- Screenshots: `docs/qa/evidence/e2ee/devices-disabled-zh.png` and `docs/qa/evidence/e2ee/inbox-decrypted-zh.png`. Synthetic sender credentials are not included in screenshots or repository files.
- Final secure detail uses an independent view showing verified title/body and acknowledgment, without the legacy template report/reminder text. Final signed Simulator build succeeded (`/tmp/pushnow-e2ee-detail-final.log`). Its final visual reopen was not verified: the debug-only in-memory session fixture had already rotated its refresh token and was not renewed before the final reinstall. This does not invalidate the earlier actual inbox decryption evidence; production session refresh persists through the Keychain session store and passed the concurrent-refresh regression.
- All new Swift files remain below 250 lines. `AuthService.swift` is approximately 258 lines, within the 300-line service limit; it retains one session-lifecycle responsibility while API request/response models were moved to `AuthAPIModels.swift`.

## Remaining external acceptance

- Signed physical-device APNs delivery, extension execution under lock and timeout, and recipient-visible notification delivery require an APNs-enabled build and backend APNs secrets. Simulator build or API acceptance is not evidence of these.
- Two physical device pairing and recipient-visible APNs notification presentation still require physical-device validation. Exported sender configuration and encrypted inbox presentation were verified locally as above.
- Account-root sharing grants every approved device authority to approve future devices. No Signal-style ratchet, post-compromise security or forward secrecy claim is made.
- Device revocation cannot retract plaintext already displayed or erase keys from a compromised device. Atomic notification replay receipts currently persist for the installation lifetime.
