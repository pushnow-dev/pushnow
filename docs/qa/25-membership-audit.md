# Membership Live Audit

Date: 2026-09-13. Read-only audit; no catalog, pricing, credential, offer-code, or production purchase writes performed.

## RevenueCat MCP Readback

- Project `proj4269c63c`; App Store app `appfdd73d89a1`, bundle `com.createitv.pushnow`.
- App Store Connect API key configured: **false**. Subscription key configured: **false**.
- Offering `ofrng8c206301a1`, identifier `default`: active and current.
- Entitlements `plus` (`entl36f1e6a695`) and `pro` (`entleb2d79baee`): active. Expanded product attachments were independently read back.

| Package | Store product identifier | Entitlement | ASC ID | ASC state | Current China price |
| --- | --- | --- | --- | --- | --- |
| plus_monthly | com.createitv.pushnow.plus.monthly | plus | 6811365720 | MISSING_METADATA | CNY 8/month |
| plus_annual | com.createitv.pushnow.plus.yearly | plus | 6811365755 | MISSING_METADATA | None returned |
| pro_monthly | com.createitv.pushnow.pro.monthly | pro | 6811365836 | MISSING_METADATA | CNY 18/month |
| pro_annual | com.createitv.pushnow.pro.yearly | pro | 6811365781 | MISSING_METADATA | None returned |

Public SDK key: existing `AppConfiguration` was nil at audit start. Current exposed RevenueCat MCP tools stop alphabetically at `get_overview_metrics`; no SDK-key read/list tool is callable. `get_app` returns configuration booleans, not an SDK key. Retrieval remains blocked through the required MCP surface; no dashboard/API bypass was attempted. No key value is printed here.

## App Store Connect

Live `asc subscriptions list --group-id 22379561 --paginate` and `asc subscriptions pricing summary --app 6811365630 --territory CHN` confirm the table above. All four `asc subscriptions offers offer-codes list --subscription-id … --paginate` calls returned no entries.

Subscription levels currently differ by duration: Pro monthly level 1, Plus monthly 2, Pro yearly 3, Plus yearly 4. This needs review before annual launch: equivalent-duration variants of the same tier should not unintentionally invert the Plus/Pro upgrade relationship. No hierarchy changes made.

Annual prices must not be invented. Hide unavailable annual products or explicitly decide their prices before launch. Missing metadata blocks submission readiness, but must **not** be represented as proof that sandbox purchase is impossible. Apple explicitly says sandbox does not require prior App Review submission. Product configuration, agreements, availability, signed build and tester environment still need real verification. [Apple TN3186](https://developer.apple.com/documentation/technotes/tn3186-troubleshooting-in-app-purchases-availability-in-the-sandbox)

Previous release audit identifies missing review screenshots. This audit reconfirmed aggregate MISSING_METADATA state, not each screenshot relationship. Agreements/banking/tax and sandbox account readiness were not audited. No purchase, restore or code redemption was executed.

## Native Redemption and Entitlement Refresh

For the iOS 18 baseline use `import StoreKit` and `.offerCodeRedemption(isPresented:onCompletion:)`. The installed Xcode `_StoreKit_SwiftUI.swiftinterface` lines 504-507 confirms availability iOS 16+ and callback `Result<Void, Error>`. Do not use the newer beta `options:` overload as an iOS 18 API. [Apple API](https://developer.apple.com/documentation/swiftui/view/offercoderedemption(ispresented:oncompletion:))

The completion does not provide a verified paid entitlement. RevenueCat transaction processing and CustomerInfo updates must drive the membership state, never sheet dismissal. Observe updated CustomerInfo; returning from an external App Store redemption link requires purchase synchronization, with user-initiated restore available. RevenueCat documents inconsistent sandbox/TestFlight redemption-sheet behavior and requires an in-app purchase key for offer-code tracking. No offer codes currently exist in this catalog. [RevenueCat offer-code guidance](https://www.revenuecat.com/docs/subscription-guidance/subscription-offers/ios-subscription-offers)

## Minimal Repair and Verification Order

1. Obtain the public iOS SDK key through an available authorized RevenueCat MCP read tool; configure the existing app. Connect the proper Apple credentials in RevenueCat without exposing private keys.
2. Finish the actual RevenueCat SDK service; use stable authenticated account IDs, actual StoreProduct prices/packages, centralized `plus`/`pro` entitlements, purchase/cancel/pending/error/restore states. SDK integration is being implemented by the iOS owner.
3. Keep initial purchasable scope monthly unless annual prices/hierarchy are deliberately resolved. Complete required ASC review metadata before submission.
4. Verify sandbox purchase, restore, account-switch isolation, renewal/expiration and server entitlement synchronization. StoreKit local testing is useful but is not RevenueCat/Apple sandbox proof.
5. Configure offer codes deliberately before claiming successful redemption, then prove the native sheet transaction updates RevenueCat CustomerInfo and the correct signed-in account. A visible native sheet alone is not a redeemed membership.

This report does not verify the backend RevenueCat webhook or claim that paid server quotas now synchronize; that requires separate signed event and server readback evidence.

## Membership UI Source Review

- **P2: stale pending approval state.** `JiZhi/ViewModels/PaywallViewModel.swift:7` stores `isPending`, sets it on pending purchase at line 37, and only clears it when another purchase begins at line 28. Successful restore/redemption/refresh and account changes do not reconcile it. `MembershipContentView.swift:55` can therefore continue showing an approval-waiting banner after membership activates, or after switching accounts. Reconcile the banner against verified entitlement updates and clear account-specific pending state on account change. Reported to the coordinator; no source edits made by this review.
- Prices are sourced from RevenueCat `StoreProduct.localizedPriceString`; adapter mapping permits only the two audited monthly products. The UI does not display unpriced yearly plans or use legacy hardcoded prices. `MembershipContentView.swift:80` disables the free/current/unavailable plan purchase action; the free choice is not presented as a paid transaction.
- Native redemption uses the iOS 18-compatible system sheet. Completion initiates RevenueCat synchronization; it does not directly grant membership. The redeem button still cannot prove a usable code exists: live catalog readback above found none.
- Comparison features match the implemented encrypted push, multi-device, history, HTTP and CLI surfaces. Pro's “Unlimited” is a daily membership quota statement, not unlimited attachment size, API rate, or abuse allowance; these other operational limits remain applicable.
- Added UI and payment-state keys are present in all six app locales. Platform-provided error descriptions and StoreProduct prices intentionally remain runtime strings. Source review does not establish narrow-screen translation layout quality; Simulator visual verification remains with the coordinator.

Scope: read-only UI/service source review, no Simulator interaction, purchase or redemption performed.
