# Agent-for-App 说明

## 产品目标

本仓库是一个 Codex CLI 模板工作区，用于根据参考应用链接、应用想法或产品功能描述生成完整 iOS 应用。

每个生成应用的预期结果都不能停留在静态原型。代理应推动完整路径：产品规划、iOS 实现、外部官网部署、App Store 审核准备，以及 App Store Connect 上传就绪。

## 默认生成上下文

- 生成目标是 iOS 应用模板，不是网页应用、演示页面或纯 Swift 包。
- 默认最低系统版本是 iOS 18.0。除非用户明确要求更低版本，否则所有工程配置、架构设计、构建命令和审核准备都按 iOS 18 及以上处理。
- 默认架构使用 SwiftUI + MVVM，并以 `templates/ios-mvvm/` 作为项目生成基线。
- `templates/ios-mvvm/` 只能作为模板来源。生成后的项目文件夹、Xcode project/workspace、target、scheme、product name 和 App display name 必须依据最终应用名称命名，不得继续显示为 `templates`、`ios-mvvm`、`TemplateApp` 或其他模板占位名。
- 当前克隆仓库名称只代表模板工作区，不能作为生成 App 的最外层目录名、Xcode 工程名或用户可见名称。最终交付的 App 最外层目录必须直接使用最终 App 名称，除非用户明确指定其他目录名。
- 默认使用当前机器 Xcode 已登录账户和可用签名团队授权。代理不得要求用户重新创建账号或替换证书；如果当前 Xcode 账户、团队、证书或 provisioning profile 不可用，必须把它记录为签名阻塞项。
- iOS 工程默认启用 Xcode 自动签名，除非用户明确指定手动签名方案。
- 每个生成 App 默认必须支持亮色模式和暗色模式，所有页面都必须跟随系统外观切换并保持可读可用。
- 每个生成 App 默认必须支持多语言。默认第一语言和开发基准语言是英文；默认语言集为英文、简体中文、日文、韩文、西班牙文和德文；除非用户明确指定，不要默认扩展过多语言。
- 所有默认界面文案、设计稿图片内文字、AI image/imagegen 视觉提示词、App Store 主元数据和官网主语言内容必须先按英文生成，再做其他语言本地化。
- App Store Connect 默认按全球发布准备，除非用户明确限定国家或地区。
- 生成应用在进入发布材料、官网、上传或最终交付前，必须打开 iOS Simulator 运行应用，按设计稿检查界面一致性，并验证主要功能流程一致性。不能只做静态代码检查或构建通过就进入下一步。
- 当前机器可用模拟器信息：Xcode 26.4.1；iOS 18.4 有 `iPhone 16 Pro`；iOS 26.4 有 `iPhone 17 Pro`、`iPhone 17 Pro Max`、`iPhone 17e`、`iPhone Air`、`iPhone 17` 和多款 iPad。默认优先用 `iPhone 16 Pro (iOS 18.4)` 做 iOS 18 基线验证；如不可用，使用当前可用的最新 iPhone 模拟器并记录实际设备。

## SwiftUI 代码拆分与文件长度

- 生成 iOS 应用时必须主动拆分 SwiftUI View，不得把首页、设置页、详情页、付费墙或复杂流程集中写进一个巨大文件。
- 每个主要 screen 必须拆成一个容器 View 加多个子 View、section View、row/card View、empty/loading/error state View 和必要的 toolbar/navigation 组件。
- 单个 Swift 源文件默认不超过 250 行；确有必要时可以到 350 行，但必须在步骤代理报告中说明原因和后续拆分点。超过 350 行必须先拆分。
- 单个 SwiftUI View 的 `body` 应保持短小，默认不超过 80 行；复杂布局必须提取为私有子 View 或独立组件文件。
- View 只负责声明 UI、绑定状态和触发 ViewModel action；网络、支付、持久化、解析、业务规则和权限判断必须放到 ViewModel、Service、Repository 或 Support 层。
- ViewModel、Service、Repository 也要按职责拆分，默认单文件不超过 300 行；不得用一个全局 ViewModel 或单个 Service 承载多个不相关功能。
- 架构文档必须先给出 View 拆分计划和文件边界；实现代理必须按该计划创建多个文件，而不是先写大文件再承诺以后拆。
- 总控代理在合并审查时必须检查新增 Swift 文件行数、View 拆分和 MVVM 边界；如果出现明显巨型文件，必须要求对应步骤代理拆分后再继续。

## 并行本地 Codex 代理工作流

- 使用 `WORKFLOW.md` 作为标准应用生成流程。
- 默认执行模型是一个总控代理，加上每个主要应用开发步骤一个本地 Codex 代理。
- 当输入已经可用且文件不冲突时，步骤代理应并行工作。
- 总控代理负责范围控制、依赖排序、冲突审查、最终集成和发布就绪。
- 每个步骤代理必须产出具体文件，不能只给总结。
- 每个步骤代理必须报告假设、未解决问题、修改文件和已执行验证。
- 除非总控代理明确串行安排，否则不得让多个代理同时编辑同一文件。
- 后续对单个步骤的细化应更新 `WORKFLOW.md` 中对应章节。

## 本地 Codex 代理配置

本仓库使用 `.codex/agents/` 存放可复用的本地 Codex 代理提示词。`coordinator.md` 是总控代理，其他文件是对应 `WORKFLOW.md` 各阶段的步骤代理。

