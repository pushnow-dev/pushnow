---
title: 设备、密钥与加密通知
description: 授权发送端，选择设备，发送定时提醒并查看日志。
order: 4
tryMethod: GET
tryPath: /v1/secure/devices
tryAuth: session
---

## 登录与设备绑定

在 App 中完成邮箱验证并设置密码。每个安装实例有独立设备 ID；在“账户 → 设备与加密”中改名，查看系统和 App 版本。设备不设有效期，也不提供手动撤销。退出登录停止推送，但保留记录。重新安装且丢失本地密钥时可能产生新 ID。

第二台设备登录后打开设备页面，将显示的配对码输入可信设备的“批准设备”页面。新设备自动接收加密密钥，不需要导出私钥文件。

## 授权发送端

```sh
node cli/src/main.js login --api https://api.pushnow.dev --name "Build server"
```

在 App 的“发送端”输入 CLI 授权码，核对发送端指纹，选择密钥有效期并批准，再在 CLI 核对账户指纹。授权码只能使用一次，十分钟内有效。

发送 Key 与设备 ID 相互独立。Web 或 iOS 的“账户 → 发送密钥”支持为现有发送端创建额外 Key、修改有效期或删除 Key。每个发送端最多保留 3 个有效 Key；重新生成会先让旧 Key 失效，再显示一个新的明文 Key。密钥只显示一次，需要立即复制或下载保存，并配合该发送端已有的加密凭据使用。

## 发送提醒

```sh
node cli/src/main.js devices
node cli/src/main.js send --title "构建完成" --body "可以检查了"
node cli/src/main.js send --title "个人提醒" --device DEVICE_ID
node cli/src/main.js send --title "稍后查看" --inbox-only
node cli/src/main.js send --title "检查报告" --at FUTURE_ISO_TIMESTAMP --file report.pdf
```

定时时间需在未来三十天内。不指定设备时，通知当前全部已批准且开启通知的设备；指定 ID 时只通知对应设备；仅保存模式不发系统通知。指定设备仅控制提醒，其他可信设备仍可查看账户共享历史。

SDK 在 HTTP 上传前加密内容、预览和附件。可使用 sendNotification，或 prepareMessageV2 与 submitMessageV2。加密接口不接收明文消息。

## 通知日志

在“账户 → 通知日志”查看发送 Key、计划时间和设备投递记录，也可按 Key 筛选。推送服务已接受不代表手机已经弹出通知；被阻止或失败时会显示原因。

提前阅读定时消息不会取消未来提醒。发送前再次检查账户、登录会话、设备通知开关和 Key 有效期。定时提醒由服务端周期扫描处理，不承诺精确到秒。

GET /v2/keys 和 GET /v2/logs?key_id=KEY_ID 使用账户登录会话调用。日志只包含路由信息，不包含解密正文或私钥。


## 浏览器自动连接

登录 Dashboard 后自动识别账号设备，浏览器在本地生成加密密钥并申请绑定当前账号的发送证书。首次连接请打开已登录且受信任的最新版 iPhone App，手机自动完成签署，无需抄写授权码或指纹。旧版 App 尚不支持此流程。手机账号和档案私钥不会上传服务器。

发送配置保存在当前标签页的 session storage，注销时清除。暂停或撤销的 Key 不会被自动替换；可在 Dashboard 随时撤销。自动流程信任已认证服务提供的初始账号公钥，CLI 仍保留手动指纹核对流程。

## 发送保护

单个 Key 在滚动一分钟内超过 60 次消息请求，暂停 15 分钟，返回 HTTP 429 和 Retry-After；Key 列表显示暂停截止时间。同一账号所有 Key、所有设备合计每滚动分钟最多尝试 20 次推送，超出部分排队延后，定时推送同样受限。

安全邮件每用户每滚动小时最多一封、滚动一天最多三封，失败后排队重试，不包含完整 Key 或通知正文。邮件服务商接受发送不等于已送达收件箱。
