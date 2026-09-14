# PushNow 即知

[English](README.md)

PushNow 即知是一个面向 AI Agent、后端任务、监控系统、CI 流水线、脚本、
Webhook 和个人自动化的账号绑定端到端加密通知平台。它可以把私密富通知发送
到用户信任的 iPhone 与 HarmonyOS 设备，同时避免传输服务看到明文标题、正文、
附件名称或发送端私钥。

官网：<https://pushnow.dev>  
API 基础地址：`https://api.pushnow.dev`  
SDK 组织：<https://github.com/pushnow-dev>

![PushNow 下载二维码](https://pushnow.dev/assets/download-qr.svg)

这个二维码目前指向 PushNow 下载页。App Store 公开链接还没有最终挂出时，先保留
这个稳定入口，后续只需要替换二维码目标即可。

## PushNow 能做什么

- 从 Agent、CLI、HTTP API、Webhook 和后端服务发送加密推送、收件箱消息和自动化告警。
- 使用账号 Access Token 发起 sender 授权，并由已登录 App 或可信 Dashboard 审批。
- 在传输前加密标题、正文、链接、图标引用、图片附件和文件附件。
- 支持全部设备、指定设备和仅收件箱消息。
- 支持定时发送、过期时间、自定义声音路由和可重试的加密 outbox。
- 提供 iOS、HarmonyOS、Web Dashboard、TypeScript SDK、Python SDK、Go SDK、
  Java SDK 和后端 API 源码。
- 明确区分 API 接受、APNs 服务投递和手机实际显示通知这几个验证阶段。

## 仓库组织

`pushnow-dev` GitHub organization 按开发者安装和集成习惯拆分：

| 仓库 | 用途 | 安装入口 |
| --- | --- | --- |
| `pushnow` | 主产品、官网、iOS、HarmonyOS、后端、文档和发布材料 | 产品和平台主库 |
| `pushnow-js` | Node.js 与浏览器 TypeScript SDK | npm 包 `pushnow-sdk` |
| `pushnow-python` | Python SDK，内置 Node HPKE runtime | PyPI 包 `pushnow` |
| `pushnow-go` | Go SDK，内置 Node HPKE runtime | Go module `github.com/pushnow-dev/pushnow-go` |
| `pushnow-java` | Java SDK，内置 Node HPKE runtime | Maven 坐标 `dev.pushnow:pushnow-sdk` |

## 安装 SDK

TypeScript / npm:

```sh
npm install pushnow-sdk
```

Python / PyPI:

```sh
pip install pushnow
```

Go:

```sh
go get github.com/pushnow-dev/pushnow-go
```

Java / Maven:

```xml
<dependency>
  <groupId>dev.pushnow</groupId>
  <artifactId>pushnow-sdk</artifactId>
  <version>0.1.1</version>
</dependency>
```

## 当前认证方式

PushNow 开发版 SDK 只支持 Access Token 授权流程。每个 SDK sender 都通过账号绑定的
可信 App 或 Dashboard 会话审批。

Access Token 用于从已登录 App 或可信 Dashboard 会话创建账号绑定的 sender 授权。
它本身不能完成加密，也不能单独发送消息。真正可用的发送端需要审批后返回的加密
sender config，其中包含 API origin、账号绑定、source key、sender 私钥和签名的
账号 archive 记录。

SDK 推荐流程：

1. 用户在 PushNow iOS App 或可信 Web Dashboard 登录。
2. 可信会话获得账号 Access Token。
3. SDK 使用 sender name 和 public key 调用账号授权接口。
4. 用户在已登录 App 或 Dashboard 中审批该 sender。
5. SDK 接收并校验加密 sender grant。
6. SDK 在本地加密消息内容，并把 ciphertext 发送到 API。

## HTTP API 概览

所有需要认证的 HTTP 端点都使用 `Authorization: Bearer <token>`。

账号端点使用已登录 App 或 Dashboard 的 Access Token。发送端点使用 sender config
里的 source key。文件预览读取使用 sender 生成的窄权限 attachment read capability，
服务端只保存它的哈希。

| Method | Endpoint | Token | 用途 |
| --- | --- | --- | --- |
| `POST` | `/v1/auth/email/start` | 无 | 开始邮箱登录并发送验证码 |
| `POST` | `/v1/auth/email/verify` | 无 | 校验邮箱验证码并返回 access/refresh token |
| `POST` | `/v1/auth/refresh` | refresh token | 轮换用户会话 |
| `GET` | `/v1/me` | 账号 Access Token | 读取当前登录账号 |
| `PUT` | `/v1/devices/apns-token` | 账号 Access Token | 绑定 iOS APNs token 到账号 |
| `GET` | `/v2/archive` | 账号 Access Token | 读取账号加密 archive |
| `POST` | `/v2/account-authorizations` | 账号 Access Token | 发起 Access Token 版 SDK sender 授权 |
| `POST` | `/v2/account-authorizations/:id/token` | 账号 Access Token | 轮询并消费加密 sender grant |
| `GET` | `/v2/recipients` | source Bearer token | 读取账号设备和 archive 用于加密 |
| `POST` | `/v2/attachments` | source Bearer token | 预留加密附件上传 |
| `PUT` | `/v2/attachments/:id` | source Bearer token | 上传加密附件字节 |
| `POST` | `/v2/messages` | source Bearer token | 提交加密通知消息 |
| `GET` | `/v2/messages` | 账号 Access Token | 同步加密收件箱历史 |
| `GET` | `/v2/messages/:id` | 账号 Access Token | 读取单条加密收件箱消息 |
| `POST` | `/v2/messages/:id/read` | 账号 Access Token | 标记消息已读 |
| `DELETE` | `/v2/messages/:id` | 账号 Access Token | 删除消息及其附件 blob |

## 发送消息字段

高层 SDK 消息内容：

| 字段 | 类型 | 是否加密 | 说明 |
| --- | --- | --- | --- |
| `title` | string | 是 | 通知标题和收件箱标题 |
| `body` | string | 是 | 通知正文和完整详情文本 |
| `links` | string array | 是 | 在消息详情中打开的链接 |
| `files` | file array | 是 | 以 AES-GCM ciphertext 上传的文件附件 |
| `image` | file object | 是 | 可用于通知预览的图片附件 |
| `icon` | file object | 是 | 可选图标附件或引用 |
| `attachments` | descriptor array | 是 | 低层加密附件描述符 |
| `image_id` | string | 是 | 指向 preview image 的低层附件 ID |
| `icon_id` | string | 是 | 指向 icon 的低层附件 ID |

路由和投递选项：

| 字段 | 类型 | 是否加密 | 说明 |
| --- | --- | --- | --- |
| `deviceIds` | string array | 否 | 省略表示全部可通知设备；空数组表示仅收件箱 |
| `inboxOnly` | boolean | 否 | 只保存到加密收件箱，不发送 APNs |
| `scheduledAt` | ISO datetime | 否 | 未来投递时间，目前限制在 30 天内 |
| `expiresAt` | ISO datetime | 否 | 过期时间，必须晚于投递时间，目前限制在 30 天内 |
| `sound` | string | 否 | `default`、`silent` 或 `chime` 声音路由元数据 |
| `sourceKind` | string | 否 | 可选来源归因，例如 `web`、`cli`、`api`、`subscription` |
| `Idempotency-Key` | HTTP header | 否 | 用于安全重试的稳定 message id |

低层 `/v2/messages` 请求体：

```json
{
  "message_id": "uuid",
  "archive_id": "account-archive-id",
  "enc": "base64-hpke-encapsulated-key",
  "ciphertext": "base64-encrypted-full-message",
  "preview": {
    "enc": "base64-hpke-encapsulated-key",
    "ciphertext": "base64-encrypted-preview"
  },
  "attachment_ids": ["attachment-id"],
  "notify_device_ids": ["device-id"],
  "scheduled_at": "2026-09-14T12:00:00Z",
  "expires_at": "2026-09-15T12:00:00Z",
  "sound": "default",
  "source_kind": "api"
}
```

加密消息里的明文字段：

```json
{
  "title": "Build completed",
  "body": "Version 1.2 is ready for review.",
  "links": ["https://example.com/build/42"],
  "attachments": [
    {
      "id": "attachment-id",
      "name": "report.pdf",
      "mime": "application/pdf",
      "size": 12345,
      "key": "base64url-aes-key",
      "nonce": "base64url-aes-gcm-nonce",
      "sha256": "lowercase-plaintext-sha256",
      "read_token": "base64url-read-token"
    }
  ],
  "image_id": "attachment-id",
  "icon_id": "attachment-id"
}
```

附件名称、MIME、内容哈希、AES key 和 read token 都在加密消息内部。服务端只能看到
路由元数据、source/account id、attachment id、加密字节数、定时/过期信息和 ciphertext。

## TypeScript 示例

```ts
import {beginAccountLogin, finishAccountLogin, sendNotification} from 'pushnow-sdk';

const pending = await beginAccountLogin(
  'https://api.pushnow.dev',
  accountAccessToken,
  'CI alerts'
);

const config = await finishAccountLogin(pending);

await sendNotification(config, {
  title: 'Build completed',
  body: 'Version 1.2 is ready for review.',
  links: ['https://example.com/build/42']
}, {
  sound: 'default',
  sourceKind: 'api'
});
```

## SDK 状态

SDK 已经包含真实本地测试覆盖：

- TypeScript：构建、后端 Worker fixture、浏览器 import、crypto interop、Access Token
  授权、附件、定时、声音路由和脱敏错误。
- Python：`unittest` 检查、CLI 生成的 HPKE vectors 和本地 HTTP E2EE 请求测试。
- Go：`go test ./...`、vectors、配置校验和本地 HTTP E2EE 请求测试。
- Java：POSIX setup/test 脚本、固定 JSON 依赖 checksum、Java 11 编译和 runtime bridge 测试。

这些测试证明本地 SDK 行为和 wire compatibility，不等于生产 APNs 投递、App Store
可下载状态或手机实际显示通知。

## SEO 关键词

加密推送通知 API、端到端加密通知 SDK、AI Agent 通知收件箱、安全 Webhook 通知、
私密自动化告警、HTTP 推送通知 API、Bearer Token 通知接口、Access Token 发送端授权、
HPKE 加密通知、iOS 加密推送、HarmonyOS 通知 SDK、加密文件附件通知、定时推送通知、
CI 流水线告警、服务器监控告警、API 驱动移动收件箱、Agent 结果投递、开发者私密通知。

## License

当前尚未授予开源许可证。复制、修改或再分发本仓库前请联系项目所有者。
