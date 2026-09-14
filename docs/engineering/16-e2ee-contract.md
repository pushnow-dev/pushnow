# Account-bound encrypted notifications v1

Implementation contract. Wire JSON uses snake_case; TypeScript and Swift models use camelCase.
All binary values are standard padded Base64. IDs are UUID strings; timestamps are ISO8601 UTC strings.

## Cryptography and trust

- RFC9180 authenticated HPKE: DHKEM(P-256, HKDF-SHA256), HKDF-SHA256, AES-256-GCM.
- Each installation/account has a distinct P256 agreement private key in shared Keychain.
- Each account has a P256 signing identity created on its first device. Public key is pinned on devices and sender configurations. Private identity transfers only in an HPKE Base encrypted approval package after fingerprint verification.
- Device certificate: P256 ECDSA SHA256, IEEE P1363 raw 64-byte signature, over UTF8 `pushnow-device-v1\n{userId}\n{deviceId}\n{publicKey}`.
- Source certificate: same signature over `pushnow-source-v1\n{userId}\n{sourceId}\n{publicKey}`. Source private agreement key is generated on the authorizing phone and exported directly to sender, never to API.
- Registration proof: ECDSA using the same raw scalar as device agreement key, over `pushnow-register-v1\n{userId}\n{deviceId}\n{publicKey}\n{challenge}`. API requires login plus a one-time, session-bound challenge (five-minute expiry) and proof; it binds current session.device_id only after verification and atomic challenge consumption.
- Public P256 keys use 65-byte uncompressed x963 representation. Private keys use 32-byte raw representation. Swift ECDSA rawRepresentation interoperates with WebCrypto signatures.
- Message HPKE info UTF8 `pushnow-message-v1`. AAD UTF8 `pushnow-message-v1\n{userId}\n{sourceId}\n{deviceId}\n{messageId}\n{expiresAt}`. Fresh Sender instance per recipient/message. Auth sender key must have a valid source certificate against pinned account identity.
- Approval HPKE Base info UTF8 `pushnow-approval-v1`; AAD UTF8 `pushnow-approval-v1\n{userId}\n{deviceId}\n{publicKey}`. Plaintext JSON `{identity_private_key: Base64}`. Receiving device verifies derived identity matches explicitly pinned/confirmed root and its certificate before saving.
- This is not a ratcheting protocol: no claim of Signal-style forward secrecy or compromise recovery. A malicious directory can withhold or replay old signed records; it cannot invent a valid new key. Initial account identity requires trusted out-of-band pairing. Revocation cannot erase already delivered plaintext/ciphertext from a formerly authorized device.

## API

- GET /v1/secure/devices -> `{identity_public_key: string|null, devices: SecureDevice[]}` (session auth).
- GET /v1/secure/device-challenge -> `{challenge}`; requires session. Challenge is random, bound to this session, expires after five minutes and can only be consumed once.
- POST /v1/secure/devices -> body `{device_id,name,platform,public_key,proof,challenge,identity_public_key?,certificate?}`; first device initializes immutable account identity and valid certificate, later devices pending. Re-register existing same key requires proof, never changes keys/cert/status from client. Returns `{device,identity_public_key}` and binds session to device. Revoked devices cannot re-register; create a fresh key/id.
- PATCH /v1/secure/devices/:id -> `{name?,notifications_enabled?}` owner only.
- DELETE /v1/secure/devices/:id -> revoke device, sessions, tokens; owner only. Last trusted device revocation is allowed but destroys ability to approve unless a trusted device/backup remains.
- POST /v1/secure/devices/:id/approve -> `{certificate,approval:{enc,ciphertext}}`; caller must be registered active trusted device. Verify root certificate and target pending; store Base approval, activate target.
- GET /v1/secure/devices/:id/approval -> `{approval:{enc,ciphertext}|null}` only current bound device.
- PUT /v1/secure/devices/:id/push -> `{token,environment,app_version?}` only current bound nonrevoked device; encrypted at rest with separate server secret, unique environment/token binding. Do not turn notification preferences on implicitly.
- PUT /v1/secure/sources/:id -> `{public_key,certificate}` owner and active trusted session; certificate valid, immutable source public key. Existing source becomes encryption-required; reject plaintext ingest for it.
- GET /v1/secure/recipients -> Source Key auth -> `{user_id,source_id,identity_public_key,source_public_key,source_certificate,devices}`; only active approved devices. Includes disabled devices so sender can elect inbox-only delivery; API defaults target all approved devices with notifications enabled for push.
- POST /v1/secure/messages -> Source Key auth and Idempotency-Key identical message_id -> `{message_id,expires_at,scheduled_at?,envelopes:[{device_id,enc,ciphertext}]}`. Plaintext parameters forbidden. Envelopes explicitly select targets, must all belong to key user, active and certified; no silent acceptance of foreign targets. Limits max32 targets, ciphertext <=2400 decoded bytes, expiry <=30 days, due < expiry. Stores opaque messages and per-device deliveries transactionally, no private content in items table.
- GET /v1/secure/messages -> session auth, registered active device -> `{messages: SecureMessage[]}` only envelopes of current device, not all same-account envelopes. May include messages on devices with notifications disabled (inbox still available).
- POST /v1/secure/messages/:id/ack -> current active device marks received; distinguish APNs accepted from device ack.

SecureDevice fields: `id,user_id,name,platform,public_key,certificate:string|null,status:pending|active|revoked,notifications_enabled:bool,last_seen_at,created_at`.
SecureMessage fields: `message_id,user_id,source_id,device_id,expires_at,enc,ciphertext,source_public_key,source_certificate,created_at`.
Encrypted plaintext JSON: `{title,body,subtitle?,url?}`. Only title/body are rendered initially; no automatic external URL fetch.

## Delivery and UI

Cron scans due opaque deliveries with leases, retries transient APNs errors, and rechecks device status, preference, live session, source and user status immediately before sending. APNs payload has generic alert + mutable-content + secure envelope (same snake_case message fields). Never put decrypted title/body into payload. Missing APNs/storage secrets produce blocked state, not fake success. Queue acceptance/APNs200 are not device receipt.

App device management: list, current-device identification, rename, notification toggle, revoke; pending device shows its fingerprint and root fingerprint. Approval requires entering/comparing target fingerprint from the new phone. Export source sender config includes pinned identity, source private key and Source Key, via user-invoked share only. Account recovery does not silently regenerate identity.

Swift boundaries: Services/Encryption/{SecureCrypto,SecureKeyStore,SecureModels}; Services/Devices/{SecureDeviceService,SecureDeviceAPI}; ViewModels/DevicesViewModel; Views/Devices/{DevicesView,DeviceRow,DeviceApprovalView,SecureSourceSetupView}; NotificationServiceExtension/NotificationService. Each file <=250 lines preferred, <=350 maximum. Logout clears extension's active account before network request, and server disables the bound installation. New account never reuses old account private key.

## Acceptance

Cross-language Auth HPKE vector; tamper/wrong key/wrong sender/wrong AAD reject. Two same-account devices receive decryptable independent envelopes; foreign account, unapproved, revoked and disabled push targets protected. Rename is metadata-only. Duplicate ingest idempotent; same ID/different ciphertext rejected. Logout stops future delivery; same phone different account never reads old notification. Simulator visual checks and local API integration required; signed real-device APNs test separately reported.
