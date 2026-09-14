# PushNow

[English](README.md)

PushNow 是一个面向 AI Agent、自动化脚本、服务端任务和个人工作流的端到端加密通知平台。它可以把构建结果、监控告警、客户运营事件、定时提醒和富文本消息安全发送到用户信任的 iPhone 与 HarmonyOS 设备，同时避免服务端看到明文标题、正文、附件名称或私钥。

PushNow 适合需要私密通知收件箱、设备选择、定时发送、加密附件和可审计发送方授权的开发者与团队。

## 核心能力

- 账号绑定的 E2EE 通知，基于 HPKE Auth 与签名账号归档。
- 通过账号 token 发起 SDK 发送方授权，并在已登录 App 中审批；CLI/离线场景仍支持手动指纹校验。
- 支持标题、正文、链接、图片、图标和文件附件。
- 支持全部设备、指定设备、仅收件箱、定时发送和过期时间。
- 支持可重试的加密 outbox，适合构建系统、监控任务和后台队列。
- 提供 iOS、HarmonyOS、Web Dashboard、CLI、后端 API 和多语言 SDK。

## 仓库组织

`pushnow-dev` GitHub organization 按用户安装习惯拆分仓库：

| 仓库 | 用途 | 安装入口 |
| --- | --- | --- |
| `pushnow` | 主产品、iOS/Harmony/Web/Backend 源码和发布文档 | 产品和平台主库 |
| `pushnow-js` | Node.js 与浏览器 TypeScript SDK | npm 包 `pushnow-sdk` |
| `pushnow-python` | Python SDK，内置 Node HPKE runtime | PyPI 包 `pushnow` |
| `pushnow-go` | Go SDK，内置 Node HPKE runtime | Go module `github.com/pushnow-dev/pushnow-go` |
| `pushnow-java` | Java SDK，内置 Node HPKE runtime | Maven 坐标 `dev.pushnow:pushnow-sdk` |

## 快速安装

TypeScript:

```sh
npm install pushnow-sdk
```

Python:

```sh
pip install pushnow
```

Go:

```sh
go get github.com/pushnow-dev/pushnow-go
```

Java:

```xml
<dependency>
  <groupId>dev.pushnow</groupId>
  <artifactId>pushnow-sdk</artifactId>
  <version>0.1.0</version>
</dependency>
```

每个 SDK 都需要已经审批过的 sender config 和 PushNow API 访问权限。账号 token 可以发起账号绑定授权，但只有 bearer token 无法完成端到端加密。

## 发布状态

SDK 已经具备源码仓库和本地测试覆盖。正式发布到 npm、PyPI、Maven Central 时，还需要对应平台账号、组织或命名空间权限、发布 token、签名配置或 Trusted Publishing 配置。
