# Agent-for-App 工作流

本文件定义默认 Codex CLI 工作流，用于把参考应用链接、应用想法或产品功能描述，转化为一个完整 iOS 应用，并推进到外部官网部署、App Store Connect 准备和上传就绪阶段。

该工作流面向“总控代理 + 并行本地 Codex 步骤代理”设计。总控代理决定某个步骤何时已有足够输入可以运行，分派本地代理，审查产物，解决冲突，并集成最终结果。

默认生成目标是 iOS 18.0 及以上的 SwiftUI iOS 应用模板，架构使用 MVVM，并以 `templates/ios-mvvm/` 作为项目生成基线。默认使用当前机器 Xcode 已登录账户和可用签名团队授权。除非用户明确指定其他方案，工程应启用 Xcode 自动签名；如果账户、团队、证书或 provisioning profile 不可用，必须记录为签名阻塞项。

`templates/ios-mvvm/` 只能作为模板来源。生成后的项目文件夹、Xcode project/workspace、target、scheme、product name 和 App display name 必须依据最终应用名称命名，不得继续显示为 `templates`、`ios-mvvm`、`TemplateApp` 或其他模板占位名。

当前克隆仓库名称只代表模板工作区，不能作为生成 App 的最外层目录名或 Xcode 用户可见名称。最终交付的 App 最外层目录必须直接使用最终 App 名称，除非用户明确指定其他目录名。

每个生成 App 默认必须支持亮色模式和暗色模式，所有页面都必须跟随系统外观切换。每个生成 App 默认必须支持多语言，默认第一语言和开发基准语言是英文；默认语言集为英文、简体中文、日文、韩文、西班牙文和德文。所有默认界面文案、设计稿图片内文字、AI image/imagegen 视觉提示词、App Store 主元数据和官网主语言内容必须先按英文生成，再做其他语言本地化。App Store Connect 默认按全球发布准备，除非用户明确限定国家或地区。

在进入发布材料、官网部署、归档上传或最终交付前，必须打开 iOS Simulator 运行应用，截图或读取运行时 UI，和设计稿逐页对照，确认视觉风格、布局、文案密度、亮色/暗色模式、多语言、主要功能流程和付费流程一致。当前机器默认优先使用 `iPhone 16 Pro (iOS 18.4)` 做 iOS 18 基线验证；如果不可用，使用当前可用的最新 iPhone 模拟器，并在 QA 报告中记录设备名称、运行时版本和 UDID。

SwiftUI 实现必须采用小文件、小组件和明确 MVVM 边界。主要页面不得堆在单个 `ContentView.swift`、`HomeView.swift` 或 `SettingsView.swift` 中；每个主要 screen 应拆成容器 View、section View、row/card View、状态 View 和必要的 toolbar/navigation 组件。单个 Swift 源文件默认不超过 250 行，确有必要时可到 350 行并说明原因，超过 350 行必须先拆分。单个 SwiftUI View 的 `body` 默认不超过 80 行；View 不得直接承担网络、支付、持久化、解析或复杂业务规则。

## 执行模型

- 一个总控代理控制完整运行。
- 每个主要步骤应尽量分派给一个本地 Codex 代理。
- 只有当输入稳定且不需要编辑同一批文件时，代理才可以并行运行。
- 每个步骤代理必须创建或更新具体文件。
- 每个步骤代理必须返回修改文件、已执行验证、假设和未解决问题。
- 在继续实现、构建、上传或 App Store 提交工作前，总控代理必须审查所有步骤输出。

## 第 1 步：输入整理代理

**目标：** 将用户原始输入转化为结构化应用请求。

**输入：**
- 参考应用链接、应用名称、产品想法或功能描述。
- 用户约束、语言、目标市场和商业化偏好。

**输出：**
- `docs/product/01-intake.md`
- 应用名称候选。
- 目标用户。
- 核心用户问题。
- 参考应用备注。
- 已知约束和未解决问题。

## 第 2 步：产品分析代理

**目标：** 将产品拆解为核心价值、竞品模式和应用机会。

**输入：**
- `docs/product/01-intake.md`
- 可用的参考应用研究。

**输出：**
- `docs/product/02-product-analysis.md`
- 核心功能列表。
- 差异化策略。
- App Store 分类建议。
- 审核、隐私或商业化风险说明。

## 第 3 步：最小可行版本范围代理

**目标：** 定义 1.0 版本必须包含什么，以及哪些内容应推迟。

