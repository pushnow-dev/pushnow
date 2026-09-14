# System notification app icon verification

2026-09-13 — iPhone 16 Pro, iOS 18.4 only.

## Finding

The current installed iOS build correctly displays PushNow's app icon in a real system notification banner. No iOS app-icon configuration defect was found; no native project or source changes were made for this investigation.

The absence of `ASSETCATALOG_COMPILER_APPICON_NAME` directly inside `project.pbxproj` is not a defect: both Debug and Release include `JiZhi/Config/Shared.xcconfig`, which sets `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`.

Both the current build artifact and installed app declare:

- `CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconName = AppIcon`
- `CFBundleIcons.CFBundlePrimaryIcon.CFBundleIconFiles = [AppIcon60x60]`
- Compiled `AppIcon60x60@2x.png` and iPad icon file exist. Visual inspection confirms the blue PushNow artwork.
- Source `AppIcon-1024.png` is RGB with no alpha channel.

The notification extension identifies as `com.apple.usernotifications.service`, bundle `com.createitv.pushnow.NotificationServiceExtension`; the notification is delivered to the containing app `com.createitv.pushnow`. It does not need a separate app launcher icon.

## Runtime evidence

Using `simctl push` with a plain local `aps.alert` payload addressed to `com.createitv.pushnow`, the iOS 18.4 system banner visibly displayed the correct PushNow icon. Desktop app icon also displayed correctly. Screenshot:

`evidence/system-app-icon/ios18-system-banner.png`

This is a system banner test, separate from icons inside encrypted message content. It verifies local simulator notification presentation, not production APNS transport or macOS notification mirroring.

## Remaining scope

The user's screenshot contains an iPhone badge on a macOS-style notification. The current iOS evidence does not establish the cause of a blank mirrored icon on that Mac, and no Mac-mirroring fix is claimed. A real-device/Mac mirroring investigation requires confirmation of the notification source and is outside the user's iOS-18.4-only testing constraint. Do not attribute the issue to caching or an old build without further evidence.
