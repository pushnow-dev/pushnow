---
title: Errors and retries
description: Diagnose authentication, targeting, quota and encryption errors without duplicating alerts.
order: 10
---

## HTTP errors

Inspect the HTTP status and structured `code` if returned. Error bodies may also include a human-readable `message`; do not depend on its exact wording. SDKs may expose only the HTTP status to avoid leaking response content in application logs.

| HTTP / code | Cause | Action |
| --- | --- | --- |
| 400 `idempotency_must_equal_message_id` | Header does not equal the payload UUID | Submit the matching header and envelope |
| 400 `invalid_scheduled_at` | Missing timezone, invalid date, past time or more than 30 days ahead | Choose a new future timezone-qualified timestamp |
| 400 `invalid_expires_at` | Expiry is before due time or beyond the allowed window | Correct the date before preparing a new message |
| 400 `attachment_not_ready` | Missing, expired or unavailable upload | Reserve and upload a fresh encrypted file |
| 400 `invalid_limit` / `invalid_cursor` | Bad pagination parameters | Use 1–100 for limit and the returned opaque cursor |
| 401 | Missing, expired or revoked credential | Use the right token type; refresh account login or rotate the sender Key |
| 401 `authorization_expired` / `authorization_consumed` | Approval flow expired or was already consumed | Start a new CLI login |
| 403 `invalid_target` | Device is not an eligible owned target | Refresh and verify the sender directory |
| 403 `email_verification_required` | Account email is unverified | Complete email verification |
| 402 `quota_or_attachment_conflict` | Daily quota exhausted or concurrent attachment conflict | Check membership usage and upload state; do not blindly retry |
| 409 `wrong_archive` | Submitted archive differs from the account archive | Stop and verify the account identity and archive pin |
| 409 `message_id_conflict` | Same message UUID with different payload/source | For a retry use the original envelope; for new content use a new UUID |
| 410 `message_deleted` | A deleted message ID was retried | Do not resurrect it; submit a new message only intentionally |
| 413 `preview_too_large` | Push preview exceeds transport limits | Reduce preview/image metadata with SDK preparation |
| 429 `slow_down` / `rate_limited` | Authorization polling or request rate too high | Honor the polling interval and back off |
| 5xx / network timeout | Temporary or uncertain result | Retry the exact prepared envelope, with backoff |

Additional validation errors can be returned for malformed Base64, unsupported fields or invalid UUIDs. The finalized optional top-level `sound` field accepts only `default`, `silent` or `chime`. Omit it for default behavior; arbitrary filenames, uploaded audio, `null` and critical-alert objects are not valid values. Use the SDK's sound option rather than placing it inside encrypted content.

Sound support is being implemented and is not yet production-audited. If a deployed version rejects the new field, check migration and release status before retrying. Do not silently replace a requested mode or mutate an already submitted envelope. For an exact retry, retain the original sound value or omission.

## Exact retries

Encryption is randomized. Calling a high-level send helper again can generate a new UUID and ciphertext, creating another message. For reliable retries, prepare once, store the encrypted envelope securely, and submit that same envelope with the same `Idempotency-Key`.

```sh
node cli/src/main.js send --title "Deployment finished" \
  --body "Ready for review" --outbox ./deployment-outbox.json

# After a timeout or uncertain result:
node cli/src/main.js retry --outbox ./deployment-outbox.json
```

Keep the file unchanged. A deduplicated response means the original request is already stored. It does not restart delivery. Do not automatically retry content conflicts, wrong-account errors or deleted messages by assigning a fresh ID.

## Fingerprint or decryption errors

Stop if the SDK reports a changed account identity, wrong source key, invalid source/device certificate or archive mismatch. Check which account approved the sender and whether you mixed configurations from different sources. Do not disable verification or replace the stored identity pin with an unverified server value.

A newly logged-in device that cannot decrypt history needs the encrypted archive transfer from an existing trusted device. A browser account token alone cannot resolve this.

## Custom-header or CORS errors

For playground extra headers, supply a JSON object with at most ten `X-` names matching `/^[xX]-[a-zA-Z0-9-]{1,60}$/` and string values of at most 200 printable ASCII characters. Remove tabs, line breaks, non-ASCII values and attempts to override mandatory headers. The SDK sets authentication and message idempotency itself.

If the browser preflight fails, check that the page's origin is configured and that the backend deployment includes the custom-header CORS change. The change is implemented locally but production availability awaits the parent deployment. A blocked preflight is not evidence of an invalid Key. Use `{}` to isolate an extra-header problem, then retry the original prepared message only if submission was uncertain. UI traces redact custom values. See [Custom headers](/docs/send-test-request/#custom-headers).

## API accepted but no alert

Check [notification logs](/docs/notification-logs/) for the message ID, device target, schedule and per-device status. Confirm the app is signed in, has completed device setup, has registered a push token and has notification permission. Verify the sending Key was still valid when the reminder became due.

`accepted` means **provider accepted**, not device delivered. An inbox-only message intentionally has no alert. A scheduled alert may still be pending. A generic fallback preview is different from a missing message: open the app to inspect the saved encrypted content.

## Visible alert but no sound

`sound: "silent"` intentionally requests no audio while retaining the alert. `chime` requires the new app build with `pushnow-chime.wav`; `default` requests the system sound. Check iOS notification/sound preferences and Focus/DND. These modes do not request critical alerts, and provider acceptance does not confirm audio playback. Backend migration, deployment and audible verification on a device remain pending the release audit.
