---
title: TypeScript 和 JavaScript
description: 构建本地 npm 包，在浏览器或 Node.js 中授权并发送加密通知。
order: 12
---

## 安装本地包

从仓库根目录执行：

```sh
npm --prefix sdk/typescript ci
npm --prefix sdk/typescript run build
cd sdk/typescript
npm pack
```

在你的项目里安装生成的 tarball：

```sh
npm install /absolute/path/to/sdk/typescript/pushnow-sdk-0.1.0.tgz
```

包名是 `pushnow-sdk`。发布后可使用 `npm install pushnow-sdk`，本地开发也可以安装 tarball。包格式是 ESM，并包含 TypeScript declarations；没有 CommonJS 入口。

如果在不打包的浏览器里使用，把构建后的 `dist/browser.js` 作为 ES module 从你的应用里提供。它已经包含 HPKE 依赖。运行环境需要 HTTPS 或 loopback HTTP，并支持 WebCrypto、`fetch`、`AbortController` 和 `structuredClone`。

## 使用账号 Token 授权一次

使用已登录 PushNow App 或可信 Dashboard 会话里的账号 access token，创建账号绑定 sender 授权。

```ts
import { beginAccountLogin, finishAccountLogin } from 'pushnow-sdk';

const pending = await beginAccountLogin(
  'https://api.pushnow.dev',
  accountAccessToken,
  'My integration',
);
// 展示这些公开值，并在已登录 App 中批准 sender。
console.log(pending.authorization.user_code);
console.log(pending.fingerprint);

const config = await finishAccountLogin(pending);
```

token 只用于访问 `/v2/account-authorizations` 创建授权。只有 bearer token 不能加密消息；真正发送仍需要返回的 sender config。

没有账号 token 的 CLI 或离线环境，可以继续使用手动账号根指纹流程：

```ts
import { beginLogin, finishLogin } from 'pushnow-sdk';

const pending = await beginLogin('https://api.pushnow.dev', 'My integration');
const config = await finishLogin(pending, {
  expectedIdentityFingerprint: trustedAccountFingerprint,
});
```

手动流程里的 `trustedAccountFingerprint` 必须从已登录可信 App 独立获取。也可以传入 `confirmIdentity: async ({ fingerprint, userID }) => boolean`，要求用户把 fingerprint 和手机上的可信账号指纹进行人工对比。两种校验方式只能选择一种。缺少校验或 fingerprint 不匹配都会失败。

`config` 含有私密凭证。浏览器场景只建议保存在当前会话内；服务端场景应放入安全的 secret store。不要把它写进公开 JavaScript、URL、日志或明文浏览器存储。接入 Dashboard 时，应确认 `config.user_id` 等于当前登录账号，`config.api_url` 等于预期 API origin，然后调用 `recipientsV2(config)` 校验设备目录。用户退出登录或切换账号时清理配置。

## 发送文字和文件

```ts
import { sendNotification } from 'pushnow-sdk';

const result = await sendNotification(config, {
  title: 'Build complete',
  body: 'The report is ready.',
  links: ['https://example.com/reports/latest'],
  files: [{
    data: new Blob(['Build passed']),
    name: 'build.txt',
    mime: 'text/plain',
  }],
}, {
  inboxOnly: true,
});
console.log(result.message_id, result.deduplicated);
```

去掉 `inboxOnly` 会通知所有可接收设备。发送到指定设备时使用 `deviceIds: [selectedDeviceID]`，不要和 `inboxOnly: true` 同时使用。`scheduledAt` 和 `expiresAt` 放在第三个参数的 options 里。

`image` 或 `icon` 可以作为 content 字段传入，格式同样是 `{data,name,mime}`，SDK 会上传并引用图片。文件数据可以是 `Blob`、`Uint8Array` 或 `ArrayBuffer`。

声音参数在第三个参数中传入：

```ts
await sendNotification(config, { title: 'Quiet update', body: 'Ready to review.' }, {
  sound: 'silent',
});
```

`MessageOptions.sound` 支持 `'default' | 'silent' | 'chime'`。省略时保持默认行为。声音是公开路由元数据；消息正文和文件仍然加密。不支持任意音频文件名、音频上传或 critical alert。

## Prepare 和重试

```ts
import { recipientsV2, prepareMessageV2, submitMessageV2 } from 'pushnow-sdk';

const directory = await recipientsV2(config);
const prepared = await prepareMessageV2(config, directory, {
  title: 'Report ready', body: 'Open the app to review.',
}, { inboxOnly: true });

const result = await submitMessageV2(config, prepared);
// 如果网络结果不确定，重试 submitMessageV2(config, prepared)。
```

必须保留原始 `prepared` 对象。SDK 会把它和账号/source 在内存中绑定；JSON 序列化、clone 或重新导入会丢失绑定并被拒绝。当前版本不提供持久化 outbox 导入。需要进程重启后仍可重试时，请使用 CLI 或其他绑定的 durable outbox 流程。

## 脱敏请求事件

```ts
await sendNotification(config, { title: 'Ready', body: 'Done' }, {
  onRequest(event) {
    console.log(event.method, event.path, event.status, event.durationMs, event.outcome);
  },
});
```

事件不包含 headers、tokens、明文或原始响应体。路径使用 template，不输出具体 ID。自定义 `fetcher` 会收到凭证和密文请求体，它必须是可信代码；它不是脱敏日志钩子。

HTTP 错误会暴露 `APIError.status`。请求会拒绝 redirect 并带超时。可以传入 `AbortSignal` 取消请求；取消不证明服务端没有收到提交。
