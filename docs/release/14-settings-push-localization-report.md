# Settings, Push, Localization Verification

Date: 2026-09-12

## Implemented

- Added a visible global account entry on the Home screen. The top-left account icon now opens Settings.
- Added Settings route support so users can view account, email, short user ID, login status, subscription state, and App push state in one place.
- Added an `Account & Notifications` section in Settings. Verified users can enable or rebind App push from this section.
- After verified email login, the app now requests notification authorization when needed and binds the APNs token when available.
- On cold launch, the app refreshes notification state and attempts stored-token binding without showing the iOS permission prompt immediately.
- Added dynamic light/dark theme colors across the shared JiZhi color system.
- Added localization regions for English, Simplified Chinese, Japanese, Korean, Spanish, and German.
- Expanded `Localizable.xcstrings` for core account, push, settings, tab, and filter labels.

## Verification

- Simulator build passed on iPhone 16 Pro, iOS 18.4.
- `Localizable.xcstrings` compiled into all configured language folders during Xcode build.
- Dark mode screenshot verified the Home screen renders correctly and selected filter chip contrast is readable.
- Home account entry screenshot: `/tmp/jizhi-home-account-entry-light-late.png`.
- Settings light-mode screenshot: `/tmp/jizhi-settings-account-notifications-light.png`.
- Settings dark-mode screenshot: `/tmp/jizhi-settings-account-notifications-dark.png`.
- UI accessibility readback confirmed the Home account icon is labeled `设置` and opens the Settings screen.

## Real Device Status

Real-device reinstall of this latest build is pending because the previously available iPhone 15 Pro named `林逍遥` is currently reported as `unavailable` by `devicectl`.

To finish the physical-device push proof, reconnect or unlock the device, install the latest build, log in with email, accept the iOS notification prompt, then verify a current app version `1.0` APNs token row in the Cloudflare D1 `device_push_tokens` table.
