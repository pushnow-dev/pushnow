# Encrypted sender validation

Date: 2026-09-12. Local implementation evidence, not production APNs delivery.

## Executed

- `cd cli && npm test`: 5 test groups passed. They cover independent two-device
  ciphertext, fresh randomness, wrong recipient/sender/account/source/message/expiry,
  modified ciphertext, signed recipient certificate verification, directory root
  pinning, notification preferences, explicit target selection, size limit, HTTPS,
  redirect rejection and ciphertext-only transport.
- `cd cli && npm run interop`: native macOS CryptoKit and Node `@hpke/core` Auth
  HPKE interoperated in both directions for two independently generated devices.
  CryptoKit verified Node P256 ECDSA device certificates and rejected modified AAD.
- The same interop command compiled the actual app `SecureCrypto.swift` and
  `SecureModels.swift`, decrypted the Node messages, rejected wrong device/source,
  modified ciphertext and expired messages, transferred an account identity in a
  Base HPKE approval, and rejected substituted account identity and wrong recipient.
- `npm install --ignore-scripts` installed the pinned `@hpke/core` 1.9.0 dependency;
  npm reported zero vulnerabilities for its two-package dependency tree at this run.

All test identities are generated locally and discarded. No production secrets,
real email, or real notification recipients are used by these checks.

## Implemented sender behavior

CLI configuration pins the account public identity and owns a source private
agreement key plus the source API credential. Recipient discovery must match the
account/source pin, source certificate/private key, and every device certificate.
Default targets are approved notification-enabled devices; repeated `--device`
options select an explicit subset. No plaintext is included in ingest JSON.

`--outbox` writes ciphertext before transmission for exact idempotent retries.
The CLI reports API acceptance with `delivery_confirmed: false`; it does not claim
that Apple accepted a request or that any handset displayed a notification.

## Limits

These tests establish cryptographic interoperability and negative-case behavior,
not a third-party cryptographic audit. Device directory revocation freshness still
trusts the backend; static recipient keys do not provide ratchet forward secrecy.
Simulator UI, actual database routing and signed physical-device APNs delivery
have separate reports and acceptance boundaries.
