---
title: Go
description: Integrate the local Go binding and deploy its Node encryption runtime alongside your binary.
order: 14
---

## Local setup

Requires Go 1.22+ and Node.js 22+. From the repository root:

```sh
cd sdk/go
npm --prefix runtime ci --ignore-scripts
```

The module path is `github.com/pushnow-dev/pushnow-go`. To use the published source repository from another Go project:

```sh
go get github.com/pushnow-dev/pushnow-go
```

Import it as `pushnow "github.com/pushnow-dev/pushnow-go"`. Deploy the runtime directory and npm dependencies with your application and pass an absolute path. The Go executable does not embed Node or HPKE dependencies.

## Authorize with an account token

In your integration, with `context` and the local `pushnow` package imported:

```go
client := pushnow.New("/absolute/path/to/sdk/go/runtime/main.js", "", nil)
ctx := context.Background()
pending, err := client.BeginAccountAuthorization(ctx, "https://api.pushnow.dev", accountAccessToken, "Go automation")
if err != nil { return err }
// Display only the user_code and sender fingerprint, then approve in the signed-in app.
config, err := client.AuthorizeAccount(ctx, pending)
if err != nil { return err }
```

The account token only creates the account-bound authorization. Store `config` securely because it includes the sender private key and source credential. Do not print it or the complete pending authorization.

Manual fingerprint authorization remains available with `New(..., trustedRootFingerprint, nil)`, `BeginAuthorization(...)` and `Authorize(...)` when an account token is not available.

## Send with an outbox

```go
client := pushnow.New("/absolute/path/to/sdk/go/runtime/main.js", "", config)
enabled := false
envelope, err := client.Prepare(ctx, pushnow.Notification{
    Title: "Build complete", Body: "Report attached.",
    PushEnabled: &enabled,
    Files: []pushnow.File{{Path: "/absolute/path/to/report.pdf", MIME: "application/pdf"}},
})
if err != nil { return err }
// Persist envelope privately before submission.
result, err := client.Retry(ctx, envelope)
if err != nil { return err }
_ = result // Inspect message_id and deduplicated; do not log private inputs.
```

`DeviceIDs` is a pointer to a slice: `nil` means all eligible devices, a pointer to an empty slice means inbox-only, and a populated slice selects those IDs. `PushEnabled` is a pointer to a bool and defaults to true when omitted.

`ScheduledAt` and `ExpiresAt` accept timezone-qualified ISO strings. `Images`, `Icon` and `Links` add richer content. Under the finalized contract, `Sound` points to a string containing `default`, `silent` or `chime`; leave it `nil` to preserve default behavior:

```go
sound := "silent"
notification := pushnow.Notification{
    Title: "Quiet update", Body: "Ready to review.", Sound: &sound,
}
```

Sound is public routing metadata; content and files remain encrypted. Silent retains a visible alert, while chime requests the new app's bundled asset. Arbitrary filenames and sound uploads are not accepted. iOS settings and Focus/DND apply without a critical-alert guarantee. This contract is being implemented; migration, deployment and audible-device verification are pending. See [sound rollout status](/docs/message-content/#sound-and-notification-permissions).

## Runnable examples and cancellation

Set `PUSHNOW_ACCESS_TOKEN` to a signed-in account token, then run from `sdk/go`:

```sh
go run ./examples authorize
go run ./examples send
```

The example creates private config and outbox files. A later send run retries the same message; use a new outbox for new content. On Windows, apply private file ACLs appropriate to your service account.

All methods accept a context. Cancellation terminates the bridge process, but cannot prove an in-flight request was rejected. Retry the saved outbox to resolve uncertainty. Use one client per goroutine because configuration and `RequestLogs` are mutable and not synchronized.

`RequestLogs` contains redacted local HTTP metadata. Successful API acceptance remains separate from provider acceptance and device display.
