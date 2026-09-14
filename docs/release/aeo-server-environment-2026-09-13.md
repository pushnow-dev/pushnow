# Server environment isolation for release

The app now exposes Server environment on the email sign-in screen and Account settings. Sandbox remains visible as a persistent banner. Changing servers requires signing out first; it never transfers authentication between services. The selector is available in release builds so a reviewer can choose the isolated test backend without a hidden debug gesture.

Production API: `https://api.pushnow.dev`.
Sandbox API: `https://sandbox-api.pushnow.dev`.

Production keeps all existing storage keys and directory names. Sandbox uses a `.sandbox` suffix for the secure Keychain service, auth session service, APNs token preference, notification cache directory, temporary attachment directory, and each Discovery preference key. Keychain stores capture their namespace at initialization. The shared notification extension reads the chosen environment through the existing Keychain access group, and image attachment downloads use the captured environment URL instead of a fixed production URL.

RevenueCat uses the existing `jizhi_<uuid>` identity in production and `jizhi_sandbox_<uuid>` in Sandbox. The backend agent is coordinating the matching server prefix. The Apple billing environment is separate from the backend selector: the UI explicitly explains that choosing Sandbox does not itself turn an Apple purchase into a sandbox transaction.

Switching invalidates outstanding authentication work, requires no current or persisted session, waits for serialized RevenueCat logout, removes old push observers, clears a pending navigation route, saves the selector, and recreates the complete AppEnvironment plus root view identity. Existing account keys are preserved. The existing ordinary logout behavior still removes regenerable notification caches and temporary decrypted attachments; switching itself does not erase account data. Display language, appearance, and timezone are intentionally shared device preferences, not account credentials.

Validation added in `JiZhi/Tests/AppPreferencesTests.swift`, class `ServerEnvironmentIsolationTests`:

1. Production key compatibility and distinct fixed service URLs.
2. The same synthetic Keychain account stores different secrets per environment; removing its sandbox entry preserves production.
3. The same Discovery account and notification cache IDs resolve to separate storage.
4. A signed-in auth service cannot prepare for a server switch and retains its session generation.

Tests use unique synthetic keys and do not modify the selected environment. A fresh disposable iOS 18.4 simulator was created for isolation testing; no physical device account or key was changed by this work.

Source parse and project plist validation passed. A complete unsigned Simulator build of app and notification extension succeeded; evidence: `/tmp/pushnow-server-env-build.log` (`BUILD SUCCEEDED`). Scheme is `JiZhi`, although the app display name is PushNow.

Runtime tests are NOT verified. Two iOS 18.4 attempts failed before test execution because CoreSimulator crashed during app installation (`Invalid device state`, code 405, `Mach server died`). A fallback iOS 26.4 attempt had not produced any test results when the user prohibited further simulator activity; its xcodebuild process was stopped immediately. Do not report these tests as passing. Physical-device/native-mirroring verification remains with the coordinator and QA agent. No more simulator operations are authorized for this task.

Also fixed the unauthenticated inbox empty state with English source strings and six-language translations, added eight six-language environment strings, and corrected six stale English/Chinese website claims saying APNs sending was not implemented.

## Changed source files

- `JiZhi/Services/Encryption/SecureKeyStore.swift`: environment selection and captured secure namespace, shared with extension.
- `JiZhi/App/AppConfiguration.swift`, `AppEnvironment.swift`, `JiZhiApp.swift`, `AppRootView.swift`: selected API, authenticated switch gate, service/root recreation, Sandbox banner.
- `JiZhi/Services/Auth/AuthSessionStore.swift`, `AuthService.swift`: isolated sessions and invalidation of pending auth work.
- `JiZhi/Services/Storage/EncryptedNotificationCache.swift`, `NotificationCacheKeys.swift`, `AppPreferences.swift`: separate encrypted caches/keys and notification-language sync.
- `JiZhi/Services/Discovery/DiscoverySubscriptionStore.swift`, `Services/Encryption/SecureAttachmentService.swift`: isolated local preferences/files.
- `JiZhi/Services/Notifications/PushRegistrationService.swift`: separate saved APNs tokens and observer shutdown.
- `JiZhi/Services/Payments/RevenueCatService.swift`: environment-specific identity and serialized logout before switching.
- `JiZhi/Views/Auth/ServerEnvironmentView.swift`, `AuthView.swift`, `Views/Settings/AccountSettingsView.swift`: visible environment controls.
- `JiZhi/Views/Shared/AuthRequiredStateView.swift`, `Resources/Localizable.xcstrings`: English-first empty state and six-language environment strings; coordinator subsequently completed other missing translations.
- `NotificationServiceExtension/SecurePreviewLoader.swift`: environment-specific attachment requests.
- `JiZhi/Tests/AppPreferencesTests.swift`: four isolation tests (compiled, not runtime verified).
- `JiZhi.xcodeproj/project.pbxproj`: new small View file added to app target.

Final website recheck after APNs corrections: Astro check 0 errors, 0 warnings, 0 hints; build 127 pages successful (`/tmp/pushnow-aeo-final-build.log`). A check briefly observed SDK declarations mid-rebuild; a subsequent full check/build passed with the stable SDK output. `git diff --check` passed.
