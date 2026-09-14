---
title: 内容、图片与文件
description: 发送加密标题、正文、链接、图片和附件，并理解预览与图标限制。
order: 6
---

## 支持的内容字段

下面这些字段属于完整的**加密明文**。SDK 会先把它们放入消息正文，再进行 HPKE 加密。它们不是 HTTP envelope 的顶层明文字段。

| 字段 | 类型 | 行为 |
| --- | --- | --- |
| `title` | String | 收件箱中保存完整标题；通知预览可能使用较短副本 |
| `body` | String | 收件箱中保存完整正文；通知预览会按 UTF-8 安全截断 |
| `links` | 字符串数组 | 消息关联链接；普通跳转建议使用 HTTPS URL |
| `attachments` | 加密文件描述数组 | 最多 20 个上传文件；解密材料在加密消息内 |
| `image_id` | Attachment UUID | 选择一个附件作为消息图片和可用通知预览图 |
| `icon_id` | Attachment UUID | 标识消息内容中的图标；不会替换 iOS 应用图标 |

服务端不会读取完整标题、正文、链接目标或文件名。它只看到路由 ID、source、设备、调度时间、附件 ID、大小和投递状态等元数据。

## 标题和正文

```sh
node cli/src/main.js send \
  --title "Build complete" \
  --body "Version 1.2 is ready for review."
```

保存到收件箱的完整消息不会为了系统通知而被截断。CLI/SDK 会单独控制通知预览长度，最终 APNs payload 还必须小于系统限制。iOS 也可能在锁屏或通知中心进一步缩短显示文本。

当前发送合约中消息不可编辑。再次调用 SDK 修改内容会创建一条新消息，而不是更新之前的通知。用旧 `message_id` 提交不同内容会产生冲突。

## 链接、文件、图片和图标

```sh
node cli/src/main.js send --title "Review report" \
  --body "Results and supporting files are attached." \
  --link https://example.com/reports/latest \
  --file ./report.pdf --image ./preview.png --icon ./project-icon.png
```

`--file`、`--image` 和 `--icon` 都会在本地加密文件后上传。`image` 会成为消息图片和可用的通知预览图；`icon` 是消息内容里的图标引用，不会替换 iOS 系统通知中的 App 图标。没有提供图标时，系统通知仍显示 PushNow App 图标。

附件描述符包含文件 ID、名称、MIME、大小、AES key、nonce、hash 和读取 token，但这些信息在消息正文里加密传输。不要把附件描述符输出到日志。

## 文件传输限制

SDK 会为每个附件生成随机 AES key、nonce 和 attachment UUID，用 AES-256-GCM 加密，再通过附件 API 上传密文。当前合约限制：

- 最多 20 个附件。
- 单个加密文件最大 20 MiB。
- 加密 manifest 最大 256 KiB。
- 预览 payload 必须适配 APNs 大小限制。

上传完成不会自动创建消息。只有后续加密消息引用这些 attachment ID 后，它们才和消息关联。

## 声音和通知权限

v2 合约支持可选的顶层 `sound` 路由元数据。它在加密正文之外，服务端可见；标题、正文、链接、图片描述和文件仍然加密。

| 值 | 行为 |
| --- | --- |
| 省略或 `default` | 请求系统默认通知声音 |
| `silent` | 不带 APNs `sound`，但仍请求可见通知 |
| `chime` | 请求 App 内置的 `pushnow-chime.wav` |

这是三个命名模式，不是任意声音文件名。不要把 `pushnow-chime.wav` 当作 API 值，也不要上传声音文件。要完全不产生系统通知，请使用[只保存到收件箱](/zh-Hans/docs/scheduling/#只保存到收件箱)。

iOS 通知权限、声音设置、专注模式和勿扰模式优先级更高。API 接受请求不等于设备一定已经响铃。
