---
title: Java
description: 使用本地 Java 绑定和内置 Node HPKE runtime 授权并发送加密通知。
order: 15
---

## 不使用 Maven 的准备方式

需要 Java 11+ 和 Node.js 22+。在 macOS/Linux 中从 `sdk/java` 目录执行：

```sh
sh setup.sh
sh test.sh
```

`setup.sh` 会安装锁定版本的 npm 依赖，下载固定版本的 JSON jar，校验 SHA-256，并以 Java 11 兼容模式编译源码、测试和示例。它不会发布包。

Maven 用户也可以运行 `mvn package`。无论哪种方式，部署应用时都需要把 `runtime/` 放在应用旁边，并单独安装它的 npm 依赖。JAR 不会内置 Node 或 runtime。Windows 上可使用 Maven 编译，并把示例/测试命令中的 classpath 分隔符从 `:` 改成 `;`。

## 使用账号 Token 授权

```java
Client client = new Client(Path.of("/absolute/path/to/runtime/main.js"), null);
JSONObject pending = client.beginAccountAuthorization(
    "https://api.pushnow.dev", accountAccessToken, "Java automation");
System.out.println(pending.getJSONObject("authorization").getString("user_code"));
System.out.println(pending.getString("fingerprint"));
JSONObject config = client.authorizeAccount(pending); // 等待可信手机批准。
```

需要导入 `dev.pushnow.Client`、`java.nio.file.Path`、`org.json.JSONObject` 和 `org.json.JSONArray`。账号 token 只用于创建账号绑定授权，不能单独加密消息。不要完整打印 pending 或 config，它们包含私密凭证。

## 发送通知

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
// 提交前先安全保存 envelope。
JSONObject result = client.retry(envelope);
```

省略 `deviceIds` 会通知所有可接收设备。使用 `client.recipients().getJSONArray("devices")` 中的设备 ID 数组可以指定目标设备。`pushEnabled=false` 或空 `deviceIds` 数组表示只保存到收件箱。

`scheduledAt` 和 `expiresAt` 是带时区的 30 天内未来 ISO 时间。`sound` 支持 `default`、`silent`、`chime`，并作为公开路由元数据发送。省略它保持默认行为。`silent` 保留可见通知但不带 `aps.sound`；`chime` 映射到 App 的 `pushnow-chime.wav`。`JSONObject.NULL` 和未知值会在上传前以 `INVALID_SOUND` 失败。声音不会进入加密正文。

`send` 返回包含 envelope 和 result 的 `JSONObject`。可靠发送场景使用 prepare/persist/retry。`requestLogs()` 返回脱敏本地请求元数据。失败使用带受控错误码的 `IllegalStateException`，不暴露服务端响应体。自定义构造器可以指定 Node 可执行文件和总 deadline，默认 660 秒；单个 HTTP 请求超时 30 秒。线程中断会销毁子进程，但不确定提交仍然需要通过已保存 envelope 重试。建议每个线程使用独立 client。

## 示例命令

```sh
export PUSHNOW_ACCESS_TOKEN='your signed-in account access token'
java -cp target/test-classes:json-20250517.jar Example authorize
java -cp target/test-classes:json-20250517.jar Example send
```

示例使用 POSIX 0600 文件权限。若文件系统不支持私有权限，它会失败而不是静默写入不安全凭证。Windows 应用应使用 secret store 或明确配置的私有 ACL。重复运行 send 会重试同一个 outbox；新通知应使用新的 outbox。
