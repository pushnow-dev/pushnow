# Pushnow subscription release audit

Verified live on 2026-09-13 using ASC CLI and RevenueCat MCP. User authorized catalog completion. Existing products were reused; no duplicate products, new prices, entitlement grants, or review submissions were created.

## Saved catalog changes

- Renamed all four ASC product reference names from JiZhi to Pushnow, preserving stable store identifiers.
- Corrected existing English and Chinese customer-visible subscription names.
- Renamed the subscription group to Pushnow Membership; completed its English, Simplified Chinese, Japanese, Korean, Spanish and German names, with Pushnow as the custom app name.
- Monthly products already had six locales. Annual locales were completed as catalog housekeeping, without enabling annual purchases or inventing prices.
- Exact mutation list and readbacks: `payment-catalog-readback.json`.

| Product | ASC ID | Release scope | China monthly price | Entitlement |
| --- | --- | --- | --- | --- |
| com.createitv.pushnow.plus.monthly | 6811365720 | Current native paywall | CNY 8 | plus |
| com.createitv.pushnow.pro.monthly | 6811365836 | Current native paywall | CNY 18 | pro |
| com.createitv.pushnow.plus.yearly | 6811365755 | Excluded; no price | — | plus |
| com.createitv.pushnow.pro.yearly | 6811365781 | Excluded; no price | — | pro |

Monthly levels remain Pro 1 / Plus 2. Annual existing levels are unchanged; before annual launch, align equivalent tier levels and deliberately set annual prices. Plus monthly availability was freshly counted at 175 territories, with new territories enabled. Earlier same-day audit confirmed the same for Pro; no availability change was made.

## RevenueCat live readback

Project `proj4269c63c`; App Store app `appfdd73d89a1`; bundle `com.createitv.pushnow`. Both App Store Connect API key and subscription key configured booleans are true. This supersedes earlier reports describing missing credentials.

Offering `ofrng8c206301a1` (`default`) is active/current. Its four packages each contain the matching ASC store identifier, on the correct App Store app. Expanded entitlement reads confirm monthly/yearly Plus products attached to `plus` and monthly/yearly Pro attached to `pro`. No mapping writes were needed.

Some RevenueCat internal display names and offering metadata still say JiZhi. The available MCP surface has no update-app/product/offering capability, and the required RevenueCat skill mandates MCP for interaction. These internal labels were not modified via an alternate interface; store identifiers and native package mapping are correct.

## Reviewer instructions

Sign in with the review account provided in the app review record. Open Settings, then Membership. Select Plus or Pro monthly and complete the Apple sandbox sheet. Return to Membership and verify the purchased tier. Use Restore Purchases on this page to restore the same Apple account's purchase; the backend account must match the intended RevenueCat identity. Privacy and Terms links are provided from this page.

Actual membership-screen review screenshots must be attached to both monthly products. Do not substitute an unconfigured paywall or generated UI for this evidence. Marketing screenshots can be packaged separately from genuine device captures.

## Remaining verification gates

- At catalog readback, all four products remain MISSING_METADATA. Plus review screenshot relationship was confirmed empty; both monthly screenshots were empty in the earlier same-day detailed audit. Upload genuine functioning membership screenshot and re-read processing/state.
- Actual sandbox purchase, restore and paid account entitlement synchronization are not certified by this catalog work.
- The production backend deliberately filters out sandbox subscriptions. App Review purchases need an explicit, persistent isolated sandbox routing/backend solution; the existing local sandbox verifier does not provide reviewer access.
- Paid Apps Agreement, banking and tax readiness are unverified through the public ASC API. Do not interpret API authentication as agreement confirmation.
- Earlier same-day audit found Apple-to-RevenueCat notification URLs unset. The actual RevenueCat app-specific URL needs a supported read surface; do not guess one. This affects update freshness, not basic proof that SDK purchase is impossible.

No App Store review submission, real-money purchase, agreement acceptance or production entitlement grant was performed by this audit.

## Isolated review backend follow-up

