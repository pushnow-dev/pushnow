# Dashboard key management and tab navigation

2026-09-13. Dashboard sections now switch through the left navigation instead of rendering as one long page. Account/devices, notification keys, send notification and delivery logs are individual panels while documentation remains a link.

Notification key management now explains that HTTP integrations use source_key, the secret is shown once, and each sender can keep at most two active keys. Generated keys can be copied or downloaded immediately. Existing rows show only prefixes and metadata, support expiry changes, deletion, and regeneration; regeneration deletes the selected old key before creating and displaying a replacement.

Backend source-key creation now accepts expires_at as well as expiresAt, returns both source_key and sourceKey for compatibility, and rejects a third active key for the same source with source_key_limit_exceeded. PATCH /v2/keys accepts expires_at and expiresAt.

Validation: backend tsc passed, full backend tests passed (15 files, 103 tests) before the final frontend-only sender-message polish; a later full run had one unrelated 5-second auth test timeout and `auth-service.test.ts` passed immediately when rerun alone. Web astro check passed (54 files, no errors/warnings/hints), web build passed (127 pages). Production deployed backend version 5e2ec520-7e9a-463a-b1b4-a9b5f21d1a7a and web version 6bc159e2-7565-4c5b-95d9-e934f71cce11.
