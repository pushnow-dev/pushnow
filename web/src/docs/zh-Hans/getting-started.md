---
title: 快速开始
description: 几分钟内把 Pushnow 接入 Agent、脚本和 Webhook。
order: 1
tryMethod: GET
tryPath: /healthz
tryBody: 
---

# 快速开始

Pushnow 即知是一个绑定用户的 iOS 通知收件箱。Agent、脚本、监控或自动化流程可以把事件保存进来，并按需推送到手机。

## 基础流程

1. 在 iOS App 或网页控制台输入邮箱登录。
2. 完成邮箱验证码验证。
3. 为 Agent、CLI、Webhook 或订阅创建一个来源。
4. 生成来源密钥，并像密码一样保存。
5. 发送事项时设置优先级和是否 App 推送。

## 优先级模型

- `P0` 用于需要立刻打断你的紧急事件。
- `P1` 用于重要但不一定立刻打断的事件。
- `normal` 用于常规更新。
- `silent` 会把事项保存在 App 内，不发送推送。

## 测试 API

健康检查接口不需要登录，适合直接在这个页面里测试。
