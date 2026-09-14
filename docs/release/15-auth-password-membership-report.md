# Auth Password And Membership Report

> Date: 2026-09-12
> Scope: email verification plus password login, RevenueCat-oriented membership plans, daily quota enforcement, push notification review boundary.

## Completed

- Added backend password setup after verified email login.
- Added backend email and password login at `POST /v1/auth/password/login`.
- Added password hash storage with salt, PBKDF2-SHA256 iterations, and server pepper.
- Added `hasPassword` and `passwordSetAt` to user/session contracts.
- Added `GET /v1/me/plan` for membership status.
- Added Free, Plus, and Pro membership model:
  - Free: 50 notification items per day.
  - Plus: 500 notification items per day.
  - Pro: unlimited notification items, still subject to abuse and platform limits.
- Added server-side usage counting for new ingested items. Idempotent retries do not consume quota.
- Added D1 migration `0003_auth_password_membership.sql` for password fields, entitlements, and usage counters.
- Updated iOS auth UI to support password login, email-code verification, and password setup after verification.
- Updated iOS settings to show account email, user ID, login state, App push state, and push rebind action.
- Updated iOS paywall UI with Free, Plus, and Pro cards and the daily quota labels.
- Updated product and engineering docs with the new auth and membership plan.
- Updated OpenAPI with password login, password setup, and membership status endpoints.

## Production Backend Verification

- `npm run check`: passed.
- `npm test`: passed, 5 files and 17 tests.
- `npm run db:migrate:local`: applied local D1 migrations.
- `npm run deploy:dry`: passed and read back production bindings for D1, Email Service, and auth env vars.
- `npx wrangler deploy`: deployed Worker version `98b6a16a-7b61-4b80-94da-4d7493bc8b27`.
- `GET https://api.pushnow.dev/health`: `{"status":"ok"}`.
- `GET https://api.pushnow.dev/readyz`: `{"status":"ready"}`.
- Missing-user password login returned `401 invalid_credentials`, without exposing account existence.
- Remote D1 readback confirmed `users.password_hash`, `users.password_set_at`, `entitlements`, and `usage_counters`.

## iOS Verification

- `xcodebuild build -project JiZhi.xcodeproj -scheme JiZhi -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4'`: passed.
- `xcodebuild test` compiled and started testing, then was interrupted after the runner stalled during test-session cleanup. It did not produce an XCTest assertion failure, but it is not counted as a completed test pass for this run.
- Simulator install and launch succeeded on iPhone 16 Pro iOS 18.4.
- Screenshot evidence:
  - `/tmp/jizhi-current-2.png`: dark-mode home screen rendered.
  - `/tmp/jizhi-settings.png`: settings page shows account, user ID, login state, App push state, and Free quota.
  - `/tmp/jizhi-paywall-2.png`: paywall shows Free 50/day, Plus 500/day, and Pro unlimited.

## RevenueCat Status

Local app code now has the plan model, entitlement mapping, paywall UI, and a `RevenueCatService` integration boundary. RevenueCat project resources, app, products, entitlements, current offering, and packages have been created and read back; see `docs/release/16-revenuecat-configuration-report.md`.

Do not claim App Store purchase readiness until these are configured and verified:

- Public iOS SDK key is available and configured.
- App Store Connect subscription metadata is complete for:
  - `com.createitv.pushnow.plus.monthly`
  - `com.createitv.pushnow.plus.yearly`
  - `com.createitv.pushnow.pro.monthly`
  - `com.createitv.pushnow.pro.yearly`
- App Store Connect prices, availability, localizations, review screenshots, and review notes are complete.
- RevenueCat App Store Connect API key and subscription key are configured.
- RevenueCat webhook secret is configured in Cloudflare and events update `entitlements`.
- Sandbox purchase and restore work on a real device or TestFlight.

## Apple Review Assessment

The Free, Plus, and Pro quota model is viable for App Review if the paid tiers unlock app service capacity and are sold as in-app purchases through Apple's IAP flow via RevenueCat. The app must clearly disclose quota limits, renewal terms, pricing, and what the user receives.

Apple push notifications can support this product behavior, but they cannot be guaranteed as an always-immediate delivery channel. The app must request notification authorization, respect user settings, and treat APNs delivery as best-effort. Membership can control how many notification items the service accepts or schedules, but it should not promise that iOS will display every notification instantly under all device conditions.

Official references:

- App Store Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Notifications overview: https://developer.apple.com/notifications/
- UserNotifications authorization: https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
