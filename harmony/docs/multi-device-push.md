# Pushnow iOS and HarmonyOS devices

The current protocol is [v2](../../docs/engineering/20-v2-wire-contract.md). An approved HarmonyOS installation is a device in the same account directory as iOS. Signing identity, account archive key, installation/device ID, login session and provider push token are distinct.

## User flow

1. Sign in with the same verified email account on HarmonyOS (email code or password).
2. The first device creates and pins the account signing identity. A subsequent device registers as pending and displays its pairing code.
3. On an existing trusted iOS or Harmony device, select the pending device, compare the entire pairing code shown on the new device, and approve it.
4. Refresh the new device. It verifies the device certificate, decrypts its approval, checks the transferred identity private key against the pinned public key, and imports the certified account archive key. Existing approved devices without archive material can receive an encrypted history grant.
5. In Devices, enable notifications and register Push. The system notification permission and a real Huawei Push Kit token are required. Names and notification settings are managed through the shared device directory. Devices are retained; sender credentials can be revoked separately.
6. On the HTTP sender, run `node cli/src/main.js login --api https://api.pushnow.dev --name 'My Agent'`. In the trusted phone's Senders tab, enter its authorization code and compare the sender fingerprint. The sender must also compare the full account fingerprint displayed by the phone. The grant contains the API credential and certified public archive, never the account private key.

## Send to either platform

From the repository root, after sender authorization:

```sh
node cli/src/main.js devices
node cli/src/main.js send --title 'Build complete' --body 'Ready for review' --device <harmony-device-id>
node cli/src/main.js send --title 'Build complete' --body 'Ready for review' --device <ios-device-id>
node cli/src/main.js send --title 'Build complete' --body 'Ready for review' --device <ios-device-id> --device <harmony-device-id>
```

Omitting `--device` notifies all eligible active devices. `--inbox-only` saves history without notification. The SDK/CLI encrypts locally and sends HTTP:

```http
POST /v2/messages
Authorization: Bearer <source-key>
Idempotency-Key: <message-id>
Content-Type: application/json
```

```json
{
  "message_id": "<uuid>",
  "archive_id": "<certified-account-archive-id>",
  "enc": "<HPKE-encapsulated-key-base64>",
  "ciphertext": "<encrypted-full-message-base64>",
  "preview": { "enc": "<separate-preview-enc>", "ciphertext": "<encrypted-preview>" },
  "attachment_ids": [],
  "notify_device_ids": ["<ios-device-id>", "<harmony-device-id>"]
}
```

These are wire placeholders, not a plaintext curl API. Use `cli/src/sdk.js` or the CLI to construct authenticated HPKE ciphertext. The sender is certified by the account signing identity. `notify_device_ids` only selects notifications: authorized devices share account history. An explicit empty array means inbox only; disabled devices stay silent even if explicitly selected. Legacy `/v1/secure/messages` remains compatible with per-device encryption and acknowledgements.

## Platform transport

- iOS: existing APNs encrypted-preview/notification-extension flow.
- HarmonyOS: native Huawei V3 standard alert with generic encrypted-reminder text and message/device routing IDs. The app refreshes authenticated history on open/foreground, verifies sender certificates and decrypts on the device. Standard notifications do not expose plaintext previews on the lock screen.
- Token updates are rebound to the active session. Logout calls the server to stop session delivery and clears in-memory credentials and plaintext. A remote-logout failure is shown explicitly.
- Push acceptance, stored history and device-visible delivery are separate states.

Huawei V3 requires `HARMONY_PUSH_PRIVATE_KEY`, `HARMONY_PUSH_KEY_ID`, `HARMONY_PUSH_SUB_ACCOUNT`, `HARMONY_PUSH_PROJECT_ID` and existing `PUSH_TOKEN_ENCRYPTION_KEY`. Match the AppGallery app, signed bundle and client Push Kit configuration. Configure secrets through the deployment environment; never commit them. See [backend verification](../../docs/qa/harmony-backend.md) for the verified API format and official sources.

## Local security and content

The app uses RFC 9180 P-256 / HKDF-SHA256 / AES-256-GCM and raw64 ECDSA certificates matching iOS. OS Asset protects account-scoped credentials and private keys; it never falls back to plaintext preferences. Upgrade migration first vaults and reads back old keys, then resolves ownership against the signed account/device directory and preserves the prior device ID.

The inbox verifies account, archive and source certificates before decrypting. It synchronizes read/deleted history and rejects mismatched identities. Attachments verify GCM authentication, exact size and SHA256 before preview/export. Text/Markdown is currently displayed as text, images have local previews, and other files can be saved through the system picker. Plaintext is kept in memory unless the user explicitly saves a file. Links are selectable/copyable text.

## Verification and remaining device work

Run `bash harmony/scripts/build-debug.sh` and `node --test harmony/tests/*.test.mjs harmony/test/*.test.mjs` from the root. Protocol tests execute the ArkTS source through Node platform adapters against independent HPKE implementations; they do not prove the device's CryptoFramework or Asset runtime.

The project currently has no signing configuration and this session found no `hdc` target. The generated HAP is unsigned. Real-device sign-in, pairing with iOS, Asset persistence, system notification permission, Huawei registration, app-background/terminated delivery, file picker, six-language UI and light/dark appearance remain device QA gates. The backend changes also need deployment before production can use the updated Huawei provider.
