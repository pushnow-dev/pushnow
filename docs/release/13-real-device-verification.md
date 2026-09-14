# JiZhi Real Device Verification

Date: 2026-09-12

## Device

- Device name: `林逍遥`
- Device model: iPhone 15 Pro (`iPhone16,1`)
- iOS version: 18.7
- Device UDID: `00008130-0000791C3409001C`
- CoreDevice identifier: `863FF34A-1D38-5EBF-8C8A-4F3EBFF8A6DB`
- Pairing state: paired
- Developer Mode: enabled

## Build

Command:

```bash
xcodebuild \
  -project JiZhi.xcodeproj \
  -scheme JiZhi \
  -configuration Debug \
  -destination 'platform=iOS,id=00008130-0000791C3409001C' \
  -derivedDataPath /tmp/JiZhiRealDeviceDerivedData \
  -allowProvisioningUpdates \
  build
```

Result:

- Build succeeded.
- Product path: `/tmp/JiZhiRealDeviceDerivedData/Build/Products/Debug-iphoneos/JiZhi.app`
- Bundle ID: `com.createitv.pushnow`
- Version: `1.0`
- Build number: `1`

## Signing Readback

- Signing identity: `Apple Development: xfy150150@icloud.com (F42NTWF3JS)`
- Provisioning profile: `iOS Team Provisioning Profile: com.createitv.pushnow`
- Provisioning profile UUID: `da2ae951-7360-430c-952a-7f67eca40f88`
- Team ID: `677U99F8TX`
- Entitlements read back from the signed app:
  - `application-identifier`: `677U99F8TX.com.createitv.pushnow`
  - `aps-environment`: `development`
  - `com.apple.developer.team-identifier`: `677U99F8TX`
  - `get-task-allow`: `true`

This confirms the physical-device Debug build is signed with development APNs capability.

## Install And Launch

Install command:

```bash
xcrun devicectl device install app \
  --device 00008130-0000791C3409001C \
  /tmp/JiZhiRealDeviceDerivedData/Build/Products/Debug-iphoneos/JiZhi.app
```

Install readback:

- App name: `即知`
- Bundle ID: `com.createitv.pushnow`
- Installed version: `1.0`
- Installed build: `1`
- Device installation URL: `file:///private/var/containers/Bundle/Application/F7C1D1C6-F04E-49E8-BE7E-751E53B25255/JiZhi.app/`

Launch command:

```bash
xcrun devicectl device process launch \
  --device 00008130-0000791C3409001C \
  com.createitv.pushnow
```

Launch readback:

- `Launched application with com.createitv.pushnow bundle identifier.`
- Process list readback found JiZhi running as PID `64882`.

## Visual Evidence Limitation

The command-line tools available in this Xcode installation do not expose a real-device screenshot command through `xctrace screenshot` or `devicectl device screenshot`. `devicectl device info displays` did read back the primary display, but the main display backlight was off at the time of verification.

## APNs Status

Verified:

- The signed app contains `aps-environment=development`.
- The App has been installed and launched on a physical iPhone.
- The device is paired and Developer Mode is enabled.

Still pending:

- Open the App on the device.
- Complete email verification login.
- Go to Settings in the App and tap `启用 App 推送`.
- Accept the iOS notification permission prompt.
- Confirm the App receives an APNs token and binds it to `https://api.pushnow.dev/v1/devices/apns-token`.

This pending step requires foreground user interaction on the physical device.
