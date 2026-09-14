# 本地 Codex 代理

本目录存放本项目可复用的本地 Codex 代理提示词。每个文件对应一个明确角色。

## 默认上下文

- 生成目标是 iOS 18.0 及以上的 SwiftUI iOS 应用模板。
- 默认架构为 MVVM，项目生成基线为 `templates/ios-mvvm/`。
- `templates/ios-mvvm/` 只能作为模板来源。生成后的项目文件夹、Xcode project/workspace、target、scheme、product name 和 App display name 必须使用最终应用名称，不能继续叫 `templates`、`ios-mvvm` 或 `TemplateApp`。
- 当前克隆仓库名称只代表模板工作区，生成 App 的最外层目录必须使用最终 App 名称，不能沿用当前仓库目录名。
- 默认使用当前机器 Xcode 已登录账户和可用签名团队授权。
- 默认启用 Xcode 自动签名；如果账户、团队、证书或 provisioning profile 不可用，必须记录为签名阻塞项。
- 视觉设计阶段必须使用本地 `imagegen` skill 生成 App icon 和主要界面设计稿。设计稿必须符合应用功能风格、iOS 18 移动端气质和简洁内容密度。
- 上线前必须生成外部官网，用于 App 功能介绍、影像能力展示、扫码下载、隐私政策、服务条款、支持入口、SEO/GEO 配置和 Cloudflare 部署。
- 当产品需要 HTTP/CLI 接入、账号同步、邮箱验证、附件、订阅频道、服务端排程、远程推送、Webhook 或跨设备状态时，必须增加后端/API/通知基础设施阶段，产出 `backend/`、`cli/`、OpenAPI、数据库迁移、Worker 和部署文档。
- 每个生成 App 默认必须支持亮色模式和暗色模式，并在所有页面支持多语言。本地化默认第一语言和开发基准语言是英文；默认语言集为英文、简体中文、日文、韩文、西班牙文和德文；除非用户明确指定，不再扩展过多语言。
- 视觉设计、imagegen 设计稿、App Store 主元数据、官网主语言内容和默认 UI 文案必须先使用英文，再同步本地化到其他默认语言。
- App Store Connect 默认按全球发布处理。元数据、截图包装和官网多语言内容必须覆盖默认语言集，并按各语言/地区分别准备。
- SwiftUI 实现必须采用小文件和小组件。主要 screen 要拆成容器 View、section View、row/card View、状态 View 和可复用组件；Swift 文件默认不超过 250 行，确有必要时可到 350 行并说明原因，超过 350 行必须拆分；SwiftUI View 的 `body` 默认不超过 80 行。
- QA 阶段必须打开 iOS Simulator 运行应用，对照设计稿检查界面一致性，并验证主要功能流程一致性；验证未完成或失败时不得进入发布材料、官网、归档或上传步骤。
- 当前机器默认优先使用 `iPhone 16 Pro (iOS 18.4)` 做 iOS 18 基线验证；如不可用，使用当前可用的最新 iPhone 模拟器并记录实际设备。

## 使用顺序

1. 先使用 `coordinator.md` 读取用户输入、`AGENTS.md` 和 `WORKFLOW.md`。
2. 由总控代理确认当前应用生成任务的范围、依赖和写入边界。
3. 总控代理按阶段分派步骤代理。
4. 原型与体验阶段必须先生成 App icon，再生成主要界面设计稿，并把最终 imagegen 提示词写入设计文档。
5. iOS 项目生成阶段必须把设计阶段的 App icon 放入合适的 App icon 资源位置，或记录明确阻塞项。
6. iOS 项目生成阶段必须依据最终应用名称创建最外层 App 目录，并重命名项目文件夹、Xcode 工程、target、scheme、product name 和 App display name，清除当前克隆仓库名和模板占位命名。
7. 架构阶段必须判断是否需要后端；需要时安排后端/API/通知基础设施代理，先稳定 API 合约、邮箱验证、用户绑定、数据库、Worker、CLI 和部署边界。
8. 架构、项目生成、功能实现和支付实现阶段必须继承亮色/暗色模式与默认语言集要求。
9. 架构阶段必须规划 View 拆分、文件边界和行数预算；项目生成和功能实现阶段必须按该计划创建多个 Swift 文件，不得集中到少数大文件。
10. App Store 材料阶段必须为默认语言集准备本地化元数据、审核材料和 AI 包装截图计划。
11. QA 阶段必须启动 Simulator 运行应用，对照设计稿验证 UI，并验证主要功能一致性；依赖后端的项目还必须验证邮箱登录/验证、API、Worker、CLI、附件、APNs token 注册和提醒排程。
12. App Store 材料阶段之后，必须运行外部官网与 Cloudflare 部署代理，产出官网、隐私政策 URL 和服务条款 URL。
13. 步骤代理完成文件产物后，必须回报修改文件、验证结果、假设和未解决问题。
14. 总控代理审查所有产物，解决冲突，再继续下一阶段。

## 并行规则

可以并行的工作必须同时满足：

- 输入已经稳定。
- 写入范围不重叠。
- 后续步骤不依赖其中某个代理尚未完成的输出。

必须串行的工作包括：

- 多个代理需要修改同一文件。
- 一个代理依赖另一个代理的文档或代码产物。
- 架构、支付、发布配置等会影响全局决策的阶段。

## 代理文件

- `coordinator.md`：总控代理。
- `intake-agent.md`：输入整理。
- `product-agent.md`：产品分析。
- `scope-agent.md`：最小可行版本范围。
- `monetization-agent.md`：权限与商业化。
- `ux-agent.md`：原型与体验。
- `architecture-agent.md`：技术架构。
- `backend-agent.md`：后端/API/通知基础设施。
- `ios-project-agent.md`：iOS 项目生成。
- `feature-agent.md`：核心功能实现。
- `revenuecat-agent.md`：RevenueCat 支付。
- `qa-agent.md`：验证与质量检查。
- `app-store-agent.md`：App Store 材料。
- `web-deploy-agent.md`：外部官网与 Cloudflare 部署。
- `release-agent.md`：构建上传与审核准备。
