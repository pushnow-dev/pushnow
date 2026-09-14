# App Store archive and IPA export

Completed with `asc xcode archive` / `asc xcode export`, Release, `generic/platform=iOS`. No Simulator was opened or used. No upload or review submission was performed by this agent.

## Artifacts

- Final archive: `/Users/tnt/Documents/Github/100-app/pushnow.dev/.asc/artifacts/Pushnow-1.0-1-final.xcarchive`
- Verified IPA: `/Users/tnt/Documents/Github/100-app/pushnow.dev/.asc/artifacts/Pushnow-1.0-1.ipa`
- Export options: `.asc/artifacts/ExportOptions-AppStore.plist` (`method=app-store-connect`, `destination=export`, automatic signing, version management disabled).
- Machine-readable IPA audit: `.asc/artifacts/IPA-Verification-1.0-1.json`.
- Archive log: `/tmp/pushnow-appstore-archive-final.log`; export log: `/tmp/pushnow-appstore-export.log`.
- IPA size: 10,816,681 bytes.
- SHA-256: `9212b80b382c494d4d869d4ca95977dcb4b3a97182b2763f12000fddffc680e2`.

## Audit results

Before archiving, ASC app `6811365630` had zero builds and the CLI returned next build number 1. The app and extension source configurations were both version 1.0/build 1, team `677U99F8TX`, automatic signing, iOS 18.0 minimum. Test targets are not included in the archive product.

Both final archived and exported products report 1.0 (1) and iOS 18.0 minimum. Bundle identifiers are `com.createitv.pushnow` and `com.createitv.pushnow.NotificationServiceExtension`.

The archive uses a development signing profile as input to export. The exported IPA was unpacked and separately verified:

- Both signatures pass `codesign --verify --strict`.
- Both products have `get-task-allow=false`, team `677U99F8TX`, and App Store provisioning profiles without registered-device restrictions. Profiles expire 2027-08-08.
- Main app `aps-environment=production`.
- Shared keychain group is `677U99F8TX.com.createitv.pushnow.secure` in both products.
- Main app and extension each contain their own root `PrivacyInfo.xcprivacy`, declaring UserDefaults reason CA92.1. The RevenueCat SDK manifest is also retained.
- Both Info.plists contain `ITSAppUsesNonExemptEncryption=false`, based on the separate OS-only encryption implementation audit.
- All six required localization folders exist; an additional existing Traditional Chinese folder is also present.

The obsolete initial diagnostic archive `Pushnow-1.0-1.xcarchive` predates final manifest inclusion and is not the upload artifact. Only the final IPA above was handed to the coordinator.

Xcode emitted an unrelated missing-token warning for another logged-in Apple ID, but archive and export both completed successfully using the available team and distribution provisioning. No credentials or certificates were replaced manually.
