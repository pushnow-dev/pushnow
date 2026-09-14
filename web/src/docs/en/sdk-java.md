---
title: Java
description: Run the local Java binding with pinned JSON parsing and the bundled Node HPKE runtime.
order: 15
---

## Local setup

Requires Java 11+ and Node.js 22+. The binding uses `org.json:json:20250517`, pinned in its Maven configuration. From the repository root on macOS/Linux:

```sh
cd sdk/java
sh setup.sh
```

The setup installs runtime npm dependencies, downloads and verifies the pinned JSON jar, and compiles the Java source and examples. It does not publish a package. Maven users can build locally with `mvn package` and install `runtime/` dependencies separately.

Keep the runtime next to the deployed application; the JAR does not embed Node. No Maven Central publication is assumed.

## Authorize with an account token

Use `dev.pushnow.Client`, `java.nio.file.Path`, `org.json.JSONObject` and `org.json.JSONArray`:

```java
Client client = new Client(
    Path.of("/absolute/path/to/sdk/java/runtime/main.js"),
    "", null);
JSONObject pending = client.beginAccountAuthorization(
    "https://api.pushnow.dev", accountAccessToken, "Java automation");
System.out.println(pending.getJSONObject("authorization").getString("user_code"));
System.out.println(pending.getString("fingerprint"));
JSONObject config = client.authorizeAccount(pending);
```

Approve the sender in the signed-in trusted app. The account token only creates the account-bound authorization; it cannot encrypt messages by itself. Save `config` privately and never print the whole object.

Manual fingerprint authorization remains available with `new Client(..., trustedRootFingerprint, null)`, `beginAuthorization(...)` and `authorize(pending)` when an account token is not available.

## Prepare and retry

```java
Client client = new Client(
    Path.of("/absolute/path/to/sdk/java/runtime/main.js"),
    trustedRootFingerprint, config);
JSONObject notification = new JSONObject()
    .put("title", "Build complete")
    .put("body", "Your report is ready.")
    .put("pushEnabled", false)
    .put("files", new JSONArray().put(new JSONObject()
        .put("path", "/absolute/path/to/report.pdf")
        .put("mime", "application/pdf")));
JSONObject envelope = client.prepare(notification);
// Save envelope privately before submitting it.
JSONObject result = client.retry(envelope);
```

Omit `pushEnabled` for alerts to all eligible devices. Set `deviceIds` to an array from the verified recipient directory to select devices, or an empty array for inbox-only. `images`, `icon` and `links` add content; `scheduledAt` and `expiresAt` select the delivery window.

The finalized `sound` input accepts `default`, `silent` or `chime`. Omit it for default behavior rather than passing `JSONObject.NULL`:

```java
JSONObject notification = new JSONObject()
    .put("title", "Quiet update").put("body", "Ready to review.")
    .put("sound", "silent");
```

Sound is public routing metadata, while content and files remain encrypted. Silent still requests a visible alert; chime uses the new app's bundled asset. Arbitrary filenames and sound uploads are not accepted. iOS settings and Focus/DND apply without a critical-alert guarantee. This contract is being implemented; migration, deployment and audible-device verification are pending. See [sound rollout status](/docs/message-content/#sound-and-notification-permissions).

## Runnable examples

After setting `PUSHNOW_ACCESS_TOKEN` from a signed-in account session, run from `sdk/java`:

```sh
java -cp target/test-classes:json-20250517.jar Example authorize
java -cp target/test-classes:json-20250517.jar Example send
```

These examples use private POSIX files and fail if the filesystem cannot enforce their permissions. On Windows, use Maven for compilation, `;` in classpaths and a secret store or appropriate private ACLs instead of relying on these POSIX file examples.

`send` returns an object containing `envelope` and `result`; use prepare/save/retry for durable recovery. The example reuses its saved outbox on subsequent runs, so create a new outbox for a new notification.

## Diagnostics

`requestLogs()` returns a copy of redacted request metadata. Failures use bounded `IllegalStateException` codes without raw server response content. Use one client per thread. Interrupting a request destroys the subprocess but may leave an uncertain HTTP result; resolve it by retrying the saved envelope.
