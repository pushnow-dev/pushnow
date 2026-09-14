# JiZhi App Store Readiness

Date: 2026-09-12

## Current ASC State

- Bundle ID: `com.createitv.pushnow`
- Bundle resource ID: `T4XCCFSV6F`
- Apple team ID: `677U99F8TX`
- Bundle capabilities read back in ASC:
  - `IN_APP_PURCHASE`
  - `PUSH_NOTIFICATIONS`
- App Store Connect app ID: `6811365630`
- App Store Connect name: `JiZhi`
- Primary locale: `en-US`
- Version: `1.0`, state `PREPARE_FOR_SUBMISSION`
- Distribution method: public App Store
- Availability: all 175 App Store countries or regions, plus new territories
- Price: free app
- Repo workflow file: `.asc/workflow.json`

## Completed This Pass

- Created the ASC Bundle ID `com.createitv.pushnow` with name `JiZhi`.
- Added and read back Push Notifications capability.
- Created the App Store Connect app record for bundle `com.createitv.pushnow`.
- Set App Info localizations:
  - en-US name `JiZhi`, subtitle `Agent-ready push reminders`, privacy URL `https://pushnow.dev/privacy`.
  - zh-Hans name `JiZhi 即知提醒`, subtitle `自动化推送提醒工具`, privacy URL `https://pushnow.dev/zh-Hans/privacy`.
- Set version localizations for en-US and zh-Hans with descriptions, keywords, promotional text, support URL, marketing URL, privacy link, and terms link.
- Set categories to Productivity and Utilities.
- Set content rights to `DOES_NOT_USE_THIRD_PARTY_CONTENT`.
- Set age rating declaration to safe default: no advertising, gambling, chat, user-generated content, unrestricted web access, weapons, medical content, adult content, horror, profanity, contests, loot boxes, parental controls, health/wellness topics, or age assurance requirement.
- Set copyright to `2026 Xiaofeng Hu`.
- Initialized worldwide App availability for all 175 countries or regions.
- Deployed the public website and legal/support pages to Cloudflare at `https://pushnow.dev`.
- Confirmed production readback for home, privacy, terms, support, sitemap, robots, localized paths, QR, and app design-board assets.
- Built, signed, installed, and launched JiZhi on a physical iPhone 15 Pro running iOS 18.7.
- Read back the signed physical-device Debug entitlements, including `aps-environment=development`.
- Added an ASC workflow with:
  - `audit` for bundle capability and app-record readback.
  - `release-readiness` for status, builds, validate, review dry-run, and optional confirmed submission once `APP_ID` exists.

## Public Review URLs

- Marketing website: `https://pushnow.dev/`
- Privacy Policy: `https://pushnow.dev/privacy`
- Terms of Use: `https://pushnow.dev/terms`
- Support URL: `https://pushnow.dev/support`

The App Store download button remains in a pending state until the App Store Connect app record exists and the public App Store URL can be written into `web/src/data/site.ts`.

## App Record Creation Inputs

- Platform: iOS
- Name: `JiZhi`
- Bundle ID: `com.createitv.pushnow`
- SKU: `JIZHI-IOS-001`
- Primary locale: `en-US`
- Initial version: `1.0`
- Access: Full Access

## Membership And Subscription Setup

| Plan | Launch price | Daily quota | Product ID | Status |
| --- | --- | --- | --- | --- |
| Free | Free | 50 notification items | - | App tier |
| Plus | CNY 8/month, globally equalized | 500 notification items | `com.createitv.pushnow.plus.monthly` | Priced globally |
| Pro | CNY 18/month, globally equalized | Unlimited, subject to platform and abuse limits | `com.createitv.pushnow.pro.monthly` | Priced globally |
| Plus yearly | Pending owner price | 500 notification items | `com.createitv.pushnow.plus.yearly` | Created, not priced |
| Pro yearly | Pending owner price | Unlimited, subject to platform and abuse limits | `com.createitv.pushnow.pro.yearly` | Created, not priced |

The subscription group and all subscription products have English and Simplified Chinese localizations. Monthly products are available in all subscription territories. Annual products should either receive confirmed annual pricing before launch or be removed from the submitted launch set.

## Review Metadata Still Needed

- Review contact phone number. The CLI rejected review detail creation without `contactPhone`.
- Final review contact first name, last name, and email if they should differ from `Xiaofeng Hu` and `support@pushnow.dev`.
- App Store screenshots for required iPhone sizes.
- Subscription App Review screenshots showing the membership page and pricing.
- A build uploaded to App Store Connect and attached to version `1.0`.
- App Privacy questionnaire in App Store Connect. Expected declaration:
  - Data collected and linked to the user: email address, user ID/account ID, device push token, notification/source configuration, app interaction or usage counters required for quota enforcement.
  - Data not used for tracking.
  - No SMS or phone-call reminders.
  - No camera, microphone, location, contacts, photos, calendar, Bluetooth, or health permissions.
- Optional accessibility declaration, if you want to publish Apple accessibility labels. The current SwiftUI UI uses standard controls, but no formal ASC accessibility declaration has been submitted yet.

## Remaining Device Verification Blocker

Physical-device build, install, launch, and development APNs entitlement readback are complete. Final APNs token binding proof still requires foreground device interaction: complete email login in the App, tap `启用 App 推送`, accept the iOS notification permission prompt, and confirm the token bind request reaches the production backend.

## Current Review Doctor Result

After the metadata, age rating, copyright, availability, and Terms link updates, `asc review doctor` reports 6 blocking errors:

- No build attached to App Store version `1.0`.
- Review contact first name missing.
- Review contact last name missing.
- Review contact email missing.
- Review contact phone missing.
- No App Store screenshots uploaded.

Warnings remain for annual subscription pricing, subscription App Review screenshots, optional subscription promotional images, and subscription `MISSING_METADATA` state until those assets and prices are completed.
