# PushNow

[中文说明](README.zh-CN.md)

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
- Account-token sender authorization with signed-in App approval.
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
| `pushnow-js` | TypeScript SDK for Node.js and browsers | npm package `pushnow-sdk` |
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

## Quick Start

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

Each SDK requires an approved sender config and access to the PushNow API.
Account tokens can start account-bound authorization, but a bearer token alone
is not enough to encrypt messages.

## SEO Keywords

Encrypted push notifications, E2EE notification SDK, AI agent notifications,
private automation alerts, secure mobile inbox, HPKE notification API, iOS
notification automation, HarmonyOS push SDK, encrypted attachment notification,
scheduled encrypted notifications.

## License

No open-source license has been granted yet. Contact the project owner before
copying, modifying or redistributing this repository.
