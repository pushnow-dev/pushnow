# RevenueCat Configuration Report

> Date: 2026-09-12
> Scope: RevenueCat project bootstrap, App Store app mapping, subscription catalog, entitlement mapping, App Store Connect pricing, localization, and review boundary.

## RevenueCat Readback

RevenueCat project and catalog were created and read back successfully.

| Resource | ID | Identifier | Status |
| --- | --- | --- | --- |
| Project | `proj4269c63c` | `JiZhi PushNow` | Created |
| App Store app | `appfdd73d89a1` | `com.createitv.pushnow` | Created |
| Offering | `ofrng8c206301a1` | `default` | Active and current |
| Plus entitlement | `entl36f1e6a695` | `plus` | Active |
| Pro entitlement | `entleb2d79baee` | `pro` | Active |

The RevenueCat app readback confirms:

- App type: `app_store`
- Bundle ID: `com.createitv.pushnow`
- Custom URL scheme: `rc-fdd73d89a1`
- App Store Connect API key configured: `false`
- Subscription key configured: `false`

## Products

| Plan | Product ID | RevenueCat product ID | Type | Entitlement |
| --- | --- | --- | --- | --- |
| Plus monthly | `com.createitv.pushnow.plus.monthly` | `prodb87bf8275c` | Subscription | `plus` |
| Plus yearly | `com.createitv.pushnow.plus.yearly` | `prode436244da2` | Subscription | `plus` |
| Pro monthly | `com.createitv.pushnow.pro.monthly` | `prod8caca76845` | Subscription | `pro` |
| Pro yearly | `com.createitv.pushnow.pro.yearly` | `prod6e3c9f898f` | Subscription | `pro` |

## Offering Packages

| Package | Package ID | Product ID |
| --- | --- | --- |
| `plus_monthly` | `pkgef1d4fdc743` | `com.createitv.pushnow.plus.monthly` |
| `plus_annual` | `pkge104b7eb494` | `com.createitv.pushnow.plus.yearly` |
| `pro_monthly` | `pkgeb1f0fc9b5e` | `com.createitv.pushnow.pro.monthly` |
| `pro_annual` | `pkged6a9aa3bdc` | `com.createitv.pushnow.pro.yearly` |

The `default` offering metadata records the product model:

- Free daily limit: `50`
- Plus daily limit: `500`
- Pro daily limit: `unlimited`

## App Store Connect Audit

ASC app creation and subscription bootstrap were performed after browser authorization.

- `asc auth status`: authenticated with the `landlady` keychain credential.
- `asc bundle-ids capabilities list --bundle "T4XCCFSV6F"`: confirmed `IN_APP_PURCHASE` and `PUSH_NOTIFICATIONS`.
- Browser-created App Store Connect app:
  - App ID: `6811365630`
  - Name: `JiZhi`
  - Bundle ID: `com.createitv.pushnow`
  - SKU: `PUSHNOW-JIZHI-IOS`
  - Primary locale: `en-US`
- `.asc/workflow.json` has `APP_ID` set to `6811365630`.

The browser showed this post-create warning:

- User access settings could not be saved.
- The app was created and is currently available to all users.
- User access can be adjusted later from App Information.

## App Store Connect Subscriptions

ASC subscription group and subscription products were created and read back through the official `asc` API.

| Resource | ID | Identifier | Period | Pricing status |
| --- | --- | --- | --- | --- |
| Subscription group | `22379561` | `JiZhi Membership` | - | Created |
| Plus monthly | `6811365720` | `com.createitv.pushnow.plus.monthly` | `ONE_MONTH` | CNY 8 base price, equalized to 175 territories |
| Plus yearly | `6811365755` | `com.createitv.pushnow.plus.yearly` | `ONE_YEAR` | Pending owner confirmation |
| Pro monthly | `6811365836` | `com.createitv.pushnow.pro.monthly` | `ONE_MONTH` | CNY 18 base price, equalized to 175 territories |
| Pro yearly | `6811365781` | `com.createitv.pushnow.pro.yearly` | `ONE_YEAR` | Pending owner confirmation |

Monthly pricing was applied from the China mainland base prices confirmed by the owner:

- Plus monthly: CNY 8, read back as USD 0.99 in the United States.
- Pro monthly: CNY 18, read back as USD 2.99 in the United States.
- Each monthly product returned `175 succeeded, 0 failed` from `asc subscriptions pricing equalize`.
- Subscription availability is enabled for all pricing territories and future territories.

Annual subscription products exist because the catalog was bootstrapped with monthly and yearly products. Annual prices were intentionally not invented; they must be confirmed before those products can be submitted.

## App Store Connect Subscription Localizations

The subscription group and all four subscription products have English and Simplified Chinese review-facing localizations.

| Resource | en-US | zh-Hans |
| --- | --- | --- |
| Group | `JiZhi Membership` | `JiZhi 即知会员` |
| Plus monthly | `JiZhi Plus Monthly` - `500 notification items per day.` | `即知 Plus 月度` - `每天 500 次通知事项。` |
| Plus yearly | `JiZhi Plus Yearly` - `500 notification items per day with yearly billing.` | `即知 Plus 年度` - `每天 500 次通知事项，按年订阅。` |
| Pro monthly | `JiZhi Pro Monthly` - `Unlimited notification items per day.` | `即知 Pro 月度` - `通知事项不限次数，仍受平台和防滥用限制。` |
| Pro yearly | `JiZhi Pro Yearly` - `Unlimited items per day with yearly billing.` | `即知 Pro 年度` - `通知事项不限次数，按年订阅。` |

## Cloudflare Backend Audit

- `cd backend && npx wrangler secret list`: only `AUTH_TOKEN_PEPPER` is configured.
- `REVENUECAT_WEBHOOK_SECRET` is not configured.
- The current Worker route table does not implement `POST /v1/webhooks/revenuecat` yet.

Do not create a RevenueCat webhook until the Worker has a verified webhook endpoint, a production secret, and a readback test showing webhook events update the `entitlements` table.

## Remaining Release Blockers

- Confirm annual Plus and Pro prices or remove annual products from the launch scope.
- Upload subscription App Review screenshots for submitted subscription products.
- Connect the RevenueCat App Store app to App Store Connect credentials and subscription key.
- Retrieve and configure the RevenueCat public iOS SDK key in the app build settings.
- Replace the placeholder `RevenueCatService` implementation with the real RevenueCat iOS SDK integration.
- Implement and verify `POST /v1/webhooks/revenuecat` plus `REVENUECAT_WEBHOOK_SECRET`.
- Run sandbox purchase and restore on a real device or TestFlight build.

## Review Position

The RevenueCat dashboard catalog and ASC product identifiers match. English and Simplified Chinese subscription localizations are in place, and the monthly launch products have global prices. The app is not yet App Store purchase-review ready because annual product pricing is undecided, subscription review screenshots are missing, and the real iOS SDK configuration plus RevenueCat webhook are not yet verified.
