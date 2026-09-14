# iOS Payment Verification

## Review and Repairs

The previous client updated RevenueCat entitlements but never called the backend membership-reconciliation endpoint. This was a real integration gap: a successful store transaction could leave notification quotas waiting for an independent webhook.

- `RevenueCatService` now reconciles after successful customer-info refresh, purchase, explicit restore, and redemption synchronization. The AppEnvironment binding sends authenticated `POST /v1/me/plan/reconcile` with an empty JSON object. It never sends a client-asserted plan, receipt, or sandbox override.
- Auth user ID and generation are checked before token acquisition, before the request, and after the response. SDK operations remain serialized under the `jizhi_<lowercase account UUID>` identity, with immediate logout invalidation and late-result rejection.
- The response's `membership.plan` is parsed and compared with SDK access. A successful HTTP response with a different plan does not count as completed synchronization. The SDK plan and server-confirmed plan remain distinct; sandbox access is not claimed as production quota access.
- Failed reconciliation does not misreport an already successful store transaction as a failed purchase. The app retains verified SDK access and shows a synchronization-pending warning with a visible refresh action and pull-to-refresh retry.
- Backend reconciliation occurs before offering loading during refresh, so a catalog failure cannot prevent an otherwise valid quota retry.
- The redemption sheet requires a verified app login and retains the opening auth generation. A callback from a sheet opened for a different session is discarded. Completing the sheet still only triggers SDK synchronization, never a local entitlement grant.
- PaywallViewModel reset now invalidates every in-flight result, including failure and cancellation paths. An old account's completion cannot overwrite the new screen state.

## Focused Tests

`/tmp/pushnow-payment-verification-tests.log`: **TEST SUCCEEDED**, 16 tests, 0 failures, iPhone 16 Pro / iOS 18.4. This comprises 12 RevenueCat adapter tests and 4 existing auth-session race tests.

The new payment regressions cover all four reconciliation triggers, correct account propagation, a successful store result followed by backend failure and refresh retry, SDK/server mismatch, logout during backend synchronization, and resetting a ViewModel while a purchase is pending. Existing tests cover live-price mapping, no invented access, restore, cancellation, pending approval, expired access with catalog failure, logout versus purchase completion, redemption without access, and missing configuration/login.

These deterministic tests do not perform a real transaction. No browser, store purchase confirmation, restore confirmation, or code redemption was operated by this agent.

## Device Verification

The signed rebuild passed (`/tmp/pushnow-payment-verification-real.log`), and CLI installation on the existing paired iPhone 15 Pro succeeded (`/tmp/pushnow-payment-verification-install.json`). The installed artifact is `/tmp/pushnow-payment-real/Build/Products/Debug-iphoneos/JiZhi.app`.

Real phone launch diagnostics completed with `configured=true`, `signedIn=true`, `sdkPlan=free`, `serverPlan=free`, and `serverSyncPending=false`. The real SDK catalog again returned Plus monthly at CNY 8.00 and Pro monthly at CNY 18.00. Evidence: `/tmp/pushnow-payment-verification-diagnostics.log`. This verifies the current account's actual free-plan backend reconciliation and product fetch, not a paid transaction. The existing login was preserved.

The bounded console session ended, then a normal launch without diagnostic arguments succeeded (exit 0), recorded in `/tmp/pushnow-payment-verification-normal-launch.json`. No build, test, or console session remains running under this agent.

DEBUG-only diagnostics are launched with `--payment-diagnostics`; normal launches emit none. The marker includes only configuration/sign-in booleans, product/package IDs, localized prices, SDK plan, server-confirmed plan, synchronization-pending status, and safe error codes. It excludes keys, tokens, user IDs, and message content.

```sh
xcrun devicectl device process launch --device <paired-device-id> --terminate-existing --console --timeout 60 com.createitv.pushnow --payment-diagnostics
```

## Remaining Transaction Gates

Real sandbox purchase approval, cancelled store sheet, deferred purchase approval, restore on another installation, offer-code redemption, renewal/expiry/refund, and paid server-quota activation still require transaction evidence. No paid transaction was performed in this pass. Store product loading, a free-plan reconciliation response, and passing adapter tests are not substitutes for those gates.
