---
title: 发送测试事项
description: 使用来源密钥从自己的工作流创建通知事项。
order: 3
tryMethod: POST
tryPath: /v1/ingest/items
tryAuth: source
tryBody: {"title":"构建完成","body":"生产构建已经成功完成。","priority":"P1","notify":true,"idempotencyKey":"demo-001"}
---

# 发送测试事项

外部系统使用来源密钥，而不是用户的登录密码。你可以在 App 或 API 中创建来源密钥，然后把它作为 bearer token 传入。

## 请求

```bash
curl -X POST https://api.pushnow.dev/v1/ingest/items \
  -H "content-type: application/json" \
  -H "authorization: Bearer YOUR_SOURCE_KEY" \
  -H "idempotency-key: demo-001" \
  -d '{"title":"构建完成","body":"生产构建已经成功完成。","priority":"P1","notify":true}'
```

## 送达选择

当事项需要 App 推送时，把 `notify` 设置为 `true`。只想保存在 App 里查看时，设置为 `false`。
