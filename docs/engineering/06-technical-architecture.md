# 即知技术架构方案

> 版本：v0.1
> 日期：2026-09-12
> 输入：`即知-App产品规划.md`、`WORKFLOW.md`、`templates/ios-mvvm/`
> 结论：即知必须按“iOS 客户端 + 后端 API + 后台排程 Worker + APNs 推送 + 附件对象存储 + CLI 接入”的完整产品实现，不适合做成纯本地 App。

## 1. 总体决策

即知的核心价值是 Agent 或脚本把内容先送到平台，平台保存内容并按用户规则在未来触达。延迟、定时、重复提醒、确认停止、订阅频道分发、附件访问、API 密钥和 CLI 接入都要求服务端持有状态，因此第一版就需要后端。

推荐技术栈：

| 层级 | 技术方案 | 选择原因 |
| --- | --- | --- |
| iOS App | SwiftUI + MVVM，最低 iOS 18.0，基于 `templates/ios-mvvm/` | 符合仓库默认约束，适合收件箱、提醒计划、订阅和设置等状态型界面 |
| 本地缓存 | SwiftData + 文件缓存目录 | 支持离线浏览最近内容、减少重复拉取；提醒触发仍以服务端为准 |
| 网络层 | URLSession + Codable + async/await | 轻量、原生、易测试；API 合约来自 OpenAPI |
| 账号认证 | 邮箱验证码或验证链接登录 + 服务端 session | 邮箱是第一版唯一登录/注册方式，兼容未来网页版，并能把来源、设备、订阅和通知状态绑定到用户 |
| 支付 | RevenueCat iOS SDK + 后端 RevenueCat webhook | 任何 Pro、额度、保留时间和高级提醒能力都基于 `pro` 权益集中判断 |
| 后端 API | Cloudflare Workers + TypeScript + Hono 或原生 router + Zod + OpenAPI | 与 CLI、后台和测试共享 schema，输入校验清晰，适合 Agent 接入 API |
| 数据库 | Cloudflare D1 + Drizzle SQLite schema | 事项、提醒计划、订阅、分发和审计是关系数据；迁移可审查，并能直接绑定 Workers |
| 后台任务 | Cloudflare Queues + Cron Triggers + D1 due-scan | 支持异步发送、重试、到期扫描和补偿扫描；避免依赖单机内存定时 |
| 附件存储 | Cloudflare R2，S3-compatible 私有桶 | 附件不进数据库；用签名 URL 上传和下载 |
| iOS 推送 | APNs token-based provider auth | 到点提醒由后端发送远程通知；App 打开后同步状态 |
| 邮件发送 | Cloudflare Email Service | 用于邮箱验证、账号安全邮件和未来可选邮件通知模板；当前提醒渠道仍只承诺 App 推送或 App 内查看 |
| 官网 | Astro + 原生 CSS，Cloudflare Pages 或 Workers Static Assets 部署 | 符合当前 workflow 的轻量官网、法律页面、SEO/GEO 要求 |
| 部署 | Cloudflare Workers、Pages/Static Assets、D1、Queues、R2、Cron Triggers、Email Service | 全部核心网页、后端、关系数据、队列、附件和验证邮件发送运行在 Cloudflare；APNs 与 RevenueCat 仍为外部集成 |

## 2. iOS 端架构

目录使用生成后的真实 App 名称，不保留 `TemplateApp`。建议最终 App 目录名先使用 `JiZhi/`，英文品牌名和 bundle ID 待确认；若采用域名品牌，可改为 `PushNow/`。

建议模块：

