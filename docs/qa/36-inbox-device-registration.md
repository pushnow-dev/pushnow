# Inbox device registration diagnosis

2026-09-13. Production was observed read-only using a sanitized Wrangler tail that emitted only timestamp, path, method, HTTP status and outcome. No authorization headers, request bodies or device tokens were printed. No backend deployment, database mutation or additional notification was performed during diagnosis.

## Before client compatibility fix

Tail confirmed repeated `POST /v1/secure/devices` HTTP400 at event timestamps1789261800507,1789261806218 and1789261820059. Preceding `GET /v1/secure/device-challenge` and `GET /v1/secure/devices` returned200. The same window's `/v1/items` and `/v1/sources` reads returned200. Some GET requests were canceled, not server500 responses.

The coordinator's signed physical-device diagnostics identified the precise code: `unexpected_field`. Existing production error handling does not log expected HTTP error codes, so the code is established by the client log rather than inferred from tail. Earlier browser OPTIONS/login401 traffic was excluded from the device diagnosis.

## Client compatibility verification

The coordinator implemented one compatibility retry for registration's `400 unexpected_field`: omit only optional device metadata, obtain a new challenge, then sign and submit again. The cryptographic key, certificate and proof requirements remain intact. This agent made no client/runtime changes.

Readback of `/tmp/pushnow-inbox-fixed-diagnostics.log` confirms:

```text
PUSHNOW_API_ERROR status=400 path=/v1/secure/devices code=unexpected_field
PUSHNOW_INBOX_LOADED count=3
```

This establishes successful complete inbox loading after the compatibility retry, not merely suppressing an error or displaying stale fallback data. The final tail window received cron events but did not emit the corresponding post-fix registration HTTP200 before shutdown; no direct tail200 claim is made. Physical-device diagnostics are the post-fix evidence.

All tail subprocesses opened by this agent were stopped, including sessions69039,14328,5466,13047 and71669. No listener remains for this task.
