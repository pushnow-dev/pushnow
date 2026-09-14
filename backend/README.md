# JiZhi Cloudflare Backend

This Worker is the first production backend slice for JiZhi. It supports health/readiness probes, email registration/login, first-login email verification, password setup, password login, session refresh/logout, current-user lookup, email change, account deletion request, membership quotas, user-bound sources, source-key ingest, inbox items, reminder plans, secure multi-device registration, and iOS/Harmony push-token binding.

## Cloudflare Stack

- Workers: HTTP API at `api.pushnow.dev`
- D1: `jizhi-production` stores user, challenge, session, delivery, notification preference, push token, secure device, source, item, content block, reminder, entitlement, and usage counter tables
- Email Service: `pushnow.dev` sends verification codes and can later support notification email templates
- Secrets: `AUTH_TOKEN_PEPPER` and `TURNSTILE_SECRET_KEY` are configured in Cloudflare Workers Secrets

Cloudflare Email Service pricing currently requires Workers Paid for sending to arbitrary recipients. Free can send only to verified destination addresses, which is not enough for public user signup/login emails.

## API Surface

- `POST /v1/auth/email/start`
- `POST /v1/auth/email/verify`
- `POST /v1/auth/password/login`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `GET /v1/me`
- `POST /v1/me/password`
- `GET /v1/me/plan`
- `GET /v1/sources`
- `POST /v1/sources`
- `POST /v1/sources/:source_id/keys`
- `POST /v1/ingest/items`
- `GET /v1/items`
- `GET /v1/items/:item_id`
- `PATCH /v1/items/:item_id/state`
- `POST /v1/items/:item_id/reminders`
- `GET /v1/reminders`
- `PUT /v1/devices/apns-token`
- `GET /v1/secure/devices`
- `POST /v1/secure/devices`
- `PATCH /v1/secure/devices/:device_id`
- `POST /v1/secure/devices/:device_id/approve`
- `PUT /v1/secure/devices/:device_id/push`
- `POST /v1/secure/sources/:source_id/setup`
- `POST /v1/secure/ingest`

## Secure Multi-Device Push

JiZhi treats each phone, tablet, or desktop app install as a user-bound secure device. A source can target one device by including one encrypted envelope, or target all approved devices by including one envelope per device. The backend stores one delivery row per `message_id + device_id`, so iOS APNs and Harmony Push deliveries can be retried independently.

Secure push-token binding is allowed only after the target device is approved and active. Pending devices can appear in the device directory, but they cannot bind APNs/Harmony Push tokens until a trusted device approves them.

Supported secure device platforms:

- `ios`: APNs token validation and APNs delivery are implemented.
- `harmony`: Harmony token binding is accepted and tested. Provider delivery uses Huawei Push Kit V3 after Huawei/AppGallery credentials are configured.

Required Harmony provider secrets:

- `HARMONY_PUSH_PRIVATE_KEY` (service account PKCS#8 key, base64 or PEM)
- `HARMONY_PUSH_KEY_ID` (service account `key_id`)
- `HARMONY_PUSH_SUB_ACCOUNT` (service account `sub_account`)
- `HARMONY_PUSH_PROJECT_ID` (must match the service account project)

Optional `HARMONY_PUSH_TEST_MESSAGE=true` enables Huawei test-message delivery. The adapter uses a locally signed PS256 service-account JWT and HarmonyOS V3 `payload` / `target` / `pushOptions`, not the legacy HMS Android client-secret flow. Lock-screen content stays generic; only message/device routing IDs travel in notification click data, and the app downloads/decrypts its archive after opening. Notification display/decryption on a physical device still requires AppGallery Push Kit configuration and validation.

## Setup

1. Install dependencies:

   ```bash
   npm install
   ```

2. Create a D1 database and replace the placeholder `database_id` in `wrangler.jsonc`:

   ```bash
   npx wrangler d1 create jizhi-production
   ```

3. Configure the auth and Turnstile secrets:

   ```bash
   npx wrangler secret put AUTH_TOKEN_PEPPER
   npx wrangler secret put TURNSTILE_SECRET_KEY
   ```

4. For local development only, create `backend/.dev.vars`:

   ```bash
   AUTH_TOKEN_PEPPER=replace-with-local-random-value
   TURNSTILE_SECRET_KEY=1x0000000000000000000000000000000AA
   ```

5. Apply migrations:

   ```bash
   npm run db:migrate:remote
   ```

6. Deploy:

   ```bash
   npx wrangler deploy
   ```

## Verification

```bash
npm run types
npm run check
npm test
npm run deploy:dry
```
