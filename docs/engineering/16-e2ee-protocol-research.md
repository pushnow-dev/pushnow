# Account-bound multi-device encrypted notifications

Research date: 2026-09-12. This document is a design decision and acceptance guide, not evidence of production delivery or a security audit.

## Decision

Use RFC 9180 HPKE to encrypt each notification independently for each selected device. Use native Apple CryptoKit on iOS and the MIT-licensed `@hpke/core` package on the sender. Keep account authentication, source authorization, device routing, and content encryption as separate responsibilities.

Selected implementation suite: DHKEM(P-256, HKDF-SHA256), HKDF-SHA256, AES-256-GCM (IDs 0x0010, 0x0001, 0x0002), HPKE Auth mode with a source public key certified by the pinned account identity. Create a fresh HPKE context per recipient per message and seal once. HPKE manages nonce derivation; callers must not copy a fixed AES IV into a script. Base mode does not prove who authored the message and is used only for the fingerprint-verified approval package. The exact current wire protocol is in `16-e2ee-contract.md`.

This choice is an engineering inference for an asynchronous, one-way reminder product with small payloads. It does not implement Signal, Telegram, or Matrix interoperability. HPKE is a standard encryption building block, not a complete account/device management protocol.

## Options examined

| Option | Useful property | Fit and dependency cost |
| --- | --- | --- |
| Telegram | Familiar account and device management | Ordinary Cloud Chats use client/server encryption; Secret Chats use E2EE but are device-specific. The Cloud Chat synchronization design does not satisfy this product's E2EE requirement. No Telegram code dependency proposed. |
| Signal Sesame / libsignal | Asynchronous multi-device sessions, ratcheting, device changes | Strong future option for interactive messaging. libsignal exposes Swift and TypeScript through Rust; upstream explicitly does not support use outside Signal and APIs may change. AGPLv3 dependency requires product-license consideration. Greater persistent session/prekey/toolchain work. |
| Matrix Rust SDK | Existing E2EE, device verification and synchronization ecosystem | Apache-2.0 SDK. Appropriate if adopting Matrix accounts, rooms and homeserver protocol. Larger protocol/platform commitment for an existing small Workers reminder backend. |
| HPKE / CryptoKit / hpke-js | Standard independent public-key message encryption | Small integration into existing API. iOS-native implementation and WebCrypto sender. Device authorization, replay control and key trust still belong to this app. Selected. |

