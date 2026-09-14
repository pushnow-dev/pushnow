# Cache test notification

Date: 2026-09-13 Asia/Shanghai.

Sent exactly one notification through the existing authorized v1 CLI sender; no
new pairing, credential export, or duplicate send was performed. The supplied
message fixture is `cli/test/cache-notification.json`.

- Title: 即知缓存测试
- Body: 这是一条缓存测试通知。重新进入首页时，已加载的消息应先显示，再后台刷新。
- Target device: `443f3c5b-5af6-469c-bc09-1166cb00cc91`
- Message ID: `40a13e88-09f3-4aea-a987-2c503a4a1c9c`
- CLI result: exit 0, API accepted, device delivery not claimed.

Read-only production D1 query restricted to this message's delivery metadata
confirmed `status=accepted`, `attempts=1`, `last_error=null`, and
`accepted_at=2026-09-12T23:13:09.677Z` (07:13:09 on September 13 in Shanghai).
`acknowledged_at` was null. Thus APNs accepted the push on the first attempt;
actual device presentation and the new cache behavior still require device proof.

Credentials were not printed or changed. The encrypted outbox is retained in the
existing private secrets directory for traceability; it was not retried.
