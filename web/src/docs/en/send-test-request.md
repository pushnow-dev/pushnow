---
title: Dashboard API testing
description: Test account endpoints, submit encrypted envelopes and inspect redacted HTTP results.
order: 5
tryMethod: GET
tryPath: /v2/logs
tryAuth: session
---

## Open the API tester

Sign in at [Dashboard](/dashboard/) and open **API playground**. Public Docs do not require login. Dashboard's account views load device, Key and log metadata with your account session; its playground sends encrypted notifications using a separately connected sender.

The following requests help distinguish the credentials in each part of the workflow. The playground is a notification form, not an arbitrary HTTP endpoint editor. Use the account views for management reads, or the HTTP examples with your own client:

| Request | Credential | Expected result |
| --- | --- | --- |
| `GET /health` | None | Service health response; no delivery guarantee |
| `GET /v1/me` | Account session | Your own user record |
| `GET /v1/secure/devices` | Account session | Your registered devices |
| `GET /v2/keys` | Account session | Key metadata without secret values |
| `GET /v2/logs?limit=20` | Account session | Message and delivery metadata |
| `GET /v2/recipients` | Authorized sender Key | Certified recipient directory and archive public record |

Use the response status and returned IDs to verify the account before sending. Never put bearer tokens in the path or query string. A source Key is not a substitute for the account access token on management endpoints.

## Connect your sender

Use **Authorize browser** to start an HPKE authorization, approve the displayed code and sender fingerprint in the trusted iOS app, then enter the independently verified account fingerprint to complete it. Alternatively, import an existing sender configuration that you already trust. Dashboard validates its account and API origin against your current login and verifies the certified recipient directory.

Sender configuration contains both a transport Key and a private sender key. It stays in memory until you disconnect, leave the page or sign out. If you explicitly export it, store the downloaded file privately. Do not place it in source control. Changing only the Key field is valid for another Key from the same source, not a different account or sender.

An account login or additional Key alone cannot replace this encrypted authorization. See [HPKE authorization](/docs/hpke-authorization/) for the fingerprint checks.

## Test an encrypted send

1. Enter a title and body; add HTTP(S) links on separate lines if needed.
2. Choose inbox-only for an initial test without a system alert, or enable push and choose all devices or selected devices.
3. Choose one of the three sound dropdown modes: **Default**, **Silent** or **Chime**. Default requests the system sound; Silent keeps a visible alert without requesting sound; Chime requests the new app's bundled chime. There is no arbitrary filename field or sound-upload option.
4. Optionally choose a future time within 30 days and select files, an image or an icon. The form accepts PNG, JPEG, GIF or WebP for image/icon inputs.
5. Send. The browser SDK verifies recipients, encrypts file uploads, creates the full message and preview envelopes, then submits `POST /v2/messages` with the matching idempotency header.
6. Open an entry in **HTTP activity** to inspect its request/response and status, then inspect the account delivery log separately.

Optional extra headers use the [custom-header workflow](#custom-headers) below. The playground sets mandatory authentication, content type and message idempotency automatically.

The form's schedule input uses your local timezone and is converted to UTC. Transport expiry is currently an SDK/CLI option, not a separate playground field. Inbox-only still saves immediately, even if a future time is selected.

Sound is sent as public top-level routing metadata; the form still encrypts content and files locally. Inbox-only produces no alert for any sound mode. iOS sound settings and Focus/DND remain respected, with no critical-alert or audible-delivery guarantee. The sound contract is being implemented: backend migration, deployment and device-audible verification await the release audit. See [sound modes](/docs/message-content/#sound-and-notification-permissions) before testing against production.

## Custom headers

Enter a JSON object in the additional-headers field, for example:

```json
{
  "X-Workflow": "release-check",
  "X-Run-ID": "build-42"
}
```

Use at most ten custom header names matching `/^[xX]-[a-zA-Z0-9-]{1,60}$/`. Each value must be a string of at most 200 printable ASCII characters (space through `~`), with no tabs or line breaks. Arrays, nested objects, numbers and booleans are not valid header values. Use `{}` when you do not need extra headers.

The locally implemented backend CORS policy permits these custom names for configured origins. An unconfigured origin is not granted access by adding an `X-` header. This support still requires the parent deployment before it can be relied on in production.

Custom headers cannot override `Authorization` or `Content-Type`. The SDK supplies the required bearer credential and sets the message's `Idempotency-Key` automatically; do not try to replace these with custom headers. Extra headers are HTTP metadata, not HPKE-encrypted content, so keep secrets out of them.

The UI HTTP trace redacts custom header values. You can inspect header names and request status without exposing those values in the trace; review all diagnostic output before sharing it.

## Retry the last request

Use the playground's retry control after an uncertain result. It reuses the original in-memory encrypted envelope and message ID. A successful duplicate returns `deduplicated: true`, creating no second message. Disconnecting or changing accounts clears that prepared request.

The playground does not currently import a serialized CLI outbox. Use the CLI for a durable outbox across process restarts:

```sh
node cli/src/main.js send --title "API test" --body "Check my inbox" \
  --inbox-only --outbox ./test-outbox.json
node cli/src/main.js retry --outbox ./test-outbox.json
```

For low-level HTTP clients, see [HTTP API](/docs/http-api/). The endpoint accepts encrypted envelopes, not plaintext title/body JSON.

## Read a redacted HTTP trace

Keep two kinds of logs distinct: the tester's HTTP request/response trace and the account's persisted [notification delivery log](/docs/notification-logs/). A redacted trace can look like this; values below are illustrative, not a live delivery result:

```http
POST /v2/messages
Authorization: Bearer [REDACTED]
Content-Type: application/json
Idempotency-Key: 00000000-0000-4000-8000-000000000001

{
  "message_id": "00000000-0000-4000-8000-000000000001",
  "archive_id": "[REDACTED_ID]",
  "enc": "[REDACTED_ENVELOPE]",
  "ciphertext": "[REDACTED_ENVELOPE]",
  "preview": {"enc":"[REDACTED_ENVELOPE]","ciphertext":"[REDACTED_ENVELOPE]"},
  "attachment_ids": [],
  "notify_device_ids": []
}

HTTP 201 Created
{"message_id":"00000000-0000-4000-8000-000000000001","deduplicated":false}
```

The redacted example is not a sendable payload. A successful envelope retry returns HTTP 200 with `deduplicated: true`. Neither response confirms notification display.

## Share diagnostic output safely

Before copying a trace, remove authorization headers, cookies, email codes, passwords, access and refresh tokens, `source_key`, `device_code`, attachment read tokens, private keys and any plaintext test data. Redact nested response values too: a Key-creation response contains a one-time secret. Ciphertext and account/device IDs can also be redacted for a public bug report.

Keep the HTTP method, endpoint template, response status, error code, timing and a privately shared message ID when support needs to locate a delivery. Avoid sharing entire recipient directories or full browser storage dumps.

## When a request fails

A browser network error can mean a connectivity or CORS issue, not an invalid Key. Check whether an HTTP response was received. A 401 requires the correct current credential; a 403 can indicate missing trusted-device binding or an invalid device target. Do not keep retrying a rejected payload unchanged. See [Errors and retries](/docs/errors/).
