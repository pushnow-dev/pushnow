---
title: Scheduling and inbox-only
description: Choose recipients, set a future reminder and distinguish transport expiry from history.
order: 7
---

## All devices by default

Omit `notify_device_ids` from the encrypted HTTP envelope to select all currently active, certified, notification-enabled devices in the sender's account. Recipient selection happens when the message is accepted. A device added later can read shared history once authorized, but is not automatically added to the original alert's delivery rows.

| Envelope option | Notification behavior |
| --- | --- |
| No `notify_device_ids` field | All eligible devices at submission |
| `"notify_device_ids":["<DEVICE_ID>"]` | That owned device if notifications are enabled |
| Multiple device IDs | Those owned devices if enabled |
| `"notify_device_ids":[]` | Save to the account inbox; create no system notification deliveries |

Unknown or foreign IDs are rejected. A disabled device is not forced to notify by listing it explicitly. Server-side eligibility is checked again at delivery time.

## Send later

```sh
# Generate a timezone-qualified timestamp one hour from now.
AT=$(node -e 'console.log(new Date(Date.now()+3600000).toISOString())')
node cli/src/main.js send --title "Review the report" \
  --body "The report is in your inbox." --at "$AT"
```

The CLI maps `--at` to `scheduled_at`. It must be in the future and within 30 days of submission. Use an ISO 8601 timestamp with `Z` or an explicit numeric timezone offset, including seconds. An unqualified local date such as `2026-10-01 09:00` is invalid.

Scheduled messages appear in the account history immediately. `scheduled_at` postpones the system alert, not visibility of the saved message. The server's periodic delivery process handles due reminders; it does not guarantee an exact second of display.

## Expire an alert

```sh
AT=$(node -e 'console.log(new Date(Date.now()+3600000).toISOString())')
EXPIRES=$(node -e 'console.log(new Date(Date.now()+7200000).toISOString())')
node cli/src/main.js send --title "Meeting reminder" \
  --at "$AT" --expires "$EXPIRES"
```

`expires_at` must be after the scheduled time (or after now for immediate sends) and within 30 days of submission. Without it, delivery uses a transport expiry 30 days after message creation. Expiry stops further notification attempts; it does not delete account history.

Keep the sending Key valid through the delivery window. Revoking or expiring that Key can suppress a pending reminder even when the message itself has not expired.

## Inbox-only

```sh
node cli/src/main.js send --title "Daily results" --body "Saved for later." --inbox-only
```

The sender emits `notify_device_ids: []`. No APNs alert is created, but the message is available in the app after sync. This is not a silent background push, and it does not guarantee an immediate background refresh on every device.

Under the finalized [sound contract](/docs/message-content/#sound-and-notification-permissions), `sound: "silent"` instead requests a visible alert without sound. Inbox-only creates no alert regardless of `sound`. The sound rollout still awaits migration, deployment and audible-device verification.

Do not combine inbox-only with a future schedule expecting the message to stay hidden until then: the message is saved immediately and no delivery rows exist to trigger an alert later.

## Read, delete and retry

Reading an unread immediate message before delivery can suppress its alert. Reading a scheduled message does not cancel its scheduled reminder. Deleting a message cancels its outstanding deliveries and removes its encrypted content and attachments; other trusted devices synchronize the deletion.

The current API has no schedule-edit endpoint. To replace a reminder, delete the old message using a bound app session and submit a new one with a new ID.

For an uncertain network response, retry the exact prepared envelope and original idempotency header. See [Errors and retries](/docs/errors/). Retrying an already accepted message does not create new alerts or reschedule its delivery.
