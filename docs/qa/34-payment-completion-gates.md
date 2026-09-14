# Payment completion gates

Verified 2026-09-13 with ASC CLI, RevenueCat CLI/MCP, local tests and physical-device CLI installation. This report supplements reports 30-33; it does not certify a completed paid transaction.

## Completed in this pass

- Re-audited saved Apple credentials, current default offering and product-to-entitlement attachments. Plus monthly maps to plus; Pro monthly maps to pro. Product IDs match ASC and the native adapter.
- Confirmed monthly prices CNY 8/18, 175 available territories, correct monthly upgrade hierarchy and six metadata locales. No price, product or agreement changes were made.
- Fixed the missing iOS authenticated membership-reconciliation call after purchase, restore, redemption and refresh. A successful store result is not reported as a failed purchase merely because server synchronization fails.
- Added explicit SDK/server mismatch detection, a retry action and six-language synchronization messages. Added account-generation protection for late payment and redemption callbacks.
- Native focused suite: 16 tests passed. Backend expanded suite: 35 tests passed, TypeScript check passed. Modified payment files remain within the project file-size limits; git diff --check passed.
- Signed native build installed on the paired physical phone without removing the account. Actual device diagnostics returned configured=true, signedIn=true, sdkPlan=free, serverPlan=free, serverSyncPending=false, and both real monthly products. See report 31.
- Added an isolated local sandbox verifier. The coordinator fixed its esbuild working-directory resolution and bounded the initial RevenueCat lookup to 12 seconds, then reran it from the repository root successfully. Real customer lookup200, actual local authenticated reconcile200, Free50, matching D1 readback, no production writes.
- Both in-app legal destinations currently return HTTP200: https://pushnow.dev/privacy/ and https://pushnow.dev/terms/. Reachability is not legal-content approval.

## Required before claiming purchase completion

1. Complete an Apple sandbox purchase on the installed app using the same signed-in app account. Confirm the system sheet is a sandbox purchase; do not use a real-money purchase as a test.
2. Verify the transaction and matching account entitlement in RevenueCat, not just a success message in the app.
3. Run `node backend/scripts/verify-sandbox-membership.mjs` to verify actual sandbox entitlement-to-quota synchronization in isolated local D1. Plus should produce500 daily, Pro unlimited. A Free result is not a paid-test pass.
4. Exercise restore and code redemption, then repeat account/entitlement verification. Test expiry/refund and reject foreign-account restoration; issuance of codes alone proves neither redemption nor membership.
5. For end-to-end physical-device or App Review sandbox quota use, provide a persistent isolated HTTPS sandbox backend and explicit test routing. Production currently and intentionally rejects sandbox entitlements. The local verifier is not a hosted test environment.

## Remaining release prerequisites

- Both monthly ASC products remain MISSING_METADATA with empty review-screenshot relationships. Capture the actual configured membership page, upload its review screenshots and read back processing/state before submission.
- Paid Apps Agreement, banking and tax readiness remain unverified: the available public ASC API does not expose them. Successful API access does not establish these financial prerequisites.
- Apple-to-RevenueCat production/sandbox notification URLs are still null. Obtain the actual app-specific URL from RevenueCat, set both ASC URLs and V2 versions through the official API, and verify a test notification. No URL was guessed. The already configured RevenueCat-to-Worker webhook is a separate integration.
- Actual RevenueCat-origin webhook delivery has not been proved. Earlier synthetic TEST processing verifies endpoint authentication and deduplication only.
- Annual products remain outside the purchase UI and unpriced; no annual purchase readiness is claimed.

The missing Apple server notification URL primarily affects notification latency and refund update freshness; it is not by itself proof that SDK purchases cannot work. [RevenueCat Apple server notifications](https://www.revenuecat.com/docs/platform-resources/server-notifications/apple-server-notifications)

No real-money purchase, App Store submission, agreement acceptance or production entitlement grant was performed in this pass.