| 目录 | 内容 |
| --- | --- |
| `App/` | App 入口、环境注入、配置、启动同步 |
| `Navigation/` | Tab、Router、详情路由、sheet 目的地 |
| `Models/` | `InboxItem`、`ContentBlock`、`ReminderPlan`、`Source`、`Category`、`SubscriptionChannel`、`EntitlementState` |
| `ViewModels/` | 每个 screen 一个主 ViewModel，复杂流程拆子 ViewModel |
| `Views/Inbox/` | 信息列表、快捷视图、分类筛选、事项卡片 |
| `Views/ItemDetail/` | 内容块阅读、附件、状态、提醒操作 |
| `Views/Reminders/` | 即将提醒、已延后、循环计划、提醒记录 |
| `Views/Sources/` | 我的来源、个人接入、来源密钥、订阅频道 |
| `Views/Subscriptions/` | 发现来源、频道详情、我的订阅、订阅设置 |
| `Views/Settings/` | 通知权限、隐私、声音、账号、付费入口 |
| `Views/Paywall/` | RevenueCat 付费墙组件 |
| `Services/API/` | APIClient、邮箱登录、session 刷新、分页、错误映射 |
| `Services/Notifications/` | 推送权限、device token 注册、本地测试通知 |
| `Services/Storage/` | SwiftData cache、附件缓存、导出/分享 |
| `Services/Payments/` | RevenueCatService、权益刷新 |
| `Repositories/` | Inbox、Reminder、Source、Subscription、Settings repository |
| `Resources/` | Assets、`.xcstrings`、颜色 token、App icon |
| `Support/` | 时间、时区、格式化、feature flags、测试数据 |

主要 screen 拆分：

| Screen | 容器 View | 子组件边界 |
| --- | --- | --- |
| 信息 | `InboxView` | `InboxToolbar`、`QuickFilterBar`、`CategoryStrip`、`InboxItemRow`、`InboxEmptyState` |
| 事项详情 | `ItemDetailView` | `ItemHeaderSection`、`ReminderStatusSection`、`ContentBlockList`、`AttachmentList`、`ItemActionBar` |
| 提醒 | `ReminderCenterView` | `ReminderSegmentedHeader`、`UpcomingReminderList`、`SnoozedReminderList`、`ReminderHistoryList` |
| 订阅 | `SourcesRootView` | `MySourcesSection`、`SubscribedChannelsSection`、`DiscoverChannelsEntry`、`SourceRow` |
| 频道详情 | `ChannelDetailView` | `ChannelHeader`、`SampleUpdateList`、`SubscribeOptionsForm`、`ChannelTrustSection` |
| 设置 | `SettingsView` | `NotificationPermissionSection`、`DeliveryPreferenceSection`、`PrivacySection`、`AccountSection` |
| 付费墙 | `PaywallView` | `PaywallHeader`、`EntitlementBenefitList`、`PackageCard`、`PurchaseStatusView`、`LegalLinksView` |

文件预算：

- View 文件默认不超过 250 行；复杂详情页最多 350 行，超过必须拆分。
- ViewModel、Service、Repository 默认不超过 300 行。
- 单个 SwiftUI `body` 默认不超过 80 行。
- 网络、支付、持久化、排程规则不得写在 View 里。

## 3. 后端架构

后端放在 `backend/`，采用 pnpm workspace，并面向 Cloudflare Workers 运行时：

```text
backend/
  apps/
    api-worker/
    queue-worker/
  packages/
    auth/
    contracts/
    database/
    email/
    notifications/
    storage/
    shared/
  migrations/
  docs/
```

服务边界：

| 服务 | 职责 |
| --- | --- |
| `api-worker` | 邮箱登录/验证、移动端同步、Agent 接收 API、来源密钥、订阅管理、附件签名 URL、RevenueCat webhook |
| `queue-worker` | APNs 发送、重试、未确认升级、摘要生成、频道分发和 delivery 记录 |
| `cron-trigger` | 每分钟扫描 D1 中到期提醒，写入 Queue，并做补偿扫描 |
| `contracts` | Zod schema、OpenAPI 生成、错误码、分页游标 |
| `database` | D1/Drizzle schema、迁移、种子数据、测试 fixtures |
| `notifications` | APNs、App 推送 payload、delivery 状态和 no-op adapter |
| `email` | 邮箱验证、账号安全邮件和未来邮件通知模板 |
| `storage` | R2 signed upload/download、附件元数据校验 |

