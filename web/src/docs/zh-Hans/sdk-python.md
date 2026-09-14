---
title: Python
description: 使用本地 Python 绑定和内置 Node HPKE runtime 发送加密通知。
order: 13
---

## 本地准备

需要 Python 3.10+ 和 Node.js 22+。从仓库根目录执行：

```sh
cd sdk/python
npm --prefix runtime ci --ignore-scripts
```

保持 `pushnow.py` 和 `runtime/` 在一起，或者把 `sdk/python` 加入 Python path。不要假设它已经发布到 pip。可选的 `pip install .` 只安装 Python module；仍然需要保留 runtime，并在需要时传入它的绝对 `main.js` 路径。

## 使用账号 Token 授权

使用已登录 PushNow App 或可信 Dashboard 会话里的账号 access token：

```python
import os
from pushnow import Client

client = Client()
pending = client.begin_account_authorization(
    'https://api.pushnow.dev',
    os.environ['PUSHNOW_ACCESS_TOKEN'],
    'Python automation',
)
print(pending['authorization']['user_code'])
print(pending['fingerprint'])
config = client.authorize_account(pending)
```

在已登录的可信 App 中批准 sender。不要完整打印 `pending` 或 `config`：它们包含私钥和 API 凭证。`examples/authorize.py` 会写入新的私有配置文件，并避免覆盖已有配置。

## Prepare、保存和发送

拿到 `config` 后：

```python
client = Client(config=config,
                runtime='/absolute/path/to/sdk/python/runtime/main.js')
envelope = client.prepare(
    title='Build complete', body='The report is attached.',
    pushEnabled=False,
    links=['https://example.com/reports/latest'],
    files=[{'path': '/absolute/path/to/report.pdf', 'mime': 'application/pdf'}],
)
# 需要可靠重试时，先把 envelope 安全保存到私有位置。
result = client.retry(envelope)
print(result['message_id'], result['deduplicated'])
```

省略 `pushEnabled` 默认通知所有可接收设备。使用 `deviceIds=[id]` 可以发送到 `client.recipients()['devices']` 中的指定设备。使用 `images=[{'path':..., 'mime':'image/png'}]` 或 `icon={'path':..., 'mime':'image/png'}` 添加图片内容。`scheduledAt` 和 `expiresAt` 接受 30 天内的 ISO 时间。

Python 输入参数使用 camelCase；HTTP envelope 字段是 snake_case。`sound` 支持 `'default'`、`'silent'`、`'chime'`，省略表示默认行为，不要传 `None`：

```python
envelope = client.prepare(title='Quiet update', body='Ready to review.', sound='silent')
```

声音是公开路由元数据，不是加密正文。`silent` 仍保留可见通知；`chime` 使用 App 内置声音。不支持任意音频文件名或上传音频。

## 仓库示例

在 `sdk/python` 目录下，设置 `PUSHNOW_ACCESS_TOKEN` 后运行：

```sh
python3 examples/authorize.py
python3 examples/send.py
```

发送示例会保存一个加密 outbox，并在后续运行中重试同一个 outbox。每条新消息应使用新的 outbox。配置文件和 outbox 都必须避免被其他用户读取，也不要提交到源码仓库。

`client.send(...)` 是快捷方法，返回 `{'envelope': ..., 'result': ...}`。如果请求结果不确定但之前没有保存 outbox，它无法恢复；可靠场景优先使用 prepare/save/retry。

## 诊断

使用 `client.request_logs` 查看脱敏的 method/path/status/timing 元数据。捕获 `PushNowError` 获取受控错误码。默认子进程总超时是 660 秒；单个 HTTP 请求有更短超时。`node=`、`runtime=` 和 `timeout=` 可配置本地 runtime。超时不证明消息发送失败，应重试已保存的 envelope。
