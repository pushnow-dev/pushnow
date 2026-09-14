# Harmony / iOS parity source audit

Date: 2026-09-13. Baseline: current local `JiZhi/` live application and `harmony/entry/src/main/ets/`, read-only source review before the UI rewrite. This audit does not prove what build is installed on the user's iPhone or establish pixel fidelity. Mirror screenshots and physical-device checks remain mandatory. Paths below are repository-relative. Other agents may change the implementation after this baseline.

## Result and evidence boundaries

The original Harmony app is a working encrypted-message/device/sender client with a different four-panel UI, not a port of the iOS interface. iOS has Home, Sources (tab label Inbox), Discover, Reminders, plus a Settings navigation tree. Harmony has Inbox, Devices, Senders, Account and no navigation stack for message details. Existing encrypted transport must be retained while rebuilding navigation and adding missing product flows.

`AppEnvironment.live()` uses `RemoteJiZhiRepository`; previews are not the live reference. Some live iOS UI intentionally or accidentally uses static/local content. These limitations are listed explicitly so no port falsely advertises server behavior.

## Page-by-page UI and functionality acceptance matrix

| Area / source | iOS structure and actual behavior | Original Harmony gap | Acceptance evidence required |
|---|---|---|---|
| Shell: AppRootView, AppTab, JZChrome | Floating translucent rounded four-icon tab bar; Home / Inbox / Discover / Reminders. Settings via home avatar. Stack routes and sheets. | Full-width text button strip with different destinations; persistent Pushnow + Refresh header on every page. | Mirror each tab and route; reproduce titles, icon placement, selected colors, bottom safe area, back behavior, scrolling. |
| HomeView / InboxViewModel | Avatar, centered name, search, plus; 6 horizontal filter chips; flat separated rows with unread dot, icon, title, relative timestamp, two-line summary and priority/reminder badges; pull refresh, cached inbox and recoverable refresh error. Plus opens Sources or Auth. | Large heading, bordered cards, inline expansion and action buttons; no filters, source icons, relative time or offline inbox. | Same-account same-message screenshot pair; unread/priority/reminder filters; offline relaunch; refresh failure with cached content. Search and two filter limitations below. |
| SourcesView | Centered subscription title and plus; My sources/Discover segment; personal access cards; subscribed rows with switches. Plus sheet goes to sender authorization for trusted device, otherwise Devices. | Missing entire page, replaced with Senders tab. | Route through plus, untrusted/trusted states, source loading, segment switching; preserve actual static subscription behavior transparently. |
| DiscoverView / DiscoverySubscriptionEditor | Search, 7 filters, branded platform rows, local saved status; edit sheet with daily notification toggle, time, searchable timezone, save/update/unsubscribe confirmation. Account scoped persistent storage. | Entire catalog, editor, preferences and brand assets missing. | Search/filter all catalog entries; save/relaunch/edit/remove; change account and verify isolation; ensure UI says delivery pending/local-only. |
| RemindersView | Title, ellipsis, 4 chips, day-grouped active timeline and cancelled section. Data comes from /v1/reminders with item/source join. | Missing page/service/model. | Same account reminders, priority and cancelled states; server errors must not be called successful loading. iOS chips currently do not filter. |
| Legacy ItemDetailView | Back header; source/timestamp; hardcoded report banner/body; remote content module rows; acknowledge and reminder editor. | No /v1/items support, legacy message rows or detail layout. | Verify actual iPhone has legacy items; fetch same IDs; acknowledgement readback; treat hardcoded text/no-op controls as limitations. |
| SecureItemDetailView (v1) | Dedicated encrypted detail with timestamp/title/body and acknowledgement then back. | Inline expansion, separate mark-read action. | Open same secure message; acknowledge API and both-device state. |
| SecureV2DetailView / model | Dedicated nav detail; optional icon + hero image; selectable title/date/body; tappable HTTP(S) links; named/size attachment rows; auto-mark-read on load; trash confirmation; Markdown sheet or QuickLook. Clears files and dismisses on account change. | Inline body; URLs only selectable; no automatic read on open; no iconId/imageId placement; text-only Markdown; binary files save-only. | Same message image/link/Markdown/PDF/text attachment checks, back/read state, cancel/confirm deletion, cross-device deletion, account change clears content. |
| ReminderEditorView | Save-only/immediate/delay/scheduled/repeat modes; date picker; priorities; push/ack constraints; API save for legacy items. Encrypted item reminders rejected with sender scheduling instruction. | Entire page and service missing. | Submit each mode and inspect payload/readback; push off clears ack; repeat uses daily RRULE. Do not claim encrypted scheduling supported. |
| SettingsView | Account, Membership; Timezone, Language, Appearance; About; Privacy/Terms links in grouped list. | Only basic Account panel. | Screenshot every child and legal link; return navigation and persistent values. |
| AuthView / AuthViewModel | Dedicated header/icon/help, segmented password/email-code flow, phased fields; first-login password setup with confirmation; busy/error states; automatic push enable then back after verification. | All email/code/password fields simultaneously shown; no password setup, phase model, segmented control or auto push enable. | Existing password login; email verify; first-time password setup; invalid/expired inputs; logout/relaunch session. Never send emails without user's explicit authorization. |
| AccountSettingsView | Email/user ID/verified state; Devices & Encryption, Sender keys, Notification logs; push status/retry; logout. | Omits user ID, nested links, detailed push states. | Correct current-account data and navigation; real push permission/token binding readback; failed state and logout. |
| DevicesView / DeviceRow | Account fingerprint or pending pairing code; account devices hiding revoked entries; model/system/app info; rename alert; notification switch; history grant; sender route; sync history key; pending poll every 3 sec. | Card layout, bind/check buttons, absent metadata/account fingerprint/history sync button; displays revoked entries; no pending poll. | Two-device pairing/approval, name/toggle readback, history grant and message availability; compare pending screens. |
| DeviceApprovalView | Dedicated form requires typing 16 hex pairing digits, verifies via service. | Show code button + checkbox-equivalent dialog confirmation instead of input. | Correct and incorrect code; no approval before matching; resulting trust on other device. |
| SenderAuthorizationView | Form; key/log links; account fingerprint, lookup, name/sender fingerprint, explicit match toggle, expiry picker, authorize; active sender list/revoke. | Basic lookup/confirm/revoke exists but no expiry picker or key/log links; revoked senders not filtered. | Lookup same request, expiry payload, invalid/expired code, unchecked match prevents authorization; revoke readback. |
| SenderKeysView + editor | Key source/prefix/state/dates; logs per key; edit expiry; create additional key; one-time secret display; revoke confirmation. | Entire key lifecycle UI/service absent. | /v2/keys load/patch/delete, /v1/sources/:id/keys creation; account-switch clears secret; expiry readback. |
| NotificationLogsView + detail | Paged /v2/logs list; key filter; source, ID, schedule/expiry/read; per-device delivery attempts/status/acceptance/error. | Entire feature absent. | Multi-page cursor, key filter, detail and retry; distinguish push service accepted from recipient delivered. |
| MembershipContentView | Current membership, comparison table, Free/Plus/Pro plan picker, live price/availability, RevenueCat purchase/restore, offer redemption, pending/reconcile status, legal footer. | No membership model/service/view. | Same account entitlement and limits; real catalog availability; purchase/restore sandbox evidence. Apple redemption and Apple billing are platform-specific; do not fabricate functional Harmony purchase buttons. Repo requires RevenueCat for paid functionality. |
| Preferences | Persisted system/light/dark appearance; system + six languages; searchable IANA timezone list; timestamps honor setting. About real version/build/minimum OS. | System-color watch only; system localization only; fixed theme file not aligned; no timezone/about. | Switch, relaunch, compare light/dark screenshots and date formatting for each supported language; platform-specific About values accurate. |
| Push entry / cache | iOS notification route validates account, fetches/decrypts target and pushes detail; secure extension previews; encrypted inbox/message/attachment cache and deletion reconciliation. | onNewWant only refreshes; no deep-link target route; only key/session storage, no equivalent encrypted offline history cache. | Tap real received notification from background/cold start; opens correct message only for current account; offline history and deletion sync. |

