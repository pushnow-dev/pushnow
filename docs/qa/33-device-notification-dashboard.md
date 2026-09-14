# Device notification dashboard

The dashboard now presents bound devices as responsive cards with a direct notification action. Selecting a card chooses only that device in the encrypted composer; users may select multiple eligible devices or explicitly choose all. Account device membership is distinct from the signed encryption recipient directory: devices absent from the latter show a connection action and setup guidance, never silently fall back to broadcasting.

The composer prioritizes destination, delivery method, title, body, and submit. Scheduling, sound, attachments, links, token, headers, browser configuration, and HTTP activity remain available under disclosures. Missing-icon copy describes the PushNow App icon fallback implemented in the iOS app.

## Checks

- Astro check: 53 files, no errors/warnings/hints; production build: 127 pages.
- Chrome local fixture login automatically established its encrypted sender connection.
- Clicking the fixture iPhone card selected the correct checkbox and focused the title field.
- Submitted notification `84824ed4-56f5-4331-bd44-24634e7ef57e` had only the selected iPhone device in delivery logs. The local fixture has no APNS credentials: push transport was reported blocked, not delivered.
- On iPhone 16 Pro / iOS 18.4, the selected-device message decrypted and displayed with the default App icon. Separate SDK encrypted icon upload retained the custom GitHub icon. See `default-app-icon-ios.md` for screenshots and evidence.
- Empty selected-device state was rejected. Changing the destination cleared the previous retry state. Direct account changes clear prior device selections.
- Desktop 1440px light and normal desktop dark inspected; 390px mobile showed no horizontal overflow. Temporary viewport override reset before returning to the user's live tab.
- Production signed-in dashboard loaded both account device cards. Its encryption directory contained one eligible device; the UI now explicitly distinguishes device setup from send readiness.
- Browser file picker permission prevented the custom-file upload UI test. SDK upload and iPhone custom-icon rendering passed independently; browser upload success is not claimed.

No production notification was sent by the agent during this task. No App Store release was performed; native fallback changes require the updated app.

Production web version: `8d854cdf-2e0a-4a76-b9bf-e4d7f037373d` on `https://pushnow.dev/dashboard/`.

## Expired-session regression found during production verification

The previous retry-header change passed a `Headers` instance into `jsonResponse`, which spread it as a plain object and discarded CORS headers on known errors. Once the real browser access token expired, this surfaced as MissingAllowOriginHeader and prevented token refresh. `jsonResponse` now normalizes every HeadersInit using `new Headers`, retaining CORS and Retry-After. Backend TypeScript check and three focused tests passed (401 CORS, 429 CORS plus retry guidance, tuple header support).

Backend fix deployed as `cd884fe2-d2af-4ec4-a9c1-96c61bbcc721`. Live 401 readback retained Access-Control-Allow-Origin, and the user's browser successfully refreshed its expired session and loaded the dashboard without entering credentials. Final live UI verified both the eligible-device selection and the unavailable-device setup guidance.