首版后端不实现完整公开创作者市场，但要保留公开频道和个人订阅的数据模型，避免后续重构。

## 4. 核心数据模型

首版必须建模：

| 模型 | 关键字段 |
| --- | --- |
| `users` | email_normalized、email_display、email_verified_at、locale、timezone、status、RevenueCat app user id、created_at、deleted_at |
| `auth_challenges` | email_normalized、code_hash、purpose、expires_at、attempt_count、consumed_at、ip_hash、user_agent_hash |
| `sessions` | user_id、refresh_token_hash、device_id、expires_at、rotated_at、revoked_at、created_at |
| `devices` | user_id、platform、apns_token_hash、environment、last_seen_at |
| `sources` | user_id、name、type、status、default_category_id、created_at |
| `source_keys` | source_id、key_prefix、key_hash、scopes、revoked_at |
| `items` | user_id、source_id、title、summary、nature、priority、status、task_key、idempotency_key |
| `content_blocks` | item_id、type、body_json、sort_order |
| `attachments` | item_id、r2_key、filename、mime_type、size、checksum、status |
| `categories` | user_id、name、icon、color、sort_order、is_system |
| `tags` / `item_tags` | 标签和事项关系 |
| `reminder_plans` | item_id、mode、timezone、next_fire_at、repeat_rule、requires_ack、status |
| `deliveries` | reminder_plan_id、channel、provider、status、attempt_count、triggered_at |
| `subscriptions` | user_id、channel_id、category_id、reminder_mode、filters、status |
| `channels` / `channel_updates` | 公开频道、样例、更新、来源口径、状态 |
| `entitlements` | user_id、pro_active、source、expires_at、updated_at |
| `email_deliveries` | user_id、email_normalized、template、provider_message_id、status、sent_at、error_code |

## 5. API 合约

API 域名建议：

- 官网：`https://pushnow.dev`
- API：`https://api.pushnow.dev`
- 上传下载：通过 API 下发 R2 signed URL，不公开桶。

首版 API 分组：

| 分组 | 端点示例 | 调用方 |
| --- | --- | --- |
| Auth | `POST /v1/auth/email/start`、`POST /v1/auth/email/verify`、`POST /v1/auth/refresh`、`POST /v1/auth/logout`、`GET /v1/me` | iOS、Web |
| Device | `PUT /v1/devices/apns-token`、`DELETE /v1/devices/:id` | iOS |
| Inbox | `GET /v1/items`、`GET /v1/items/:id`、`PATCH /v1/items/:id/state` | iOS |
| Reminders | `POST /v1/items/:id/reminders`、`PATCH /v1/reminders/:id`、`DELETE /v1/reminders/:id` | iOS |
| Sources | `GET /v1/sources`、`POST /v1/sources`、`POST /v1/sources/:id/keys` | iOS |
| Ingest | `POST /v1/ingest/items`、`POST /v1/ingest/items/:external_id/updates` | Agent、CLI |
| Attachments | `POST /v1/attachments/upload-url`、`POST /v1/attachments/complete` | iOS、CLI |
| Subscriptions | `GET /v1/channels`、`POST /v1/subscriptions`、`PATCH /v1/subscriptions/:id` | iOS |
| Webhooks | `POST /v1/webhooks/revenuecat` | RevenueCat |
| Health | `GET /healthz`、`GET /readyz` | Cloudflare、监控 |

Agent 接入要求：

- 使用 source key，不使用用户登录 token。
- `Idempotency-Key` 必填，用于重复提交去重。
- 接收成功只表示平台已保存，不表示用户已读或已看到通知。
- API 返回 `item_id`、`received_at`、`scheduled_reminder_id`、`delivery_status_url`。
- 所有附件先拿 signed upload URL，再 complete，不允许直接把大文件塞进 JSON。

