# Final localization audit and fixes

Scope: app-wide source audit for untranslated static/dynamic UI text, date/number formatting, and user-visible errors. This pass did not use UI automation, simulators, device installation, or an app build. Existing navigation/back-button work was excluded and preserved.

The coordinator subsequently authorized fixing the confirmed findings below. All are now corrected in source. One new six-language catalog entry is provided separately for merge.

## Confirmed findings, now fixed

| Finding | Exact current source locations | Change |
| --- | --- | --- |
| Push registration failure used system-language NSError text and a hardcoded Chinese fallback | `JiZhi/Services/Notifications/PushRegistrationService.swift:121`, `:141`, `:171`–`:174` | All failure paths now pass through AppError. The no-error-object fallback resolves the existing localized key in the selected app language. |
| Device/source requests bypassed safe app-language error mapping | `JiZhi/Services/Devices/SenderManagementService.swift:173`; `SenderAuthorizationService.swift:118`, `:147`; `SecureSourceService.swift:32`; `SecureDeviceService.swift:129`; `JiZhi/Views/Devices/DeviceRow.swift:47`, `DevicesView.swift:49`, `DeviceApprovalView.swift:19` | Catch handlers now store `AppError(error).localizedDescription`. URLSession/OS failures use the existing selected-language public message; underlying URLs, tokens, paths, and server descriptions are not shown. Known API, payment, and encryption errors retain their existing safe mapped messages. |
| Encrypted detail and legacy content loading had the same error-language and raw-error exposure | `JiZhi/ViewModels/SecureV2DetailModel.swift:32`, `:46`, `:57`; `JiZhi/ViewModels/HomeViewModel.swift:85` | Applied the same AppError mapping for load, attachment-open, delete, and content-module errors. |
| Attachment byte-size formatter used the system locale | `JiZhi/Views/ItemDetail/SecureV2DetailView.swift:43` | Replaced static ByteCountFormatter with ByteCountFormatStyle using `environment.preferences.locale`. Checked the installed Apple SDK interface for the initializer. |
| Notification delivery details rendered raw backend lastError strings | `JiZhi/Views/Devices/NotificationLogsView.swift:90`–`:93` | Replaced raw error text with a translated, user-actionable delivery failure message. Backend details are not interpolated into visible text. |

## Catalog handoff

Merge `docs/qa/localization-final-entries.json` into Localizable.xcstrings. It contains one new key, `Notification delivery failed. Check the device or contact support.`, with English, Simplified Chinese, Japanese, Korean, Spanish, and German translations. This agent did not edit the shared catalog.

The direct static Text/Button/Label/Section/Picker/navigation/accessibility-key scan found no missing existing literal keys in the current catalog before this new key was introduced. Identifier values, version numbers, user-provided titles, IANA timezone identifiers, and standardized protocol timestamps are not missing UI translations.

## Verification and boundaries

- Swift parser accepted all 12 changed Swift files.
- `git diff --check` passed.
- Re-scanned changed error paths: no direct raw `error.localizedDescription` assignment remains in those catches.
- Existing AppError maps unknown errors to public localized text and logs only domain/code; existing APIStatusError uses known public keys, never arbitrary server descriptions.
- App-selected-language/OS-language mismatch and actual file-size rendering still need physical-device verification. No new runtime verification is claimed.
- The pending system back-button localization fix was not duplicated or reverted.
