# PushNow v2 implementation contract

This is the integration contract for CLI, Worker and iOS. Preserve v1 routes/data.
Wire JSON is snake_case. Existing readJsonBody normalizes incoming keys to camelCase;
Swift API encoder/decoder uses automatic snake conversion. Encrypted JSON uses
explicit snake_case too; use JSONDecoder.api / JSONEncoder.api on iOS.

## Cryptography

Same RFC9180 suite as v1: P256 / HKDF-SHA256 / AES256-GCM. Base64 is standard padded.
ECDSA certificates remain raw64 signatures of SecureCrypto.text(kind,user,id,key).
An account has one separate P256 archive agreement key, id UUID, certificate kind
`archive`. Never derive it from the signing identity or upload its private key.
First trusted client initializes it; subsequent clients verify its root certificate.
Archive private material transfers within existing encrypted device approval or
archive grant. Do not silently replace a pinned archive.

v2 HPKE info UTF8 `pushnow-v2`. Auth mode for message and preview, authenticated by
certified source key. AAD is UTF8 compact JSON array:
`[2,purpose,user_id,source_id,message_id,archive_id]` where purpose is `message` or
`preview`. Seal separately for each purpose. Recipient is account archive key.
Envelope fields: `enc,ciphertext`. Stored/read message fields:
`message_id,user_id,source_id,archive_id,enc,ciphertext,preview,source_public_key,
source_certificate,created_at,read_at` (preview is another envelope).
APNs custom payload `secure_v2` holds those identity fields plus preview enc/ciphertext
as its top-level enc/ciphertext, and `device_id`; no full body/attachment secrets.
Verify source cert/root, archive ID, user ID, targeted device and atomic replay claim.

Full plaintext: `{title,body,links:[],attachments:[],icon_id?,image_id?}`.
Each attachment: `{id,name,mime,size,key,nonce,sha256,read_token}`. key is random32 and nonce12,
AES-GCM ciphertext includes16-byte tag. SHA256 is lowercase hex of plaintext.
Attachment AAD UTF8 compact JSON `[2,"attachment",user_id,source_id,attachment_id]`.
Preview plaintext `{title,body,image?}` where optional image is attachment descriptor.
Notification ciphertext/metadata must fit4096bytes; omit preview image if needed,
truncate preview strings UTF8-safely, never truncate the stored full message.
Links remain links; Markdown/image/file attachments are opened according to MIME.

## Account archive routes (bound active device session)

GET `/v2/archive` -> `{archive:null|{id,public_key,certificate}}`.
POST `/v2/archive` `{id,public_key,certificate}` -> `{archive}`; immutable compare
on conflict. POST `/v2/archive/grants/:device_id` `{enc,ciphertext}` ->204, requires
active bound grantor and approved target sameaccount. GET same path -> `{grant}`
only target bounddevice. HPKE Base grant info `pushnow-archive-grant-v2`, AAD
UTF8 compact JSON `[2,"archive-grant",user_id,device_id,archive_id]`, plaintext
`{archive_id,archive_private_key}`. Existing approval plaintext additionally includes
these two fields for future devices. Existing trusted devices may request grants;
trusted approving device UI sends a grant to already-approved keyholding devices.

## Sender authorization