总控代理负责：

- 读取用户输入和 `WORKFLOW.md`。
- 决定哪些步骤可以并行，哪些步骤必须串行。
- 为每个步骤代理提供稳定输入和明确写入范围。
- 审查步骤代理产物，解决冲突后再进入后续步骤。
- 维护最终发布就绪状态。

步骤代理必须：

- 只处理自己负责的工作流阶段。
- 只编辑自己写入范围内的文件。
- 产出具体文件，不只返回总结。
- 报告假设、未解决问题、修改文件、验证结果和发布阻塞项。

QA 代理必须在 Simulator 中完成视觉和功能验证后，总控代理才能继续后续发布材料、官网部署、归档或上传准备。

当多个代理需要编辑同一文件时，必须由总控代理串行安排。未经总控代理确认，步骤代理不得同时修改同一文件。

## 强制支付技术栈

- 任何由本模板生成、且包含订阅、付费功能、消耗型项目、非消耗型项目、终身购买、免费试用、高级访问、点数或权益门控功能的应用，都必须通过 RevenueCat 集成支付。
- 不得把直接 StoreKit 购买层作为主要支付架构。
- StoreKit 只能在测试、Apple 平台兼容或 RevenueCat 支持流程需要时，通过 RevenueCat 或与 RevenueCat 配合使用。
- 高级访问检查必须基于 RevenueCat 权益，不得散落成产品标识判断。
- 默认权益名称是 `pro`，除非应用需求明确需要不同权益模型。
- 默认 RevenueCat offering 名称是 `default`。

## RevenueCat 实现要求

每个付费应用或包含权益门控功能的应用，都必须生成并接入：

- `RevenueCatService` 或等价的应用内支付服务。
- 集中的权益状态模型。
- 付费墙视图。
- 购买和恢复购买流程。
- 加载、取消、失败、等待和成功状态。
- 用户可见的恢复购买入口。
- 付费墙上的隐私政策和使用条款链接。
- 与 RevenueCat `store_identifier` 完全一致的 App Store Connect 产品标识。
- 应用的 RevenueCat 产品、权益、offering 和 package 文档。

## 默认产品标识格式

基于最终 bundle ID 使用稳定产品标识：

- 月订阅：`<bundle_id>.premium.monthly`
- 年订阅：`<bundle_id>.premium.yearly`
- 终身购买：`<bundle_id>.premium.lifetime`

创建后必须保持产品标识稳定。不得使用展示名称作为唯一标识。

## App Store 审核要求

对于 RevenueCat 支持的应用，还必须准备：

- App Store Connect 订阅或应用内购买检查清单。
- RevenueCat 目录映射检查清单。
- 审核备注，说明付费墙出现位置，以及如何测试购买和恢复购买。
- 订阅或应用内购买审核所需截图要求。
- 默认语言集下的本地化元数据、审核备注和截图计划。
- 使用 AI image 包装各语言 App Store 截图的提示词、输出路径和 App Store Connect locale 映射。包装必须基于真实 App UI，不得伪造功能。
- 沙盒、TestFlight 和 App Store Connect 验证步骤。

## 外部官网与法律页面要求

每个准备上线的应用都必须生成一个轻量外部官网，用于介绍 App 功能、突出影像能力、提供扫码下载入口，并承载 App Store 审核需要的公开页面。

- 官网默认放在 `web/`，由 `web-deploy-agent.md` 负责生成和部署。
- 官网必须包含首页、隐私政策、服务条款、支持或联系页面。
- 首页必须突出 App 的核心功能和影像/视频/图片相关能力，并提供 App Store 下载按钮和二维码下载区域。
- 官网视觉风格参考 Apple iOS 官方页面的克制、清晰、留白和产品叙事，但不得复制 Apple 商标、文案、图片或专有素材。
- 官网必须兼容移动端和 PC 端，移动端优先保证下载、法律页面和支持入口清楚可用。
- 官网必须包含 SEO 和 GEO 配置，包括 title、description、canonical、Open Graph、Twitter Card、JSON-LD、sitemap、robots，以及面向生成式搜索摘要的清晰问答和功能结构。
- 官网必须支持默认语言集，并配置语言路径、hreflang、地区化 title/description 和 canonical。
- 默认优先使用 Astro 和原生 CSS，避免重型前端依赖；只有动态能力确实需要时才使用 Next.js。
- 默认使用 Cloudflare 部署。官网优先使用 Cloudflare Pages 或 Workers Static Assets，后端优先使用 Cloudflare Workers、D1、R2、Queues 和 Cron Triggers。当前 Cloudflare/Wrangler 已授权时，代理应自动执行部署；未授权、域名未配置或 App Store 下载链接缺失时，必须记录为发布阻塞项。
- App Store Connect 使用的隐私政策 URL、服务条款 URL 和支持 URL 必须来自该官网或明确记录为阻塞项。

## 推荐发布自动化

当可用时，App Store Connect 工作应使用 `asc` 工作流：

- 创建或审计 App Store Connect 订阅和应用内购买。
- 验证元数据、截图、构建绑定和审核就绪状态。
- 保持 App Store Connect 产品标识与 RevenueCat `store_identifier` 一致。
- 任何写操作前都先运行审计。

## Git 提交

- 不要在提交信息中追加 `Co-Authored-By`。
