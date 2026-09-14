# iOS MVVM 模板

本目录是生成 iOS 18.0 及以上 SwiftUI 应用时的默认 MVVM 模板。项目生成代理应把 `TemplateApp` 替换为最终应用名称，并按最终 bundle ID、签名团队和产品范围生成真实 Xcode 项目。

## 目录职责

- `App/`：应用入口、根视图、依赖图和基础配置。
- `Config/`：Xcode 构建配置，默认 iOS 18.0 和自动签名。
- `Models/`：业务模型、权益状态和错误模型。
- `Views/`：SwiftUI 页面和可复用视图组件。
- `ViewModels/`：页面状态、用户动作和异步流程。
- `Services/`：系统服务、支付服务和外部能力适配。
- `Repositories/`：数据仓库协议和默认实现。
- `Navigation/`：Tab、路由、sheet 和导航状态。
- `Resources/`：资源目录、预览资源和本地化资源入口。
- `Support/`：跨模块通用类型和常量。
- `Tests/`：模型、仓库和 ViewModel 测试模板。

## 默认约束

- 最低系统版本：iOS 18.0。
- UI 技术：SwiftUI。
- 状态模型：Observation API，优先使用 `@Observable`、`@State` 和类型化 `@Environment`。
- 架构：MVVM，View 不直接执行网络、支付或持久化逻辑。
- 签名：默认使用当前机器 Xcode 已登录账户和可用签名团队的自动签名。
- 支付：付费应用必须通过 RevenueCat，权益检查集中在 `EntitlementState` 和 `RevenueCatService`。

## 生成要求

项目生成代理使用本模板时必须：

1. 生成真实 iOS 应用目标，而不是只复制 Swift 文件。
2. 把最低系统版本设置为 iOS 18.0。
3. 把签名设置为 Xcode 自动签名，并使用当前可用团队。
4. 根据产品范围保留、改名或扩展 feature 目录。
5. 为付费应用接入真实 RevenueCat SDK，并替换模板中的支付适配实现。
6. 构建失败时记录命令、错误摘要和签名阻塞项。
