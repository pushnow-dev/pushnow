# Settings parity implementation

Reference: `JiZhi/Views/Settings/*.swift`, `JiZhi/Views/Auth/AuthView.swift`.

Entry: `SettingsPanel({ model, onBack })`. Before presentation, initialize `preferenceService` from `services/preferences/PreferenceService.ets` with the UIAbility context.

Implemented:
- Settings navigation order: Account, Membership; Preferences (time zone, language, appearance); App (About); Legal.
- Signed out / verified account branches, email/password and email/code mode separation, real model authentication, logout, push registration.
- Time zone searchable system IANA IDs, seven language choices, three appearance choices, persisted via ArkData preferences with flush before state publication.
- Public privacy / terms links, actual installed bundle version.
- Light/dark palette selection from AppStorage appearance and systemColorMode.

Integration requirements:
- Localization must observe AppStorage language or preferenceService.onChange.
- Timestamp formatter must consume preferenceService.timezoneIdentifier or AppStorage timezone.
- System color mode storage uses Harmony ConfigurationConstant.ColorMode values DARK=0, LIGHT=1.

Not yet parity / release blockers:
- Membership purchase, restore, redemption and plan synchronization have no Harmony implementation; the membership route explicitly reports unavailable.
- Notification log API/UI is absent; route explicitly reports unavailable.
- First-time email verification password setup is absent from HarmonyModel/AuthService.
- Devices and sender pages still use existing components.
- Icons are text stand-ins pending real matching icon assets.
- No iPhone mirror comparison or Harmony physical-device verification was performed by this subagent.
- Build passed before Index imported these new components; a final integrated build is required.
