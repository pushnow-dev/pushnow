---
title: Quickstart
description: Connect your account, authorize a sender, and send your first encrypted notification.
order: 1
tryMethod: GET
tryPath: /health
---

PushNow saves notifications to your account and can alert all your enabled devices, selected devices, or none. Message content and files are encrypted on the sender before upload. Start with the CLI; a plain API key alone cannot create an encrypted sender.

## Before you start

- Sign in to the iOS app with a verified email. Allow notifications if you want system alerts.
- Finish device setup in the app. Additional devices need an encrypted key transfer from a trusted device before they can decrypt shared history.
- Use Node.js 22 or later for the repository CLI. The commands below run from the repository root; they do not assume a published npm package.

```sh
npm --prefix cli ci
node cli/src/main.js login --api https://api.pushnow.dev --name "Build server"
```

## Approve the sender

1. In the app, open the sender authorization screen and enter the code printed by the CLI.
2. Compare the full sender fingerprint on both screens. Approve only if it matches.
3. Choose the sender Key's expiry in the app.
4. Compare the account fingerprint printed by the CLI with the one on your phone, then confirm it.

The code expires after ten minutes. Your sender's private key stays local. See [HPKE authorization](/docs/hpke-authorization/) for the trust checks and wire format.

## Send a notification

```sh
node cli/src/main.js devices
node cli/src/main.js send \
  --title "Build complete" \
  --body "The release is ready for review." \
  --outbox ./build-outbox.json
```

Without a device selector, PushNow targets all currently eligible notification-enabled devices. The CLI encrypts the full message and its shorter notification preview, then sends one `POST /v2/messages` request. It may also read the device directory first; files require separate encrypted uploads.

An API success means the message was accepted into the account, not that a phone displayed it. Open [Dashboard](/dashboard/) to inspect [notification logs](/docs/notification-logs/) and confirm the message in the app.

## Choose how to notify

```sh
# Replace DEVICE_ID with an ID returned by the devices command.
node cli/src/main.js send --title "My phone only" --device DEVICE_ID

# Save to the shared inbox without a system notification.
node cli/src/main.js send --title "Daily archive" --inbox-only

# Retry the exact encrypted request after an uncertain network result.
node cli/src/main.js retry --outbox ./build-outbox.json
```

Device selection controls the alert, not access to history. Other trusted devices in the same account can read the saved message.

## Next steps

- [Account and token binding](/docs/email-login/): email login, session tokens and sender credentials.
- [Devices and keys](/docs/account-notifications/): names, device IDs, Key expiry and rotation.
- [Message content](/docs/message-content/): titles, body text, links, images and files.
- [Scheduling](/docs/scheduling/): future alerts, expiry and inbox-only requests.
- [Dashboard API testing](/docs/send-test-request/): test authenticated endpoints and inspect redacted HTTP results.
- [SDKs](/docs/sdks/): TypeScript, JavaScript, Python, Go and Java integration status.