### 5.1 邮箱登录与用户绑定

即知第一版只支持邮箱登录/注册。当前流程是首次邮箱验证码验证后设置密码，后续默认用邮箱和密码登录；验证码继续用于首次验证、找回密码、重设密码和换邮箱验证。

登录流程：

1. `POST /v1/auth/email/start` 接收邮箱、客户端语言、时区和设备信息，规范化邮箱后创建验证 challenge。
2. 服务端通过 Cloudflare Email Service 发送验证邮件，并记录 `email_deliveries`。
3. 接口返回统一的中性状态，不暴露邮箱是否已注册。
4. `POST /v1/auth/email/verify` 校验验证码、过期时间、尝试次数和是否已消费。
5. 验证成功后，如果用户不存在则创建 `users`；如果已存在则复用该用户。
6. 如果该账号未设置密码，iOS 引导用户调用 `POST /v1/me/password` 设置密码。
7. 后续登录优先调用 `POST /v1/auth/password/login`。
8. 服务端创建 access token 和 refresh token，refresh token 只以 hash 形式保存在 `sessions`。
9. iOS 把 refresh token 存入 Keychain；未来 Web 版本使用 Secure、HttpOnly、SameSite cookie。

用户绑定要求：

- 所有个人资源表必须直接或间接拥有 `user_id`，包括 source、source key、device、item、category、tag、reminder、subscription、attachment、delivery 和 entitlement。
- 未完成邮箱验证的请求不得创建来源密钥、绑定 APNs token、订阅频道、上传附件或接收真实 Agent 事项。
- Source key 只用于 Agent/CLI 接入，不能替代用户登录态；每个 source key 必须能追溯到唯一 `user_id`。
- 更换邮箱必须先验证新邮箱，再更新 `users.email_normalized`，历史资源不迁移用户。
- 删除账号必须撤销 session、source key、future reminder 和 device token，并停止后续 App 推送。

安全与风控：

- 验证码只保存 hash；hash 计算需要服务端 pepper，不能明文落库。
- 密码只保存带 salt、迭代参数和服务端 pepper 的派生 hash，不保存明文或可逆密文。
- 邮箱和 IP 维度都要限流；同一邮箱短时间重复请求只重发或复用未过期 challenge。
- 所有登录、刷新、登出和邮箱变更操作写入安全审计事件。
- 认证错误需要结构化返回，让 iOS 区分验证码错误、过期、次数过多、session 失效和网络错误。

## 6. 提醒与推送策略

定时提醒必须服务端驱动：

1. API 保存事项和提醒计划。
2. 数据库记录 `next_fire_at`、timezone、repeat_rule 和确认规则。
3. Cron Trigger 每分钟扫描 due reminder，并把发送任务写入 Cloudflare Queue。
4. Queue consumer 调用 APNs 发送远程通知，记录 delivery attempt。
5. App 打开后同步 item/reminder 状态。
6. 用户点击“知道了”后，App 调 API 确认，后续重复提醒停止。

本地通知只用于：

- App 内权限测试。
- 已同步提醒的短期 fallback。
- 开发和 QA 场景。

不得把本地通知当作 Agent 延迟提醒的主要机制，因为 App 可能未打开、设备可能更换，且服务端无法确认本地计划状态。

P1/P0：

- 第一版保留 priority、requires_ack、重复提醒和升级状态。
- 用户可以自定义级别名称、排序、颜色、图标、是否 App 推送、是否要求确认和重复提醒规则。
- 级别只影响 App 推送和 App 内展示，不代表短信、电话或邮件等额外渠道。
- 用户关闭某个级别或单个事项的 App 推送后，该事项只进入 App 内列表和提醒中心。

## 7. CLI 与 Agent 接入

CLI 放在 `cli/`，优先 TypeScript 实现，发布为 npm 包或本地二进制包装。

命令建议：

