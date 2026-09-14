# Membership bridge production deployment

Authorized production rollout on 2026-09-13. Supersedes the local-only/configuration-blocked status in reports 27 and 28.

## Credential scope

RevenueCat's official [API v1 authentication](https://www.revenuecat.com/docs/api-v1), [API key guide](https://www.revenuecat.com/docs/projects/authentication), and [customer endpoint](https://www.revenuecat.com/docs/api-v1/customers) support the public app key for subscriber lookup. The Worker uses only the official GET subscriber endpoint, never privileged entitlement-grant or customer-delete endpoints.

Renamed the binding to `REVENUECAT_SUBSCRIBER_API_KEY`: this is the public iOS app key, not a privileged RevenueCat secret. It is kept in a Worker secret binding to avoid printing it in deployment output. `REVENUECAT_WEBHOOK_SECRET` is a separate randomly generated 48-byte bearer secret. Both were loaded from ignored `.secrets/revenuecat-worker.json` (0600) without printing values. No broad RevenueCat API secret was created.

A real query for an existing production application's mapped user returned HTTP 201 because that RevenueCat customer had not yet existed. A repeated query returned HTTP 200. Both original identities matched exactly, snapshot timestamps were current, and entitlements were empty. This proves API compatibility, not a purchase or paid entitlement.

## Rollout evidence

- Before mutation: production had migrations 0001-0006, no RevenueCat tables, and zero duplicate non-null customer identity groups.
- Private backup: `/tmp/pushnow-prod-before-29.ws0jSv/production.sql`, directory0700/file0600, 27736 bytes.
- Applied only `0007_revenuecat_bridge.sql`. Readback confirms all seven migrations, the unique identity index and three RevenueCat tables.
- Configured app `appfdd73d89a1`, explicitly `REVENUECAT_ENVIRONMENT=PRODUCTION`. Existing D1, private R2, APNs and auth bindings preserved.
- Deployed Worker version `9d74cabe-e613-409a-b658-c7c753427040` to `api.pushnow.dev/*`; one-minute cron retained. Bundle136.62KiB, gzip28.59KiB.
- Live health200; unauthenticated webhook401; correctly authenticated SANDBOX event400. Negative probes do not grant membership.
- Final renamed-binding focused suite: seven tests passed (7.36 seconds). `npm run check` passed.

Coordinator owns creation and saved readback of the RevenueCat webhook integration using the same private bearer value. Real sandbox/production purchase, restore, RevenueCat event delivery and paid quota enforcement remain separate verification gates. Production never accepts sandbox subscriptions; isolated sandbox infrastructure requirements remain as documented in report28. Transfers and anonymous-origin ownership ambiguity still fail closed.

## Post-configuration synthetic verification

After the coordinator reported integration `whintgr7a285d9b21` created and read back, a direct synthetic `TEST` event was sent using the same private bearer header. Event `qa-synthetic-test-39cf1a89-15aa-4931-ae64-38e012e87d3c` returned HTTP200 `processed`; an identical retry returned HTTP200 `duplicate`. Production D1 readback confirms status `processed` and zero RevenueCat entitlement-state rows. No fabricated purchase event was submitted. This proves endpoint authentication and event deduplication only, not actual RevenueCat delivery or payment.

Full post-rename regression command `npm test -- --maxWorkers=1 --fileParallelism=false`: **7 files, 32 tests passed**, 25.85 seconds. No test process remains running.
