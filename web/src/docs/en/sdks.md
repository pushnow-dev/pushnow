---
title: SDK overview
description: Choose a local SDK and understand runtime, encryption and retry differences.
order: 11
---

## Choose an SDK

All SDKs target the encrypted v2 API. They authorize a sender, verify account binding, encrypt message content and files locally, and submit ciphertext over HTTPS. The source packages are in the repository; no registry publication is assumed by these instructions.

| Language | Repository directory | Runtime | Guide |
| --- | --- | --- | --- |
| TypeScript / JavaScript | `sdk/typescript` | Modern browser with WebCrypto, or Node.js 22+ | [TypeScript and npm](/docs/sdk-typescript/) |
| Python | `sdk/python` | Python 3.10+ **and Node.js 22+** | [Python](/docs/sdk-python/) |
| Go | `sdk/go` | Go 1.22+ **and Node.js 22+** | [Go](/docs/sdk-go/) |
| Java | `sdk/java` | Java 11+ **and Node.js 22+** | [Java](/docs/sdk-java/) |

Python, Go and Java are subprocess bindings to a bundled, pinned JavaScript HPKE runtime. They are not native cryptographic implementations and their compiled artifacts do not embed Node. Deploy `runtime/` and its installed dependencies alongside your service.

## Authorization is separate from login

Sign in and initialize the account in the iOS app first. The SDK's authorization flow does not register users or sign them in with email/password. It creates a sender key pair and asks your trusted device to approve it.

The recommended flow starts authorization with an account access token from a signed-in app or trusted dashboard session, then completes approval on the trusted phone. The token only authorizes the setup request; it is not enough to encrypt messages.

SDK authorization now uses the account Access Token flow only. The token starts an account-bound authorization, and the signed-in trusted app still approves the sender before the SDK receives a reusable encrypted config.

The resulting configuration includes `api_url`, `user_id`, `source_id`, `source_key`, `identity_public_key`, `sender_private_key` and the certified archive public record. Keep it secret. A bearer token or source Key alone cannot encrypt a message; it must match the sender configuration's source and account.

## Options differ by language

| Behavior | TypeScript | Python / Java | Go |
| --- | --- | --- | --- |
| All devices | Omit `deviceIds` | Omit `deviceIds` | `DeviceIDs: nil` |
| Selected devices | `deviceIds: [id]` | `deviceIds` list/JSON array | Pointer to a slice of IDs |
| Inbox-only | `inboxOnly: true` or `deviceIds: []` | `pushEnabled: false` or empty `deviceIds` | `PushEnabled` points to false, or pointer to empty IDs |
| Schedule | `scheduledAt` option | `scheduledAt` input | `ScheduledAt` |
| Images | `image` file input | `images` file list | `Images` |
| Sound | `MessageOptions.sound` | `sound` input | `Sound` pointer |

Device targeting never limits shared account history. Scheduling is within 30 days and does not hide the saved message until the due time. See [Content](/docs/message-content/) and [Scheduling](/docs/scheduling/).

All sound inputs use the enum `default | silent | chime`; omission preserves default behavior. Sound is public routing metadata, while message content remains HPKE-encrypted and files remain AES-GCM-encrypted. Silent still requests a visible alert; chime uses the new app's bundled asset, not an arbitrary filename or upload. iOS settings and Focus/DND apply, with no critical-alert guarantee. This sound contract is being implemented; migration, deployment and audible-device verification are pending. See [sound modes and rollout status](/docs/message-content/#sound-and-notification-permissions).

## Retries and logging

Prepare once and retry the exact envelope. The TypeScript SDK currently keeps an in-memory account/source binding on the prepared object; serialized outbox import is not supported there. Keep the original prepared object for retries. The CLI and Python/Go/Java bindings provide durable encrypted outbox workflows.

Use SDK request metadata callbacks or log accessors for diagnostics. They intentionally expose method, endpoint template, status and elapsed time rather than tokens or payloads. These local traces are separate from the account's [delivery logs](/docs/notification-logs/).

Successful SDK submission is API acceptance, not confirmation that a device displayed the alert.