```bash
pushnow send --title "Report ready" --file ./report.md --remind "5h"
pushnow send --title "Gold update" --priority p1 --at "2026-09-13T20:00:00+08:00"
pushnow sources list
pushnow keys rotate <source-id>
```

CLI 必须读取环境变量或 keychain 中的 source key，不能把密钥写进日志。文档中所有示例使用占位 key。

## 8. RevenueCat 与权限

默认权益：

- Entitlement：`plus`、`pro`
- Offering：`default`
- 产品 ID：
  - `<bundle_id>.plus.monthly`
  - `<bundle_id>.plus.yearly`
  - `<bundle_id>.pro.monthly`
  - `<bundle_id>.pro.yearly`

会员边界：

| 能力 | Free | Plus | Pro |
| --- | --- | --- | --- |
| 每日新事项/通知事件额度 | 50 次 | 500 次 | 不限次数 |
| 私人来源数量 | 基础限额 | 更高限额 | 高限额 |
| 历史保留 | 基础保留 | 更长 | 最长 |
| P1/P0 高级规则 | 基础级别和少量重复提醒 | 更多规则 | 完整自定义级别、过滤器、重复提醒策略和历史保留 |

后端必须接收 RevenueCat webhook，同步 `entitlements`。iOS 可以本地读取 RevenueCat 权益改善体验，但服务端在写入来源、上传附件、创建高级提醒规则和访问订阅能力时必须重新检查权益。

## 9. 部署与环境

Cloudflare 服务：

| 服务 | 说明 |
| --- | --- |
| `api-worker` | Cloudflare Workers HTTP API |
| `queue-worker` | Cloudflare Queues consumer |
| `cron-trigger` | 到期提醒扫描和补偿扫描 |
| `d1` | 主关系数据库 |
| `r2` | 附件对象存储 |
| `pages` 或 `static-assets` | Astro 官网 |

外部服务：

- Cloudflare DNS 管理 `pushnow.dev`、`api.pushnow.dev`。
- Cloudflare D1 存关系数据，Queues 和 Cron Triggers 处理提醒任务，R2 存附件。
- Cloudflare Email Service 发送邮箱验证、账号安全邮件和未来可选邮件通知模板。
- APNs 使用 Apple Developer token-based auth。
- RevenueCat 管理付费和权益。

关键环境变量：

```text
API_BASE_URL
JWT_SECRET
AUTH_CODE_PEPPER
ACCESS_TOKEN_TTL_SECONDS
REFRESH_TOKEN_TTL_SECONDS
EMAIL_FROM
EMAIL_REPLY_TO
EMAIL_VERIFICATION_TTL_SECONDS
APNS_TEAM_ID
APNS_KEY_ID
APNS_PRIVATE_KEY
APNS_BUNDLE_ID
APNS_ENVIRONMENT
R2_ACCOUNT_ID
R2_BUCKET
R2_ACCESS_KEY_ID
R2_SECRET_ACCESS_KEY
REVENUECAT_WEBHOOK_SECRET
```

Cloudflare 资源绑定通过 `wrangler.toml` 或等价配置声明，至少包含 D1 database binding、R2 bucket binding、Queue producer/consumer binding、Cron Triggers 和 Email Service binding。

## 10. Cloudflare 套餐与及时响应保证

第一版默认按 **Cloudflare Workers Paid** 设计和验证，不按 Free 计划承诺生产及时性。Workers Paid 是独立于 Cloudflare Free/Pro/Business 网站套餐的 Workers 付费计划，当前官方价格页显示最低账户费用为 `$5 USD/month`，并提供更高的 Workers、Pages Functions、D1、Queues、KV、Durable Objects 等用量额度。具体金额和额度上线前必须再次以 Cloudflare 官方 pricing 页面为准。

即知的及时响应保证采用“产品级保证”，不是合同级 SLA：