## iOS limitations that must not be confused with complete features

- Home search is `IconButton(...){ }`. Home `新到结果` and `来源` filters fall through to all items.
- Sources `loadSubscribedChannels()` uses `PreviewJiZhiRepository`; each switch mutates local View state only. Source cards have no tap action despite chevron.
- Discover catalog is static, but search/filter and account-scoped local subscription save/edit/delete are real. Delivery is explicitly inactive; neither remote activation nor cross-device subscription sync exists.
- Reminder selectedFilter is never consumed by active/cancelled arrays; ellipsis has no trailing action. Error loading is swallowed into empty data. Day order includes hardcoded Chinese example strings.
- Legacy detail report text and reminder banner are hardcoded; module buttons and favorite have empty actions. Remote module loading and acknowledge do call APIs.
- Legacy reminder editor writes a real API request, but timezone display is hardcoded Beijing while submitted timezone is current system. Encrypted reminder creation is explicitly rejected.
- `SecureSourceSetupView` and `SourceCreationSheet` contain implementation but the current Sources plus sheet resolves to `SecureSourceEntryView` -> sender authorization/device approval. Their existence alone is not a reachable feature proof.
- RevenueCat service code is implementation evidence only; current live offering/products, purchase readiness and same-account entitlement must be checked independently.

