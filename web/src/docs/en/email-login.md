---
title: Account and token binding
description: Understand email login, account sessions, sender keys and device ownership.
order: 2
tryMethod: GET
tryPath: /v1/me
tryAuth: session
---

Register or sign in before using PushNow. Every sender and device belongs to an account. Clients cannot choose another recipient account by placing an email address or `user_id` in a send request; the server resolves ownership from the authenticated sender Key.

## Sign in with email

Use the iOS app or [Dashboard](/dashboard/). First sign-in verifies your email with a code. Once your email is verified, set a password in the account settings to enable password login. Email-code login remains available. The hosted Dashboard adds its browser safety token automatically; direct browser-origin auth requests must include a valid Turnstile token.

The equivalent API calls are:

```http
POST /v1/auth/email/start
Content-Type: application/json

{"email":"you@example.com","locale":"en","timezone":"UTC","client":{"platform":"cli"}}
```

```http
POST /v1/auth/email/verify
Content-Type: application/json

{"email":"you@example.com","code":"<EMAIL_CODE>","client":{"platform":"cli"}}
```

For an existing password:

```http
POST /v1/auth/password/login
Content-Type: application/json

{"email":"you@example.com","password":"<PASSWORD>","client":{"platform":"cli"}}
```

These examples deliberately omit real credentials. Do not include passwords or verification codes in screenshots, URLs, shared logs or source control.

## Which credential goes where?

| Value | What it represents | Where to use it |
| --- | --- | --- |
| Account access token | Your signed-in account session | `Authorization: Bearer <ACCESS_TOKEN>` for account, device, Key and log management |
| Refresh token | Renewal of an account session | Only the refresh/logout flow; never a sender credential |
| Sender Key (`source_key`) | Permission to send as one source in one account | Bearer header for `/v2/recipients`, message submission and file upload |
| Sender private key | Cryptographic identity of the authorized sender | Local SDK encryption; never send it to the server |
| Device ID | A registered app installation | `notify_device_ids` to choose alerts; it is not a password |
| Authorization user code | A pending sender approval | Enter it on a trusted phone; it is not an access token |
| Attachment read token | Read capability for one encrypted attachment | `Authorization: Attachment <READ_TOKEN>` for that attachment only |

## Account API example

```sh
# Set ACCESS_TOKEN securely in your environment first.
curl --fail-with-body https://api.pushnow.dev/v1/me \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

Use `POST /v1/auth/refresh` with `{"refresh_token":"<REFRESH_TOKEN>"}` when the session needs renewal. Do not repeatedly retry with an expired access token. Follow the returned session state; a logged-out or expired refresh session requires sign-in again.

Dashboard stores its session in the current tab's `sessionStorage` under `pushnow.web.session`; the current clients accept `access_token` and `accessToken`. This is account authentication, not an HPKE authorization grant. A web login does not give the browser the device's private encryption keys.

## Binding and decryption

A logged-in app registers its device identity and binds its push token to that device. A device ID remains useful even if APNs refreshes its transport token. Devices have no user-managed expiry or revoke control. Logging out stops eligible push delivery without deleting the device record.

Account membership alone is not enough to decrypt old messages: a new installation must obtain the account archive key through the app's encrypted device approval flow. Never export or paste the account archive private key into Dashboard.

Use [sender authorization](/docs/hpke-authorization/) to connect a script or the Dashboard playground, with trusted iOS approval in either case. Use [Key management](/docs/account-notifications/#manage-sender-keys) to add a replacement transport Key for that same sender.
