# Cross-version inbox order

`RemoteJiZhiRepository.loadInbox` previously concatenated v2 shared, v1 encrypted and v1 plain messages. A fresh plain message therefore appeared below older v2 messages.

The combined result now sorts by parsed `receivedAt` descending. ISO 8601 timestamps with fractions, without fractions and with timezone offsets are supported. Equal timestamps retain input order; missing or invalid timestamps remain in their input order after dated messages. Reconciled inbox data is sorted before cache persistence, and cached reads are sorted so previous cache snapshots also display consistently.

Changed files:
- `JiZhi/Repositories/RemoteJiZhiRepository.swift`
- `JiZhi/Tests/JiZhiModelTests.swift`

Added two XCTest cases for mixed protocol versions and stable unknown/equal-date fallback, including empty input. Standalone macOS Swift execution of the exact extracted production sorter passed assertions for mixed versions, timestamp formats, offsets, ties, missing/invalid dates and empty inbox. The first attempt to invoke XCTest directly through the Swift interpreter lacked the XCTest module; the assertions were therefore run using Foundation-only Swift. The committed XCTest cases are not claimed as run under the app target.

`git diff --check` passed. No Simulator, UI interaction or full app build was performed. Physical-device behavior must be checked after the coordinator installs the updated build.
