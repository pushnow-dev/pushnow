# Membership backend audit

Audit date: 2026-09-13. Read-only source/configuration audit, including the existing RevenueCat configuration report. No source edits, purchases, webhook creation, deployment, secret changes or production record writes were performed.

## Conclusion

Real purchases cannot currently enable backend Plus/Pro limits. The quota reader supports Free 50, Plus 500 and Pro unlimited **if** a valid entitlement row already exists, but there is no implemented path from RevenueCat purchase state to that row. The catalog configuration report is not evidence of purchase-to-quota synchronization.

## Release blockers and findings

### P1 - No authenticated RevenueCat ingestion or reconciliation

`backend/src/index.ts` has no RevenueCat webhook route. Searching all backend source finds no entitlement insert/update writer or RevenueCat customer reconciliation call. `backend/src/product-store.ts:278` only reads `entitlements`, defaulting an absent/expired row to Free via `product-service.ts:206`.

Current production readback: `entitlements` contains zero rows; there are two users and both have a RevenueCat app-user mapping field. Only the `entitlements` table exists among webhook/RevenueCat/entitlement-related tables. The live Worker secret-name list includes APNs credentials, `AUTH_TOKEN_PEPPER` and `PUSH_TOKEN_ENCRYPTION_KEY`; it does **not** include `REVENUECAT_WEBHOOK_SECRET` or a RevenueCat server API credential. No secret values were read or printed.

Therefore webhook authentication, replay deduplication, event ordering, refunds/revocations, billing grace periods, transfers/aliases and renewal synchronization are **not implemented**, rather than verified secure. Do not add a public webhook pointing at this Worker and call the purchase flow complete.

Required implementation: authenticated RevenueCat webhook and authoritative customer reconciliation; a durable event ID/ordering record; explicit allowed project/app/environment and entitlement IDs; account mapping to the application's authenticated user; atomic update of the effective highest active plan and expiry. Authentication must fail closed before processing a body, and duplicates/out-of-order events must not downgrade a newer entitlement. Sandbox and production entitlement policy must be explicit.

### P1 - Current native payment service does not perform a real purchase

The inspected `JiZhi/Services/Payments/RevenueCatService.swift:15` treats any nonempty API key as configured. `purchase(plan:)` at line 27 only inserts a local entitlement string; it does not call the RevenueCat SDK. Refresh and restore are effectively no-ops after the configuration check. This can make the UI appear upgraded while the backend remains Free.

The real SDK must identify the same account used for server reconciliation. `backend/src/auth-service.ts:83` assigns `jizhi_<user UUID>` to `users.revenuecat_app_user_id`; the implementation must deliberately use or migrate that exact mapping, rather than accidentally mixing anonymous SDK IDs, bare user UUIDs and the prefixed identifier.

### P2 - Plaintext ingest can consume quota without creating a message

`backend/src/product-service.ts:103` consumes usage before title/content/reminder validation and before `createItemWithBlocksAndReminder`. Invalid input (for example a missing title at line 112), a later database failure, or two concurrent calls with the same idempotency key can increase usage without an additional accepted message. The increment itself is outside the message transaction (`product-store.ts:297`). Concurrent requests at the limit can also leave the counter above the limit despite one request being rejected.

Move validated plaintext message insertion, quota reservation and idempotency into one atomic operation, matching the secure paths. The same user's plaintext failure currently reduces their secure v1/v2 allowance because all three routes share `notification_events`.

### P2 - Pro usage is not counted, so displayed daily usage and same-day downgrade behavior are incomplete

All three paths skip the usage increment entirely when the plan limit is null (`product-service.ts:209`, `secure-messages.ts:68`, `v2-messages.ts:30`). Unlimited sending works, but `usedToday` omits Pro-period traffic. If a Pro entitlement expires or is revoked later in the same UTC day, only pre-Pro counted usage participates in the newly active limit.

Decide whether usage means all accepted messages or only limited-tier messages. If it means all accepted messages, count Pro traffic while omitting only the enforcement check. This also makes billing/support usage evidence accurate without restricting Pro.

## What already works conditionally

| Area | Source evidence | Current behavior |
| --- | --- | --- |
| Plan limits | `membership.ts:3` | Free 50, Plus 500, Pro null/unlimited |
| Expiry read | `product-store.ts:280` | Rows whose expiry is in the past are ignored; absent rows fall back to Free |
| Secure v1 | `secure-messages.ts:67` | Message, quota increment/check and envelopes share a D1 transaction; duplicate ingestion does not charge again |
| Secure v2 | `v2-messages.ts:29` | Message, quota increment/check, attachment commitment and deliveries share a D1 transaction |
| User isolation | Source authentication and ownership checks | The source key determines whose plan and shared counter are used |
| Quota semantics | `membership.ts:28` and ingest calls | UTC calendar day, charged at message acceptance; one message counts once even when targeting multiple devices or using inbox-only delivery |

Expiry filtering alone is not subscription lifecycle synchronization: a nullable expiry permits indefinite access if a writer supplies it, and no writer currently updates cancellation/refund state. Subscription cancellation must not blindly remove access before the paid entitlement actually ends.

The dormant `planForRevenueCatProduct` helper uses substring matching (`membership.ts:21`) and is not currently called by a webhook. Do not use that helper as the security boundary for future external events; use an exact entitlement/catalog mapping and resolve the effective current entitlement.

## Required acceptance tests

1. Real SDK sandbox purchase and restore produce a server-verified entitlement for the same app account; `/v1/me/plan` then returns Plus 500 or Pro unlimited.
2. Missing/wrong webhook authorization, wrong app/project/environment and unknown users cannot change entitlements. Valid duplicate events change state once; stale events do not regress newer state.
3. Renewal, expiry, refund/revocation, upgrade/downgrade, overlapping Plus/Pro entitlements and account transfer/alias cases reconcile correctly. Verify expiry boundaries using server time.
4. Across plaintext, secure v1 and secure v2, combined accepted traffic reaches 50/500 exactly; the next request fails without committing a message or consuming extra usage. Concurrent duplicates and invalid plaintext input do not spend quota.
5. Pro accepts traffic beyond 500, with the chosen usage-counting and same-day expiry semantics. A scheduled message is charged at acceptance, not again at dispatch; multi-device delivery does not multiply message usage.
6. A successful purchase must be followed by saved production/sandbox entitlement readback and actual API-limit behavior. UI success, catalog existence or webhook HTTP 200 alone is insufficient.

## Evidence limits

Production inspection read only aggregate counts, schema names and secret names. No customer emails, tokens, private keys or purchase payloads were exposed. This audit did not run a purchase or mutation-based quota test, and the RevenueCat/ASC catalog itself was not freshly audited here; its state comes from `docs/release/16-revenuecat-configuration-report.md` and may have changed. Existing backend tests cover portions of quota enforcement but do not establish purchase-to-entitlement synchronization.
