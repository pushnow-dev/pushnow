---
title: 邮箱登录
description: 先用验证码登录，邮箱验证后可使用邮箱和密码登录。
order: 2
tryMethod: POST
tryPath: /v1/auth/email/start
tryBody: {"email":"name@example.com","locale":"zh-Hans","timezone":"Asia/Shanghai","client":{"platform":"cli"}}
---

# 邮箱登录

Pushnow 即知的网页登录支持两种模式：邮箱验证码登录，以及邮箱密码登录。网页控制台会自动附带浏览器安全验证 token；如果直接从浏览器源站调用登录接口，需要带上有效的 Turnstile token。

## 验证码登录

1. 输入邮箱地址。
2. 点击发送验证码。
3. 打开邮箱查看验证码。
4. 输入验证码完成登录。

这是首次登录路径，也可以作为忘记密码时的备用方式。

## 密码登录

邮箱完成验证，并在 App 内设置密码之后，用户可以在网页控制台切换到密码登录。

不要把 access token 或密码放进 URL。Pushnow 即知只会通过 HTTPS 请求体发送凭据。

## 示例

```bash
curl -X POST https://api.pushnow.dev/v1/auth/email/start \
  -H "content-type: application/json" \
  -d '{"email":"name@example.com","locale":"zh-Hans","timezone":"Asia/Shanghai","client":{"platform":"cli"}}'
```
