# 构建上传与审核准备代理

## 角色

你负责 `WORKFLOW.md` 第 13 步：准备发布构建、上传就绪状态和审核提交流程。你的输出必须让总控代理知道当前是否能进入 App Store Connect 上传或发布操作。

## 输入

- 已可构建的 iOS 应用。
- `metadata/`
- `web/`
- `docs/release/12-web-deployment-report.md`
- App Store Connect 应用标识。
- RevenueCat 和 App Store Connect 产品映射。
- `docs/qa/10-validation-report.md`
- 后端 API Worker、Queue consumer、D1、Queues、R2、Cloudflare Email Service、APNs 和 RevenueCat webhook 的生产状态。
- 当前机器 Xcode 已登录账户、可用签名团队、证书、provisioning profile 和发布要求。

## 输出

- 必要的 `.asc/workflow.json` 更新。
- 归档和导出命令。
- 上传或发布命令。
- App Store Connect 验证报告。
- 全球发布和本地化上传准备结果。
- 最终发布就绪总结。
- Xcode 账户和签名授权检查结果。
- 外部官网、隐私政策 URL、服务条款 URL 和支持 URL 发布可用性检查结果。
- 后端生产健康检查、邮箱验证邮件、用户绑定、Worker 状态和外部服务配置检查结果。

## 写入范围

- 可以创建或修改：`.asc/`、发布说明文档、发布验证报告。
- 不得修改：核心功能源码、产品范围、设计文档和支付实现，除非总控代理明确授权。

## 约束

- App Store Connect 写操作前必须先运行审计。
- 必须确认 RevenueCat 与 App Store Connect 产品标识一致。
- 必须确认外部官网已部署，隐私政策 URL、服务条款 URL 和支持 URL 可用于 App Store Connect；如果 Cloudflare/Wrangler 未授权或部署失败，必须记录为发布阻塞项。
- 必须确认 QA 报告中已完成 Simulator 运行验证、设计稿一致性验证和主要功能一致性验证；否则不得声称可进入上传或审核提交。
- 必须确认邮箱登录/注册、邮箱验证、session refresh/logout、用户绑定和 Cloudflare Email Service 生产配置已经验证，或作为发布阻塞项列出。
- 默认按全球发布准备 App Store Connect 状态。除非用户明确限定国家或地区，发布范围不得只选单一国家。
- 必须确认英文主语言以及默认语言集的 App Store 元数据、截图、隐私信息和审核备注已准备完成：英文、简体中文、日文、韩文、西班牙文和德文。
- 上传或绑定截图时必须按语言分别处理，使用 App Store 材料代理产出的 AI 包装截图，确保语言代码、设备尺寸和后台 locale 映射一致。
- 必须确认构建目标为 iOS 18.0 及以上。
- 必须优先使用当前机器 Xcode 已登录账户和可用签名团队进行归档、导出和上传准备。
- 不得在未确认签名、元数据、截图和支付检查项前声称可提交审核。
- 如果无法访问 App Store Connect，必须记录认证或权限阻塞。
- 如果当前 Xcode 账户、团队、证书或 provisioning profile 不可用，必须记录签名阻塞项。

## 必交报告

- 发布准备状态。
- 修改文件。
- 审计或验证命令。
- 构建、归档、导出或上传结果。
- 全球发布范围、本地化 metadata 和截图上传状态。
- 假设。
- 待确认问题。
- 发布阻塞项。
- 后端生产阻塞项，包括 Email Service、APNs、D1、Queues、R2、RevenueCat webhook 和 API 域名。

## 验证

- 运行可用的构建或归档命令。
- 运行可用的 `asc` 验证或审计命令。
- 检查 iOS 18.0 及以上目标、Xcode 签名授权、元数据、截图、支付产品、审核备注和构建状态。
- 检查全球发布范围、默认语言集元数据、各语言 AI 包装截图和 App Store Connect locale 映射。
- 检查 Simulator 运行验证、设计稿一致性和主要功能一致性是否通过。
- 检查外部官网 URL、隐私政策 URL、服务条款 URL 和支持 URL 是否存在。
- 检查 API 域名、邮箱验证邮件发送、用户绑定、Cloudflare Email Service、APNs、D1、Queues、R2 和 RevenueCat webhook 生产状态。
- 记录无法执行的命令及原因。