## Shared security/business services already implemented in Harmony

Auth refresh/logout and generation guards; secure device enrollment, identity comparison and approval; P256 signing/verification, key derivation and authenticated decryption; shared archive key transfer; v1 and v2 encrypted inbox fetching; v2 pagination/deletion sync; integrity-checked attachment download/decrypt and image/text preview/file export; sender authorization/revoke; secure push token registration/rotation; device rename and notifications API writes. These are not placeholders, but source alone is not E2E proof.

Missing backend client surfaces include legacy /v1/items, /v1/sources, /v1/reminders; /v2/keys and /v2/logs; password setup; membership reconciliation. Do not replace existing crypto services with sample content to make screenshots resemble iOS.

## Visual tokens from iOS source

Light background #FFFFFF, dark #0D1117; grouped #F6F8FA / #161B22; elevated #FFFFFF / #21262D; text #1F2328 / #F0F6FC; muted #59636E / #8B949E; divider #D1D9E0 / #30363D; blue #0969DA / #58A6FF. Standard cards padding 14 radius 8, 1-point divider at 0.7 opacity. Home content inset 18, row vertical padding 14, icon 38 circle, unread dot 8. Chips height 32 with horizontal padding 12. Tab bar outer horizontal margin 22/bottom 8, radius 18, internal padding 6 and icon 18. Font metrics must be verified against real phone mirror, not assumed identical across OS rendering.

## Verification gates

1. Capture iPhone mirror reference for all reachable pages and sheets, same account, appearance and locale; document exact installed build and device dimensions. Capture sensitive one-time keys only with redaction in shared artifacts.
2. Reproduce the same state on Harmony physical phone and save screenshots before/after; compare normalized content bounds while recording system status/navigation bar differences.
3. Test every matrix row, not just shell. Read server state back after writes; confirm actual recipient behavior for push. Do not mutate production sender keys or purchase merely to satisfy a checkbox without task authorization.
4. Verify persistence, account isolation, failure/offline states, large content and back navigation. Visual parity cannot compensate for lost encryption/trust/attachment behavior.
5. Mark each row passed/failed/blocked with artifact paths. Build/install/start success is insufficient. Unimplemented platform payment semantics and unreached iPhone pages remain explicit gaps.

## Source inventory

Files enumerated for audit scope (application code, excluding template and test source). UI/routes/live data paths were inspected directly; supporting services were checked by declarations and call sites where no divergence required a deeper read. This is not a formal security review.


### JiZhi/App

- `JiZhi/App/AppConfiguration.swift`
- `JiZhi/App/AppDelegate.swift`
- `JiZhi/App/AppEnvironment.swift`
- `JiZhi/App/AppRootView.swift`
- `JiZhi/App/JiZhiApp.swift`

### JiZhi/Navigation

- `JiZhi/Navigation/AppRoute.swift`
- `JiZhi/Navigation/AppRouter.swift`
- `JiZhi/Navigation/AppTab.swift`
- `JiZhi/Navigation/SheetDestination.swift`

### JiZhi/Views

