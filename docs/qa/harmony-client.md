# HarmonyOS managed-device implementation and QA

Date: 2026-09-13

## Scope and architecture

The existing iOS code and v2 wire contract are the reference. Harmony is an account device alongside iOS, with platform-specific notification transport and the same cryptographic trust model. This task modifies Harmony app code, Huawei provider code/tests and workflow/integration documentation. It does not change iOS sources, deploy production, commit the worktree or submit an app release.

Boundaries:

- `AuthService` + `ApiClient`: verified email/password authentication, snake_case responses, secure session persistence, one refresh task, accepted token lineage within a session, account-generation checks and remote logout.
- `DeviceService` + `SecureDeviceEnrollmentService`: stable account device IDs, real device directory, signed challenge proof, pinned identity, pairing approval, metadata, notification settings and token binding. Old unscoped keys are vaulted and read back before plaintext cleanup; ownership and original device ID are restored using the authenticated directory.
- `SecureCrypto` + `SecureStorage`: P-256, SHA256, ECDSA raw64 certificates, RFC9180 base/auth HPKE, AES256-GCM and OS Asset credentials. Private material never falls back to Preferences.
- `SecureArchiveService` + `SenderAuthorizationService`: certified archive initialization with lost-response recovery, immutable archive validation, encrypted history grants, sender code lookup, explicit fingerprint confirmation and authorization grant.
- `InboxService` + `SecureAttachmentService`: v2 history/deletion pagination and local decryption, v1 compatibility, source/recipient verification, read/ack/delete operations and attachment integrity checks.
- `HarmonyModel`, five component panels and `Index`: actual UI actions and error/empty states, no demo fallback. Device revocation controls removed in favor of retained devices and notification settings. First-party/system foreground and notification-open events refresh authenticated history.

All app service files are at most 300 lines, components are below 80 lines, and the UI model is 212 lines. English is the development language with matching Simplified Chinese, Japanese, Korean, Spanish and German resource sets (82 added strings per locale). System appearance selects light/dark backgrounds; actual device rendering remains unverified.

## Executed checks

1. `bash harmony/scripts/build-debug.sh`: **BUILD SUCCESSFUL**, final build 2.963 seconds. DevEco SDK 6.1.1/API24. Existing deprecation and throwing-API lint warnings remain; no ArkTS compile errors. `No signingConfig found for product default` means the output is unsigned.
2. `node --test harmony/tests/*.test.mjs harmony/test/*.test.mjs`: **25 passed / 0 failed**.
   - Four cryptographic interoperability tests execute unchanged ArkTS crypto logic with Node adapters against independent HPKE/WebCrypto implementations: base grants in both directions, authenticated v1/v2 messages, certificate/AAD/ciphertext/key tampering and legacy DER import.
   - Four enrollment tests: snake_case directory/registration, pending root pinning/replacement rejection, vault-before-delete migration with original device ID and logout during challenge.
   - Five auth/session tests: real response parsing, token refresh lineage/single flight, logout during refresh, new login while old refresh is pending and local clearing when server logout fails.
   - Six archive/sender tests: lost-response recovery, archive substitution, transferred-key mismatch, logout isolation, foreign grant target rejection and explicit fingerprint authorization.
   - Three attachment tests: real AES-GCM/AAD and size/SHA256 verification, wrong-account rejection, source/length/hash tampering.
   - Three device push tests: strict server payload fields, active/notification/permission gating and account-device switch during native token retrieval.
3. Six-language resource parity and lookup references: passed.
4. `git diff --check`: passed for tracked changes.
5. `/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/hdc list targets`: **[Empty]**.
6. Backend typecheck and tests: see [backend report](harmony-backend.md). Full suite passed 65 tests before the final provider error-code refinements; final affected suite passed 40 tests after those refinements.

Node adapters validate the app's protocol and service logic, not real-device CryptoFramework, Asset, PushKit, file picker or UI execution. No simulator screenshot or physical delivery evidence is claimed.

## Build artifact

`harmony/entry/build/default/outputs/default/entry-default-unsigned.hap`

## Remaining runtime gates

- Configure the existing Harmony project signing and matching AppGallery/PushKit application identity. No signing material was added by this task.
- Deploy the reviewed Worker changes and securely configure/verify Huawei service-account credentials and existing push-token encryption key. Provider tests use mock network responses; production state was not modified or revalidated here.
- On a real Harmony device: verify first-install email/password login, Asset persistence after restart, pairing both iOS→Harmony and Harmony→iOS, history grants, sender authorization, notification permission/token update, same-account/selected-device delivery, logout suppression and decrypted attachment export.
- Test system foreground/background/terminated notification delivery separately. Standard Huawei alerts contain generic text and routing IDs; app-open history is decrypted locally. Lock-screen plaintext/image previews require a separate Huawei extended-notification capability and implementation.
- Verify all six languages, light/dark modes and layouts on device. Markdown currently renders as selectable text; links are copyable; images can be previewed and other attachments explicitly saved through the system picker.
- Remote logout failures remain visible: local credentials and plaintext are cleared, but server-side revocation is not claimed when the request fails.

## User flow and HTTP integration

See [Harmony/iOS multi-device push](../../harmony/docs/multi-device-push.md) for the exact account, pairing, sender authorization and HTTP/CLI routing flow.
