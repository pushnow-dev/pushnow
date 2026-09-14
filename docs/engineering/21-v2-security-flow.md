# Account-bound encrypted notifications

Implementation wire formats are defined in [20-v2-wire-contract.md](20-v2-wire-contract.md).

## Normal sender flow

1. The signed-in, approved phone owns the account identity and archive keys.
2. `pushnow login` generates a sender key locally and requests a short-lived code.
3. The phone looks up the code. The user compares the complete sender fingerprint
   and explicitly approves the computer.
4. The phone certifies that sender and encrypts its API credential and the signed
   archive public key to the computer. Private phone/archive keys are not exported.
5. The user compares the account identity fingerprint shown by the CLI against the
   phone before accepting first authorization. The CLI then stores its own
   credential locally, preferring macOS Keychain.
6. Subsequent sends encrypt the complete message locally. The Worker checks the
   credential, account, quotas and target devices, then stores ciphertext.
7. APNs carries an encrypted preview. The notification extension authenticates
   the sender and decrypts locally. Opening the notification retrieves and decrypts
   the full message in the app.

The API credential authorizes an operation; it is not an encryption key. Plaintext
JSON submitted directly to a remote HTTP service would expose content to that
service, even over HTTPS. HTTP integrations requiring E2EE must encrypt at their
origin with the SDK or an equivalent implementation before submitting the request.

## Devices and history

- Device login and cryptographic approval are separate. Knowing an account login
  does not by itself provide archive decryption material.
- All approved account devices can read undeleted archive history. Notification
  target selection only controls interruption, not access to account history.
- New devices obtain archive material through an encrypted trusted-device grant.
- Device names are display metadata, not authorization identities. Routing uses
  stable device IDs and server-verified account ownership.
- Revoking a sender blocks future authenticated sends. Revoking a device blocks
  future server access and notification delivery; neither erases previously copied
  plaintext or keys from a device controlled by an attacker.

## Files and deletion

Each attachment uses an independent random AES-GCM key and nonce. Its name, MIME
type, integrity hash, key and scoped download capability are inside encrypted
message content. Storage receives opaque ciphertext. The notification extension
can download a single committed encrypted image without holding a login token.

Account-wide deletion removes message ciphertext, queues blob deletion, cancels
queued delivery and retains a tombstone against retry resurrection. Clients sync
tombstones to remove cached files and delivered notifications. Already in-flight
pushes, offline clients and exported copies cannot be recalled synchronously.

## Explicit security limits

- Routing metadata, account/device/source IDs, approximate sizes and timing remain
  visible to the service and relevant push infrastructure.
- Decrypted notification previews can be visible on the lock screen according to
  the user's iOS notification settings.
- The shared archive design deliberately supports new-device history. It does not
  claim forward secrecy or post-compromise security equivalent to a ratcheting chat
  protocol. Archive-key compromise can expose retained ciphertext.
- Losing every trusted copy of the archive key loses encrypted history. A password
  reset cannot make the server decrypt it.
- Certificate verification and local pinning detect unapproved key substitution
  after trust establishment; this is not a public key-transparency system.
- Old v1 ciphertext requires an existing trusted decryptor for migration. Expired
  or deleted legacy content cannot be reconstructed by the server.

## Acceptance evidence

Track separately: unit/route tests, cross-runtime crypto interoperability, signed
app build, Simulator interaction, APNs acceptance, and visible physical-device
receipt. None is a substitute for the next. A second simulated account/device can
prove authorization rules but is not evidence of two physical phones receiving.
