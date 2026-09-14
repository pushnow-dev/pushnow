# Account browser authorization

Verified account sessions can create `POST /v2/account-authorizations` with `name` and `public_key`. The server returns the normal v2 polling credential and the authenticated account's identity public key. It stores the account binding separately from legacy short-code requests. The browser pins this identity, retains its generated private key locally, and polls using the existing one-time encrypted grant protocol.

An upgraded, trusted iOS app polls `GET /v2/account-authorizations/pending` while active. Only pending requests bound to its account are returned. It signs the sender certificate with its local identity key and seals the grant to the browser's public key. No account or archive private key is uploaded. The server rejects approval and short-code lookup of an account-bound request by another account. Legacy manual authorization continues unchanged for unbound requests.

This deliberately trusts the verified web session to request sending access. It does not authenticate the browser through an independent fingerprint comparison. Session theft can therefore result in a sender being authorized while the trusted app is active. Key revocation and abuse controls remain separate enforcement layers.

## First connection and compatibility

The trusted phone must run this upgraded version and be online with the app active for the first browser connection. Existing installed versions will not process automatic requests. No mobile interaction, code copying, or fingerprint entry is needed, but an offline phone cannot issue its signature. An account without a trusted identity/archive must first complete phone initialization. Browser credentials continue to work afterward without a live phone and can be revoked from key management.

## Validation

- Backend: `npm test -- --run test/v2-integration.test.ts -t 'automates only'` checks unbound web sessions, trusted-device listing, cross-account isolation, approval and one-time grant consumption against real D1.
- SDK: `npm run build` in `sdk/typescript` rebuilds browser and module exports.
- Simulator: `AccountFlowUITests/testAutomaticAccountSender` uses `backend/test/simulator-server.mjs` on loopback port 8799. It registers a fixture user, logs a browser in by password, waits for the foreground phone's automatic approval, and asserts SDK authorization and device discovery without exposing credentials.
