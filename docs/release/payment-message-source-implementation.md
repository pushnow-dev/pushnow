# Message source implementation

2026-09-13. Completed backend, web and CLI implementation and deployment. No historical message text or attribution was rewritten.

Contract: v1/v2 POST accepts optional source_kind web|cli|api|subscription. Missing input stays NULL in storage and returns unknown. Invalid values (including explicit unknown/null) are rejected with invalid_source_kind. v1 inbox and newly supported GET /v1/secure/messages/:id, v2 list/detail return source_kind, source_name and source_type. Source names/types resolve against account-owned sources; v2 missing source metadata returns null. Attribution is a sender declaration, never an authorization rule.

Migration 0015 adds constrained nullable source_kind to both message tables. Audited both remote schemas before apply, then read back both columns after apply. Existing rows remain NULL. Only optional explicitly supplied sourceKind is appended to the idempotency hash; legacy absent-field hashes and cryptographic AAD are unchanged. Outbox objects retain source_kind for exact retries.

Web playground writes web through TypeScript SDK sourceKind option. Both CLI v1/v2 command paths write cli; reusable preparation APIs keep sourceKind optional. Explicit integrations may send api or subscription. No shipping subscription notification producer was found to modify; local discovery subscriptions are not falsely marked as server message producers. SDKs remain backward compatible and can omit the field. No npm publication.

Validation: backend tsc passed; initial secure/v2 integration regression 48/48, updated secure+v2 schedule 44/44, final secure detail regression 9/9 and final v2 source list/detail suite passed. CLI 18/18. Web check 0 errors/warnings/hints and build 127 pages. Production/sandbox readyz 200. Published webpage JavaScript sourceKind=web asset SHA256 matches local build. See payment-message-source-readback.json for Worker versions and remote schema evidence. No user message state was altered for verification; final iOS visual validation remains coordinator-owned.