Primary sources: [Telegram FAQ](https://telegram.org/faq#q-how-do-you-encrypt-data), [Telegram Secret Chats](https://core.telegram.org/api/end-to-end), [Sesame specification](https://signal.org/docs/specifications/sesame/), [libsignal repository and license](https://github.com/signalapp/libsignal), [Matrix SDK](https://github.com/matrix-org/matrix-rust-sdk), [Matrix E2EE guide](https://matrix.org/docs/matrix-concepts/end-to-end-encryption/), [HPKE RFC](https://www.rfc-editor.org/rfc/rfc9180.html), [Apple HPKE](https://developer.apple.com/documentation/cryptokit/hpke), [hpke-js](https://github.com/dajiaji/hpke-js), [hpke-js MIT license](https://github.com/dajiaji/hpke-js/blob/main/LICENSE).

## Identity and enrollment

1. Login establishes the account session. The server derives `userId` from that session; request bodies cannot choose an owner.
2. An installation generates a random device ID and its own key pair. Use a separate binding/key per account on the same installation. Store private keys in the shared Keychain access group needed by the app and notification extension, never in API requests or UserDefaults.
3. Upload only public key, key ID, device metadata, and notification registration. A device display name is editable metadata, never an authorization identifier. APNs token is a changing delivery address, not the identity or encryption key.
4. For a first device, export its account/device/key fingerprint to the sender over a trusted channel. Pin the actual public key and account/device ID in sender configuration. First-use trust must be visible and deliberate.
5. Additional logged-in devices can register as pending. They become encryption recipients after existing-device approval or explicit sender-side trusted configuration. An account login alone cannot establish cryptographic trust against a compromised server.
6. The selected implementation gives the first device an account signing identity. After explicit device/root fingerprint verification, an existing trusted phone signs the new device certificate and transfers the account identity private key inside an HPKE Base encrypted approval package. The receiving phone checks that the transferred private key derives the confirmed root and verifies its certificate. Each trusted phone is consequently an account enrollment authority; compromise of one exposes that authority.

The sender configuration pins the account root and its source private key. It accepts new recipient keys only when their device certificates verify under that root. This allows approved additional phones without re-exporting every sender configuration. Static certificates authenticate keys but do not sign the current directory membership or revocation state. A malicious server can replay a previously valid revoked-device certificate. A future versioned signed roster plus remembered revocations and freshness enforcement would strengthen that boundary. Never describe this initial certificate directory as providing authenticated revocation freshness.

## Sending and receiving

The sender selects all enabled trusted devices, or an explicit subset, under one account. It creates one message ID and encrypts the complete private JSON separately to each device. Each recipient gets only its envelope; the backend cannot re-encrypt a message to an unselected new phone.

Bind protocol version, account ID, source ID, device ID, key ID, message ID and expiry to HPKE authenticated additional data. Use a specified byte encoding shared by Swift and JavaScript, such as UTF-8 JSON of an ordered string array; do not rely on arbitrary object property order. Use a fixed versioned `info` domain separator. Store the exact protocol contract and test vectors beside the implementation.

The source API key authorizes ingestion for its server-recorded owner. The backend rejects foreign, revoked, disabled or stale-key recipients as a whole, and stores ciphertext plus minimal routing/scheduling metadata. It must not keep a parallel plaintext title, summary, URL, attachment name, logs or analytics event containing the private payload.

At dispatch time, recheck source/device ownership, revocation and enabled state. This applies to retries and queued jobs. Encrypt APNs token at rest with a server-held storage key; the server must recover this address to send, but never recover message private keys.

APNs carries a generic alert and either a small encrypted envelope or an opaque message ID. A notification service extension decrypts using its device key, checks recipient/context/expiry and replay state, then renders. Invalid, unavailable or timed-out decryption leaves a generic alert. An opaque-ID fetch needs narrowly scoped, device-bound authorization; do not put a general account refresh token into a notification.

Replay state should use a shared transactional store and atomic claim by account/device/message ID because the app and extension can run concurrently. Duplicate processing and delivery receipts must not reveal plaintext. Application code must also decrypt the inbox; a notification-only decryptor is not complete feature delivery.

## Revocation and recovery

- Device rename preserves identity and key. Disabling notifications stops delivery to that device; it does not revoke its already-held decryption capability.
- Logout revokes device delivery and local extension access, clears the corresponding private-key/account context and cancels its pending local notifications. Global logout revokes all sessions and delivery bindings.
- Revocation prevents future encryption and delivery to the device. It cannot erase plaintext already read or prevent decryption of ciphertext already copied together with its old private key.
- Reinstallation or key loss creates a new identity/key. Old history is unavailable unless a trusted old endpoint intentionally re-encrypts it or an explicitly designed encrypted backup exists. Password reset alone must not unlock old ciphertext.
- Delete obsolete private keys after the retention window if history requirements permit. Rotating static keys narrows exposure but is not equivalent to a Double Ratchet.

## Security boundaries

Static-recipient HPKE protects content from the relay and APNs when recipient keys are authenticated. It does not provide Signal-style forward secrecy after compromise of the long-term recipient private key, post-compromise recovery, or post-quantum security. Do not advertise these properties.

Pinned recipient keys prevent silent server substitution for known recipients. Automatic acceptance of every server-listed device would let a malicious directory add its own recipient. HPKE Base also lets anyone who knows the public key form a valid encrypted message; Source Key validation only addresses this at an honest backend. Cryptographic sender authentication requires Auth mode with pinned sender identity, or an independently verified signature design.

The relay still observes account/device identifiers, timing, network addresses, payload size, and scheduling metadata. Padding can reduce size leakage. An authorized sender knows the original content. A compromised endpoint, notification preview shown on an unlocked screen, or a recipient copying content is outside the confidentiality guarantee.

## Validation required

- JavaScript encryption -> native Swift decryption with a fixed public test fixture and the chosen suite; fresh ciphertext on repeated sends.
- Wrong private key, changed ciphertext, changed AAD, foreign device/account, stale key, duplicate message and expired message rejected.
- Two phones on one account each receive/decrypt their own envelope; an unselected third phone cannot fetch/decrypt it.
- Another account cannot rename, register over, fetch or dispatch to the first account's devices.
- Revoke or logout after queueing and before retry: no new delivery; local account switch cannot render the previous account's content.
- Simulator verifies app inbox/device management/extension payload handling. Real APNs delivery to physical devices is separately required; simulated payload delivery and HTTP acceptance are not APNs proof.
- Audit persisted message rows and APNs payloads for plaintext. Test Keychain accessibility after first unlock and locked-screen behavior, including extension failure fallback.

Research verification: inspected the local Xcode iPhoneOS 26.4 SDK CryptoKit Swift interface. HPKE Sender/Recipient, Auth mode, P256 and SecureEnclave.P256 key agreement conformance are marked available from iOS 17, compatible with the iOS 18 baseline. This is SDK evidence, not runtime or interoperability test evidence. Online primary repository README/license pages were checked; no upstream dependency code was copied by this research task.
