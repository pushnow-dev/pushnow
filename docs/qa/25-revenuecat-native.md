# RevenueCat Native Integration

## Implementation

- Replaced the placeholder entitlement mutation with RevenueCat purchases-ios 5.89.0, pinned exactly through Swift Package Manager. Package resolution succeeded locally.
- The `default` offering maps `plus_monthly` to `com.createitv.pushnow.plus.monthly` and `pro_monthly` to `com.createitv.pushnow.pro.monthly`. These identifiers were independently read back from the existing RevenueCat catalog. Annual products remain outside this monthly-only UI; no invented annual prices.
- UI prices come from `StoreProduct.localizedPriceString`. Missing packages are unavailable, not substituted with hardcoded prices or local entitlements.
- CustomerInfo active entitlements are the only local access source. Failed RevenueCat response verification is rejected. Expired access is applied before fetching offerings, so an offering failure cannot retain expired access.
- Authenticated identities use `jizhi_<lowercase account UUID>`, matching the backend's persisted RevenueCat ID. Login, logout, refresh, restore, sync, and purchase operations are serialized. Auth changes synchronously invalidate displayed access, with generation checks around async SDK results.
- SDK customer-info delegate updates trigger an authoritative refresh rather than directly applying potentially stale callback contents.
- Cancellation is distinct from failure. Deferred transactions remain pending with no local access grant. Redemption completion uses `syncPurchases`, not an assumed entitlement. Restore is explicit user action.
- Public iOS SDK configuration is read from the `RevenueCatAPIKey` Info.plist value, backed by build setting `REVENUECAT_PUBLIC_SDK_KEY`. Only `appl_` keys are accepted. No secret API key belongs in the client.

## Verification

Seven injectable-adapter tests in `RevenueCatServiceTests.swift` passed on iPhone 16 Pro / iOS 18.4: identity and live-price mapping, purchase/restore entitlement authority, cancellation/pending ViewModel states, expired-access catalog failure, logout versus delayed purchase, redemption synchronization without invented access, and invalid-key/signed-out behavior. Evidence: `/tmp/pushnow-payment-tests.log`, `TEST SUCCEEDED`, 7 tests and 0 failures. These are deterministic adapter tests, not sandbox transaction proof.

The device-signed build succeeded at `/tmp/pushnow-payment-real/Build/Products/Debug-iphoneos/JiZhi.app`. Artifact readback confirmed a public iOS SDK key was actually present in Info.plist, with the correct bundle and iOS 18 minimum. An explicit partial `JiZhi/App/Info.plist` was needed because the generated plist omitted the custom build-setting key. The value is not reproduced here.

CLI `devicectl` installed and launched this build on the connected iPhone 15 Pro. An initial 35-second attachment had no product result, so a DEBUG-only `--payment-diagnostics` launch switch was added. Its sanitized JSON emits only configuration/sign-in booleans, package/product identifiers, prices, and safe error codes; no account identifiers, tokens, keys, or message contents.

The rebuilt, signed, and installed app completed a real SDK refresh on the phone with `configured=true` and `signedIn=true`. Returned live products were `plus_monthly` / `com.createitv.pushnow.plus.monthly` at CNY 8.00 and `pro_monthly` / `com.createitv.pushnow.pro.monthly` at CNY 18.00. **Live product loading passed.** Evidence: `/tmp/pushnow-payment-diagnostics.log`, marker `PUSHNOW_PAYMENT_DIAGNOSTICS` with `phase=completed`. No GUI, purchase, restore, or redemption interaction was performed. The console attachment was bounded to 60 seconds.

## Remaining Release Gates

The coordinator retrieved the correct public iOS SDK key from the authorized RevenueCat dashboard. It is now configured in both Debug and Release build settings; the key value is intentionally omitted from this report. App Store Connect/subscription credential and backend production setup are separately owned by the coordinator. No real purchase, sandbox purchase, restore transaction, offer-code redemption, or paid backend quota transition was executed by this implementation agent.

The backend's authoritative plan-reconciliation endpoint is a separate integration boundary; this client does not make an undeployed endpoint mandatory for successful StoreKit completion. Server quotas must continue to trust server RevenueCat validation/webhooks, never client entitlement claims.

## Sources

- [Official iOS SDK installation](https://www.revenuecat.com/docs/getting-started/installation/ios)
- [Customer identity guidance](https://www.revenuecat.com/docs/customers/identifying-customers)
- [Pinned release 5.89.0](https://github.com/RevenueCat/purchases-ios/releases/tag/5.89.0)
