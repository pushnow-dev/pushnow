# Dashboard and SDK Frontend Acceptance

Date: 2026-09-13. Scope: frontend first; backend activation remains a separate gate.

## Implemented

- Independent `/dashboard/` and localized dashboard paths, signed-in navigation on the website and Docs, and post-login dashboard redirect.
- Shared account-session handling: single-flight token refresh, late-401 handling, remote logout, account-change cleanup and transient-error retention.
- Dashboard account/device/membership views, Key metadata/expiry controls, delivery logs and a browser API playground.
- Playground sender authorization or private configuration import, account/origin binding, editable source Token, verified device selection, encrypted title/body, icon/image/files/links, inbox-only, UTC schedule, exact in-memory retry and redacted HTTP activity.
- Sender secrets remain in memory, cleared on logout/account change/page exit. Explicit export is a secret-bearing file; no source credentials are stored in browser storage.
- English local-Markdown Docs with their own layout, real Markdown links/tables/headings, SDK and HTTP guides. Docs also show the login state.
- Local `sdk/typescript/` npm package plus `sdk/python/`, `sdk/go/`, `sdk/java/` bindings. The last three require their documented bundled Node runtime; no registry publication occurred.
- Account-scoped iOS discovery subscription preferences, daily wall-clock time/timezone, edit/cancel/unsubscribe and truthful pending-activation state. See `goal-ios-subscriptions.md` for boundaries and files.

## Verified

- Web static check rerun: 47 files, zero errors/warnings/hints.
- Astro build: 121 pages. `@hpke/common` emits its Node crypto fallback externalization warning; actual browser E2EE runs succeeded without Node globals.
- `web/scripts/test-account-session.mjs`: signed-in nav, one refresh for concurrent/late 401s, 503 retention, server logout and UI/storage cleanup passed.
- `web/scripts/test-account-console.mjs`: English 1440px and Chinese 390px Key creation, expiry, revoke confirmation, log filter/pagination and one-time-secret cleanup passed.
- `web/scripts/test-playground.mjs`: actual browser HTTP/CORS to disposable Worker/D1/R2 passed. Checks cross-account rejection, invalid Token rejection, encrypted title/body, icon/image/file manifests, links, selected recipients, inbox-only, future schedule, byte-identical retry/deduplication, no secrets/plaintext in HTTP traces, logout cleanup and no horizontal overflow.
- The playground test passed against the built site at `http://127.0.0.1:4326`, not only Vite development code. The browser explicitly grants local-network access to the fixture; CORS enforcement is not disabled.
- Parent reviewed screenshots `/tmp/pushnow-dashboard-390.png` and `/tmp/pushnow-dashboard-1440.png` and fixed mobile navigation overlap and outer section framing.
- SDK agent reports: TypeScript seven tests including real Chromium/Worker/D1/R2/CLI decryption; Python/Go/Java checks and nine runtime vector/HTTP tests passed. Their source assertions and documented runtime requirements were reviewed.
- Signed iOS generic-device build passed after adding subscription source/test references. This is compilation evidence only.
- Physical iPhone 15 Pro (iOS 18.7) subscription tests passed: 10 passed, zero failed/skipped. Evidence: `/tmp/pushnow-subscriptions-real-02.xcresult`, read using `xcresulttool get test-results summary`. Latest app installed and launched on the same phone; visual subscription-flow acceptance remains separate.
- `test-login-modal.mjs` passed code/password mode, four-digit validation, Enter handling, centered desktop/mobile presentation and clean Dashboard redirect.
- Browser authorization in `test-playground.mjs` passed against the real local HTTP fixture, including independent root fingerprint confirmation and a send using the newly authorized sender.
- Real-device visual interaction through iPhone Mirroring passed: Discover > GitHub > set daily time from 09:00 to 10:00 > save > row shows 10:00 and Asia/Shanghai > reopen editor retains both > unsubscribe confirmation > row returns to unsubscribed. The test-only preference was removed. The UI accurately states local storage / pending activation.
- Cloudflare website deployed, current version `172e363a-d27d-456c-8fdc-aabf12904435`. Public Chromium checks on `https://pushnow.dev` passed for Dashboard and TypeScript/Python/Java/Go Docs: HTTP 200, no page errors, no horizontal overflow at 390px. Screenshot: `/tmp/pushnow-live-sdk-mobile.png`. Homepage now uses the actual encrypted SDK example instead of the obsolete plaintext ingest example.

## Not Completed

- Physical cross-account UI inspection remains pending; persistence and unsubscribe were exercised visually, account isolation was unit tested. The first disconnected-device attempt failed; the subsequent unit-test run passed. No Simulator was used.
- Production Dashboard-to-iPhone delivery verification is pending a real signed-in browser session. The user was asked to sign in on the live Dashboard; no production browser credentials were fabricated or bypassed.
- Production backend still requires auditing/applying existing pending device/Key/schedule migrations and deploying the matching Worker before all dashboard management paths can be claimed live.
- Custom and silent per-message sounds have frontend controls but fail explicitly before submission. They are not in the current v2 backend/APNs contract. System default sound remains supported.
- Arbitrary extra `X-` request headers require server CORS support; leave them empty for the current backend.
- Discovery subscriptions save preferences locally per verified account. They do not fetch content, sync across devices, or activate recurring server delivery yet, as requested for the frontend-first phase.
- No App Store, npm, PyPI, Maven or Go registry publishing was performed.

## Remaining Acceptance

Inspect daily-time/account-switch flows on the physical iPhone. Then verify one explicit production Dashboard push on that phone. Re-audit all pending backend gates rather than inferring production readiness from the local fixture. Keep the overall goal active until the full requested state is verified.