POST `/v2/authorizations` unauthenticated `{name,public_key}` ->
`{id,device_code,user_code,expires_at,interval:3}`. Random device_code32bytes,
server stores hash only; user_code eight unambiguous alphanumerics. TTL10minutes,
bounded issuance/lookup/polling rates. CLI generates private key locally and prints
code plus full SHA256(public_key) fingerprint for user comparison. No private export.
GET `/v2/authorizations/lookup?code=...` bound active session ->
`{authorization:{id,name,public_key,expires_at},archive}`. Phone displays fingerprint
and requires explicit matching confirmation. Codes are not login bearer credentials.
Phone creates source using existing source APIs, signs source certificate kindsource,
sets secure source using existing setup API, and seals grant with requester publickey.
POST `/v2/authorizations/:id/approve` bound active session
`{source_id,enc,ciphertext}` ->204; source must belong to sameaccount and matchingkey.
Grant HPKE Base info `pushnow-sender-grant-v2`; AAD UTF8 compact JSON
`[2,"sender-grant",authorization_id,public_key]`.
Grant plaintext `{api_url,user_id,source_id,source_key,identity_public_key,archive}`
where archive is signed publicrecord. Sender attaches its own private key locally.
Before saving first authorization, CLI requires the user to compare the full SHA256
account identity fingerprint against the phone approval screen. Base HPKE alone
does not authenticate the phone to a sender with no pre-existing root pin.
POST `/v2/authorizations/:id/token` `{device_code}` ->
`{status:"pending"|"approved",grant?:{enc,ciphertext}}`. Grant consumption single-use.
GET `/v2/senders` bound session -> `{senders:[{id,name,public_key,created_at,status}]}`
where id=source_id. DELETE `/v2/senders/:id` ->204 revokes source and its credentials.
POST `/v2/logout` source Bearer ->204 revokes only the authenticated source and all
its credentials; CLI calls this before clearing local credentials. Offline logout
may clear local storage but must clearly report remote revocation not confirmed.
GET `/v2/recipients` source Bearer -> v1 recipient directory fields plus `archive`.

## Encrypted files and messages

POST `/v2/attachments` source Bearer `{id,size,read_token}` -> `{id}` reservation; size is
ciphertext bytes. PUT `/v2/attachments/:id` source Bearer octet-stream ->204.
GET same path bound accountsession ->ciphertext, only attached live message blobs.
Also accept `Authorization: Attachment <read_token>` for that single committed blob;
read_token is sender-generated random32bytes base64url, server stores only SHA256.
It travels inside encrypted descriptors, never in URL. This capability only reads
ciphertext and becomes unusable when deleted; it grants no account/list access.
Notification extension uses this capability, not a shared login/refresh token, so
image decryption still works when the main app's short access token has expired.
R2 binding `SECURE_BLOBS`, opaque keys. Never log filename or cleartext. Cap file20MiB,
manifest256KiB,20attachments/message,100MiB/account initial attachment storage cap. Enforce actual
stream sizes and aggregate reservations atomically; explicit413/402 not silentpurge.
Orphan pending uploads expire24h, committed attachments last until message deletion.

POST `/v2/messages` source Bearer and Idempotency-Key=message_id:
`{message_id,archive_id,enc,ciphertext,preview,attachment_ids:[],notify_device_ids?:[]}`
-> `{message_id,deduplicated}`. Missing targets means all active notification-enabled
devices; explicit[] means inbox only. Never select foreign/revoked devices. Disabled
devices do not get notifications even if explicit; account history remains shared.
Persist immutable sourcecert/key snapshot. Atomic quota and idempotency enforcement.
GET `/v2/messages?cursor=...&limit=50` bound active accountsession ->
`{messages:[],next_cursor:null|string,deleted_ids:[]}`; return accountshared history,
not target-filtered. GET `/v2/messages/:id` -> `{message}`.
POST `/v2/messages/:id/read` bound session ->204 marks shared read state.
DELETE `/v2/messages/:id` bound session ->204 idempotent for owned ID; tombstone
retained, prevent retry resurrection, cancel delivery, delete blobs/manifest/preview.
GET `/v2/deletions?cursor=...` -> `{deleted_ids:[],next_cursor}` fullpaged tombstone
sync for offline devices, local caches and delivered-notification removal.
Retention indefinite by default; transport expiry/retry timeout never deleteshistory.

## Compatibility and acceptance

Do not reset users/sessions/source keys or delete v1 records. New firstscreen uses
v2 plus legacy history; only a trusted holder can decrypt/re-encrypt v1 records for
migration, deterministic mapping prevents duplicates. No restoration of expireddata.
Existing sending works while new authorization is adopted. CLI `login/logout/send`
defaults local credentials; retain `--config` legacy path compatibility.
Native content and credential code lives in services, small split SwiftUI screens.
Test real HTTP routes, real CryptoKit/Node vectors, userisolation/revocation/deletion,
attachments, grant tampering/replay, newdevice history. Never equate API/APNs200 with
recipient-visible delivery. No production migration/deploy without coordinator review.
