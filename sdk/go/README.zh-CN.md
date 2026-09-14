# PushNow Go SDK

[English](README.md)

Go 1.22+ 和 Node.js 22+ 是必需运行环境。这是绑定到 Node HPKE runtime 的 Go SDK，不是原生 Go HPKE 实现。Go 代码只使用标准库。

## 安装

```sh
go get github.com/pushnow-dev/pushnow-go
```

部署时需要把 `runtime/` 目录和 npm 依赖一起带上，并传入 `runtime/main.js` 的绝对路径。Go 可执行文件不会内置 Node 或 HPKE npm 依赖。

## 本地测试

```sh
npm --prefix runtime ci --ignore-scripts
go test ./...
npm --prefix runtime test
```

## 授权

```go
client := pushnow.New("/absolute/path/to/runtime/main.js", trustedRootFingerprint, nil)
pending, err := client.BeginAuthorization(ctx, "https://api.pushnow.dev", "Go automation")
config, err := client.Authorize(ctx, pending)
```

只展示 `user_code` 和 sender 指纹。账号根指纹必须从可信设备获得，不能从 grant 或 source token 自动信任。

## 发送通知

```go
client := pushnow.New("/absolute/path/to/runtime/main.js", trustedRootFingerprint, config)
sound := "chime"
result, err := client.Send(ctx, pushnow.Notification{
    Title: "Build finished",
    Body: "Your report is ready.",
    Sound: &sound,
})
```

SDK 会本地加密消息和附件。服务器不会看到明文标题、正文、文件名或附件密钥。测试不证明生产 APNs 设备可见送达。
