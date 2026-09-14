---
title: HTTP API reference
description: Send encrypted v2 envelopes and use the correct authentication for each endpoint.
order: 9
---

## Base URL and authentication

Production API origin: `https://api.pushnow.dev`. Use HTTPS. JSON field names on the wire are `snake_case`. Sender encryption must happen before HTTP submission.

| API family | Authentication |
| --- | --- |
| Account, device and Key/log management | `Authorization: Bearer <ACCESS_TOKEN>` |
| Sender directory, messages POST, attachments POST/PUT | `Authorization: Bearer <SOURCE_KEY>` |
| Archive, approval, message history/read/delete | A bound trusted device's account session |
| One attachment download | Bound account session, or `Authorization: Attachment <READ_TOKEN>` |

The legacy plaintext ingest routes are not the encrypted v2 contract. Do not substitute a plaintext `title`/`body` request to those routes and expect the same E2EE behavior.

## Browser CORS and custom headers

The locally implemented CORS policy allows configured origins to send up to ten custom header names matching `/^[xX]-[a-zA-Z0-9-]{1,60}$/`. Dashboard accepts them as a JSON object with string values of at most 200 printable ASCII characters each. This does not permit an unconfigured origin or override mandatory `Authorization`, `Content-Type` or message idempotency headers supplied by the SDK.

Custom values are redacted in the UI trace but remain HTTP metadata, outside message encryption. See the [playground header example](/docs/send-test-request/#custom-headers). Production availability awaits the parent deployment; a preflight failure on an older deployment does not establish that a sender Key is invalid.

## Submit a message

`POST /v2/messages` requires a sender Key and `Idempotency-Key` equal to `message_id`.

| Field | Required | Meaning |
| --- | --- | --- |
| `message_id` | Yes | Newly generated message UUID; also the idempotency header |
| `archive_id` | Yes | Verified account archive UUID |
| `enc` | Yes | Full-message HPKE encapsulated key, 65 decoded bytes |
| `ciphertext` | Yes | Full-message HPKE ciphertext; at most 256 KiB decoded |
| `preview` | Yes | Separately encrypted `{enc,ciphertext}` preview; ciphertext at most 2400 decoded bytes and overall push payload must fit |
| `attachment_ids` | Yes | Array, empty if none; maximum 20 unique uploaded attachment UUIDs |
| `notify_device_ids` | No | Omitted for all eligible devices; array of up to 100 unique IDs, empty for inbox-only |
| `scheduled_at` | No | Future ISO timestamp within 30 days |
| `expires_at` | No | ISO timestamp after due time, within 30 days |
| `sound` | No | Public routing enum: `default`, `silent` or `chime`; omitted preserves default behavior |

```http
POST /v2/messages
Authorization: Bearer <SOURCE_KEY>
Content-Type: application/json
Idempotency-Key: 00000000-0000-4000-8000-000000000001

{
  "message_id":"00000000-0000-4000-8000-000000000001",
  "archive_id":"<ARCHIVE_UUID>",
  "enc":"<BASE64_HPKE_ENC>",
  "ciphertext":"<BASE64_CIPHERTEXT>",
  "preview":{"enc":"<BASE64_HPKE_ENC>","ciphertext":"<BASE64_CIPHERTEXT>"},
  "attachment_ids":[],
  "notify_device_ids":[]
}
```

Placeholders above are not valid encryption. Obtain the actual payload from an SDK. Success is HTTP 201 and `{"message_id":"...","deduplicated":false}`. An identical retry is HTTP 200 and `deduplicated:true`.

## Sound routing

Add `"sound":"silent"` or `"sound":"chime"` at the top level of the prepared envelope through your SDK's sound option. Omit it or use `"default"` for the default behavior. The field is public routing metadata, not part of the HPKE-encrypted content. Files remain AES-GCM-encrypted.

`silent` omits APNs `sound` while preserving a visible alert. `chime` maps to the new app's bundled `pushnow-chime.wav`. The API accepts the enum, not a filename, uploaded audio, `null` or a critical-alert object. Inbox-only still creates no system alert. iOS settings and Focus/DND take precedence; audible delivery is not guaranteed.

Keep the exact sound field along with the original envelope for retries; do not change the mode under an existing message ID. See [sound modes and rollout status](/docs/message-content/#sound-and-notification-permissions). This finalized contract is being implemented; migration, deployment and device-audible verification are pending the release audit.

## Files and recipient discovery

| Method and path | Request | Response |
| --- | --- | --- |
| `GET /v2/recipients` | Sender bearer | Account/source identity, signed device directory and archive public record |
| `POST /v2/attachments` | `{id,size,read_token}`; size is ciphertext bytes | 201 `{id}` |
| `PUT /v2/attachments/<ID>` | Ciphertext bytes; `application/octet-stream` | 204 |
| `GET /v2/attachments/<ID>` | Bound session or that file's attachment capability | Ciphertext bytes |

Upload completion does not create a message. Reference the uploaded attachment IDs in a later encrypted submission. Reusing an attachment already committed to another message is not supported.

## Read state and deletion

These endpoints require a trusted device session, not just a browser account session:

| Method and path | Result |
| --- | --- |
| `GET /v2/messages?limit=50&cursor=...` | `{messages,next_cursor,deleted_ids}` with encrypted shared history |
| `GET /v2/messages/<ID>` | `{message}` |
| `POST /v2/messages/<ID>/read` | 204; update shared read state |
| `DELETE /v2/messages/<ID>` | 204; cancel delivery and delete encrypted message/files |
| `GET /v2/deletions?cursor=...` | `{deleted_ids,next_cursor}` for deletion synchronization |

Deleted message IDs cannot be resurrected by retry. This API currently has no message-content PATCH or schedule-edit endpoint.

## Management references

See [Account and token binding](/docs/email-login/) for login and refresh, [Devices and sender keys](/docs/account-notifications/) for account management, [HPKE authorization](/docs/hpke-authorization/) for grants, and [Notification logs](/docs/notification-logs/) for status queries.
