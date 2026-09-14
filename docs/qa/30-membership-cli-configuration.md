# Membership CLI configuration

Verified on 2026-09-13 using ASC CLI, official RevenueCat CLI and MCP. Supersedes earlier missing-key/configuration blockers; no browser automation was used after the user requested CLI-only operation.

## Saved configuration

- RevenueCat CLI OAuth profile `pushnow` is authenticated. Project `proj4269c63c`, app `appfdd73d89a1`, bundle `com.createitv.pushnow`.
- App Store Connect API credentials and subscription private-key credentials were submitted through the official app-update API. Independent MCP readback reports both configured. Existing local keys were used without printing private material.
- The public iOS SDK key is present in the signed app's actual Info.plist. Real-device diagnostic output confirms signed-in product loading: `plus_monthly` / `com.createitv.pushnow.plus.monthly` / CNY 8.00; `pro_monthly` / `com.createitv.pushnow.pro.monthly` / CNY 18.00. See report 25.
- Both monthly products have saved en-US, zh-Hans, ja, ko, es-ES and de-DE metadata. Annual prices were not invented; annual plans remain hidden. Review screenshots remain missing. See report 26.
- Production migration 0007 and Worker version `9d74cabe-e613-409a-b658-c7c753427040` are live. App/environment validation, authorization and duplicate handling were verified. See report 29.
- RevenueCat webhook `whintgr7a285d9b21` was created for this app and production environment at `https://api.pushnow.dev/v1/webhooks/revenuecat`. Independent GET confirms ID, URL, app and environment. The authorization header was supplied during creation but is omitted from API readback; it cannot be independently compared from that response.
- A direct authenticated synthetic TEST was processed and its retry deduplicated. This is not evidence of RevenueCat-origin delivery or a purchase.

## Sandbox offer codes

- Plus and Pro each have 10 codes, independently confirmed as SANDBOX.
- Each grants one free month, with automatic renewal disabled; expiry is 2026-10-13.
- Private files: `.secrets/asc-sandbox-plus-20260913.json` and `.secrets/asc-sandbox-pro-20260913.json`. No code has been redeemed during this configuration run.
- These files, `.secrets/revenuecat-worker.json` and `.secrets/revenuecat-webhook-created.json` are Git-ignored and mode 0600, verified after configuration.

## Remaining verification gates

- Apple-to-RevenueCat server-notification URLs: explicit ASC field readback is null for production and sandbox URLs and their versions. Do not confuse this with the configured RevenueCat-to-Worker webhook. The actual app-specific RevenueCat destination must be obtained from an authoritative source before setting it; no guessed URL is acceptable.
- A bounded read-only RevenueCat CLI Rico audit also executed its app read tool and confirmed that the destination URL is not exposed by its available tools. Available CLI/MCP reads therefore cannot complete this field; dashboard retrieval remains necessary.
- Real sandbox purchase, restoration, redemption and RevenueCat-origin event delivery have not been completed. CLI product fetching and a synthetic webhook do not prove them.
- Production intentionally rejects sandbox events and does not grant production quotas from sandbox purchases. Full sandbox quota testing requires an isolated sandbox backend.
- App Store review screenshots and final review readiness remain incomplete. No app submission, real-money transaction or agreement acceptance occurred.

## Verification artifacts

- `/tmp/pushnow-payment-tests.log`: seven payment tests passed.
- `/tmp/pushnow-payment-real-build.log`: signed physical-device build passed.
- `/tmp/pushnow-payment-diagnostics.log`: real physical-device product-fetch result, without credentials or user identifiers.
- Backend: 32 tests across seven files passed; TypeScript check passed (report 29).

Apple notifications improve subscription-update latency but are not required for most updates: [RevenueCat Apple server notifications](https://www.revenuecat.com/docs/platform-resources/server-notifications/apple-server-notifications).
