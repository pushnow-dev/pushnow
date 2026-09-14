# PushNow Go SDK

[中文说明](README.zh-CN.md)

Go 1.22+ and **Node.js 22+** are required. This is a binding to a bundled Node
HPKE runtime, not native Go HPKE. Go code uses only the standard library.
Read [CONTRACT.md](CONTRACT.md) for the complete trust and wire contract.

## Local Setup and Tests

```sh
npm --prefix runtime ci --ignore-scripts
go test ./...
npm --prefix runtime test
```

The module path is `github.com/pushnow-dev/pushnow-go`. From another Go module,
install it with:

```sh
go get github.com/pushnow-dev/pushnow-go
```

Keep the runtime folder with your deployed program and pass its absolute main.js
path. Compiling a Go binary does not embed Node or npm dependencies.

## Authorize With an Account Token

```go
client := pushnow.New("/absolute/path/to/runtime/main.js", nil)
ctx := context.Background()
pending, err := client.BeginAccountAuthorization(ctx, "https://api.pushnow.dev", accountAccessToken, "Go automation")
if err != nil { return err }
// Show only pending["authorization"].(map[string]any)["user_code"] and pending["fingerprint"].
// Approve on the signed-in trusted phone.
config, err := client.AuthorizeAccount(ctx, pending)
if err != nil { return err }
// Store config securely. It includes the sender private key and API credential.
```

Import this package as `pushnow "github.com/pushnow-dev/pushnow-go"`. The account
access token only creates the account-bound authorization; the returned config
is still required for encryption and sending.

## Notifications

```go
client := pushnow.New("/absolute/path/to/runtime/main.js", config)
enabled := true
sound := "chime"
envelope, err := client.Prepare(ctx, pushnow.Notification{
    Title: "Build finished", Body: "Your report is ready.",
    PushEnabled: &enabled, Sound: &sound,
    Links: []string{"https://example.com/build/123"},
    Files: []pushnow.File{{Path: "/tmp/report.pdf", MIME: "application/pdf"}},
    Images: []pushnow.File{{Path: "/tmp/preview.png", MIME: "image/png"}},
    Icon: &pushnow.File{Path: "/tmp/icon.png", MIME: "image/png"},
})
if err != nil { return err }
// Persist envelope before submitting for durable retries.
result, err := client.Retry(ctx, envelope)
```

`Notification.DeviceIDs` is `*[]string`: nil means all eligible devices, a pointer
to an empty slice means inbox-only, and a pointer to a list selects specific IDs.
`PushEnabled` is `*bool`: nil defaults to true. `ScheduledAt` and `ExpiresAt` are
optional ISO strings within 30 days. `Sound` is `*string`: nil uses the default
behavior; supported values are `default`, `silent` and `chime`. Sound is public
routing metadata, not encrypted message content. Silent keeps the visible alert,
and chime maps to `pushnow-chime.wav`. Unknown values fail with `INVALID_SOUND`
before uploads. `File.DataBase64` is `*string`, allowing an explicit empty file.

`Recipients` returns a verified directory. `Send` returns an Object containing
envelope and result; `Retry` returns the submission result. The Object alias is
`map[string]any`. `RequestLogs` contains only method, route, status and elapsed
milliseconds. Errors expose redacted codes, never server response content.

All methods take a context. Cancellation kills the bridge process but does not
guarantee an in-flight HTTP request was rejected. Use the saved outbox to resolve
uncertain submission. Calls are capped at 660 seconds and individual HTTP requests
at 30 seconds. Use one client per goroutine; mutable config and logs are not synchronized.

## Runnable Example

```sh
export PUSHNOW_ACCESS_TOKEN='your signed-in account access token'
go run ./examples authorize
go run ./examples send
```

The example writes config and outbox with mode 0600 and prints only approval
information or API result identifiers. Re-running send retries the same outbox.
Use a new outbox for a new notification. Windows deployments must apply private
file ACLs appropriate for their service account.
