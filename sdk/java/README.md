# PushNow Java SDK

[中文说明](README.zh-CN.md)

Java 11+ and **Node.js 22+** are required. This is a Java binding to a bundled
Node HPKE runtime, not a native Java HPKE implementation. JSON parsing uses
`org.json:json:20250517`, pinned in pom.xml. See [CONTRACT.md](CONTRACT.md) for
the full trust model, API fields, limits, errors and scheduling semantics.

## Setup Without Maven

From this folder on macOS/Linux (curl, shasum, javac and java required):

```sh
sh setup.sh
sh test.sh
```

setup.sh installs exact npm dependencies, downloads the pinned JSON jar, checks
its SHA-256 and compiles source, tests and examples with Java 11 compatibility.
It does not publish. Maven users can also run `mvn package`; retain runtime/
beside the resulting application and install its npm dependencies separately.
The JAR does not embed Node or the runtime. On Windows use Maven for compilation
and change classpath separators from `:` to `;` in the example/test commands.

## Authorize With an Account Token

```java
Client client = new Client(Path.of("/absolute/path/to/runtime/main.js"), null);
JSONObject pending = client.beginAccountAuthorization(
    "https://api.pushnow.dev", accountAccessToken, "Java automation");
System.out.println(pending.getJSONObject("authorization").getString("user_code"));
System.out.println(pending.getString("fingerprint"));
JSONObject config = client.authorizeAccount(pending); // Waits for trusted phone approval.
```

Imports are `dev.pushnow.Client`, `java.nio.file.Path`, `org.json.JSONObject`
and `org.json.JSONArray`. Use an account access token from a signed-in app or
trusted dashboard session. The token only creates the account-bound
authorization; it cannot encrypt or send messages by itself. Never print the
whole pending/config objects; they contain private credentials.

## Notifications

```java
Client client = new Client(Path.of("/absolute/path/to/runtime/main.js"), config);
JSONObject notification = new JSONObject()
    .put("title", "Build finished").put("body", "Your report is ready.").put("sound", "chime")
    .put("links", new JSONArray().put("https://example.com/build/123"))
    .put("files", new JSONArray().put(new JSONObject()
        .put("path", "/tmp/report.pdf").put("mime", "application/pdf")))
    .put("images", new JSONArray().put(new JSONObject()
        .put("path", "/tmp/preview.png").put("mime", "image/png")))
    .put("icon", new JSONObject().put("path", "/tmp/icon.png").put("mime", "image/png"));
JSONObject envelope = client.prepare(notification);
// Persist envelope securely before submitting.
JSONObject result = client.retry(envelope);
```

Omit deviceIds to notify all eligible devices. Use a JSONArray of IDs from
`client.recipients().getJSONArray("devices")` to target selected devices.
`pushEnabled=false` or an empty deviceIds array saves inbox-only.
scheduledAt/expiresAt are timezone-qualified future ISO strings within 30 days.
Sound accepts `default`, `silent` or `chime` as public routing metadata. Omit it
to use the default behavior. Silent keeps the visible alert without aps.sound;
chime maps to the app's `pushnow-chime.wav`. JSONObject.NULL and unknown values
fail with `INVALID_SOUND` before uploads. Sound never enters the encrypted body.

`send` returns a JSONObject with envelope and result. Use prepare/persist/retry
for durable recovery. `requestLogs()` returns a copy of redacted local request
metadata. Failures use IllegalStateException with a bounded error code and no
server body. A custom constructor accepts the Node executable and Duration
deadline (default 660 seconds); HTTP requests individually time out at 30 seconds.
Thread interruption destroys the subprocess, but an uncertain submission must
still be resolved by retrying the saved envelope. Use one client per thread.

## Runnable Example

```sh
export PUSHNOW_ACCESS_TOKEN='your signed-in account access token'
java -cp target/test-classes:json-20250517.jar Example authorize
java -cp target/test-classes:json-20250517.jar Example send
```

The example uses POSIX mode-0600 files and fails rather than silently writing
unprotected credentials on a filesystem without POSIX permissions. Windows
applications should use a secret store or explicitly configured private ACLs.
Re-running send retries the same outbox; use a new outbox for a new message.
