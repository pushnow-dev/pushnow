# Message source attribution audit

Read-only audit, 2026-09-13. No user plaintext/ciphertext was selected, decrypted or printed. No code or database mutation.

## Current interface facts

- v1 SecureMessages.inbox returns message_id, user_id, source_id, device_id, expires_at, enc/ciphertext, source_public_key, source_certificate, created_at and read_at. It has no source name, type, key ID or sending-client kind.
- v2 apiMessage returns message_id, user_id, source_id, archive_id, envelopes/preview, source certificate/key, created_at, read_at, scheduled_at, expires_at and sound. MessageRow has source_key_id internally but apiMessage omits it. No origin kind.
- sources.source_type / source API sourceType enum is agent|cli|webhook|subscription. There is no web value. This is a connection category, not proof of which program emitted a message.
- /v2/senders selects id, name, public_key, created_at, status, omitting source_type. /v1 sources exposes sourceType via ProductStore.
- SenderAuthorizationService.swift and SecureSourceService.swift create sources with sourceType .agent, including browser and CLI authorizations. Consequently agent cannot be mapped to API accurately.
- Browser playground-sender.ts uses account authorization name Web dashboard. api-playground.ts constructs content and prepareMessageV2 without origin metadata. Config import/export means a browser-named sender can be used elsewhere.
- CLI v2-auth.js sends configurable name and public key only. v2-command.js creates encrypted content and prepared messages without origin metadata. Both tools use the same v2 encrypted API; an HTTP endpoint or User-Agent alone does not establish a meaningful API source category.

## Production metadata evidence

Latest nondeleted v2 messages for the current review account, selected without payload fields:

- 992f8f1e-c294-431a-95e9-49d89fa172cc, 2026-09-13T04:58:38.460Z
- e0a04c91-2da1-4faf-b91c-528d242bbdf4, 2026-09-13T04:53:40.049Z

Both use source 128f6ee1-96a3-40a0-a157-c4792735169c, source_name Web dashboard, source_type agent, key b5ea0ec2-d436-4c62-8a34-3771ba51c04f. These metadata align with the newly used browser sender; without reading the title they cannot independently identify which row has the user-supplied title. The source name is valid to display as a name, not verified execution origin.

## Recommended compatible minimum

1. Add source_name and source_type to v1/v2 message responses through owner-scoped sources join (or resolve existing source_id using source list). These are immediately useful historical sender labels. Preserve old fields. Do not translate agent or unknown into API; show Other/Unknown or just the source name.
2. For actual sending-tool labels, add optional per-message source_kind enum web|cli|api|subscription to ingestion and nullable column on secure_messages and v2_messages. API returns source_kind, resolving NULL to unknown. Per-message storage is necessary because credentials are exportable and reusable between tools.
3. Browser prepares source_kind=web; CLI prepares cli; a dedicated API integration explicitly sets api; a subscription producer sets subscription. Generic SDK defaults unknown (using an SDK does not prove an API workflow). Keep the optional field in saved outbox messages and include it in idempotency hashing only when supplied, preserving legacy request hashes.
4. source_kind is authenticated sender-declared metadata, not proof of runtime or browser origin. If the UI needs cryptographic linkage to the encrypted message, also carry it inside authenticated encrypted content and reject contradictory metadata after decryption. Do not advertise tool attribution as independently verified. Do not derive source_kind from user-controlled name or spoofable request headers.
5. No automatic historical backfill by name. Older records can show source_name with unknown kind. Known subscription connection metadata may be displayed as source type, separately from message tool attribution.

This report proposes the changes only. No shared iOS/frontend/backend source was modified for this audit.
