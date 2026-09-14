# Harmony capabilities audit and submitted application

Verified in AppGallery Connect UI: 2026-09-13.

## Application identity

- App: 即知 / Pushnow
- Bundle name: `com.createitv.pushnow`
- App ID: `6917616271661468373`
- Existing project: `Molayer`
- Project/sender ID: `101653523864728722`

The existing project contains both apps. Project name does not change the selected app identity; only Pushnow is in scope. No project-level switches for unrelated products were changed.

## Observed saved capability status

- APP ID details: Push Kit checked (platform-managed). App Linking and Authentication Service also checked; existing selections preserved.
- Growth > Push Kit > Configuration: project normal, Push Kit enabled; selected app 即知, exact bundle matches, QPS 6000.
- Message self-classification entitlement: 工作事项提醒 submitted at 2026-09-13 10:44:34 (console time); application record reads 审核中. Submission is not approval. The application notice states review within five working days.
- Project data storage location: not selected. UI says this affects topic/device-group/web sending. Current code uses direct device tokens, so no storage location was selected for this shared project.
- Project/application receipts and precise targeting not enabled. No receipt endpoint or targeting integration exists in the current code, so these were not enabled.
- Ordinary email authentication, local cryptographic keys, shared archive and server scheduling use Pushnow's own API and OS CryptoFramework/Asset. No additional Huawei cloud/auth/location capability was added.
- Voice broadcast / in-app calling / priority notifications / live view / proxy reminder / wallet / payment / cloud storage are not current native code dependencies. No speculative capability requests were submitted.

## Required next capability: service and communication self-classification

Submitted category: 服务与通讯类消息 > 工作事项提醒. The live category explicitly includes user-set schedules and workflow fault/abnormal/warning notifications.

Application description draft:

> 即知（Pushnow）是一款用户主动授权的信息提醒工具。用户在应用内登录并批准自己的设备和发送方后，由用户配置的脚本、自动化程序或 Agent 通过 HTTP 发送操作结果、系统状态变化和用户设定的到期提醒。通知仅投递到该用户授权的设备，用户可关闭设备通知或撤销发送方。申请服务与通讯类消息权益用于这些用户主动订阅或操作触发的服务提醒。营销、广告和资讯推广不作为本次服务类申请用途。

Examples matching implemented provider behavior:

- Trigger: a user's configured build/automation completes or fails.
- Trigger: a user's configured system monitor detects an abnormal state.
- Trigger: a user-requested scheduled reminder becomes due.
- Current Huawei notification title: `PushNow`.
- Current Huawei notification body: `You have a new encrypted reminder.`
- On tap: the app retrieves authenticated encrypted history and locally decrypts the actual result/detail. Private titles, bodies and attachment secrets are not sent as provider alert text.
- In-app examples can be “Build complete — Ready for review”, a configured server alert, or a user-scheduled reminder; any screenshots submitted must come from the actual signed app, not mock screenshots.

The provider code currently sends ordinary push-type 0 without an approved category. After entitlement approval, implement the officially assigned applicable category in the V3 payload and verify on device before claiming the service rate is available. Application submission/approval is distinct from enabling a checkbox.

## Submission evidence

The user explicitly agreed to the application requirements and authorized submission. The console displayed 申请完成, then 查看进展 showed one record: 工作事项提醒, 2026-09-13 10:44:34, 审核中.

Submitted message example:

> 标题：PushNow
> 正文：You have a new encrypted reminder.
>
> 上述为当前应用实际发送的通知栏文案，中文含义为“您有一条新的加密提醒”。申请场景为用户主动配置的工作流程结果、故障告警和日程提醒；具体工作内容在用户点击通知进入应用后解密查看，不在通知栏明文展示。

Submitted remarks:

> 即知（Pushnow，包名 com.createitv.pushnow）是用户主动授权的信息提醒工具。用户登录并授权自己的设备与发送方后，由用户配置的脚本、自动化程序或 Agent 通过 HTTP 发送工作提醒，仅投递给该用户授权的设备。申请工作事项提醒类别用于：用户主动设置的日程到期提醒、工作自动化任务完成或失败提醒、用户配置的系统故障/异常/预警通知。用户可以关闭通知或撤销发送方授权。为保护工作信息，推送服务仅接收上述固定提示文案；具体内容通过加密档案在终端本地解密显示。本次申请不用于广告、营销或资讯推广。

No screenshot upload was requested by this form. The application record tab is retained for review.

## Signing observation

Current local debug Profile is for `com.createitv.pushnow` and app-identifier `6917616271661468373`. Build product still lacks `signingConfig` binding. No signing/private credentials were modified. A matching Profile file is not proof of a signed HAP or delivered push.

## References

- Current console: https://developer.huawei.com/consumer/cn/service/josp/agc/index.html#/myProject/101653523864728722/9249519184595935885?appId=6917616271661468373
- Self-classification: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-apply-right
- Push preparation: https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-config-setting
