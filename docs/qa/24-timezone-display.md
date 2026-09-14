# Timestamp Display and Time Zone Preferences

## Scope

- Relative inbox timestamps use an injectable clock and the selected app locale, with minute/hour/day boundaries; invalid timestamps are not presented as new messages.
- ISO timestamps with and without fractional seconds are supported.
- Encrypted v1/v2 and generic details display the original timestamp as `yyyy-MM-dd HH:mm:ss`, with a date-specific GMT offset and IANA zone identifier.
- Preferences offers system time zone or a searchable IANA zone list. The local preference persists in UserDefaults; invalid identifiers fall back to system. No server timestamp is changed.
- Three additional UI strings have English, Simplified Chinese, Japanese, Korean, Spanish, and German translations.

## Verification

- Localization JSON parsed successfully; the three new keys are unique and each contains six translations.
- Added `AppTimestampTests`: fractional/non-fractional parsing, invalid input, fixed-clock minute/hour/day thresholds, Shanghai date rollover, New York winter/summer offsets, persistence and invalid-zone fallback.
- Integrated Xcode test execution and Simulator verification are delegated to the coordinator; not claimed executed by this report.
- Initial integrated run passed parsing, relative thresholds, and DST/date boundaries, but exited unexpectedly during preference persistence. Removed self-assignment from the observable property's observer, replacing it with a validated computed setter over separate observable storage. Added invalid runtime assignment regression assertions; coordinator rerun pending.

## Integration

- New Swift sources: `Services/Localization/AppTimestamp.swift`, `Views/Settings/TimezoneSettingsView.swift`, and `Tests/AppTimestampTests.swift`.
- `InboxItem.receivedAt` retains optional raw ISO metadata, integrated by the cache owner. Root uses the formatter with a periodically updated clock for visible inbox rows.
- Relative elapsed time is inherently independent of display time zone; changing zones affects absolute details, not message age.
