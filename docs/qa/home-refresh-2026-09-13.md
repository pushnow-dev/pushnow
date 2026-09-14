# Home refresh scheduling

The verified user's foreground Home root refreshes immediately when it becomes visible, then waits 30 seconds after each completed refresh before refreshing again. Leaving Home, entering a detail/settings destination, presenting a root sheet, or becoming inactive/background disables the schedule and cancels the current model request. Returning to the active Home root starts an immediate refresh.

Home's existing pull-to-refresh now uses `.scrollBounceBehavior(.always, axes: .vertical)` for short and empty loaded lists. The initial error state is also scrollable with pull-to-refresh, while retaining its retry button. Existing unread-filter empty-state and read/deletion overrides are preserved.

`InboxViewModel` coalesces concurrent loads into the same in-flight Task. Account-generation changes reset the model and cancel/invalidate the previous Task. A stale response cannot replace a newer account's items even if its repository ignores cancellation. Cancellation does not become an error screen or refresh error; already-loaded content remains visible.

Files: `HomeView.swift`, `HomeViewModel.swift`, new `HomeRefreshModifier.swift`, `HomeRefreshSchedule.swift`, and `HomeRefreshTests.swift`. The Xcode project includes both refresh files in the app target and both HomeRefreshTests and InboxReadStateTests in the test target. At coordinator request, MessageSourceBadge was added below the message title and above summary, with its source file included only in the app target.

Static validation: schedule typechecks directly with macOS Swift; project plist lint and `git diff --check` pass. App/extension Debug and Release remain build 2. Edited Swift files are at most 222 lines. No Simulator, UI or full app build was performed. The independent agent is executing the production algorithm and new tests in a macOS SwiftPM harness; its final result is recorded separately.

Physical QA still needs a new-message arrival on the visible Home screen, manual refresh with short/empty data, foreground resume, and confirmation that leaving Home suspends periodic requests.