**输入：**
- 输入整理和产品分析。

**输出：**
- `docs/product/03-mvp-scope.md`
- 必做功能。
- 明确不做事项。
- 首版验收标准。
- 功能优先级表。

## 第 4 步：权限与商业化代理

**目标：** 定义登录、隐私、免费访问、高级访问和 RevenueCat 支付边界。

**输入：**
- 最小可行版本范围。
- 用户商业化偏好。

**输出：**
- `docs/product/04-permissions-and-monetization.md`
- 登录/注册方式、邮箱验证要求、用户数据绑定和账号删除边界。
- 免费与 Pro 功能矩阵。
- RevenueCat 权益模型。
- App Store Connect 产品标识计划。
- 付费墙触发规则。
- 恢复购买要求。

**强制规则：** 任何付费功能都必须使用 RevenueCat。

## 第 5 步：原型与体验代理

**目标：** 设计屏幕地图、导航、用户流程和核心界面状态。

**输入：**
- 最小可行版本范围。
- 权限与商业化计划。

**输出：**
- `docs/design/05-prototype.md`
- 屏幕列表。
- 导航地图。
- 主要用户流程。
- 空状态、加载状态、错误状态、权限状态和付费墙状态。
- 亮色模式和暗色模式视觉规范。
- 默认语言集的界面文案长度和截图语言计划。
- App Store 提交截图计划。

## 第 6 步：技术架构代理

**目标：** 设计 SwiftUI 应用架构、后端依赖边界、API 合约边界和模块边界。

**输入：**
- 最小可行版本范围。
- 原型。
- RevenueCat 支付要求。
- 后端、推送、附件、CLI、订阅频道或定时任务需求。

**输出：**
- `docs/engineering/06-technical-architecture.md`
- SwiftUI 模块结构。
- 基于 `templates/ios-mvvm/` 的 MVVM 目录映射。
- 前端、后端、Worker、对象存储、推送通知和 CLI 的总体技术选型。
- iOS 与后端的 API 合约边界。
- 主要 screen 的 View 拆分计划、组件边界和预计文件清单。
- 单文件行数预算和需要拆分的复杂页面清单。
- 数据模型。
- 状态管理方案。
- RevenueCat 集成架构。
- 本地持久化和接口需求。
- 后端服务、数据库、后台任务、附件存储和部署需求。
- 亮色模式和暗色模式主题架构。
- 默认语言集本地化架构。
- 构建与签名假设。

## 第 6A 步：后端/API/通知基础设施代理

**账号多设备加密提醒补充（2026-09-12）：**
- v2 一次授权、账户共享历史和加密附件遵循 `docs/engineering/20-v2-wire-contract.md`；旧消息保留 `docs/engineering/16-e2ee-contract.md` 兼容。
- 登录账号、安装设备、APNs 地址和加密密钥必须分开建模。设备长期保留，支持识别、重命名、版本信息、通知开关和多个同时登录的实例，不提供用户手动撤销或设备有效期。
- 加密来源必须拒绝明文降级；v2 发送端使用经账户签名认证的独立历史公钥执行 RFC 9180 Auth HPKE，设备目标仅控制通知。Worker 和 R2 只存储密文与必要路由信息。
- CLI 在本机生成密钥，手机以一次性授权码确认公钥；普通用户不需要导出私钥文件。发送端可撤销，历史分页与删除在账户内同步，删除不得被重试复活。
- 附件独立加密，Markdown、图片、链接和其他文件按真实内容预览；通知配图只使用单附件密文读取凭据，不共享登录或刷新令牌。
- 首台设备建立账号公钥信任锚，后续设备使用绑定账户身份和设备公钥的短配对码由可信设备批准，新设备自动验证接收密钥；API 使用会话绑定、限时、一次性挑战验证设备私钥持有证明。
- 投递与重试前重新验证账号、来源、发送 Key 有效期、设备、会话及通知偏好；退出登录必须停止相应会话投递。设备记录与发送 Key 的到期、撤销独立。
- v2 支持立即、定时与仅保存；Web/iOS 提供按 Key 筛选的设备投递日志。预先阅读定时消息不取消未来提醒。模拟器必须验证注册、配对、授权、Key 管理和解密收件流程。
- 缺少 APNs 或设备地址存储密钥必须记录阻塞，不得把入库或 APNs 接受当作手机收到。

**目标：** 为需要服务端能力的 App 落地后端 API、数据库、后台 Worker、对象存储、推送通知、CLI 接入和部署计划。

