# Account devices

## Product contract

Devices belong to the verified account that registers them. A device has no
membership expiry and no user-facing removal or revocation operation. Signing
out stops delivery to that session but retains the device record. Membership
and sender credential expiry are separate from device identity.

The device ID is the existing installation UUID, stored with the account's local
encryption keys. Re-registering with the same keys retains that ID and the custom
name. Erasing local keys or reinstalling without retained keys can create a new
installation ID; this is not a permanent hardware identifier. APNs tokens are
transport credentials, may rotate, and must never be used as the public device ID.

## Management API

- `GET /v1/secure/devices`: list the signed-in account's devices.
- `GET /v1/secure/devices/{id}`: read one owned device; other accounts receive 404.
- `PATCH /v1/secure/devices/{id}`: update `name` or `notifications_enabled`.
- `DELETE /v1/secure/devices/{id}`: unsupported (405).
- Registration accepts optional `system_version`, `app_version`, and `model`.
  Re-registration refreshes these values and `last_seen_at`, preserving custom names.

The list includes `id`, `name`, `platform`, `system_version`, `app_version`,
`model`, `created_at`, `last_seen_at`, and notification/encryption readiness.
OS and model values are client-reported, not hardware attestation.

## Sending

An authorized encrypted sender reads `GET /v2/recipients`. For `POST /v2/messages`,
omitting `notify_device_ids` targets all currently approved notification-enabled
devices, providing IDs targets only those devices, and `[]` stores without pushing.
Targeting controls notifications; encrypted account history remains shared.
Cross-account IDs are rejected. Payloads and attachments continue using the
existing encryption SDK. The public device ID alone is not an authorization key.

## Pairing and sender management

New devices display a 16-hex-character pairing code binding user ID, device ID,
device public key and account identity. A trusted device verifies the code before
granting encrypted keys. The new device pins the identity and automatically
validates and accepts the grant, without re-entering a long fingerprint.

Sender Keys support expiry and independent revocation through `/v2/keys`.
`/v2/logs` exposes account-scoped per-key/per-device metadata with pagination.
V2 accepts `scheduled_at` and `expires_at`; delivery checks Key validity again.
Reading a scheduled message does not cancel its requested reminder.

## UI boundaries

`DeviceRow` renders device identity, metadata, rename and notification controls.
`SecureDeviceService` performs registration and metadata collection.
The web account console renders the same API fields and edits device names.
Apply migration `0008_device_information.sql` before deploying the backend.
