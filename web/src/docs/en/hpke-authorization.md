---
title: HPKE authorization
description: Approve a sender without uploading private keys, and verify the account it can notify.
order: 4
---

## Approve a sender safely

```sh
node cli/src/main.js login --api https://api.pushnow.dev --name "My automation"
```

The CLI generates a P-256 sender key pair locally and starts an authorization. In the app, enter the user code and compare the full SHA-256 sender fingerprint. After approval, the CLI asks you to compare the account identity fingerprint with the phone. Complete both checks before using the sender.

The account check matters: an encrypted grant alone does not prove who approved it when a sender has no previously trusted account identity. The CLI pins that identity and verifies future source and archive certificates against it. Never bypass a fingerprint mismatch to make login finish.

## Authorization HTTP sequence

| Step | Request | Authentication and response |
| --- | --- | --- |
| Start | `POST /v2/authorizations` with `name`, `public_key` | No account token; returns `id`, `device_code`, `user_code`, `expires_at`, `interval` |
| Inspect on phone | `GET /v2/authorizations/lookup?code=<USER_CODE>` | Bound trusted device session; returns authorization and archive public record |
| Approve on phone | `POST /v2/authorizations/<ID>/approve` | Bound session; `source_id`, encrypted `enc`/`ciphertext`, optional `expires_at`; returns 204 |
| Poll from sender | `POST /v2/authorizations/<ID>/token` with `device_code` | Returns `{"status":"pending"}` or an approved encrypted grant |

Poll no faster than the returned interval (currently three seconds). Codes expire after ten minutes and approved grants are consumed once. On expiry, start again; do not reuse the pending key or response from a different authorization. The authorization code's expiry is separate from the resulting sender Key's expiry.

## Encryption contract

Use the supplied SDK or CLI for encryption. The implemented RFC 9180 suite is DHKEM P-256 with HKDF-SHA256 and AES-256-GCM. Binary envelope fields use standard padded Base64.

| Payload | HPKE mode | `info` | Recipient |
| --- | --- | --- | --- |
| Sender grant | Base | `pushnow-sender-grant-v2` | Locally generated sender public key |
| Full message | Auth | `pushnow-v2` | Account archive public key |
| Notification preview | Auth | `pushnow-v2` | Account archive public key |
| Archive transfer to a device | Base | `pushnow-archive-grant-v2` | Approved device agreement key |

Grant additional authenticated data (AAD) is the UTF-8 compact JSON array:

```json
[2,"sender-grant","<AUTHORIZATION_ID>","<SENDER_PUBLIC_KEY_BASE64>"]
```

The encrypted grant contains `api_url`, `user_id`, `source_id`, `source_key`, `identity_public_key` and the signed archive **public** record. The sender adds its own private key locally. It does not receive the account archive private key and does not need it to send.

Message and preview AAD bind the account, source, message and archive IDs:

```json
[2,"message","<USER_ID>","<SOURCE_ID>","<MESSAGE_ID>","<ARCHIVE_ID>"]
```

Use `"preview"` instead of `"message"` for the separately encrypted preview. These values must match exactly; do not reuse one envelope for the other purpose. The certified sender key authenticates HPKE message encryption.

## What is visible to the service?

The service stores routing IDs, source names, Key metadata, scheduling timestamps, ciphertext sizes and delivery attempts. It cannot use these envelopes to read the full title, body, link targets or encrypted file descriptors. Source and device names are metadata: avoid putting secrets in them.

The finalized optional `sound` enum (`default`, `silent`, `chime`) is also public top-level routing metadata, outside HPKE encryption. It does not change encryption of the title, body or preview, or AES-GCM file encryption. See [sound modes and pending rollout](/docs/message-content/#sound-and-notification-permissions).

APNs receives a generic alert plus encrypted preview data. The app's notification extension can decrypt the preview on a correctly enrolled device. A generic fallback alert may appear when preview decryption or extension processing cannot finish. Lock-screen appearance remains subject to iOS preferences.

## New devices and credential storage

The first trusted client creates the account archive key. Later devices receive its private material through an encrypted approval or archive grant from an existing trusted device. Do not silently replace a pinned archive to recover from a mismatch.

The current CLI uses macOS Keychain where available and a private credential file on other systems. Treat the complete sender configuration as a secret. Dashboard's API playground can start the same SDK authorization, but still requires trusted iOS approval and account fingerprint verification. Merely signing in or adding a transport Key does not perform that grant. Dashboard never needs the account archive private key.
