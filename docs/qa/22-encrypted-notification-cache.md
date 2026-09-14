# Encrypted notification cache

## Coverage

- The repository exposes synchronous `cachedInbox()` so the UI can render a previously loaded inbox before networking. A fresh load still enrolls the current device, fetches current data and checks the auth generation before replacing the cache. Independent source/item requests now run concurrently.
- Every returned inbox row is cached, including legacy items, v1 encrypted rows and all fetched v2 history pages. This does not expand the existing legacy endpoints' 100-row limits, recover expired legacy content, or imply notifications that have never been fetched are already on disk.
- Full decrypted v2 message models are cached under authenticated local encryption, allowing detail to display immediately. A failed refresh only falls back for a conservative list of transport/offline `URLError` values. HTTP denial/not-found, revocation and cryptographic verification failures do not trigger detail fallback.
- Downloaded attachment transport ciphertext is cached and reused for icons, images, Markdown and other file previews. It is verified again against the authenticated attachment descriptor before use. Previews still use short-lived file-protected plaintext files as required by native viewers; those are separate from the persistent cache and are removed on detail dismissal, deletion or logout.
- Legacy detail pages are not given a new offline full-content cache in this change. The persistent inbox includes their already-loaded row content, not every possible legacy detail module.

## Protection

- Cache files use fresh-nonce AES-GCM with a separate random 256-bit Keychain key. Authenticated data binds the format version, account, installation/device and record name.
- Directory and record names are hashed. Files use complete file protection and cache directories are excluded from backups. Readable notification JSON, attachment secrets and filenames are not written as persistent plaintext cache files.
- Cache reads require the currently verified account and its active local device. Another account/device or a transplanted record fails authentication. Cache corruption is treated as a cache miss; fresh networking remains available.
- Logout and account switching remove the account cache key, its in-memory copy, encrypted files and temporary previews. An in-flight network result cannot save or display an old-account snapshot after its auth generation changes.
- Cache reads also check persisted tombstones using one Keychain attributes query. Failure to read those markers causes a cache miss rather than displaying possibly deleted rows.

## Read And Delete

- Successful v2 reads persist the cached unread state before the UI event is posted.
- Tombstone pages remove rows in one batch, then remove full-message records, attachment indexes and ciphertext blobs. They do not rewrite the full inbox once per deleted message. The view observer does not duplicate persistence.
- Already-read v2 records remain read when an older in-flight response reaches the cache. Persisted tombstones are checked again before saving an inbox/detail record.
- Remote deletions cannot be learned while genuinely offline. A cached notification can remain visible offline until the next successful tombstone sync; local deletion markers remain effective without networking.

## Tests And Ownership

Six focused tests cover encrypted disk round-trip/no plaintext, file protection/backup exclusion, account/device/record AAD isolation, tamper rejection, key/file removal, actual AuthService logout cleanup, and read/deletion persistence without an active inbox view. A real URLProtocol regression drives a detail request through HTTP 404, verifies tombstone/full-message/blob cleanup, then confirms an offline retry cannot restore it.

Simulator may omit the file-protection metadata attribute; the test accepts an absent attribute only on Simulator and still verifies any reported value. Physical-device tests strictly require complete protection. Production protection settings are unchanged.

The coordinator owns the combined build, Simulator acceptance and physical-device installation for this cache, theme, discovery and time-preference update. This document does not claim those checks have run yet.
