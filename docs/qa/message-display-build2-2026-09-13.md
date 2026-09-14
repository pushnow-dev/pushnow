# Message display and Home updates — build 2

Implemented readable detail timestamps in all three message protocols: localized today/yesterday with time, localized month/day for older dates, and year for prior-year dates. The selected timezone still determines date boundaries; technical GMT/IANA strings are removed from message detail presentation.

Message rows and details show source badges. Web/API/CLI/subscription attribution comes from explicit message metadata, with configured source type/name as a compatible fallback. Historical unknown attribution is not rewritten. The backend, website and CLI deployment evidence is in `../release/payment-message-source-implementation.md`.

Also integrated the bottom navigation layout fix, Subscriptions tab naming in six languages, read-on-open state, persistent read overrides, pull-to-refresh and foreground Home refresh every 30 seconds after the previous refresh finishes.

Validation: signed Debug device build succeeded (`/tmp/pushnow-inbox-updates-build.log`), and build 2 installed to the connected iPhone 15 Pro using devicectl. Ten changed localization keys contain all six supported languages. Fourteen production-algorithm macOS tests passed; see `read-state-macos-validation.md`. No Simulator was opened or used.

Pending: iPhone Mirroring reports the iPhone unavailable after installation. Current-build visual/interaction verification, replacement screenshots, release archive/upload and build-2 ASC attachment are not completed. The prior build-1 bottom-navigation screenshot verifies only that earlier layout fix. App Store privacy publication and first subscription association remain separate release checks; the app has not been submitted for review.