- API 收到 Agent/CLI 请求后必须快速返回 `received` / `scheduled` 状态，不等待 APNs 完成。
- 提醒发送必须通过 Queue 异步执行，所有发送尝试写入 delivery 状态。
- Cron Triggers 每分钟扫描到期提醒，并额外做补偿扫描，防止单次触发失败造成永久遗漏。
- delivery 必须区分 `queued`、`sent`、`failed`、`noop`、`blocked`，不能把未配置 APNs 或 provider 的 no-op 当成真实成功。
- Cloudflare Workers Logs、dashboard metrics 或等价监控必须用于生产排查；发布报告必须记录可见的 Worker、D1、Queues、Cron 和 R2 运行证据。
- 如果需要合同级 SLA、支持响应时间或服务信用，必须升级到支持 SLA 的 Cloudflare 商业/企业支持方案，并在发布阻塞项中记录合同状态。

首版不使用 Cloudflare Free 作为生产承诺基础，因为 Free 计划存在每日请求、D1 写入、Queues 操作和日志保留等限制，不能支撑“必须保证及时响应”的产品承诺。

## 11. Workflow 结合方式

当前 `WORKFLOW.md` 保留 iOS 生成主线，但需要加入 `6A 后端/API/通知基础设施代理`：

1. 第 1-5 步继续产出产品、范围、商业化和体验。
2. 第 6 步产出 iOS + 后端总体架构和 API 契约边界。
3. 第 6A 步落地 `backend/`、`cli/`、OpenAPI、D1 迁移、邮箱登录/验证、健康检查、Queue consumer、Cron Triggers 和部署文档。
4. 第 7 步生成 iOS 项目时读取第 6A 步 OpenAPI/API base URL，不再做纯 mock App。
5. 第 8 步实现核心功能时优先接真实 API；如果后端未部署，使用本地 backend + fixtures，并把缺口记为阻塞项。
6. 第 9 步 RevenueCat 同时覆盖 iOS SDK 和后端 webhook。
7. 第 10 步 QA 必须增加邮箱注册/验证、后端健康检查、API ingest smoke、APNs token 注册状态和提醒 due-scan 验证。
8. 第 12 步官网继续用 Cloudflare Pages 或 Workers Static Assets，但需要确认法律页面 URL、API 域名和下载入口。
9. 第 13 步发布前必须确认 Workers、D1、Queues、Cron Triggers、R2、Cloudflare Email Service、APNs、RevenueCat webhook 的生产配置。

## 12. 当前待确认项

- 英文 App 名称：继续用 `PushNow`，还是另取英文名。
- Bundle ID：建议 `com.createitv.pushnow`，需用户确认。
- APNs key 是否可用，生产/沙盒 bundle 是否确定。
- Cloudflare/Wrangler 是否已授权并可创建 Workers、D1、Queues、R2、Pages 或 Static Assets。
- Cloudflare Workers Paid 是否已开通；如未开通，生产及时响应为发布阻塞项。
- Cloudflare Email Service 是否已开通，发送域名、发件地址、SPF/DKIM/DMARC 和验证邮件模板是否已配置。
- Cloudflare R2 bucket 和 DNS 是否由当前账号管理。

## 13. 参考来源

- Cloudflare Workers、Pages、D1、Queues、Cron Triggers 和 R2 可以覆盖即知的网页、API、关系数据、异步任务、定时扫描和附件存储需求。
- Cloudflare Workers Paid 是本方案的默认生产套餐；上线前需复核 Workers、D1、Queues 和 R2 官方 pricing 页面。
- Cloudflare Email Service 可用于从 Workers 发送邮箱验证和事务邮件；生产上线前需复核 Email Service 可用地区、额度和价格。
- Apple Developer 的远程通知文档要求由 provider server 向 APNs 发送通知请求，因此即知的到点提醒应由后端触发。
- RevenueCat SwiftUI 文档和本仓库规则共同决定付费访问走 RevenueCat。
- Cloudflare R2 文档说明其提供对象存储能力，适合即知附件保存和签名 URL 访问。
