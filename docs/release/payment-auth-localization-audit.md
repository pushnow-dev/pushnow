# Auth and membership localization audit

2026-09-13. Source-only checks; no UI, Simulator, or device operation performed.

## Fixed

- AuthService's ten local validation failures now resolve through the selected app language, including email/password/code and sign-in prerequisites. Verification email locale now follows the app selection.
- Password mismatch now uses the existing six-language translation instead of displaying the Chinese key verbatim.
- Auth-session storage failures display the existing localized secure-storage message; raw Keychain status is no longer customer-visible.
- AppError now preserves known localized API/payment/security errors. Unknown framework errors log only domain/code and display a translated connection/service message. Missing configuration does not expose internal key names.
- Auth header now explains account benefits instead of listing device tokens and source keys. Both new English source strings have six translations in the merge file.
- Conditional membership action and duration labels explicitly use LocalizedStringKey.
- Added missing password, email-verification and Refresh text plus generic network failure translations.

Merge file: `docs/release/payment-auth-localizations.json`, six keys in English, Simplified Chinese, Japanese, Korean, Spanish and German. The coordinator owns xcstrings merging; this task did not edit that file.

Files: AuthView.swift, AuthViewModel.swift, AuthService.swift, AuthSessionStore.swift, AppError.swift, MembershipContentView.swift, MembershipPlanPicker.swift.

Validation: Swift parser passes for changed files. Static UI-literal scan against the catalog plus merge JSON found no uncovered six-locale strings in the owned Auth/Paywall/Payments scope. This does not establish rendered layout or complete App-wide localization.

## Genuine notification preparation

`scripts/review-screenshot-messages.json` has four operational notifications in each of Chinese and English: documented website build (127 pages), saved six-language subscription metadata, verified sandbox review-account readiness, and the user's requested screenshot-preparation reminder. Each item identifies its evidence. They do not claim a purchase or App Review submission occurred.

`scripts/review-screenshot-messages.mjs` previews locally by default. `--check` reads and verifies the signed recipient directory; `--send` is required for actual writes. Each encrypted outbox is saved before submission and reused for retries; accepted items are not resent. The script does not remove existing messages, change timestamps, or claim that an API acceptance proves device delivery.

Read-only configuration audit: v2 Keychain authorization is absent. The existing private v1 sender configuration is valid against the production API, with one active authorized iOS device and notifications enabled. Current account UUID is2454547b-a398-489a-b722-2cbedfc650d1. No key values are logged. Both language payloads are under300 UTF-8 bytes per item before encryption.

No notifications were sent by this task. The coordinator must schedule Chinese and then English batches around the actual device screenshots and verify the phone displays them.
