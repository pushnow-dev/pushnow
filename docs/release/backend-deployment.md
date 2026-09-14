# JiZhi Backend Deployment Checklist

Date: 2026-09-12

## Current Implementation

- Worker entry: `backend/src/index.ts`
- D1 migrations: `backend/migrations/0001_auth.sql`, `backend/migrations/0002_core.sql`
- OpenAPI contract: `docs/engineering/api/openapi.yaml`
- Local API base URL: `http://localhost:8787`
- Production API target: `https://api.pushnow.dev`

Implemented routes:

- `GET /health`
- `GET /healthz`
- `GET /readyz`
- `POST /v1/auth/email/start`
- `POST /v1/auth/email/verify`
- `POST /v1/auth/refresh`
- `POST /v1/auth/logout`
- `GET /v1/me`
- `POST /v1/me/email/start-change`
- `POST /v1/me/email/verify-change`
- `POST /v1/me/delete-request`
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

## Cloudflare Production Status

- Deployment time: 2026-09-12T06:48:57Z
- Worker: `jizhi-api`
- Production API: `https://api.pushnow.dev`
- Current deployed version ID: `a78db9fb-d425-4ec1-b998-01d886cb9998`
- D1 database: `jizhi-production`
- D1 database ID: `a0008c14-8542-4e8d-9b0c-d9ec53a46b85`
- Worker triggers: `api.pushnow.dev/*` and custom domain `api.pushnow.dev`
- Cloudflare Email Sending: `pushnow.dev` enabled
- Allowed sender addresses: `login@pushnow.dev`, `support@pushnow.dev`
- Production secret `AUTH_TOKEN_PEPPER`: set in Cloudflare Workers Secrets

Production commands completed:

```bash
npx wrangler d1 create jizhi-production
npx wrangler d1 migrations apply jizhi-production --remote
npx wrangler email sending enable pushnow.dev
npx wrangler secret put AUTH_TOKEN_PEPPER
npx wrangler deploy --domain api.pushnow.dev
```

## Verification Already Completed Locally

- `npm run types`
- `npm run check`
- `npm test`
- `npm audit --audit-level=moderate`
- `npm run deploy:dry`
- `npm run db:migrate:local`
- Local `GET /healthz` returned `200 {"status":"ok"}`
- Local `GET /readyz` returned `200 {"status":"ready"}`
- Local email start returned `202 {"status":"verification_sent","expires_in_seconds":600}`
- Local email verify returned 200, created a user, issued access/refresh tokens, and `GET /v1/me` returned the same user id.
- Local authenticated source creation returned 201.
- Local source key creation returned 201; the raw key was used only by the smoke script and not printed.
- Local source-key ingest returned 201 and duplicate idempotency retry returned 200 with `deduplicated=true`.
- Local `GET /v1/items` returned the ingested user-bound item.
- Local `GET /v1/reminders` returned the created App/in-app reminder plan.
- Local `PUT /v1/devices/apns-token` returned enabled device binding.

## Production Verification Completed

- `npx wrangler secret list` shows `AUTH_TOKEN_PEPPER` exists without exposing the value.
- `npx wrangler email sending list` shows `pushnow.dev` enabled.
- `npx wrangler d1 migrations list jizhi-production --remote` shows no pending migrations.
- `npx wrangler deploy --dry-run` shows the Worker can bind `EMAIL` and `DB (jizhi-production)`.
- `GET https://api.pushnow.dev/health` returned `200 {"status":"ok"}`.
- `GET https://api.pushnow.dev/readyz` returned `200 {"status":"ready"}`.
- `POST https://api.pushnow.dev/v1/auth/email/start` returned `202 {"status":"verification_sent","expires_in_seconds":600}`.
- Gmail readback found the `Sign in to JiZhi` email delivered to the test inbox from `JiZhi <login@pushnow.dev>`.
- Gmail headers showed SPF, DKIM, and DMARC all passed for the delivered verification email.
- Production smoke flow verified email login, source creation, one-time source key use, item ingest, P1 priority, `push_enabled=false`, in-app-only reminder creation, item read state update, and APNs token binding.

## Remaining Release Blockers

- Real APNs delivery still requires an Apple-signed build on a physical device with production/sandbox APNs token proof.
- App Store Connect app record, build upload, metadata, screenshots, review notes, and final review submission are still pending.
- RevenueCat product/catalog alignment is still pending for the paid tier.
