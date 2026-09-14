# PushNow

PushNow is an account-bound, end-to-end encrypted notification platform for
teams, agents, scripts and personal automations. It lets a CLI, backend service,
browser dashboard or SDK sender deliver rich notifications to a user's trusted
iPhone and HarmonyOS devices without exposing message content, attachment names
or private sender keys to the transport service.

PushNow is designed for AI agents, build systems, monitoring jobs, customer
operations and personal workflows that need a private notification inbox, device
targeting, scheduled delivery, encrypted attachments and auditable sender
authorization.

## What It Does

- End-to-end encrypted notification content using HPKE Auth and signed account
  archives.
- Account-bound sender authorization with short user codes and fingerprint
  verification.
- Rich messages with title, body, links, image, icon and file attachments.
- Device directory checks, selected-device delivery and inbox-only messages.
- Scheduling, expiry, custom sound routing and durable retry envelopes.
- iOS app, HarmonyOS client, TypeScript CLI, backend API and multi-language SDKs.
- Web dashboard and documentation site for account management, API testing and
  developer onboarding.

## Repositories

The `pushnow-dev` GitHub organization is organized around how developers install
and integrate PushNow:

| Repository | Purpose | Install path |
| --- | --- | --- |
| `pushnow` | Main product, iOS/Harmony/web/backend source and release docs | Product and platform home |
| `pushnow-js` | TypeScript SDK for Node.js and browsers | npm package `@pushnow/sdk` |
| `pushnow-python` | Python binding with bundled Node HPKE runtime | PyPI package `pushnow` |
| `pushnow-go` | Go binding with bundled Node HPKE runtime | Go module `github.com/pushnow-dev/pushnow-go` |
| `pushnow-java` | Java binding with bundled Node HPKE runtime | Maven artifact `dev.pushnow:pushnow-sdk` |

## SDK Status

The SDKs are source-ready and include real local test coverage:

- TypeScript: build, backend Worker fixture, browser import, crypto interop,
  authorization, attachments, scheduling, sound routing and redacted errors.
- Python: `unittest` language checks plus runtime tests against CLI-generated
  HPKE vectors and real local HTTP E2EE requests.
- Go: `go test ./...` plus runtime tests for vectors, config validation and
  local HTTP E2EE requests.
- Java: POSIX setup/test script, pinned JSON dependency checksum, Java 11
  compilation and runtime bridge tests.

These tests prove local SDK behavior and wire compatibility. They do not prove
production APNs delivery, App Store release state or third-party package-registry
ownership.

## English Quick Start

TypeScript:

```sh
npm install @pushnow/sdk
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

Each SDK requires an approved sender config, an independently trusted account
root fingerprint and access to the PushNow API. A bearer token alone is not
enough to encrypt messages.

## 中文说明

PushNow 是一个面向 AI Agent、自动化脚本、服务端任务和个人工作流的端到端加密通知平台。它可以把构建结果、监控告警、客户运营事件、定时提醒和富文本消息安全发送到用户信任的 iPhone 与 HarmonyOS 设备，同时避免服务端看到明文标题、正文、附件名称或私钥。

核心能力包括：

- 账号绑定的 E2EE 通知，基于 HPKE Auth 与签名账号归档。
- 通过手机 App 审批 SDK 发送方，支持用户码和指纹校验。
- 支持标题、正文、链接、图片、图标和文件附件。
- 支持全部设备、指定设备、仅收件箱、定时发送和过期时间。
- 支持可重试的加密 outbox，适合构建系统、监控任务和后台队列。
- 提供 iOS、HarmonyOS、Web Dashboard、CLI、后端 API 和多语言 SDK。

SDK 仓库按用户安装习惯拆分：JavaScript 放 npm 生态，Python 放 PyPI
生态，Go 使用 Go module，Java 使用 Maven 坐标。正式发布到各包管理器前，还需要对应 registry 的账号权限、签名/命名空间配置和最终发布 token。

## SEO Keywords

Encrypted push notifications, E2EE notification SDK, AI agent notifications,
private automation alerts, secure mobile inbox, HPKE notification API, iOS
notification automation, HarmonyOS push SDK, encrypted attachment notification,
scheduled encrypted notifications.

## License

No open-source license has been granted yet. Contact the project owner before
copying, modifying or redistributing this repository.