- `JiZhi/Views/Auth/AuthView.swift`
- `JiZhi/Views/Components/JZChrome.swift`
- `JiZhi/Views/Components/JZTheme.swift`
- `JiZhi/Views/Components/SecureImageView.swift`
- `JiZhi/Views/Devices/DeviceApprovalView.swift`
- `JiZhi/Views/Devices/DeviceRow.swift`
- `JiZhi/Views/Devices/DevicesView.swift`
- `JiZhi/Views/Devices/NotificationLogsView.swift`
- `JiZhi/Views/Devices/SecureSourceEntryView.swift`
- `JiZhi/Views/Devices/SecureSourceSetupView.swift`
- `JiZhi/Views/Devices/SenderAuthorizationView.swift`
- `JiZhi/Views/Devices/SenderKeysView.swift`
- `JiZhi/Views/Discover/DiscoverView.swift`
- `JiZhi/Views/Discover/DiscoverySubscriptionEditor.swift`
- `JiZhi/Views/Home/HomeView.swift`
- `JiZhi/Views/ItemDetail/ItemDetailView.swift`
- `JiZhi/Views/ItemDetail/SecureItemDetailView.swift`
- `JiZhi/Views/ItemDetail/SecureMarkdownView.swift`
- `JiZhi/Views/ItemDetail/SecureV2DetailView.swift`
- `JiZhi/Views/Paywall/MembershipComparisonTable.swift`
- `JiZhi/Views/Paywall/MembershipContentView.swift`
- `JiZhi/Views/Paywall/MembershipPlanPicker.swift`
- `JiZhi/Views/Paywall/PaywallView.swift`
- `JiZhi/Views/ReminderEditor/ReminderEditorSupport.swift`
- `JiZhi/Views/ReminderEditor/ReminderEditorView.swift`
- `JiZhi/Views/Reminders/RemindersView.swift`
- `JiZhi/Views/Settings/AboutSettingsView.swift`
- `JiZhi/Views/Settings/AccountSettingsView.swift`
- `JiZhi/Views/Settings/AppearanceSettingsView.swift`
- `JiZhi/Views/Settings/LanguageSettingsView.swift`
- `JiZhi/Views/Settings/MembershipSettingsView.swift`
- `JiZhi/Views/Settings/SettingsView.swift`
- `JiZhi/Views/Settings/TimezoneSettingsView.swift`
- `JiZhi/Views/Shared/AuthRequiredStateView.swift`
- `JiZhi/Views/Shared/ErrorStateView.swift`
- `JiZhi/Views/Shared/LoadingStateView.swift`
- `JiZhi/Views/Sources/SourceCreationSheet.swift`
- `JiZhi/Views/Sources/SourcesView.swift`

### JiZhi/ViewModels

- `JiZhi/ViewModels/AuthViewModel.swift`
- `JiZhi/ViewModels/DiscoverySubscriptionsViewModel.swift`
- `JiZhi/ViewModels/HomeViewModel.swift`
- `JiZhi/ViewModels/PaywallViewModel.swift`
- `JiZhi/ViewModels/SecureImageModel.swift`
- `JiZhi/ViewModels/SecureV2DetailModel.swift`
- `JiZhi/ViewModels/SettingsViewModel.swift`

### JiZhi/Services

