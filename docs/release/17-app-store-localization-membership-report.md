# App Store Localization And Membership Report

> Date: 2026-09-12
> Scope: English and Simplified Chinese metadata, worldwide sale configuration, membership pricing, App Review checklist, and membership UI update.

## Completed In App Store Connect

- App ID: `6811365630`
- Bundle ID: `com.createitv.pushnow`
- Primary locale: `en-US`
- App price: free
- Distribution: public App Store
- Availability: all 175 App Store countries or regions, including future territories
- Categories: Productivity, Utilities
- Content rights: does not use third-party content
- Copyright: `2026 Xiaofeng Hu`
- Age rating: all objectionable-content fields set to none or false

## App Metadata

| Locale | Name | Subtitle | Legal URL |
| --- | --- | --- | --- |
| en-US | `JiZhi` | `Agent-ready push reminders` | `https://pushnow.dev/privacy` |
| zh-Hans | `JiZhi 即知提醒` | `自动化推送提醒工具` | `https://pushnow.dev/zh-Hans/privacy` |

Version `1.0` has English and Simplified Chinese descriptions, keywords, promotional text, support URL, marketing URL, privacy link, and terms link. The exact readback files are stored in:

- `metadata/app-info/en-US.json`
- `metadata/app-info/zh-Hans.json`
- `metadata/version/1.0/en-US.json`
- `metadata/version/1.0/zh-Hans.json`

The exact Chinese app name `即知` could not be used because App Store Connect reported it is already taken by another account. The submitted Simplified Chinese app-info name is `JiZhi 即知提醒`.

## Membership Products

| Tier | User-facing benefit | Launch product | Price state |
| --- | --- | --- | --- |
| Free | 50 notification items per day | - | Free app tier |
| Plus | 500 notification items per day | `com.createitv.pushnow.plus.monthly` | CNY 8/month, globally equalized |
| Pro | Unlimited notification items per day, subject to platform and abuse limits | `com.createitv.pushnow.pro.monthly` | CNY 18/month, globally equalized |

The monthly products are localized in English and Simplified Chinese and have global prices across 175 territories. Apple equalized the China mainland base prices to the United States as:

- Plus monthly: USD 0.99
- Pro monthly: USD 2.99

Annual products were created during catalog bootstrap but are not launch-ready until annual prices are confirmed:

- `com.createitv.pushnow.plus.yearly`
- `com.createitv.pushnow.pro.yearly`

## In-App Membership UI

The membership settings page now shows the current plan, daily quota, price, Free/Plus/Pro comparison, feature bullets, restore purchases, and legal links directly on the page. Users no longer need to tap a separate "view Pro" entry before seeing the plan comparison or purchase actions.

Updated files:

- `JiZhi/Views/Settings/MembershipSettingsView.swift`
- `JiZhi/Models/MembershipPlan.swift`
- `JiZhi/Resources/Localizable.xcstrings`

## Permissions And Privacy Notes

The current launch scope needs only App Push notification permission on iOS. The app does not need SMS, phone call, camera, microphone, precise location, contacts, calendar, photos, Bluetooth, health, or tracking permissions.

Expected App Privacy declaration:

- Email address: collected, linked to user, used for account management and verification.
- User ID/account ID: collected, linked to user, used for authentication, quota, and syncing.
- Device push token: collected, linked to user, used for App Push delivery.
- Notification source/rule data: collected, linked to user, used to provide reminder and inbox functionality.
- Usage counters: collected, linked to user, used for membership quota enforcement and abuse prevention.
- Tracking: no.

## Remaining Before Submission

- Provide review contact phone number so App Review details can be created.
- Confirm whether review contact name/email should be `Xiaofeng Hu` and `support@pushnow.dev`.
- Confirm annual prices for Plus yearly and Pro yearly, or remove annual products from the launch scope.
- Upload App Store screenshots.
- Upload subscription App Review screenshots.
- Complete App Privacy in App Store Connect.
- Upload and attach an App Store Connect build.
- Configure the real RevenueCat iOS SDK key and App Store credentials.
- Implement and verify the RevenueCat webhook on Cloudflare.
- Run sandbox purchase and restore testing on a real device or TestFlight.

## Verification

- `asc pricing availability view --app 6811365630` read back `availableInNewTerritories=true`.
- `asc pricing availability territory-availabilities --availability 6811365630` read back 175 available territories.
- `asc subscriptions pricing equalize` returned 175 succeeded and 0 failed for Plus monthly and Pro monthly.
- `asc metadata pull --force` wrote the four current metadata files under `metadata/`.
- `asc review doctor` now reports 6 blocking errors, limited to build, screenshots, and review contact fields.
- `xcodebuild build -project JiZhi.xcodeproj -scheme JiZhi -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4'` succeeded after the membership UI change.
