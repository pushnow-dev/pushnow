# Backend payment verification

2026-09-13. Scope: local code review and real local Miniflare D1 tests. No deployment, production data mutation, fabricated purchase event or RevenueCat configuration change in this verification pass.

## Findings and remaining gates

- No new backend authorization or sandbox-grant defect was reproduced in the reviewed paths. This does not establish successful Apple purchase or actual RevenueCat delivery; coordinator and iOS evidence are separate gates.
- Restore across named accounts and anonymous-origin ownership are intentionally not a complete automatic workflow. `revenuecat-client.ts:31` rejects nonmatching original identities; `revenuecat-sync.ts:15` blocks quarantined transfers until operator-reviewed resolution. The product must not promise automatic cross-account restoration while this restriction remains.
- Refund freshness depends on successful webhook processing or authenticated reconciliation. There is no periodic authoritative subscription sweep. If both are absent, previously cached paid access can remain until its stored expiry; ordinary expiry itself is enforced during membership reads (`product-store.ts:278`). Delivery monitoring/retry visibility remains an operational requirement.

## Verified paths

- Real wire format: tests submit `app_id`, `app_user_id`, `event_timestamp_ms`, `transferred_from` and `transferred_to`. `http.ts:29` normalizes nested keys before `revenuecat-routes.ts:13` reads camelCase fields. There is no snake_case mismatch in the current implementation.
- Webhook authentication runs before JSON parsing; app and environment must match. Event fields cannot select a granted plan: entitlement/product fields in the event are ignored and the official subscriber state is fetched instead.
- Cancellation is not automatic immediate revocation: an unsubscribed but unexpired subscription retains Plus500. A refunded authoritative subscription or expired subscription becomes Free, even if the event claims Pro.
- Strict timestamp ordering prevents older ordinary events replacing newer state. Distinct events with equal timestamps refetch. Delayed transfers quarantine affected users regardless of the ordinary watermark, cancel existing reconciliation leases, remove paid state and prevent self-reconciliation resurrecting privileges.
- Client reconciliation accepts only an authenticated session and empty body. It derives `jizhi_<user UUID>` from that session and verifies the stored mapping. The API lookup targets that user only; another account remains Free. A mismatched account mapping fails before fetch.
- Sandbox filtering applies twice: webhook event environment and authoritative subscription `is_sandbox`. A direct client reconcile cannot bypass the second check. Production accepts only non-sandbox App Store subscriptions.
- The active-plan reader selects highest unexpired verified entitlement. Overlapping Pro expiry preserves still-active Plus. Existing quota accounting itself was not altered in this pass.

## Changes and validation

Only `backend/test/revenuecat.test.ts` gained two regression cases: full cancellation/refund/expiry interpretation and successful own-account reconciliation with sandbox/foreign-account negatives. Runtime code and deployed configuration were not changed.

- Initial current-checkout full suite: 7 files, 33 tests passed, 31.40 seconds (the historical baseline was 32; current checkout already included an additional test).
- `npm run check`: passed after the two added cases.
- Final expanded full suite: 7 files, 35 tests passed, 27.93 seconds.

Tests use real local D1 with controlled RevenueCat responses. They do not simulate money movement or count as a real purchase, restore, or delivered production webhook.

## Sandbox and review blocker

Current production-only routing creates a real mismatch for Apple sandbox/TestFlight/review purchases: RevenueCat SDK can report paid sandbox access while the production backend correctly reports Free. Do not relax production filtering. Client comparison should explicitly report this mismatch instead of claiming synchronization succeeded.

The smallest real subscriber-reconciliation experiment can run locally with Wrangler/Miniflare and an isolated local D1 containing migrations0001-0007, a disposable authenticated user whose exact `jizhi_UUID` matches the SDK sandbox purchase, `REVENUECAT_ENVIRONMENT=SANDBOX`, and the existing public subscriber API key. Use separate auth pepper and test login credentials; no production database binding in the test config. Local private R2 can satisfy the Worker binding, though payment-only reconciliation does not access attachments. APNs and email are unnecessary if a local-only fixture supplies a valid login session. Real API egress must remain enabled. This verifies actual RevenueCat sandbox subscriber state into local backend quotas without changing production.

Simulator can target localhost. A physical phone requires an explicitly configured reachable development endpoint; local loopback alone is insufficient. App Review cannot reach the developer's localhost and needs a persistent HTTPS sandbox Worker with its own D1/R2/auth secrets and test-account login. A separate SANDBOX-only RevenueCat webhook and bearer secret are required to validate actual event delivery, but not for explicit client reconciliation. API base-URL selection must be deliberate and constrained to review/test accounts/build configuration; do not let an untrusted environment field redirect production entitlements.

No local live-purchase fixture or dedicated hosted sandbox was created in this pass. Coordinator authorization, disposable account identity alignment and real SDK sandbox purchase remain required before claiming this experiment has passed.

## Reusable live subscriber check

Follow-up added `backend/scripts/verify-sandbox-membership.mjs`. Run from the repository:

```sh
node backend/scripts/verify-sandbox-membership.mjs
```

The script reads the public subscriber key from ignored `.secrets/revenuecat-worker.json` and account UUID from `.secrets/real-device-sender.json`. An optional first argument can point to another private JSON file containing `user_id`. Neither credentials nor identity values are printed. Use an existing SDK customer: RevenueCat's GET-or-create endpoint can create an empty customer for an unknown ID; the script requires HTTP200 and will stop on201. It invokes no receipt submission, entitlement grant or production application API.

Each run creates a fresh isolated local D1/R2 runtime with SANDBOX-only bindings, applies migrations, logs into a random local fixture password and calls the actual authenticated `/v1/me/plan/reconcile` route. That route makes its own real RevenueCat lookup. The result is checked against local D1 before runtime disposal. It does not mutate an existing Simulator fixture or keep a server running.

Executed once successfully for the current existing customer: RevenueCat200, local reconciliation200, **Free, daily limit50, paid sandbox access false**, D1 readback matched. This is a verified real unpaid customer result, not mocked data or evidence of successful payment. After the same app account completes a sandbox purchase, rerun this command to check actual Plus500/Pro-unlimited activation locally without changing production. Restores with ambiguous original ownership still fail explicitly.
