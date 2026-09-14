---
title: SDK 总览
description: 选择 PushNow 本地 SDK，了解运行环境、加密授权、设备发送和重试差异。
order: 11
---

## 选择一个 SDK

所有 SDK 都面向加密的 v2 API。SDK 会在本地完成 sender 授权、账号绑定校验、消息内容加密、附件加密上传，并通过 HTTPS 提交密文。当前说明基于仓库里的本地源码包；不要假设这些包已经发布到公开包管理平台。

| 语言 | 仓库目录 | 运行环境 | 文档 |
| --- | --- | --- | --- |
| TypeScript / JavaScript | `sdk/typescript` | 支持 WebCrypto 的现代浏览器，或 Node.js 22+ | [TypeScript 和 npm](/zh-Hans/docs/sdk-typescript/) |
| Python | `sdk/python` | Python 3.10+ **以及 Node.js 22+** | [Python](/zh-Hans/docs/sdk-python/) |
| Go | `sdk/go` | Go 1.22+ **以及 Node.js 22+** | [Go](/zh-Hans/docs/sdk-go/) |
| Java | `sdk/java` | Java 11+ **以及 Node.js 22+** | [Java](/zh-Hans/docs/sdk-java/) |

Python、Go 和 Java 是对内置、锁定版本 JavaScript HPKE runtime 的子进程绑定。它们不是各语言原生的密码学实现，编译产物也不会把 Node 打包进去。部署时需要把对应 SDK 的 `runtime/` 目录和安装好的依赖一起带上。

## 授权和登录是两件事

先在 iOS App 里登录并初始化加密账号。SDK 授权流程不会注册用户，也不会用邮箱密码登录。它会创建一个 sender 密钥对，并请求你的可信设备批准这个 sender。

推荐流程使用已登录 App 或可信 Dashboard 会话里的账号 access token 发起账号绑定授权，再在可信手机上完成批准。token 只用于授权设置请求，不能单独加密消息。

CLI 或离线环境仍可使用手动 fingerprint 授权。该流程需要同时对比网页/终端和手机上的 sender fingerprint，并从可信 App 中独立获取账号 root fingerprint。不要用同一份未信任的 grant 计算一个“预期 fingerprint”再自动接受它。

授权完成后的配置包含 `api_url`、`user_id`、`source_id`、`source_key`、`identity_public_key`、`sender_private_key` 和经过认证的 archive public record。它是私密凭证，必须安全保存。单独一个 bearer token 或 source key 不能完成加密发送；它必须和 sender 配置里的账号、source、私钥匹配。

## 不同语言的选项差异

| 行为 | TypeScript | Python / Java | Go |
| --- | --- | --- | --- |
| 发送到所有设备 | 省略 `deviceIds` | 省略 `deviceIds` | `DeviceIDs: nil` |
| 发送到指定设备 | `deviceIds: [id]` | `deviceIds` 列表 / JSON array | 指向设备 ID 切片的指针 |
| 只保存到收件箱 | `inboxOnly: true` 或 `deviceIds: []` | `pushEnabled: false` 或空 `deviceIds` | `PushEnabled` 指向 false，或指向空设备 ID 列表 |
| 定时发送 | `scheduledAt` 选项 | `scheduledAt` 输入 | `ScheduledAt` |
| 图片 | `image` 文件输入 | `images` 文件列表 | `Images` |
| 声音 | `MessageOptions.sound` | `sound` 输入 | `Sound` 指针 |

设备定向只影响本次 APNs 推送目标，不限制账号历史记录。账号下其他设备仍可在收件箱里看到同一条消息。定时发送最长 30 天，不会把已保存消息隐藏到触发时间才出现。更多内容字段见[消息内容](/zh-Hans/docs/message-content/)和[定时发送](/zh-Hans/docs/scheduling/)。

声音参数统一为 `default | silent | chime`。省略时保持默认行为。`silent` 仍会请求可见通知，只是不带 `aps.sound`；`chime` 使用 App 内置的 `pushnow-chime.wav`，不接受任意上传的音频文件名。声音是公开路由元数据，消息正文和文件仍然加密。最终是否响铃受 iOS 通知设置、声音权限和专注模式影响。

## 重试和日志

需要可靠投递时，先 prepare 一次并保存原始 outbox，然后重试同一个 envelope。TypeScript SDK 当前在内存里绑定账号和 source，序列化 outbox 后再导入不被支持；需要重启后重试时，优先使用 CLI 或 Python/Go/Java 绑定的 durable outbox 流程。

SDK 的请求事件和日志只暴露 method、endpoint template、HTTP status、耗时和结果类型，不包含 token、明文、密文 payload 或原始响应体。这些本地诊断日志和账号里的[投递日志](/zh-Hans/docs/notification-logs/)是两套东西。

SDK 返回成功只代表 API 接受了请求，不代表某台设备一定已经显示系统通知。