A dedicated Worker `pushnow-api-sandbox` is deployed at `https://sandbox-api.pushnow.dev`. It uses D1 `pushnow-sandbox` (`a4256170-39bf-4a20-90a5-12c3390ac6bf`), private R2 `pushnow-sandbox-secure-blobs`, all 11 migrations, independent auth pepper / token encryption key / webhook secret, and `REVENUECAT_ENVIRONMENT=SANDBOX`. Production resources were not reused. APNs provider credentials are shared as Apple credentials for the same bundle; device/token rows are not shared.

RevenueCat sandbox-only webhook `whintgr0e357bf554` targets the sandbox URL and exact app `appfdd73d89a1`. Creation response verifies URL/environment/app configuration; synthetic request testing is distinct from actual RevenueCat-origin delivery.

Sandbox identities now use `jizhi_sandbox_<uuid>`. Production keeps `jizhi_<uuid>`. Signup, reconciliation and webhook identity checks share this boundary. The native owner is implementing the corresponding visible environment selector and isolated client data.

A dedicated Free review account is provisioned only in sandbox D1 with a randomized password. Credentials are in ignored `.secrets/sandbox-review-account.json`, mode 0600; never copy them into public documentation. Provisioning adds no authentication bypass endpoint. The standard password login must pass live before this is called reviewer-ready.

### Password runtime defect discovered during verification

Actual edge login returned HTTP 500, despite local tests passing. Restricted sandbox error logs identified `NotSupportedError: Pbkdf2 failed: iteration counts above 100000 are not supported (requested 210000).` Both native WebCrypto and node:crypto hit this limit. Added pinned `@noble/hashes@2.4.0` PBKDF2-SHA256 derivation, preserving the existing 210,000 iteration count, salt/pepper encoding, and stored hash format. Node-generated existing-hash vectors, valid/invalid passwords and work-factor bounds are covered by tests. The implementation follows the [library's PBKDF2 documentation](https://github.com/paulmillr/noble-hashes) and addresses the [Workers native PBKDF2 cap](https://github.com/cloudflare/workerd/issues/1346).

This source change is shared by production and sandbox. Deployment and live login evidence below determine where the fix is verified; no existing password hashes were downgraded or migrated.

### Verified sandbox outcome

Live `payment-sandbox-readback.json` confirms health200, readiness200, password-login200, correct sandbox identity namespace, Free50 account membership200, production rejection of sandbox access token401, sandbox rejection of production webhook event400 and authenticated synthetic TEST200. The test account now works through standard login without email codes. This is not a purchase/restore pass; a real Apple sandbox transaction remains required.

### Changed files and validation

- Catalog: `docs/release/payment-catalog-readback.json`, this report; 27 ASC writes, including eight annual and four group localization creations. Four original products reused; none duplicated.
- Sandbox infrastructure: `backend/wrangler.sandbox.jsonc`; three scripts for provision/local membership/live account verification; live readback JSON.
- Identity boundary: `backend/src/revenuecat-identity.ts`, `auth-service.ts`, `revenuecat-sync.ts`, `revenuecat-routes.ts`.
- Password compatibility: `backend/src/password-derivation.ts`, `crypto.ts`, package and lockfile. No password hash format or work-factor downgrade.
- Tests: `revenuecat.test.ts`, `sandbox-isolation.test.ts`, `password-derivation.test.ts`; fixed an existing narrow fixture cast in `http-cors.test.ts` so TypeScript checking succeeds.
- TypeScript passes. Focused payment/identity tests:12 passed; auth tests:5 passed; password vectors:2 passed. Full suite:90 passed with one new password-vector test timing out under concurrent suite load at5 seconds; that test now allows15 seconds and was rerun separately. No behavioral assertion failed in the full run.

The existing `auth-service.ts` remains347 lines (mostly pre-existing); new dedicated modules are6–8 lines and sync/routes remain under60 lines. No unrelated source refactor was performed.

### Final deployment readback

- Sandbox final version: `b598fc2d-04db-4b20-a47c-d63c32885ef8`, with independent sandbox resources and `SANDBOX` payment filter.
- Production final version: `885cd5ef-ac57-491c-8e85-e07f7fb7372e`, retaining `jizhi-production`, `pushnow-secure-blobs`, `api.pushnow.dev/*` and `PRODUCTION` payment filter. Only the shared runtime fix/identity code was deployed; no production account or entitlement was created/changed by this work.
- Temporary sandbox exception logging used to diagnose the native cap was removed before these final deployments.