- `JiZhi/Services/Auth/AuthAPIModels.swift`
- `JiZhi/Services/Auth/AuthService.swift`
- `JiZhi/Services/Auth/AuthSessionStore.swift`
- `JiZhi/Services/Devices/DeviceDisplayName.swift`
- `JiZhi/Services/Devices/SecureArchiveService.swift`
- `JiZhi/Services/Devices/SecureDeviceService.swift`
- `JiZhi/Services/Devices/SecureSourceService.swift`
- `JiZhi/Services/Devices/SenderAuthorizationService.swift`
- `JiZhi/Services/Devices/SenderManagementService.swift`
- `JiZhi/Services/Discovery/DiscoverySubscriptionCopy.swift`
- `JiZhi/Services/Discovery/DiscoverySubscriptionStore.swift`
- `JiZhi/Services/Encryption/SecureAttachmentService.swift`
- `JiZhi/Services/Encryption/SecureCrypto.swift`
- `JiZhi/Services/Encryption/SecureKeyStore.swift`
- `JiZhi/Services/Encryption/SecureMarkdownDocument.swift`
- `JiZhi/Services/Encryption/SecureModels.swift`
- `JiZhi/Services/Encryption/SecureV2Crypto.swift`
- `JiZhi/Services/Encryption/SecureV2Models.swift`
- `JiZhi/Services/Localization/AppLocalization.swift`
- `JiZhi/Services/Localization/AppTimestamp.swift`
- `JiZhi/Services/Networking/APIClient.swift`
- `JiZhi/Services/Networking/APIJSONCoding.swift`
- `JiZhi/Services/Notifications/PushRegistrationService.swift`
- `JiZhi/Services/Payments/PaymentDiagnostics.swift`
- `JiZhi/Services/Payments/PurchaseAdapter.swift`
- `JiZhi/Services/Payments/RevenueCatSDKAdapter.swift`
- `JiZhi/Services/Payments/RevenueCatService.swift`
- `JiZhi/Services/Storage/AppPreferences.swift`
- `JiZhi/Services/Storage/EncryptedNotificationCache.swift`
- `JiZhi/Services/Storage/LocalStorage.swift`
- `JiZhi/Services/Storage/NotificationCacheKeys.swift`
- `JiZhi/Services/System/SystemService.swift`

### JiZhi/Repositories

- `JiZhi/Repositories/FeatureRepository.swift`
- `JiZhi/Repositories/InMemoryFeatureRepository.swift`
- `JiZhi/Repositories/NotificationHistoryCache.swift`
- `JiZhi/Repositories/RemoteJiZhiAPIModels.swift`
- `JiZhi/Repositories/RemoteJiZhiRepository.swift`
- `JiZhi/Repositories/SecureInbox.swift`
- `JiZhi/Repositories/SecureV2Inbox.swift`
- `JiZhi/Repositories/StaticDiscoveryCatalog.swift`

### harmony/entry/src/main/ets

- `harmony/entry/src/main/ets/components/AccountPanel.ets`
- `harmony/entry/src/main/ets/components/AttachmentPanel.ets`
- `harmony/entry/src/main/ets/components/DevicesPanel.ets`
- `harmony/entry/src/main/ets/components/InboxPanel.ets`
- `harmony/entry/src/main/ets/components/SendersPanel.ets`
- `harmony/entry/src/main/ets/components/settings/AuthParityPanel.ets`
- `harmony/entry/src/main/ets/components/settings/SettingsRow.ets`
- `harmony/entry/src/main/ets/entryability/EntryAbility.ets`
- `harmony/entry/src/main/ets/models/JiZhiModels.ets`
- `harmony/entry/src/main/ets/pages/Index.ets`
- `harmony/entry/src/main/ets/services/ApiClient.ets`
- `harmony/entry/src/main/ets/services/AppConfig.ets`
- `harmony/entry/src/main/ets/services/AuthService.ets`
- `harmony/entry/src/main/ets/services/DeviceService.ets`
- `harmony/entry/src/main/ets/services/InboxService.ets`
- `harmony/entry/src/main/ets/services/SecureArchiveService.ets`
- `harmony/entry/src/main/ets/services/SecureAttachmentService.ets`
- `harmony/entry/src/main/ets/services/SecureCrypto.ets`
- `harmony/entry/src/main/ets/services/SecureDeviceEnrollmentService.ets`
- `harmony/entry/src/main/ets/services/SecureStorage.ets`
- `harmony/entry/src/main/ets/services/SenderAuthorizationService.ets`
- `harmony/entry/src/main/ets/services/discovery/DiscoveryCatalog.ets`
- `harmony/entry/src/main/ets/services/discovery/DiscoveryCopy.ets`
- `harmony/entry/src/main/ets/services/discovery/DiscoveryStore.ets`
- `harmony/entry/src/main/ets/services/preferences/PreferenceService.ets`
- `harmony/entry/src/main/ets/support/Localization.ets`
- `harmony/entry/src/main/ets/theme/JZTheme.ets`
- `harmony/entry/src/main/ets/viewmodels/DiscoveryModel.ets`
- `harmony/entry/src/main/ets/viewmodels/HarmonyModel.ets`
