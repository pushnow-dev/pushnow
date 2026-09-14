---
title: Content, images and files
description: Send encrypted titles, body text, links and attachments, with accurate preview limits.
order: 6
---

## Supported content

The following fields belong inside the full **encrypted plaintext**, before the SDK seals it. They are not top-level fields of the HTTP envelope.

| Field | Type | Current behavior |
| --- | --- | --- |
| `title` | String | Full title in history; a shorter copy can appear in the notification preview |
| `body` | String | Full body in history; preview is UTF-8 safely shortened |
| `links` | Array of strings | Links associated with the message; use HTTPS URLs for normal destinations |
| `attachments` | Array of encrypted file descriptors | Up to 20 uploaded files; descriptors include their decryption material inside the encrypted message |
| `image_id` | Attachment UUID | Selects an attached image for the message and eligible notification preview |
| `icon_id` | Attachment UUID | Identifies an attached icon for message content; does not replace the iOS application icon |
| `priority` / P0 / P1 | No v2 transport contract | Do not assume these change iOS interruption level or bypass notification settings |

## Titles and body text

```sh
node cli/src/main.js send \
  --title "Build complete" \
  --body "Version 1.2 is ready for review."
```

The stored full message is not truncated to fit a push notification. The CLI separately limits preview text (currently up to 400 UTF-8 bytes for title and 700 for body). The complete APNs payload must remain within 4096 bytes. iOS may further shorten displayed text.

Messages are immutable in the current send contract. Editing text in a new SDK call creates a new message with a new ID; it does not update a previously submitted notification. Reusing an old message ID with changed content causes a conflict.

## Links and files

```sh
node cli/src/main.js send --title "Review report" \
  --body "Results and supporting files are attached." \
  --link https://example.com/reports/latest \
  --file ./report.pdf --file ./notes.md
```

Repeat `--link` and `--file` for multiple entries. Files are encrypted locally before upload. The app handles previews or opens files according to supported MIME types; attaching a file does not guarantee an inline renderer for every format. Link destinations may require their own login.

## Images and icons

```sh
node cli/src/main.js send --title "Image review" \
  --body "Please review this draft." \
  --image ./preview.png --icon ./project-icon.png
```

Both flags upload encrypted files. The SDK sets `image_id` and `icon_id` to IDs in the same attachment list. An unknown reference is rejected by the sender. A preview image descriptor may be omitted from the push preview when it would exceed the payload budget; the full attachment remains in the saved message.

The notification extension decrypts the selected preview image when possible. It may fall back to the generic notification if processing cannot complete. The operating system's app icon remains PushNow's icon.

## File transport

1. Generate a random 32-byte AES key, 12-byte nonce and attachment UUID locally.
2. Encrypt with AES-256-GCM and AAD `[2,"attachment",user_id,source_id,attachment_id]` encoded as compact UTF-8 JSON.
3. Reserve through `POST /v2/attachments` using the ciphertext size and a random `read_token`.
4. Upload ciphertext with `PUT /v2/attachments/<ID>` and `Content-Type: application/octet-stream`.
5. Include the encrypted descriptor in the full message and the attachment ID in `attachment_ids`.

The descriptor contains `id`, `name`, `mime`, plaintext `size`, `key`, `nonce`, plaintext `sha256` and `read_token`. It travels encrypted. Do not expose it in request traces. Use SDK file helpers rather than implementing this sequence with plaintext uploads.

The current contract caps ciphertext uploads at 20 MiB per attachment, the encrypted manifest at 256 KiB and attachments at 20 per message. Encryption adds a 16-byte authentication tag, so a plaintext file at the exact transport size limit is too large. Pending orphan uploads expire after 24 hours; committed attachments remain associated with their message until deletion. Account storage quotas also apply.

## Sound and notification permissions

The finalized v2 contract adds optional **top-level** `sound` routing metadata. It is outside the encrypted content and visible to the service; title, body, links and previews remain HPKE-encrypted, and files remain AES-GCM-encrypted. Do not put `sound` inside the encrypted message body.

| Value | APNs behavior under this contract |
| --- | --- |
| Omitted or `default` | Request the system default notification sound |
| `silent` | Omit the APNs `sound` key; still request a visible alert |
| `chime` | Request `pushnow-chime.wav`, bundled in the new app build |

The CLI option is `--sound default`, `--sound silent` or `--sound chime`:

```sh
node cli/src/main.js send --title "Quiet update" --body "Ready to review." --sound silent
node cli/src/main.js send --title "Review reminder" --sound chime
```

These are three named modes, not arbitrary sound filenames. Do not send `pushnow-chime.wav` as the API value or upload a sound file. Dashboard's API playground offers the same three dropdown modes, with no filename or sound-upload control.

`silent` is a visible notification without a requested sound, not inbox-only or a silent background push. For **no system notification**, use [inbox-only](/docs/scheduling/#inbox-only). Inbox-only creates no alert regardless of the sound selection.

iOS notification permissions, sound preferences, Focus and Do Not Disturb still apply. No mode requests critical alerts or guarantees an audible interruption. Chime requires the new app build containing the bundled asset.

**Rollout status:** this describes the finalized contract being implemented. Backend migration, deployment and audible verification on a device are not complete; production support must be confirmed by the release audit before relying on these modes.
