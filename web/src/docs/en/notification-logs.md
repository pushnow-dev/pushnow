---
title: Notification logs
description: Trace a message to its sender Key and each device's delivery attempt without exposing content.
order: 8
tryMethod: GET
tryPath: /v2/logs?limit=20
tryAuth: session
---

## Inspect recent activity

Open [Dashboard](/dashboard/) and its notification log. Filter by Key to separate activity from different credentials. The log records message and device routing metadata, not the decrypted title, body or files.

```sh
curl --fail-with-body 'https://api.pushnow.dev/v2/logs?limit=20' \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Use an account session, not a source Key. Supported query parameters are `key_id`, `source_id`, `cursor` and `limit` (1 to 100, default 50). Treat `next_cursor` as opaque and URL-encode it when requesting the next page. Stop when it is `null`.

## Response example

This example is illustrative metadata, not evidence of a live notification:

```json
{
  "logs": [{
    "message_id": "00000000-0000-4000-8000-000000000001",
    "source_id": "<SOURCE_ID>",
    "key_id": "<KEY_ID>",
    "source_name": "Build server",
    "created_at": "2026-09-13T08:00:00.000Z",
    "scheduled_at": null,
    "expires_at": null,
    "read_at": null,
    "deliveries": [{
      "device_id": "<DEVICE_ID>",
      "device_name": "Work iPhone",
      "status": "accepted",
      "last_error": null,
      "attempts": 1,
      "accepted_at": "2026-09-13T08:00:01.000Z"
    }]
  }],
  "next_cursor": null
}
```

Older records may have no `key_id`. An empty `deliveries` array means no device delivery rows were created; this may be inbox-only or there may have been no eligible notification-enabled device at submission.

## Interpret statuses

| Status | Meaning | Next step |
| --- | --- | --- |
| `pending` | Waiting for its due time or processing | Check `scheduled_at` and later refresh |
| `sending` | A worker has claimed the attempt | Allow the attempt to finish |
| `accepted` | **Provider accepted**, not device delivered | Check device permissions, connectivity and the app |
| `retry` | Temporary failure; another attempt is planned | Inspect `last_error`; avoid creating duplicate messages |
| `blocked` | A prerequisite or provider condition prevents delivery | Check push registration/configuration or error reason |
| `suppressed` | Delivery is no longer eligible | Check session, Key validity, device preferences or message state |
| `failed` | A terminal attempt failure, such as an invalid device token | Open the signed-in app to refresh registration |
| `expired` | The transport deadline passed | History remains; create a new message if still relevant |

`accepted_at` is the provider acceptance timestamp. It is not a receipt from the phone. `read_at` is shared app read state, not proof that a banner was shown. Attempt counts include processing outcomes and should not be interpreted as the number of visible notifications.

## Common delivery reasons

- `push_token_pending`: the device has not supplied a usable push token.
- `push_not_configured`: the server transport configuration is incomplete.
- `source_key_not_active`: the sending Key expired or was revoked before delivery.
- `delivery_not_eligible`: account/device/session/message state no longer permits the delivery.
- `transport_expired`: the alert's delivery window ended.
- `push_transport_error`: a transient transport exception triggered retry handling.

Logs can include provider error codes such as `BadDeviceToken` or `Unregistered`. For diagnosis, keep the message ID and error code. Do not paste passwords, bearer credentials or encrypted attachment descriptors into support requests.
