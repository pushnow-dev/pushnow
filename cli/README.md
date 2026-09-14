# PushNow encrypted sender

## Authorize this computer

Run `node src/main.js login --api https://YOUR_API_ORIGIN --name "Build server"`.
The CLI generates its own private key. Enter the displayed code on your trusted
phone and compare the complete sender fingerprint before approving. After approval,
compare the CLI's account fingerprint against the phone's account fingerprint and
confirm it in the CLI. Both checks are required: HPKE Base protects the grant but
does not independently authenticate the first account root against a malicious relay.

On macOS credentials are stored in the login Keychain using a small compiled Swift
helper. Secrets travel through its stdin/stdout pipes, never process arguments.
An available Xcode command-line Swift compiler is required for first use. Other
systems use `~/.config/pushnow/credentials.json` with mode 600 and a private directory.

```sh
node src/main.js devices
node src/main.js send --input message.json --file report.pdf --image preview.png --icon icon.png --link https://example.com
node src/main.js send --title "Build complete" --body "Ready" --inbox-only
node src/main.js send --input message.json --device DEVICE_UUID --outbox retry.json
node src/main.js retry --outbox retry.json
node src/main.js logout
```

Repeat `--file`, `--link` and `--device` as needed. Target selection only controls
notifications: all approved account devices with the archive key can read history.
Full content remains intact; notification previews are separately encrypted and
bounded. Attachments encrypt before upload; names, MIME, keys, hashes and blob read
capabilities stay inside the encrypted manifest; the capability is also sent over
HTTPS during reservation so the server can retain its hash. API acceptance is not delivery proof.
Logout revokes the sender remotely before removing local credentials. When offline,
credentials remain so revocation can be retried. A lost sender can be revoked in-app.

SDK exports live at `src/sdk.js`: `beginLogin`, `finishLogin`, `recipientsV2`,
`uploadAttachment`, `prepareMessageV2`, `submitMessageV2`, `revokeSender`.
`finishLogin` requires either `expectedIdentityFingerprint` obtained through a
trusted channel, or a `confirmIdentity` callback that performs explicit user
verification. Never return true automatically for an unknown root. Store the returned
credential configuration securely; never log it. Call `recipientsV2` to verify the
signed source/archive/device directory before preparing a message. Public API methods
accept an optional `fetcher` for controlled runtimes/testing; `prepareMessageV2` options
accept `deviceIds: []` for inbox-only and omission for default enabled devices.

Verify v2 with `npm test`, `npm run interop:v2` (macOS/Xcode), and
`node test/v2-api-interop.js` (backend development dependencies required).

Legacy `--config <private-config.json>` commands below retain their original behavior.

# Legacy compatibility (v1)

Node 22+ sender for the account-bound secure notification API. Encryption uses
`@hpke/core` 1.9.0 (MIT), RFC 9180 Auth HPKE with P-256/HKDF-SHA256/AES-256-GCM.
The server never receives the sender private key or message plaintext.

## Existing configuration

In the app, open Devices and encrypted source setup. Create an encrypted source
and share its sender configuration directly to the computer running your agent.
This file contains a Source Key and sender private key: treat it like a password,
keep it outside this repository and do not send it through the PushNow API.
The account identity public key in this export is the sender's trust anchor.
Do not replace it from an unauthenticated server response.

```sh
cd cli
npm ci
chmod 600 /private/path/sender.credentials.json
node src/main.js devices --config /private/path/sender.credentials.json
node src/main.js send --config /private/path/sender.credentials.json --input /private/path/message.json --outbox /private/path/encrypted-outbox.json
```

Input JSON contains `title` and `body`, optionally `subtitle` and `url`. All input
fields are encrypted. Only opaque routing IDs, expiry and schedule go to the API.
The current app renders title/body and does not automatically fetch URLs.

Default delivery selects all approved devices with notifications enabled. Use
repeatable `--device UUID` flags to select a subset. An explicitly selected device
with notifications disabled can receive the encrypted inbox item without a push.
`--at` and `--expires` accept ISO8601 timestamps. Expiry defaults to 24 hours;
specify a later expiry for reminders scheduled beyond that. Maximum expiry is 30 days.
Encrypted payload is limited to 2400 bytes per device; attachments are not supported.

## Legacy retry

The outbox is written before sending and contains ciphertext only. After a network
timeout, retry the same envelope and ID instead of re-encrypting a new message:

```sh
node src/main.js retry --config /private/path/sender.credentials.json --outbox /private/path/encrypted-outbox.json
```

An API acceptance does not prove Apple accepted the push or that a phone received
it. Device acknowledgement is a separate state. Sender private keys must not be
logged, committed, put in URLs, or shared among unrelated sources.

## Legacy verification

```sh
npm test
npm run interop
npm run test:api
```

Interop requires Xcode/macOS. It generates throwaway identities, sends two-device
Auth HPKE vectors through native CryptoKit, checks both encryption directions,
verifies ECDSA certificates, and checks tampering rejection. No production keys
or notifications are used.

`test:api` also requires the backend's development dependencies (`cd ../backend &&
npm ci`). It bundles the actual Worker in disposable Miniflare D1 and verifies
two-device authenticated encryption through the HTTP routes, approval, recipient
selection, tenant isolation, exact retry and logout. It does not use the running
Simulator fixture or any production endpoint.

The protocol is not a Double Ratchet: compromise of a long-lived recipient key
can expose previously captured messages. Server metadata, directory availability
and revocation freshness remain outside message-content confidentiality.
