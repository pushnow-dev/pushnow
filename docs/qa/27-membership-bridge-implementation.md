# Local RevenueCat membership bridge

Implemented locally after the findings in audit 26. No production migration, deployment, RevenueCat configuration or secret mutation was performed.

## Interfaces and trust

- `POST /v1/webhooks/revenuecat`: requires the exact `Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>` value, validated with constant-time digest comparison before reading the body. Secrets shorter than 32 characters or missing app configuration fail closed. Event app ID and environment must match server configuration.
- `POST /v1/me/plan/reconcile`: requires a valid app login and an empty JSON body. Clients cannot select a target user, product, entitlement or plan. Returns `{membership}` after server verification.
- Both resolve the stored `users.revenuecat_app_user_id` mapping, strictly `jizhi_<lowercase UUID>`. The server queries the official RevenueCat subscriber endpoint using its private API credential. Neither event product fields nor client purchase claims directly grant access.
- Customer snapshots must be current, have the exact matching named original account, and contain exact catalog products for `plus`/`pro`. Anonymous-origin snapshots fail closed: the v1 response does not prove exclusive named-alias ownership. Anonymous-to-login migration and ambiguous restore ownership therefore require a verified ownership resolution before access can be granted. Only App Store subscriptions in the configured sandbox/production environment are accepted. Refunds, expired subscriptions and unknown products do not grant access. Grace-period expiry is considered together with entitlement and subscription expiry.

## Persistence and ordering

- Additive migration `0007_revenuecat_bridge.sql` adds event deduplication, per-account reconciliation leases, monotonic event/snapshot markers and individually expiring Plus/Pro entitlement rows. Applied migrations were not changed.
- Duplicate processed events do not refetch or grant twice. Event ID reuse with a different payload is rejected. Older ordinary events cannot overwrite a newer processed state; distinct events sharing a timestamp still refetch authoritative state. A stale API snapshot or lost lease cannot commit privileges.
- The active-plan reader uses the highest unexpired authoritative entitlement. This preserves Plus when an overlapping Pro entitlement expires, rather than falling directly to Free. Existing quota implementations are otherwise unchanged.
- Transfers are deliberately **quarantined**, not automatically reassigned: known affected accounts are atomically set Free and blocked from subsequent automatic reconciliation, even when transfer delivery is delayed behind newer ordinary events. Old events or self-reconciliation cannot resurrect transferred access. Unknown but syntactically valid account IDs do not prevent revocation of known accounts. RevenueCat anonymous IDs grant no application account access.
- Transfer quarantine requires a future operator-reviewed authoritative resolution workflow. Do not present transfer support as fully automated. This fail-closed restriction is a material launch/support limitation.

## Configuration required before deployment

| Name | Type | Purpose |
| --- | --- | --- |
| `REVENUECAT_API_SECRET` | Worker secret | RevenueCat server credential for authoritative subscriber lookup |
| `REVENUECAT_WEBHOOK_SECRET` | Worker secret | Random webhook authorization secret, at least 32 characters |
| `REVENUECAT_APP_ID` | Server configuration | Expected RevenueCat app identifier, currently documented as `appfdd73d89a1` but must be read back before configuration |
| `REVENUECAT_ENVIRONMENT` | Server configuration | `PRODUCTION` by default, or explicitly `SANDBOX` in an appropriate test environment |

Migration 0007 must be applied before deploying code that reads the new entitlement-state table. Credentials/configuration are currently unverified/unavailable for a live purchase test. Missing server credentials return explicit 503 errors and leave entitlements unchanged. Do not expose either secret in app build settings or logs.

## Validation

- Focused command: `npx vitest run test/revenuecat.test.ts --maxWorkers=1 --fileParallelism=false`: **7 tests passed** using real local Miniflare D1 and controlled authoritative API responses.
- Cases cover official lookup URL/account-alias rejection, exact product/expiry/grace/refund/environment interpretation, forged webhook authentication, malformed identity, event deduplication, old-event resurrection prevention, overlapping plan expiry, concurrent synchronization, transfer quarantine, client-selected identity/plan rejection and missing credentials.
- `npm run check`: passed. No broad test suite was restarted as part of this bounded task.
- Real RevenueCat delivery, real sandbox purchase/restore and resulting production API quota enforcement remain unverified. The plaintext quota-accounting findings from audit 26 were intentionally not changed in this task.

## Official references

The implementation follows the documented [subscriber lookup](https://www.revenuecat.com/docs/api-v1/customers) and treats [webhook events](https://www.revenuecat.com/docs/integrations/webhooks/event-types-and-fields) as reconciliation triggers. Webhook transport authentication is described in [RevenueCat's webhook documentation](https://www.revenuecat.com/docs/integrations/webhooks). These references do not replace live configured-event or purchase verification.
