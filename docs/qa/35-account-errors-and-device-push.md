# Account error messages and physical-device push

2026-09-13.

- APIClient now decodes the backend error code on every non-success HTTP response, including no-response writes. APIStatusError retains HTTP status for existing callers. Only recognized public error codes are localized; arbitrary server messages and internal configuration details are not displayed.
- Distinct messages cover invalid login credentials, expired sessions, invalid/expired verification codes, invalid email/password, weak password, email conflict, throttling, email delivery failure, forbidden/missing content, conflicts, oversized requests and service failures. Added all six app languages.
- The backend intentionally does not distinguish a nonexistent account from an incorrect password or an unset password. The client does not invent that distinction; it suggests verification-code login.
- Account Settings logout is a centered, full-width neutral gray button, with a 48-point minimum height and adaptive foreground/background. No destructive red styling remains on this button.
- Signed physical-device build succeeded. Installed and launched on the paired iPhone15Pro, retaining app data/account. Current artifact: `/tmp/pushnow-payment-real/Build/Products/Debug-iphoneos/JiZhi.app`. Build log: `/tmp/pushnow-account-errors-build.log`.
- Added two focused auth/API error tests. The first test run was blocked by an unrelated UI-test compile error that was subsequently changed by concurrent work. The second simulator test run did not finish promptly and was interrupted after physical-device installation; no passing test claim is made for this run. Localization JSON parsing and git diff --check passed.

## Actual push

Sent exactly one encrypted message titled `真机推送测试` to physical device `443f3c5b-5af6-469c-bc09-1166cb00cc91`, message `2ad6e581-483b-4c93-8549-fc0af8d67ef7`.

Production readback: APNs status accepted, attempts1, no last_error, accepted_at `2026-09-13T00:53:42.897Z`. The device is active, notifications enabled, a sandbox APNs token exists, and an active session exists. Tokens were not printed. This establishes APNs acceptance, not a recipient-visible notification; user confirmation remains pending.

The old physical-device registration failure cannot be conclusively diagnosed from its generic screenshot. The simulator's earlier401 must not be assumed to explain the phone. Retry on the installed version now displays the specific supported error reason. No device, session or account was revoked to force a test.