**触发条件：**
- 产品需要 HTTP/CLI 接入。
- 产品需要账号、邮箱验证、同步、附件、公开订阅、服务端排程、远程推送、Webhook、后台任务或跨设备状态。
- 技术架构明确要求后端。

**输入：**
- `docs/engineering/06-technical-architecture.md`
- 最小可行版本范围。
- 原型。
- 权限与商业化计划。
- 总控代理提供的域名、Cloudflare/Wrangler 授权状态、API base URL、bundle ID、APNs 配置状态、RevenueCat webhook 要求和外部服务约束。
- 如果产品需要账号，必须提供登录方式、邮箱验证要求、用户绑定范围和账号删除边界。

**输出：**
- `docs/engineering/06A-backend-api-infrastructure.md`
- `backend/`
- `cli/`
- `docs/engineering/api/openapi.yaml`
- `docs/engineering/api/examples/`
- `docs/release/backend-deployment.md`
- 数据库 schema、迁移和测试 fixtures。
- API 服务、后台 Worker、OpenAPI、CLI、部署配置和验证报告。

**默认技术栈：**
- TypeScript + Hono 或原生 Workers router + Zod + OpenAPI。
- Cloudflare D1 + Drizzle SQLite schema。
- Cloudflare Queues + Cron Triggers + D1 due-scan。
- Cloudflare R2 signed URL 附件存储。
- APNs token-based provider auth。
- 邮箱登录/注册、邮箱验证、session 刷新和用户资源绑定默认由后端实现；即知当前版本只支持邮箱认证。
- Cloudflare Email Service 发送验证邮件、账号安全邮件和未来可选邮件通知模板。
- Cloudflare Workers 部署 API 和 Queue consumer，Cloudflare Pages 或 Workers Static Assets 部署官网。
- 生产默认要求 Cloudflare Workers Paid；Free 计划只能用于试验或本地/preview 验证，不能承诺产品级及时响应。

**验证：**
- 运行后端类型检查和可用测试。
- 本地使用 Wrangler 启动 API，验证 `GET /healthz` 和 `GET /readyz`。
- 本地验证邮箱登录/注册：`auth/email/start` 不泄露邮箱是否已注册，`auth/email/verify` 可创建或登录用户，session refresh/logout 可用。
- 验证未完成邮箱验证的用户不能创建 source key、绑定 device token、订阅频道、上传附件或接收真实 Agent 事项。
- 本地调用 Agent ingest API 写入事项。
- 使用相同 `Idempotency-Key` 验证重复提交不会创建重复事项。
- 创建到期提醒并运行 Cron due-scan 与 Queue consumer，验证生成 delivery 记录。
- 无 APNs key 时必须记录 no-op 或阻塞状态，不得标记为真实触达成功。
- CLI `send` 能向本地 API 发送事项。
- 生成 OpenAPI 文档并供 iOS 阶段读取。
- 验证 Workers Logs、dashboard metrics 或等价监控可查看 API、D1、Queues、Cron 和 R2 状态。

### HarmonyOS 受管理设备补充（2026-09-13）

- 鸿蒙复用 iOS 的账号、签名身份、P-256 设备目录、一次性注册挑战、短码配对、v2 账户归档与发送方授权协议，不新建独立推送账户体系。
- 原生客户端必须实现真实 HPKE 解密和来源证书验证；设备激活、通知权限、Push Token 注册、HTTP 接受及真机显示必须分别验证，接口失败不得展示样例数据。
- 鸿蒙私钥与会话凭据存于 OS Asset 安全存储；升级旧 Preferences 密钥必须先安全迁移并读回、验证账号和公钥归属，再清理旧明文，保留原设备 ID。
- HTTP `notify_device_ids` 可选择 iOS、Harmony 或两者；共享历史与通知目标分离。Huawei V3 使用服务账号 PS256 和原生请求结构，与 APNs 分别测试。
- 标准鸿蒙通知只显示通用提醒与路由 ID，打开应用后本机解密。扩展通知明文预览需独立能力配置和设备验证。
- 鸿蒙验收输出 `docs/qa/harmony-client.md` 与 `docs/qa/harmony-backend.md`，包括 ArkTS 构建、协议互操作、账号隔离/篡改测试、签名及真实设备送达状态。

## 第 7 步：iOS 项目生成代理

**目标：** 创建真实 iOS 项目结构。

