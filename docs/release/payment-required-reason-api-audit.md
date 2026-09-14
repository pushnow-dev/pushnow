# Required Reason API privacy manifests

2026-09-13. Scope: first-party shipping Swift sources and target resource membership. No Simulator or full-app build was started by this audit.

## Declaration and source evidence

Both the main app and Notification Service Extension declare only:

- `NSPrivacyAccessedAPIType`: `NSPrivacyAccessedAPICategoryUserDefaults`
- `NSPrivacyAccessedAPITypeReasons`: `CA92.1`

Apple's current [approved reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons) define CA92.1 for the app's own user-default information. This audit fetched Apple's documentation JSON to inspect the complete reason descriptions, because the Markdown page omits the enumeration.

Main app uses:

- `Services/Storage/AppPreferences.swift`: chosen language, appearance and timezone in `UserDefaults.standard`.
- `Services/Localization/AppLocalization.swift:33`: reads the selected app language.
- `Services/Storage/LocalStorage.swift`: app-owned Boolean preferences.
- `Services/Discovery/DiscoverySubscriptionStore.swift`: account/environment-scoped discovery preferences, with standard defaults as the production store.
- `Services/Notifications/PushRegistrationService.swift:76` and `:183`: caches this app's APNs registration token for its push-registration workflow.
- `Repositories/RemoteJiZhiAPIModels.swift:182` and `:192`: reads the app's timezone preference for formatting its own messages.

The extension target compiles the shared `AppLocalization.swift` source, which contains the same standard-default language accessor. Its normal notification-language route reads a language value from shared Keychain; shared `SecureFailure` localization also refers to the AppLocalization helpers. Its executable therefore gets its own CA92.1 manifest instead of relying on the containing app's manifest.

## Reasons deliberately not declared

`1C8F.1` is for UserDefaults shared through an App Group. Shipping sources have no group-suite `UserDefaults(suiteName:)` call, and entitlements contain a Keychain access group, not an App Group entitlement. Sharing Keychain items does not justify the App Group UserDefaults reason. The `suiteName:` calls found in this repository are test fixtures only.

No first-party shipping call was found for the other Required Reason API categories (file timestamp, system boot time, disk-space capacity, active keyboard enumeration). `attributesOfItem`/file metadata checks found in `Tests/EncryptedNotificationCacheTests.swift` are not app or extension sources. Ordinary file reads/writes, file-existence checks, Keychain calls, calendar dates, and setting the backup-exclusion flag were not used to invent additional reason codes.

RevenueCat's SDK privacy manifest remains its own declaration; its API reasons are not copied into first-party manifests. Apple requires each executable's containing bundle to carry its applicable manifest: [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).

## Target resource integration

- `JiZhi/Resources/PrivacyInfo.xcprivacy` is a file reference in the Xcode project and a Copy Bundle Resources entry only for the main `JiZhi` target. Expected archive path: `Products/Applications/PushNow.app/PrivacyInfo.xcprivacy` (use actual product name from the final archive).
- `NotificationServiceExtension/PrivacyInfo.xcprivacy` is independently in the extension's Copy Bundle Resources. Expected relative path: `PlugIns/NotificationServiceExtension.appex/PrivacyInfo.xcprivacy`.
- `JiZhi.xcodeproj/project.pbxproj` resource references were updated without changing any target build settings, version or signing configuration. A before/after comparison of all target build settings was identical.

Both manifest files contain the Required Reason API section only. This focused change does not assert that the app collects no data and does not substitute for App Store privacy answers or RevenueCat's collection manifest.

## Validation and handoff

`plutil -lint` passes for both manifests and the project. Xcodeproj readback finds exactly one privacy-manifest resource per shipping target. The release/archive owner was notified to rerun the final incremental archive and inspect the two compiled bundle paths. Resource configuration is verified; packaged-bundle presence remains the archive owner's check.
