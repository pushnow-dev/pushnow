# Device naming and settings preferences

## Changes

- New installations use the available system-assigned name plus the hardware model, for example `Travel phone (iPhone 15 Pro)`.
- When iOS exposes only a generic name, the fallback includes the model and a stable six-character installation suffix, for example `iPhone 15 Pro (ABC123)`. This suffix is not a hardware serial number.
- Existing registered names are preserved exactly, including explicit renames. The backend already preserves the name on re-registration; no schema change was needed. Unknown models retain their exact hardware identifier instead of guessing a marketing name.
- Device-row rename and revoke buttons have isolated borderless button styles; the rename control has a 44-point hit area. This fixes the List row's automatic button behavior invoking multiple actions.
- Main Settings now routes to separate Account and Membership pages. Account contains email, user ID, login, push registration, devices/encryption and logout. Membership retains the existing plan/quota/paywall behavior; this change does not implement or certify production billing.
- Language supports system, English, Simplified Chinese, Japanese, Korean, Spanish and German. Appearance supports system/light/dark. Both persist in UserDefaults and update the SwiftUI environment immediately.
- Imperative app strings and LocalizedStringResource values explicitly select the chosen `.lproj` bundle. The notification extension reads the selected language from the shared Keychain. User-authored message content is not translated.

## Platform limit

iOS 16 and later require Apple's approved user-assigned-device-name entitlement to expose the user's custom name through UIDevice.name. No entitlement was fabricated or added. A name visible through Mac developer tools does not prove that a sandboxed iOS app can read the same name. See [Apple's entitlement documentation](https://developer.apple.com/documentation/BundleResources/Entitlements/com.apple.developer.device-information.user-assigned-device-name).

Hardware model identifiers were checked against [DeviceKit's registry](https://github.com/devicekit/DeviceKit/blob/master/Source/Device.swift.gyb), including `iPhone16,1` = `iPhone 15 Pro`.

## Validation

- All 19 Simulator XCTest cases passed in `/tmp/pushnow-settings-final-tests.log`.
- Six device-name tests cover real model mapping, generic-name fallback, distinct installation suffixes, preservation of renames, duplicate-model avoidance, unknown hardware and UTF-16 server length limits.
- Five preference tests cover system defaults, persistence across instances, invalid stored values, actual English/Chinese translated strings, and actual English/Chinese LocalizedStringResource resolution.
- Eight existing auth/model tests continue to pass, including stale auth completion and concurrent token refresh regressions.
- Naming-only signed physical-device build succeeded at `/tmp/pushnow-device-name-real/Build/Products/Debug-iphoneos/JiZhi.app`. Root owns installation and device-visible acceptance.
- Final settings signed physical-device build succeeded (`/tmp/pushnow-settings-real.log`, `BUILD SUCCEEDED`). Artifact: `/tmp/pushnow-settings-real/Build/Products/Debug-iphoneos/JiZhi.app`. Physical UI and APNs acceptance are recorded separately in `docs/qa/17-real-device-settings-push.md` by the coordinator.

All new views and helpers remain below 100 lines each. Authentication, preferences and model-name composition stay outside View bodies.

## Physical UI follow-up

The coordinator observed that changing the language updated settings rows but left the navigation title cached in Chinese. All five settings screens now pass resolved title text while explicitly observing the selected language; navigation and authentication state are not reset. The incremental signed device build succeeded in `/tmp/pushnow-settings-title-build.log`. Device-visible revalidation remains owned by the coordinator.

All five focused preference tests passed after this change (`/tmp/pushnow-settings-title-tests.log`), including added exact `Settings` and `设置` assertions.

## About submenu

Name, version and minimum OS now live in a separate `AboutSettingsView`, reached from the main settings list. The About title has all six language translations and explicitly observes the selected language, matching the navigation-title fix. Other menus and legal links are unchanged.

Incremental signed physical-device build passed (`/tmp/pushnow-settings-about-build.log`); the coordinator owns installation and visible submenu acceptance. No additional XCTest run was performed for this UI-only relocation.

Coordinator physical-device acceptance completed: account/membership subpages,
English/Chinese switching including updated navigation titles, light/dark/system
appearance, persistence after terminate/relaunch, and isolated rename dialog.
Preferences were restored to system after testing. See report 17 for delivery
boundaries; APNs provider credentials and an actual sent/received message remain
unverified.