**输入：**
- 技术架构。
- 如果存在第 6A 步：OpenAPI、API base URL、本地后端启动方式、认证策略和 mock/fixture 边界。
- bundle ID、应用名称和 iOS 18.0 及以上最低系统版本。

**输出：**
- Xcode iOS 应用模板或 Swift package 支持的 iOS 应用目标。
- 基于 `templates/ios-mvvm/` 生成的 MVVM 源码目录。
- 基于最终应用名称命名的最外层 App 目录、项目文件夹、Xcode project/workspace、target、scheme、product name 和 App display name。
- 应用入口。
- 基础导航。
- 按架构文档拆分的 Views 子目录、可复用 Components、StateViews 和 Navigation 组件占位。
- 资源目录占位。
- 亮色模式和暗色模式主题资源。
- 默认语言集本地化资源。
- APIClient 配置、环境变量或 xcconfig 中的 API base URL 占位。
- 可构建项目骨架。
- 使用当前 Xcode 账户和可用签名团队的自动签名配置。

**验证：**
- 当项目文件存在后，按 iOS 18.0 及以上目标运行 iOS 构建命令。
- 检查最终 App 最外层目录和 Xcode 工程打开后显示真实应用名称，而不是当前克隆仓库名、`templates`、`ios-mvvm` 或 `TemplateApp`。
- 检查自动签名配置是否指向当前 Xcode 可用团队；不可用时记录签名阻塞项。

## 第 8 步：核心功能实现代理

**目标：** 实现应用主要用户功能。

**输入：**
- 项目骨架。
- 最小可行版本范围。
- 原型。
- 技术架构和后端/API 合约。

**输出：**
- SwiftUI 页面。
- 按 screen 拆分的容器 View、section View、row/card View、状态 View 和可复用组件。
- 模型和视图模型。
- Services、Repositories、Navigation 和 Support 中的必要业务实现。
- 持久化或接口集成。
- 对接真实 API；如后端尚未部署，必须对接本地后端或明确 fixture 边界。
- 用户可见的加载、成功和失败状态。
- 所有页面的亮色模式和暗色模式实现。
- 所有用户可见文案的默认语言集本地化。

**验证：**
- 构建应用。
- 运行可用测试。
- 检查新增 Swift 文件行数，默认不超过 250 行；超过 350 行必须拆分后再交付。
- 检查主要 SwiftUI View 的 `body` 是否保持短小，复杂布局是否已提取为子 View 或组件。

## 第 9 步：RevenueCat 支付代理

**目标：** 实现 RevenueCat 购买、恢复购买和权益门控访问。

**输入：**
- 权限与商业化计划。
- 技术架构。
- 应用 bundle ID。
- 后端 RevenueCat webhook 和服务端权益检查要求。

**输出：**
- RevenueCat SDK 集成。
- 支付服务。
- 权益状态模型。
- 拆分后的付费墙视图，包括容器、权益列表、套餐卡、购买状态、恢复购买入口和法律链接组件。
- 购买和恢复购买流程。
- RevenueCat 目录检查清单。
- App Store Connect 产品检查清单。
- 后端 webhook 验签、权益同步和服务端额度检查。
- 付费墙和支付状态的亮色/暗色模式适配与默认语言集本地化。

**验证：**
- 构建应用。
- 验证权益检查是集中实现的。
- 验证后端 webhook 和服务端权益检查不会只依赖客户端状态。
- 验证付费墙包含隐私政策和使用条款链接。
- 检查付费墙和支付相关 Swift 文件行数，超过 350 行必须拆分后再交付。

## 第 10 步：质量检查与验证代理

**加密提醒专项验收：**
- 验证 CLI 与原生 CryptoKit 的双向互操作、来源证书，以及密文/AAD/账号/设备/来源公钥篡改拒绝。
- 验证同账号双设备、指定设备、不同账号隔离、待批准设备、通知关闭、退出登录、撤销、幂等重试和一次性挑战重放。
- 核查数据库和 APNs payload 不含正文；验证通知扩展与 App 内收件箱均在本机解密。
- Simulator 的登录、设备管理和模拟通知验证，与真实 APNs 的签名真机送达验收分别记录。

**目标：** 在 App Store 准备前验证应用行为。

**输入：**
- 已实现应用。
- 首版验收标准。
- RevenueCat 支付流程。

