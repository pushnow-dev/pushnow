---
title: 投递日志
description: 查看消息、发送 Key 和每台设备的投递状态，同时不暴露加密内容。
order: 8
tryMethod: GET
tryPath: /v2/logs?limit=20
tryAuth: session
---

## 查看最近活动

打开 [Dashboard](/dashboard/) 的投递日志。可以按 Key 过滤，区分不同凭证或工作流的发送记录。日志记录的是消息和设备路由元数据，不包含解密后的标题、正文或文件。

```sh
curl --fail-with-body 'https://api.pushnow.dev/v2/logs?limit=20' \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

这里使用账号 session，不是 source Key。支持的查询参数包括 `key_id`、`source_id`、`cursor` 和 `limit`。`limit` 范围是 1 到 100，默认 50。`next_cursor` 是不透明游标，请原样 URL encode 后请求下一页；返回 `null` 时表示没有更多记录。

## 响应示例

下面只是元数据示例，不是实时投递证据：

```json
{
  "logs": [{
    "message_id": "00000000-0000-4000-8000-000000000001",
    "source_id": "<SOURCE_ID>",
    "key_id": "<KEY_ID>",
    "source_name": "Build server",
    "created_at": "2026-09-13T08:00:00.000Z",
    "scheduled_at": null,
    "expires_at": null,
    "read_at": null,
    "deliveries": [{
      "device_id": "<DEVICE_ID>",
      "device_name": "Work iPhone",
      "status": "accepted",
      "last_error": null,
      "attempts": 1,
      "accepted_at": "2026-09-13T08:00:01.000Z"
    }]
  }],
  "next_cursor": null
}
```

旧记录可能没有 `key_id`。`deliveries` 为空表示没有创建设备投递行，可能是只保存到收件箱，也可能是提交时没有符合条件的通知设备。

## 状态含义

| 状态 | 含义 | 建议 |
| --- | --- | --- |
| `pending` | 等待到期或等待处理 | 查看 `scheduled_at`，稍后刷新 |
| `sending` | Worker 已领取投递任务 | 等待本次尝试结束 |
| `accepted` | 推送 provider 已接受，不等于设备已显示 | 检查设备权限、网络和 App 状态 |
| `retry` | 临时失败，会再次尝试 | 查看 `last_error`，避免重复创建新消息 |
| `blocked` | 前置条件或 provider 状态阻止投递 | 检查推送注册、配置和错误原因 |
| `suppressed` | 当前状态不再适合投递 | 检查登录、Key、设备偏好或消息状态 |
| `failed` | 终态失败，例如无效设备 token | 打开已登录 App 刷新注册 |
| `expired` | 投递窗口已过期 | 历史仍在；如仍需要提醒，创建新消息 |

`accepted_at` 是 provider 接受时间，不是手机回执。`read_at` 是 App 共享已读状态，不证明系统通知已经展示。`attempts` 是处理尝试次数，不应理解为用户看到的通知次数。

## 常见原因

- `push_token_pending`：设备还没有可用推送 token。
- `push_not_configured`：服务端推送配置不完整。
- `source_key_not_active`：发送 Key 在投递前过期或被撤销。
- `delivery_not_eligible`：账号、设备、session 或消息状态不允许投递。
- `transport_expired`：通知投递窗口结束。
- `push_transport_error`：临时传输错误，触发重试。

日志中可能包含 provider 错误码，例如 `BadDeviceToken` 或 `Unregistered`。诊断时保留 message ID 和错误码即可，不要把密码、Bearer 凭证或加密附件描述符发给支持人员。
