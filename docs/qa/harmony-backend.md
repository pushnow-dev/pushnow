# Harmony backend verification

Date: 2026-09-13

## Implemented

- Existing secure device enrollment, approval certificates, revocation, push-token binding and v2 archive delivery remain the shared account/device contract for iOS and Harmony.
- Replaced the legacy HMS Android request accidentally sent to the V3 endpoint with native HarmonyOS NEXT V3 `payload`, `target`, `pushOptions` and `push-type: 0`.
- Huawei authentication now signs a PS256 service-account JWT with Web Crypto; no client-secret OAuth request is used. Required secrets are `HARMONY_PUSH_PRIVATE_KEY`, `HARMONY_PUSH_KEY_ID`, `HARMONY_PUSH_SUB_ACCOUNT`, `HARMONY_PUSH_PROJECT_ID`, plus the existing token storage encryption key. The project must match the service account.
- Standard Huawei notifications show a generic encrypted-message alert and carry only message/device IDs and protocol name as click data. Ciphertext is downloaded through the authenticated API and decrypted inside the app. No private message title/body or source/identity keys are sent to Huawei. The iOS mutable-content preview remains unchanged.
- Raised stored push-token ciphertext decoding limit to support all accepted 4096-character Harmony tokens, including the AES-GCM tag.
- Huawei payload sizing excludes recipient tokens. Code 80300007 clears invalid tokens through the shared v1/v2 delivery policy; 80300029 and 81000001 enter retry policy.
- Provider error messages are not persisted; only bounded numeric codes or HTTP status are retained.

## Validation

- TypeScript `npm --prefix backend run check`: passed.
- Added real-D1 cross-platform v2 test: same ingested message produces one APNs call and one Harmony call; revoking the Harmony session suppresses its subsequent send while iOS remains eligible.
- Updated provider integration test to verify the actual JWT signature with an independently generated RSA public key, JWT fields/lifetime and native V3 request structure.
- Added privacy, expiry, provider-error sanitization and configuration-gating tests, and long-token encryption round trip.
- Initial full suite encountered an unrelated sender-management 5-second timeout under parallel load; rerun `npm --prefix backend test -- --maxWorkers=2 --testTimeout=30000` passed all 65 tests across 10 files (53.86 seconds).

- Final provider follow-up: TypeScript check passed; `harmony-push`, `v2-schedule`, and `secure-integration` passed 40/40 tests after response-code and token-size corrections. A real-D1 test confirms invalid Harmony token deletion preserves the iOS token and accepted delivery.
- Actual ArkTS source adapter tests: `node --test harmony/tests/device-push.test.mjs` passed 3/3; `node --test harmony/tests/auth-session.test.mjs` passed 5/5.

## Runtime boundaries

No production secrets were written and no backend was deployed by this subtask. Mock provider acceptance is not proof of physical-device receipt. Huawei AppGallery setup, service-account authorization, matching signed app/client ID, user notification consent, real token registration and physical-device receipt still require validation. Optional `HARMONY_PUSH_TEST_MESSAGE=true` enables provider test delivery. Lock-screen plaintext previews through `RemoteNotificationExtensionAbility` require separate Huawei permissions and are not enabled by this standard-notification adapter.

## Official references

- [Service account JWT](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/push-jwt-token): PS256, service-account issuer/key ID, fixed audience, one-hour lifetime and V3 authorization.
- [Push notification API data](https://developer.huawei.com/consumer/cn/doc/doccenter-capabilities/api/push-pushcommon): ALERT notification and click-action structure.
- [Notification message guide](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/push-send-alert).
- [Extended notification requirements](https://developer.huawei.com/consumer/en/doc/harmonyos-guides-V5/push-send-extend-noti-V5): additional permissions, category constraints and extension execution behavior.

- [Harmony V3 response codes and payload size](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V14/push-scenariozed-api-response-V14).