**输出：**
- `docs/qa/10-validation-report.md`
- 构建结果。
- 后端 API、Worker、CLI 和生产依赖验证结果。
- Simulator 运行验证结果，包含实际设备名称、运行时版本和 UDID。
- Swift 源文件行数与主要 View 拆分检查结果。
- 功能验证清单。
- 支付验证清单。
- API ingest、提醒排程、APNs token 注册、附件上传下载和 Worker due-scan 验证清单。
- 亮色模式和暗色模式验证清单。
- 默认语言集本地化验证清单。
- 设计稿一致性检查清单，逐页对照 `docs/design/05-prototype.md` 和 `docs/design/assets/`。
- 已知问题和发布阻塞项。

**强制规则：**
- 必须启动或打开 iOS Simulator，安装并运行应用。
- 必须截图或读取运行时 UI，并和设计稿检查是否相符。
- 必须验证主要功能流程是否与设计文档和首版范围一致。
- 对依赖后端的 App，必须验证本地或已部署 API 的健康检查、Agent ingest smoke、提醒 due-scan、device token 注册和 no-op/真实推送状态。
- 对需要账号的 App，必须验证邮箱注册/登录/验证、session 刷新/登出、未验证用户拦截和用户资源隔离。
- 必须检查新增 Swift 源文件是否存在超过 350 行的巨型文件，以及主要 screen、付费墙和设置页是否仍集中在单个大 View 文件中；发现后必须列为工程质量阻塞项或明确风险。
- 如果 Simulator 无法启动、应用无法安装、应用无法运行、设计稿明显不一致或主要功能不可用，必须记录为发布阻塞项，不能进入 App Store 材料、官网部署、归档或上传步骤。

## 第 11 步：App Store 材料代理

**目标：** 准备 App Store Connect 元数据和审核材料。

**输入：**
- 产品分析。
- 原型。
- 最终应用行为。
- RevenueCat 支付计划。

**输出：**
- `metadata/`
- 应用名称、副标题、描述、关键词和推广文本。
- 默认语言集本地化元数据。
- 隐私政策和使用条款要求。
- App 隐私检查清单。
- 说明付费功能和恢复购买的审核备注。
- 截图检查清单。
- 使用 AI image 包装各语言 App Store 截图的提示词、输出路径和上传映射。

## 第 12 步：外部官网与 Cloudflare 部署代理

**目标：** 生成并部署一个面向上线使用的轻量外部官网，用于介绍 App 功能、突出影像能力、承载隐私政策和服务条款，并给用户提供扫码下载 App 的入口。

**输入：**
- 产品分析。
- 原型与视觉设计资产。
- App Store 材料。
- 最终应用名称、bundle ID、目标市场、语言和下载链接策略。
- 隐私政策、服务条款和 App 隐私说明要求。
- 总控代理提供的 Cloudflare/Wrangler 授权状态、项目命名和部署域名偏好。
- 后端 API 域名、健康检查、附件存储和生产依赖阻塞项。

**输出：**
- `web/`
- 轻量官网项目。
- 首页，重点说明 App 核心功能、影像/视频/图片相关能力和下载入口。
- 隐私政策页面。
- 服务条款页面。
- App 支持或联系页面。
- SEO、GEO、Open Graph、Twitter Card、结构化数据、站点地图和 robots 配置。
- 默认语言集官网路径和 hreflang 配置。
- PC 端和移动端响应式布局。
- Cloudflare Pages 或 Workers Static Assets 部署配置、部署命令和部署结果记录。
- 可交给 App Store Connect 使用的隐私政策 URL 和服务条款 URL。
- API 域名、支持入口和数据删除/隐私请求路径说明。

**优先框架：**
- 默认优先使用 Astro，配合原生 CSS 和极少量客户端 JavaScript，避免引入重型 UI 框架。
- 只有当应用官网需要登录、复杂后台、动态服务端逻辑或已有项目明确使用 Next.js 时，才优先选择 Next.js。
- 默认部署目标为 Cloudflare，使用 Wrangler 自动创建、链接、配置和部署；如果 Cloudflare/Wrangler 未授权或当前账号不可用，必须记录为部署阻塞项。

**设计规则：**
- 官网视觉风格参考苹果 iOS 官方页面的克制、清晰、留白和产品摄影式叙事，但不得复制 Apple 商标、文案、图片或专有素材。
- 首屏必须直接呈现 App 名称、App icon、核心功能、一句清楚价值说明、扫码下载入口和主视觉。
- 主视觉应突出 App 的影像能力，例如视频转写、图片处理、相机、相册、视觉记录、创作或预览能力，具体取决于当前 App 功能。
- 页面内容必须简洁，不做冗长营销长文；每个区块只说明一个明确功能或用户收益。
- 必须兼容移动端和 PC 端，移动端优先保证扫码、下载、隐私政策和服务条款入口清晰。

