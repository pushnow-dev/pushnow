# PushNow Java SDK

[English](README.md)

Java 11+ 和 Node.js 22+ 是必需运行环境。这是绑定到 Node HPKE runtime 的 Java SDK，不是原生 Java HPKE 实现。JSON 解析使用 `org.json:json:20250517`。

## Maven 坐标

发布到 Maven Central 后：

```xml
<dependency>
  <groupId>dev.pushnow</groupId>
  <artifactId>pushnow-sdk</artifactId>
  <version>0.1.0</version>
</dependency>
```

部署时需要把 `runtime/` 目录和 npm 依赖一起带上。JAR 不会内置 Node 或 runtime。

## 不使用 Maven 的本地测试

```sh
sh setup.sh
sh test.sh
```

`setup.sh` 会安装锁定的 npm 依赖、下载固定版本 JSON jar、校验 SHA-256，并以 Java 11 兼容模式编译源码、测试和示例。

## 使用账号 Token 授权

```java
Client client = new Client(Path.of("/absolute/path/to/runtime/main.js"), null);
JSONObject pending = client.beginAccountAuthorization(
    "https://api.pushnow.dev", accountAccessToken, "Java automation");
JSONObject config = client.authorizeAccount(pending);
```

只展示 `user_code` 和 sender 指纹，并在已登录的可信 App 中批准。账号 access token 只用于创建账号绑定授权，不能单独加密消息。不要打印完整 pending/config。

## 发送通知

```java
Client client = new Client(Path.of("/absolute/path/to/runtime/main.js"), config);
JSONObject result = client.send(new JSONObject()
    .put("title", "Build finished")
    .put("body", "Your report is ready.")
    .put("sound", "chime"));
```

SDK 会本地加密消息和附件。服务器不会看到明文标题、正文、文件名或附件密钥。测试不证明生产 APNs 设备可见送达。
