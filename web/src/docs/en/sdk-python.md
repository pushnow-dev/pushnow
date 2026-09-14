---
title: Python
description: Use the local Python binding with its bundled Node HPKE runtime.
order: 13
---

## Local setup

Requires Python 3.10+ and Node.js 22+. From the repository root:

```sh
cd sdk/python
npm --prefix runtime ci --ignore-scripts
```

Keep `pushnow.py` next to `runtime/`, or add `sdk/python` to your Python path. No published pip package is assumed. An optional local `pip install .` installs the module only; retain the runtime separately and pass its absolute `main.js` path.

## Authorize with an account token

Use an account access token from a signed-in PushNow app or trusted dashboard session:

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

Approve the sender in the signed-in trusted app. Never print `pending` or `config` in full: they contain private credentials. The supplied `examples/authorize.py` writes a new private configuration file without overwriting an existing file.

Manual fingerprint authorization remains available with `Client(trustedRootFingerprint)`, `begin_authorization(...)` and `authorize(pending)` when an account token is not available.

## Prepare, save and send

With the returned `config` and trusted fingerprint:

```python
client = Client(config=config,
                runtime='/absolute/path/to/sdk/python/runtime/main.js')
envelope = client.prepare(
    title='Build complete', body='The report is attached.',
    pushEnabled=False,
    links=['https://example.com/reports/latest'],
    files=[{'path': '/absolute/path/to/report.pdf', 'mime': 'application/pdf'}],
)
# Save envelope privately before submission when durable retries are needed.
result = client.retry(envelope)
print(result['message_id'], result['deduplicated'])
```

Omit `pushEnabled` for the default alert to all eligible devices. Use `deviceIds=[id]` for a device from `client.recipients()['devices']`. Use `images=[{'path':..., 'mime':'image/png'}]` or `icon={'path':..., 'mime':'image/png'}` for image content. `scheduledAt` and `expiresAt` accept ISO timestamps within 30 days.

Python input option names are camelCase; HTTP envelope field names are snake_case. The finalized `sound` input accepts `'default'`, `'silent'` or `'chime'`; omit it for default behavior rather than passing `None`:

```python
envelope = client.prepare(title='Quiet update', body='Ready to review.', sound='silent')
```

Sound is public routing metadata, not encrypted content. Silent still requests a visible alert; chime uses the new app's bundled asset. No arbitrary filename or sound upload is accepted. Message content remains HPKE-encrypted and files remain AES-GCM-encrypted. iOS settings and Focus/DND apply without a critical-alert guarantee. This contract is being implemented; migration, deployment and audible-device verification are pending. See [sound rollout status](/docs/message-content/#sound-and-notification-permissions).

## Runnable repository examples

From `sdk/python`, after setting the trusted fingerprint:

```sh
python3 examples/authorize.py
python3 examples/send.py
```

The send example saves an encrypted outbox and retries that same outbox on later runs. Choose a new outbox for a new message. Protect both outbox and configuration files from other users and source control.

`client.send(...)` is a convenience method returning `{'envelope': ..., 'result': ...}`. It cannot recover an outbox that was never saved after an uncertain result; prefer prepare/save/retry for durable work.

## Diagnostics

Use `client.request_logs` for redacted method/path/status/timing metadata and catch `PushNowError` for bounded error codes. The default subprocess deadline is 660 seconds; individual HTTP calls time out earlier. `node=`, `runtime=` and `timeout=` configure the local runtime. A timeout is not proof that a send failed; retry the saved envelope.
