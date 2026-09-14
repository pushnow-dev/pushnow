# 第 6A 步：后端/API/通知基础设施计划

> 版本：v0.1
> 日期：2026-09-12
> 上游输入：`docs/engineering/06-technical-architecture.md`
> 目标：把即知的服务端能力落为可执行工作项，供后端代理、iOS 项目代理、功能实现代理、QA 和发布代理使用。

## 1. 写入范围

后端代理可以创建或修改：

- `backend/`
- `cli/`
- `docs/engineering/06A-backend-api-infrastructure.md`
- `docs/engineering/api/openapi.yaml`
- `docs/engineering/api/examples/`
- `docs/release/backend-deployment.md`

不得修改：

- iOS App 源码，除非总控代理明确授权生成 API client。
- RevenueCat iOS 支付源码。
- App Store Connect 发布配置。
- 官网 `web/`，除非只补充 API 域名引用。

## 2. 后端首版交付

首版后端必须至少交付：

- `GET /healthz` 和 `GET /readyz`。
- 邮箱登录/注册接口：`POST /v1/auth/email/start`、`POST /v1/auth/email/verify`、`POST /v1/auth/password/login`、`POST /v1/me/password`、`POST /v1/auth/refresh`、`POST /v1/auth/logout`、`GET /v1/me`。
- 邮箱验证 challenge、密码登录、session、用户创建和用户绑定逻辑；验证码和密码都只保存 hash。
- Cloudflare Email Service 发送验证邮件的生产 adapter，以及本地测试 no-op adapter；生产未配置时必须列为阻塞项。
- 验证邮件模板、账号安全邮件模板和未来邮件通知模板的最小模板目录。
- Source、source key、item ingest、item list、item detail、reminder plan 的 API。
- 所有 source、source key、device、item、category、reminder、subscription、attachment、delivery 和 entitlement 必须直接或间接绑定 `user_id`。
- `Idempotency-Key` 去重。
- Cloudflare D1 schema 和迁移。
- R2 signed upload/download 的接口骨架。
- APNs device token 注册接口。
- Cron due-scan：扫描到期提醒并写入 Queue；Queue consumer 写入 delivery 记录并调用 notification adapter。
- APNs adapter 的沙盒/开发实现；无真实 key 时必须提供 no-op adapter 并记录阻塞项。
- RevenueCat webhook 骨架、webhook secret 校验、`GET /v1/me/plan` 和服务端每日额度检查。
- OpenAPI 文档和请求示例。
- CLI 的 `send` 最小命令，可向本地或远程 API 发送事项。

## 3. 推荐目录

```text
backend/
  package.json
  pnpm-workspace.yaml
  apps/
    api-worker/
      src/server.ts
      src/routes/
      src/plugins/
      src/config/
    queue-worker/
      src/index.ts
      src/jobs/
      src/config/
  packages/
    auth/
      src/challenges.ts
      src/sessions.ts
      src/rate-limit.ts
    contracts/
      src/schemas/
      src/openapi.ts
    database/
      src/schema/
      src/migrations/
      src/client.ts
    email/
      src/templates/
      src/cloudflare-email.ts
      src/noop-email.ts
    notifications/
      src/apns/
    storage/
      src/r2.ts
    shared/
      src/errors.ts
      src/time.ts
cli/
  package.json
  src/index.ts
```

## 4. 验证要求

后端代理必须执行并报告：

- 类型检查。
- 单元测试或 API route smoke test。
- D1 迁移 dry run、本地迁移或 preview 环境迁移。
- `GET /healthz` 返回成功。
- `POST /v1/auth/email/start` 对新邮箱和已有邮箱都返回中性状态，不泄露账号是否存在。
- 验证邮件发送记录写入 `email_deliveries`；本地 no-op 必须标记为 no-op，生产不得当作成功邮件发送。
- `POST /v1/auth/email/verify` 使用有效验证码能创建或登录用户，返回 session，并把 `email_verified_at` 写入用户记录。
- 首次邮箱验证后，`POST /v1/me/password` 能设置密码；后续 `POST /v1/auth/password/login` 能用邮箱和密码登录。
- 过期、错误、重复使用或超过尝试次数的验证码必须失败，并返回结构化错误。
- refresh token 只保存 hash；`POST /v1/auth/refresh` 能轮换 session，`POST /v1/auth/logout` 能撤销 session。
- 未验证邮箱或未登录请求不得创建来源密钥、绑定 APNs token、订阅频道、上传附件或读取用户事项。
- 本地 `POST /v1/ingest/items` 能写入 item。
- Free 用户每日第 51 次新事项必须返回额度错误；Plus 为每日 500 次；Pro 不设每日次数上限。
- 重复 `Idempotency-Key` 不生成重复 item。
- 创建 reminder 后，Cron due-scan 能入队，Queue consumer 能生成 delivery 记录。
- 无 APNs key 时明确显示 no-op delivery，而不是假装推送成功。
- CLI `send` 能调用本地 API。

## 5. 与其他阶段的交付关系

| 阶段 | 依赖方式 |
| --- | --- |
| 第 6 步 技术架构 | 定义总体边界和 API 分组 |
| 第 6A 步 后端/API | 产出 backend、cli、OpenAPI、Cloudflare 部署文档 |
| 第 7 步 iOS 项目生成 | 读取 API base URL、OpenAPI、邮箱认证策略和本地 mock 数据边界 |
| 第 8 步 核心功能 | 对接真实 API；未部署时对接本地 backend |
| 第 9 步 RevenueCat | iOS SDK + 后端 webhook + 服务端权益检查 |
| 第 10 步 QA | 增加邮箱登录/验证、API、worker、CLI、推送注册和提醒扫描验证 |
| 第 12 步 官网部署 | 引用生产 API 域名、法律页面和下载策略 |
| 第 13 步 发布 | 检查 api-worker、queue-worker、D1、Queues、R2、Email Service、APNs 和 RevenueCat webhook 生产状态 |

## 6. 发布阻塞项

以下任一项未完成时，不得声称后端生产就绪：

- Cloudflare Workers Paid 未开通，或 Cloudflare/Wrangler 当前账号不可用于生产部署。
- Cloudflare API Worker、Queue consumer 或 Cron Triggers 未部署成功。
- Cloudflare Email Service 未启用，或发送域名、发件地址、SPF/DKIM/DMARC、验证邮件模板未配置。
- D1 迁移未在目标环境执行并验证。
- Queues 未配置或 consumer 无法消费队列。
- R2 bucket、权限或签名 URL 未验证。
- APNs key、bundle ID 或环境未配置。
- RevenueCat webhook secret 未配置或验签失败。
- `api.pushnow.dev` 未解析到生产 API。
- 邮箱验证码未 hash 保存、缺少过期/尝试次数限制，或登录接口会泄露邮箱是否已注册。
- 用户资源未统一绑定 `user_id`，source key 无法追溯唯一用户。
- Agent ingest API 没有幂等保护。
- 提醒到期没有 delivery 记录或无法区分 no-op、失败和成功。
- 未配置 Workers Logs、dashboard metrics 或等价监控，无法证明生产及时响应状态。
