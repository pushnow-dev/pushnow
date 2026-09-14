# Notification cache review

Scope: encrypted disk cache, cache key storage, inbox/detail/attachment reads, logout/account transitions and inbox state updates. This is a source review of the pre-fix cache snapshot; no production changes, test notifications or implementation edits were made. Line numbers refer to that reviewed snapshot. Fixes may subsequently move them.

## Findings

### P1 - Inbox retains cached content after authorization or integrity failure

`JiZhi/ViewModels/HomeViewModel.swift:28` preloads a cached snapshot. At lines 37-40, every subsequent failure is ignored whenever state is already loaded. Consequently a server 401/403 caused by device revocation, or a signature/HPKE verification error, leaves the inbox visibly successful with cached titles and bodies. The detail path already distinguishes offline errors, but the inbox does not.

Keep stale content only for the documented network-offline error allowlist. Surface authorization and integrity failures and stop treating cached state as an authenticated successful refresh. `NotificationHistoryCache.isOffline` at `JiZhi/Repositories/NotificationHistoryCache.swift:74` supplies the current allowlist.

Required regression: initialize an inbox with cached content, then have a controlled repository throw each of offline URLError, 401/403, and a crypto validation error. Only the offline case should retain content as usable cached history; the others must enter the chosen explicit failure/re-authentication state.

### P1 - A known server deletion can reappear from the offline detail cache

`JiZhi/Repositories/SecureV2Inbox.swift:55` fetches one message, but an HTTP 404/410 does not invalidate its cached message, attachment index or downloaded ciphertext. The error merely propagates. On a later offline attempt, lines 40-44 return that same cached message. This occurs when another device deletes a message and this device opens the detail before its next successful deletion-feed sync: it learns that the object is gone, but retains a cache capable of showing it again offline.

`JiZhi/Services/Networking/APIClient.swift:89` currently erases all HTTP status information into `repositoryUnavailable`, preventing targeted not-found handling. Preserve safe status information and purge/tombstone the requested owned message on definitive 404/410. Do not classify 401, malformed responses or crypto errors as deletion or as offline fallback.

Required regression: cache a message and attachment; return 404 for its detail; then return a network-offline error. The second attempt must not return cached content, and message/attachment cache entries and plaintext preview files must be absent. A transient 500 must not silently become a permanent deletion marker.

### P2 - A late refresh can overwrite local read/delete events

`JiZhi/ViewModels/HomeViewModel.swift:49` applies read/delete events only to current state; it does not invalidate an in-flight load or preserve an event overlay. A pending load can subsequently replace the state at line 36 with its earlier snapshot. `JiZhi/Repositories/NotificationHistoryCache.swift:38` merges prior read state and filters tombstones for the disk snapshot, but `JiZhi/Repositories/RemoteJiZhiRepository.swift:38` returns the original, unmerged `items` array to the view model. Thus the disk cache and visible list can disagree after a concurrent read/delete operation.

Merge pending events into the load result, invalidate/restart affected loads, or return the same monotonic filtered state written to cache. Read flags should not revert, and deleted IDs should not re-enter the visible list.

Required regression: hold a repository load with a continuation; apply a read event and a delete event; release a stale response containing both original unread items. Assert the read item stays read and the deleted item stays absent. Repeat with the real cache merge path.

## Positive checks

- Disk cache records use AES-GCM with AAD binding account, device and record name (`EncryptedNotificationCache.swift:30`, `:36`, `:63`). Filenames are hashes, files have complete file protection, and their directory is excluded from backup.
- Per-account cache keys live in Keychain. The key is removed before account files during logout (`EncryptedNotificationCache.swift:52`); auth generation changes before cache cleanup (`AuthService.swift:212`).
- Inbox and downloaded-attachment write paths check the auth generation/current device before synchronous MainActor cache writes (`RemoteJiZhiRepository.swift:29`, `SecureAttachmentService.swift:40`). No concrete cross-account plaintext leak or stale asynchronous plaintext write after logout was found in these paths.
- Cached attachments remain ciphertext inside the encrypted cache. Attachment reads revalidate GCM and the plaintext hash. Network downloads do not use the cache to bypass a failed HTTP response; valid local cache hits avoid another download.
- Detail fallback is restricted to selected URLError codes. Cache tampering results in a miss/failure rather than accepting unverified data.

## Performance and test gaps

- Refresh still enumerates every v2 history page, decrypts every message and restarts the full tombstone feed (`SecureV2Inbox.swift:22`, `:99`). The cache accelerates initial display and attachment reuse, but it does not bound refresh work as indefinitely retained history grows. This is an optimization limit, not evidence of a security regression.
- `EncryptedNotificationCacheTests.swift` covers ciphertext scope/tampering, file protection, logout removal and synchronous read/delete cache updates. It does not currently cover the asynchronous failure/race cases above, repeated attachment download counts, or a logout while a download is suspended.
- No tests or builds were run during this read-only review. Findings were sent to the iOS implementer and coordinator before this report was written. Verification after their fixes remains required.
