# Secure v1 read state

2026-09-13: audited live production and sandbox schemas before writes. Neither secure_messages table had read_at. Migration 0014 adds nullable TEXT read_at without rewriting old rows. Sandbox also received existing additive 0012 and 0013 prerequisites; production only required 0014. Live schema readback confirms nullable read_at in both environments.

POST /v1/secure/messages/:id/read accepts no body and returns 204. Requires authenticated, approved bound device, matching message owner and a delivery to that device. Missing/inaccessible message returns 404 message_not_found. Uses COALESCE to preserve first read timestamp on repeated requests. The account-wide message read timestamp appears as read_at (ISO8601 string or null) in GET /v1/secure/messages. List does not filter read messages, so All retains them. Existing expiration and 100-message list limit remain unchanged.

The existing /ack endpoint and acknowledged_at remain independent and unmodified. New read calls neither acknowledge nor remove messages. Older clients ignore the additive response field and retain their old API compatibility; new clients must call read rather than ack for opening a detail.

Validation: TypeScript check passed. Real Miniflare D1 secure integration suite passed 9/9, including read without acknowledgment, repeated read preserving timestamp, cross-owner rejection, same-owner device without delivery rejection, and acknowledgment preserving read timestamp. Both Workers deployed, both readyz returned 200; worker versions and database column properties are saved in payment-secure-read-readback.json. No real user message state was mutated for live verification. Final device UI read/unread validation belongs to coordinator after iOS integration.
