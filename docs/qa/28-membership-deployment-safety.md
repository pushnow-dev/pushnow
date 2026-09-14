# Membership deployment safety audit

Read-only production audit on 2026-09-13. No migration, deployment, remote secret change or RevenueCat key creation was performed.

## Observed state

- Active deployment: `4bb8a768-a1ba-48af-bb6f-849043a352b8`, created 2026-09-12 15:30:44 UTC.
- Production D1 has migrations 0001 through 0006. Wrangler reports only `0007_revenuecat_bridge.sql` pending.
- Existing RevenueCat tables: zero. Duplicate non-null RevenueCat user identity groups: zero, so the new unique index has no observed data conflict.
- Secret-name audit found APNs credentials, auth pepper and push-token encryption key; neither RevenueCat API nor webhook secret is configured.
- Local production config now explicitly sets `REVENUECAT_ENVIRONMENT=PRODUCTION`. Final `wrangler deploy --dry-run` passes with this binding, D1 `jizhi-production`, private R2 `pushnow-secure-blobs`, and the existing production route. Bundle is 136.61 KiB (28.58 KiB gzip).

## Minimal production rollout gate

1. Read back the RevenueCat app ID and private server API capability. Keep the public SDK key separate from server credentials. Configure the webhook to deliver only production events to `https://api.pushnow.dev/v1/webhooks/revenuecat` with a fresh random bearer secret of at least 32 characters.
2. Save a private D1 backup before the additive migration. Re-list pending migrations and apply only 0007. Verify the three new tables and unique index before deploying this code: membership reads now require the new table even when payment is unconfigured.
3. Set the two server secrets privately and the verified app ID. Preserve `REVENUECAT_ENVIRONMENT=PRODUCTION`. Deploy the reviewed current bundle, preserving existing bindings and secrets.
4. Read back deployment/version and health. Test unauthorized webhook rejection, wrong-environment rejection and an authenticated free account's membership. Only a real production purchase and authoritative server readback establish production paid access; webhook HTTP 200 alone does not.
5. Rollback code can leave additive tables in place. Do not roll back by dropping tables or resetting user identities.

The source currently fails closed on missing credentials, named identity conflicts, anonymous-origin subscribers without provable ownership, and transfers requiring review. These limitations remain regardless of successful deployment.

## Sandbox isolation

Never set the production Worker to `SANDBOX`. Webhook environment filtering and subscriber `is_sandbox` filtering both enforce the selected environment. Production explicitly requires non-sandbox subscriptions, including self-reconciliation where there is no webhook environment field.

A real Apple sandbox/TestFlight purchase test that exercises backend quotas needs a dedicated Worker (for example `jizhi-api-sandbox`) with a distinct D1 database, private R2 bucket, auth pepper, push-token encryption key, webhook secret and hostname. Do not inherit the production D1/R2 route bindings through a partial Wrangler environment override. Configure a separate sandbox-only RevenueCat webhook. Test accounts and app API base URL must target that isolated Worker. APNs credentials are optional for payment-only tests; any sandbox APNs test must register test devices in the isolated database and cannot reuse production device rows.

No sandbox resources were created in this audit. No webhook secret was generated yet; the coordinator owns credential creation and private transfer to the dashboard/Worker to avoid competing secret values.