**SEO / GEO 要求：**
- 每个公开页面必须包含唯一 title、description、canonical、Open Graph 和 Twitter Card。
- 必须生成 sitemap、robots、manifest 或等价 PWA 元信息。
- 必须包含 `SoftwareApplication`、`MobileApplication`、`FAQPage` 或适合当前页面的 JSON-LD。
- 必须加入面向生成式搜索和 AI 摘要的 GEO 内容结构：清楚的问题标题、简短答案、功能清单、价格/订阅说明、隐私承诺和支持入口。
- 多语言或多地区上线时必须配置 hreflang、地区语言路径和地区化元数据。默认第一语言是英文；默认语言集为英文、简体中文、日文、韩文、西班牙文和德文。

**下载与二维码要求：**
- 首页必须提供 App Store 下载按钮和二维码区域。
- 如果 App Store 链接尚未可用，必须使用可替换占位配置，并把正式链接缺失记录为发布阻塞项。
- 二维码必须指向最终下载页或 App Store 页面；不得指向本地临时地址。

**验证：**
- 本地构建官网。
- 检查隐私政策和服务条款页面存在且 URL 稳定。
- 检查 SEO/GEO 元数据、sitemap 和 robots。
- 检查移动端和 PC 端响应式页面。
- 如果 Cloudflare/Wrangler 已授权，运行 Wrangler 部署并记录生产 URL；如果未授权，记录明确阻塞项。

## 第 13 步：构建上传与审核代理

**目标：** 准备发布构建、上传就绪状态和审核提交流程。

**输入：**
- 可构建应用。
- 后端 API Worker、Queue consumer、D1、Queues、R2、APNs 和 RevenueCat webhook 的生产状态。
- 元数据。
- 外部官网 URL、隐私政策 URL 和服务条款 URL。
- App Store Connect 应用标识。
- RevenueCat 与 App Store Connect 目录映射。
- 当前 Xcode 账户、签名团队、证书和 provisioning profile 状态。

**输出：**
- 必要的 `.asc/workflow.json` 更新。
- 归档和导出命令。
- 上传或发布命令。
- App Store Connect 验证报告。
- 后端生产健康检查、Worker 状态和外部服务配置检查结果。
- 全球发布范围、本地化元数据和各语言截图上传准备结果。
- 最终发布就绪总结。
- Xcode 账户和签名授权检查结果。

**推荐工具：**
- `asc xcode archive`
- `asc xcode export`
- `asc validate`
- `asc publish appstore`

## 总控集成检查清单

在认为生成应用完成前，总控代理必须确认：

- 产品范围已文档化。
- 界面流程已文档化并完成实现。
- iOS 项目可构建。
- 如果产品需要服务端能力，后端 API Worker、Queue consumer、D1、Queues、R2、Email Service、APNs、CLI 和部署文档已存在并通过本地或生产验证。
- 新增 Swift 源文件符合小文件和小组件规则，没有把主要功能集中到单个巨大 View、ViewModel、Service 或 Repository。
- iOS Simulator 已运行应用，设计稿一致性和主要功能一致性已验证通过，或阻塞项已明确列出。
- 最外层 App 目录、Xcode 工程、target、scheme、product name 和 App display name 已替换为真实应用名称，没有当前克隆仓库名或模板占位命名残留。
- 所有付费访问都使用 RevenueCat。
- 权益检查是集中实现的。
- 付费墙包含恢复购买、隐私政策和使用条款。
- App Store 元数据已存在。
- 默认语言集本地化元数据、审核备注和 AI 包装截图计划已存在。
- 亮色模式、暗色模式和默认语言集已通过验证或阻塞项已列出。
- 外部官网、隐私政策 URL 和服务条款 URL 已存在，或部署阻塞项已列出。
- API 域名、健康检查、提醒排程、附件存储和推送配置已验证，或明确列为发布阻塞项。
- 邮箱登录/验证、用户绑定、session 刷新/登出、账号删除和 Cloudflare Email Service 已验证，或明确列为发布阻塞项。
- Cloudflare Workers Paid、Wrangler 授权、Workers Logs/metrics 和生产资源绑定已验证，或明确列为发布阻塞项。
- App Store Connect 与 RevenueCat 产品标识一致。
- 发布阻塞项已列出或已解决。
