---
title: Devices and sender keys
description: Name your devices, target their IDs and manage multiple sender credentials.
order: 3
tryMethod: GET
tryPath: /v1/secure/devices
tryAuth: session
---

## List your devices

After sign-in, open the device list in the app or [Dashboard](/dashboard/). It shows the registered device ID, custom name, platform and available model, system and app versions. Some older registrations may not contain every version field.

```sh
curl --fail-with-body https://api.pushnow.dev/v1/secure/devices \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

The response is `{"devices":[...]}`. Use each device's `id`, not its APNs token, in your own integrations. IDs identify installations, not permanent hardware serial numbers: reinstalling or losing local key material can create a new identity.

```http
PATCH /v1/secure/devices/<DEVICE_ID>
Authorization: Bearer <ACCESS_TOKEN>
Content-Type: application/json

{"name":"Work iPhone"}
```

Device names can be changed without changing the ID. There is no device-expiry or device-revocation step in this workflow. The notification preference and a valid signed-in device session still determine whether an alert is eligible.

## Target one or several devices

```sh
node cli/src/main.js devices
node cli/src/main.js send --title "Work update" --device DEVICE_ID
node cli/src/main.js send --title "Both phones" --device FIRST_ID --device SECOND_ID
node cli/src/main.js send --title "All enabled devices"
```

Sender-side discovery uses `GET /v2/recipients` with the sender Key. The SDK checks the account identity and signed device directory before constructing the encrypted request. Foreign account IDs are rejected. Targeting never restricts shared account history.

## Manage sender keys

Authorize a new sender with [CLI login and iOS approval](/docs/hpke-authorization/). In Dashboard, additional transport Keys can be created for an existing source. They work only with that source's existing cryptographic configuration; adding a Key does not create a new encryption identity.

Each source can keep at most two active Keys. Dashboard can delete a Key immediately, or regenerate it by invalidating the old Key first and showing a replacement secret once. Save the generated secret before closing the panel; existing rows show only the prefix and metadata.

| Operation | Account-session endpoint | Result |
| --- | --- | --- |
| List Keys | `GET /v2/keys` | `{"keys":[...]}`; prefixes and metadata, not secrets |
| Filter a source | `GET /v2/keys?source_id=<SOURCE_ID>` | Keys for an owned source |
| Add Key | `POST /v1/sources/<SOURCE_ID>/keys` | `{"source_key":"<SECRET>","key":{...}}`; secret shown once |
| Change expiry | `PATCH /v2/keys/<KEY_ID>` | Updated Key metadata |
| Revoke Key | `DELETE /v2/keys/<KEY_ID>` | `204 No Content` |

Add or update with a timezone-qualified ISO date, or `null` for no expiry:

```json
{"expires_at":null}
```

Choose a future expiry that lasts through any scheduled notifications. Delivery rechecks the sending Key; an expired or revoked Key can suppress a pending alert. Revocation is a Key operation, not a device operation, and changing an expiry does not undo revocation.

## Rotate without changing the sender

1. Create another Key for the same source, or use Dashboard's regenerate action to replace an old Key immediately.
2. Copy its secret once into your existing sender's secure configuration, replacing only `source_key`.
3. Keep the sender private key, source ID, account identity pin and archive public record unchanged.
4. Test with that sender, then revoke the old Key when it is no longer needed.

Separate senders should go through separate HPKE approvals. A Key from a different source cannot substitute for the certified sender key. Use [notification logs](/docs/notification-logs/) to distinguish activity by Key ID and source name.


## Automatic browser connection

Dashboard recognizes the devices linked to your signed-in account. The browser creates its encryption key locally and automatically requests an account-bound sender certificate. For the first connection, open an updated, signed-in trusted iPhone app: it completes the certificate exchange automatically without codes or fingerprint entry. Older apps do not support this automatic exchange. The phone's private identity and archive keys stay on the phone.

The browser remembers its sender configuration in this tab's session storage. Signing out clears it. Revoked or paused credentials are not silently replaced. You can revoke a Key at any time in Dashboard. An account-authorized browser trusts the authenticated service for the initial account public key; the CLI's manual fingerprint flow remains available.

## Sending protection

A Key making more than 60 message requests in a rolling minute is paused for 15 minutes. Requests during suspension return HTTP 429 with Retry-After. The Key list shows the pause deadline. Independently, each account is limited to 20 push transport attempts per rolling minute across devices and Keys; excess queued notifications wait rather than disappear, including scheduled messages.

Security email alerts are limited to one per user per rolling hour and three per rolling day. Failed emails remain queued for retry; an email provider accepting a message does not prove inbox delivery. Messages do not include full Keys or notification contents.
