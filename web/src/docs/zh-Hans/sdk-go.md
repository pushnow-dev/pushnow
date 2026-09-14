---
title: Go
description: 接入本地 Go 绑定，并随应用部署 Node 加密 runtime。
order: 14
---

## 本地准备

需要 Go 1.22+ 和 Node.js 22+。从仓库根目录执行：

```sh
cd sdk/go
npm --prefix runtime ci --ignore-scripts
```

模块路径 `example.com/pushnow-local` 是本地占位符，不是已发布模块。在其他 Go 项目中使用时添加本地替换：

```sh
go mod edit -require=example.com/pushnow-local@v0.0.0
go mod edit -replace=example.com/pushnow-local=/absolute/path/to/sdk/go
```

导入时使用 `pushnow "example.com/pushnow-local"`。部署时把 runtime 目录和 npm 依赖一起带上，并传入绝对路径。Go 可执行文件不会内置 Node 或 HPKE 依赖。

## 授权

在你的集成代码中：

```go
client := pushnow.New("/absolute/path/to/sdk/go/runtime/main.js", trustedRootFingerprint, nil)
ctx := context.Background()
pending, err := client.BeginAuthorization(ctx, "https://api.pushnow.dev", "Go automation")
if err != nil { return err }
// 只展示 user_code 和 sender fingerprint，然后在手机上批准。
config, err := client.Authorize(ctx, pending)
if err != nil { return err }
```

`trustedRootFingerprint` 必须从可信设备独立获取。`config` 包含私钥和 API 凭证，必须安全保存。不要完整打印 pending 或 config。

## 使用 outbox 发送

```go
client := pushnow.New("/absolute/path/to/sdk/go/runtime/main.js", trustedRootFingerprint, config)
enabled := false
envelope, err := client.Prepare(ctx, pushnow.Notification{
    Title: "Build complete", Body: "Report attached.",
    PushEnabled: &enabled,
    Files: []pushnow.File{{Path: "/absolute/path/to/report.pdf", MIME: "application/pdf"}},
})
if err != nil { return err }
// 提交前先把 envelope 私密保存。
result, err := client.Retry(ctx, envelope)
if err != nil { return err }
_ = result
```

`DeviceIDs` 是指向字符串切片的指针：`nil` 表示所有可接收设备，指向空切片表示只保存到收件箱，指向非空切片表示指定设备。`PushEnabled` 是 `*bool`，省略时默认 true。

`ScheduledAt` 和 `ExpiresAt` 接受带时区的 ISO 字符串。`Images`、`Icon` 和 `Links` 可添加丰富内容。`Sound` 是指向字符串的指针，支持 `default`、`silent`、`chime`；`nil` 表示保持默认行为：

```go
sound := "silent"
notification := pushnow.Notification{
    Title: "Quiet update", Body: "Ready to review.", Sound: &sound,
}
```

声音是公开路由元数据；正文和文件仍然加密。`silent` 仍保留可见通知，`chime` 请求 App 内置声音。不支持任意声音文件名或上传音频。

## 示例和取消

设置可信 fingerprint 后，在 `sdk/go` 目录运行：

```sh
go run ./examples authorize
go run ./examples send
```

示例会用 0600 权限写入私有配置和 outbox，并只打印授权码或 API 结果标识。重复运行 send 会重试同一个 outbox；新消息应创建新的 outbox。

所有方法都接收 `context.Context`。取消 context 会终止 bridge 进程，但不能证明服务端没有收到正在进行的 HTTP 请求。请求不确定时，使用保存的 outbox 重试。建议每个 goroutine 使用独立 client；可变 config 和 request logs 不做并发同步。
