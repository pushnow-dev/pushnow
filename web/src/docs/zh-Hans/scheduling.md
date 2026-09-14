---
title: 定时发送和只保存到收件箱
description: 选择接收设备、设置未来提醒，并区分投递过期和历史记录。
order: 7
---

## 默认发送到所有设备

省略加密 envelope 中的 `notify_device_ids` 时，服务端会选择当前账号下所有活跃、已认证且允许通知的设备。接收设备在消息被接受时确定。之后新增的设备可以读取账号共享历史，但不会自动加入这条已提交消息的系统通知投递行。

| Envelope 选项 | 通知行为 |
| --- | --- |
| 没有 `notify_device_ids` | 提交时的所有可接收设备 |
| `"notify_device_ids":["<DEVICE_ID>"]` | 指定的账号内设备，前提是允许通知 |
| 多个设备 ID | 指定的多个账号内设备 |
| `"notify_device_ids":[]` | 只保存到账号收件箱，不创建系统通知 |

未知设备、其他账号的设备或不符合条件的设备会被拒绝或过滤。显式指定某台设备不会绕过它自己的推送关闭状态。

## 稍后发送

```sh
AT=$(node -e 'console.log(new Date(Date.now()+3600000).toISOString())')
node cli/src/main.js send --title "Review the report" \
  --body "The report is in your inbox." --at "$AT"
```

CLI 会把 `--at` 映射成 `scheduled_at`。它必须是未来时间，且距离提交时间不超过 30 天。请使用带 `Z` 或明确时区偏移的 ISO 8601 时间。不要使用没有时区的本地时间字符串。

定时消息会立即出现在账号历史中。`scheduled_at` 推迟的是系统通知，不是收件箱可见时间。服务端定时任务会处理到期投递，但不承诺精确到秒显示。

## 设置投递过期

```sh
AT=$(node -e 'console.log(new Date(Date.now()+3600000).toISOString())')
EXPIRES=$(node -e 'console.log(new Date(Date.now()+7200000).toISOString())')
node cli/src/main.js send --title "Meeting reminder" \
  --at "$AT" --expires "$EXPIRES"
```

`expires_at` 必须晚于投递时间，且同样在 30 天窗口内。过期会停止后续通知尝试，但不会删除账号历史。

请确保发送 Key 在投递窗口内仍有效。撤销或过期 Key 可能会抑制尚未到期的提醒。

## 只保存到收件箱

```sh
node cli/src/main.js send --title "Daily results" --body "Saved for later." --inbox-only
```

发送端会产生 `notify_device_ids: []`。这不会创建 APNs 通知，但消息会在 App 同步后出现在收件箱中。它不是 silent background push，也不保证所有设备立即后台刷新。

`sound: "silent"` 仍然是一个可见通知，只是没有请求声音；只保存到收件箱则完全没有系统通知。不要把 inbox-only 和未来定时组合起来期待“到时间才显示”：消息会立即保存，并且没有投递行可在未来触发通知。

## 读取、删除和重试

读取即时未读消息可能会抑制还未完成的通知；读取定时消息不会取消未来提醒。删除消息会取消未完成投递，并删除加密内容和附件；其他可信设备会同步删除状态。

当前 API 没有编辑定时任务的 endpoint。要替换提醒，先删除旧消息，再用新 ID 提交新消息。

网络结果不确定时，重试同一个 prepared envelope 和原始 idempotency header。不要重新加密同一内容并复用旧 message ID。
