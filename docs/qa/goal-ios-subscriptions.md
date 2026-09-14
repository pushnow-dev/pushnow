# iOS Discovery Subscriptions

## Scope and architecture

Discovery now offers account-scoped local subscription preferences for the static channel catalog.
`DiscoverView` gates access on a verified account and recreates its content for each user ID/session
generation. `DiscoverySubscriptionsViewModel` owns loading, validation, editing and unsubscribe;
`DiscoverySubscriptionStore` owns versioned persistence. The editor owns only an unsaved draft.
The timezone picker is a separate small View inside the editor file. Inbox rows are untouched.

## Parent project integration

Add these new files to the JiZhi app target / Compile Sources:

- `JiZhi/Models/DiscoverySubscription.swift`
- `JiZhi/Services/Discovery/DiscoverySubscriptionStore.swift`
- `JiZhi/Services/Discovery/DiscoverySubscriptionCopy.swift`
- `JiZhi/ViewModels/DiscoverySubscriptionsViewModel.swift`
- `JiZhi/Views/Discover/DiscoverySubscriptionEditor.swift`

Add `JiZhi/Tests/DiscoverySubscriptionTests.swift` only to the existing unit-test target.
Existing `JiZhi/Views/Discover/DiscoverView.swift` is modified and already has a project reference.
The old `DiscoverViewModel` in HomeViewModel.swift is intentionally untouched and no longer used by
Discovery. No pbxproj, string catalog, FeatureItem, HomeView, web or backend changes were made here.

## Persistence and boundaries

- Storage: UserDefaults, `pushnow.discovery.subscriptions.v1.<base64 UTF-8 account ID>`.
- Each JSON envelope also carries the exact verified account ID and schema version; mismatches,
  corruption, duplicate channel IDs, invalid times and unknown timezones fail closed.
- Each choice contains channel ID, daily-notification preference, hour, minute and IANA timezone.
- New choices default to 09:00 in the current timezone. Wall-clock components persist independently
  of phone timezone changes. Notifications disabled means an in-app-only preference, not delivery.
- Saving is synchronous on MainActor and checks the current verified account ID and session generation.
  An old sheet cannot write after logout, account switch or a new login generation.
- Views are recreated on account changes; reads are guarded as well as writes. Logout hides preferences
  but retains them for that account's next login on this installation. No email-based/global migration.
- Updates reload storage before writing to preserve other channels saved in another window.
- Unsubscribe removes only the current account's local choice. Cancel discards the editor draft.
- These are local preferences, not encrypted message content or credentials. UserDefaults is not an
  end-to-end encrypted account sync mechanism. Device/app backup and reinstall behavior follows iOS.
- No network subscription API, content fetching, APNs scheduling, notification permission request,
  local fake notifications, backend activation, or cross-device subscription sync is implemented.
- Rows explicitly say **Saved locally - pending activation**. The editor explicitly says delivery is
  inactive and preferences are saved only on this device. Do not represent these as active subscriptions.
- Backend activation/migration and server timezone/DST scheduling policy remain a separate task.

## Validation status

Test source added; **not executed**. No Simulator, device build or tests started, per assignment.
Source inspection and file-length checks only. Parent must add references and perform compilation
and device verification before claiming runtime success.

## Unit tests supplied

`DiscoverySubscriptionTests` covers verified/nonempty account gating; persistence across store instances;
account isolation; edits/unsubscribe; stale editor after logout; wrong account and stale generation;
misbound/corrupt storage; invalid time/timezone and duplicates; wall-clock preservation; multi-window
channel preservation; and failed writes not reporting saved state.

## Parent device checks (not run here)

1. Signed out or unverified: Discovery shows the email login gate; login opens the existing auth route.
2. Account A: save GitHub at 18:45 Asia/Shanghai. Confirm pending/local status, reopen and edit.
3. Save RSS as in-app only; verify Saved channels filter, search, and retained timezone/time settings.
4. Cancel changes; reopen and confirm persisted values are unchanged. Relaunch and confirm restoration.
5. Unsubscribe with confirmation; cancel once, confirm once; verify other channel remains.
6. Switch to account B: no A choices visible. Save B choice, return to A and confirm isolation.
7. Change account/logout while an editor is open: editor disappears and cannot save to either account.
8. Change phone timezone and language; selected subscription wall-clock/timezone remain unchanged.
9. Check English/Chinese, light/dark, large text and small display; scroll long timezone identifiers.
10. Confirm no subscription-generated notifications/content appear and all saved entries remain pending.

## Localization handoff

`DiscoverySubscriptionCopy.chinese` is the complete English-key to Simplified-Chinese map for this
feature (26 entries). Merge it into the catalog later if desired. Other languages use the existing
DiscoveryCopy catalog lookup with English fallback; new strings are not yet translated into Japanese,
Korean, Spanish or German. Existing channel names/categories continue using DiscoveryCopy.

| English key | Simplified Chinese |
| --- | --- |
| Discover | 发现 |
| Search channels | 搜索频道 |
| Saved channels | 已保存频道 |
| Save subscription | 保存订阅 |
| Edit subscription | 编辑订阅 |
| Save changes | 保存修改 |
| Saved locally - pending activation | 已保存到本机，待启用 |
| Delivery is not active. These preferences are saved only on this device for your account. | 通知尚未启用。这些偏好仅为当前账号保存在本机。 |
| Daily notification | 每日通知 |
| Daily time | 每日时间 |
| Timezone | 时区 |
| In-app only | 仅在 App 内查看 |
| Search timezones | 搜索时区 |
| Unsubscribe | 取消订阅 |
| Remove saved subscription? | 移除已保存的订阅？ |
| This removes the preference from this device only. | 此操作仅移除本机保存的偏好。 |
| Cancel | 取消 |
| Done | 完成 |
| Retry | 重试 |
| Sign in to save subscriptions | 登录后保存订阅 |
| A verified email account is required. | 需要已验证的邮箱账号。 |
| Sign in | 登录 |
| No saved channels | 暂无已保存的频道 |
| Your account changed. Reopen this channel. | 账号已变更，请重新打开此频道。 |
| Choose a valid time and timezone. | 请选择有效的时间和时区。 |
| Local preferences could not be loaded or saved. Try again. | 无法读取或保存本地偏好，请重试。 |
