# Settings, devices, and server selector localization audit

Scope: 16 Swift files under Views/Settings, Views/Devices, plus Views/Auth/ServerEnvironmentView.swift. No simulator, physical-device build, or UI interaction was used for this pass. No xcstrings was modified.

Fixed the logout button and sender key creation button/navigation title to use LocalizedStringKey explicitly instead of a computed String. Fixed notification timestamps, expiry timestamps, delivery-attempt numbers, timezone display names, timezone search, and Follow system text to use the selected locale; timestamps also respect the selected timezone. Made the sender export preview title explicitly localized. The server switch failure state now stores a Boolean and renders localized Text, so it does not retain an error translated in a previous language.

Unknown delivery states now show a localized label rather than an untranslated backend enum. Merge the single new key and its six translations from `localization-settings-entries.json` into Localizable.xcstrings. All other static labels reuse existing translated catalog keys. Identifiers, account names, server addresses, version numbers, secrets, and diagnostic response values remain data, not UI translation keys.

Static verification: Swift parse succeeded; project diff whitespace check succeeded. Audited 88 directly extracted static UI keys against six languages; all already have translations. The new dynamic fallback is the one additional pending merge key. SharePreview(Text) was checked against the installed Apple SDK interface. This is source verification only; Chinese-first, then English native-device screenshot verification remains with the coordinator.

Changed in this pass:
- JiZhi/Views/Settings/AccountSettingsView.swift
- JiZhi/Views/Settings/SettingsView.swift
- JiZhi/Views/Settings/TimezoneSettingsView.swift
- JiZhi/Views/Devices/SenderKeysView.swift
- JiZhi/Views/Devices/NotificationLogsView.swift
- JiZhi/Views/Devices/SecureSourceSetupView.swift
- JiZhi/Views/Auth/ServerEnvironmentView.swift
- docs/qa/localization-settings-entries.json
- this audit

The full prior server-environment change inventory is in `docs/release/aeo-server-environment-2026-09-13.md`, section Changed source files. Its previous build success does not certify the newest localization pass; only static checks were run after the user prohibited simulator activity.
