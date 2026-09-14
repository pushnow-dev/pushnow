# PushNow release status — 2026-09-13

App 6811365630 / version 1.0 / App Store version ff337927-1615-4364-b553-34d92bbf45b1.

## Completed and verified
- 396 localization keys complete across English, Simplified Chinese, Japanese, Korean, Spanish and German; English development language. Signed physical-device build installed. Chinese/English major screens and all six language-switch/back labels verified using native macOS iPhone Mirroring, without operating Simulator for this work. App preference restored to Simplified Chinese.
- Four Chinese and four English meaningful notifications delivered visibly to the real phone. Cross-protocol latest-first ordering fixed. Prior messages preserved.
- Two Chinese and two English public screenshots created from real mirror captures with imagegen packaging; all four asc uploads independently COMPLETE, 1242x2688, checksums match. Two monthly subscription review screenshots also COMPLETE; Plus and Pro monthly products READY_TO_SUBMIT. Annual catalog entries remain excluded from the app launch offering.
- Six-language App Store metadata saved and read back. Subtitles/keywords within limits; substantial descriptions rather than placeholder launch text.
- IPA exported with Apple distribution signing, production APNs, debug entitlement disabled, correct app/extension version, privacy manifests and OS-only exempt-encryption keys. IPA: .asc/artifacts/Pushnow-1.0-1.ipa.
- Build c5228faf-dee0-4aac-a644-eba1462684ca is VALID (1.0 build1) and attached to version1.0.
- Review contact details reused from the same developer account's currently released Mo Layer1.0.9 review record. Dedicated sandbox review credentials and concrete review notes saved; readback verified. Contact/credentials remain in .secrets, not this report.
- AEO website deployed (734fcff9-a3e7-4eb1-b277-5358175e3717): six-language guide/36FAQ/JSON-LD match, canonical/hreflang/sitemap trailing slashes consistent, 121 sitemap URLs directly200, robots/sitemap/llms200.
- Latest asc validate: 0 errors, 0 blocking, 12 warnings, 1 info. Warnings mainly include optional promotional images, monthly subscriptions awaiting review and intentionally unused annual catalog entries; privacy publish state is outside public API verification.

## Not complete: actual review submission
1. App Privacy labels need purpose/linkage/tracking completion, publication and saved-state verification. Seven data types were previously selected. See metadata/review/privacy-declaration-plan.md. `asc web auth status` is unauthenticated; current native Chrome surface only exposes profile selection and no usable authenticated ASC page.
2. First-time monthly subscriptions must be associated with the app's initial version review through the supported App Store Connect web workflow. Neither product nor version has been submitted.
3. Dedicated review-account native sign-in/device-enrollment flow and actual sandbox purchase/restore need end-to-end verification. HTTP account login and visible production-account product loading are separate evidence and do not close this gate.

## Evidence
- metadata/screenshots/public-upload-readback.json
- metadata/screenshots/review/readback.json
- metadata/screenshots/review/monthly-product-readback.json
- metadata/review/details-readback.json
- .asc/audit-2026-09-13/build-final-readback.json
- .asc/audit-2026-09-13/version-build-attachment.json
- .asc/audit-2026-09-13/validate-final.json
- docs/qa/localization-device-final-2026-09-13.md
- docs/qa/appstore-archive-2026-09-13.md
- docs/release/payment-required-reason-api-audit.md
- docs/release/aeo-deployment-2026-09-13.md

Next external input: restore an authenticated App Store Connect web session (asc web login or an opened logged-in browser page). No approval has been requested for already-authorized submission; this is an unavailable-session and remaining-verification block, not a permission requirement.
