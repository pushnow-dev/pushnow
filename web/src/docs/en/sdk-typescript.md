---
title: TypeScript and JavaScript
description: Build the local npm package, authorize in a browser or Node, and send encrypted content.
order: 12
---

## Install the local package

From the repository root:

```sh
npm --prefix sdk/typescript ci
npm --prefix sdk/typescript run build
cd sdk/typescript
npm pack
```

Install the generated tarball in your consuming project:

```sh
npm install /absolute/path/to/sdk/typescript/pushnow-sdk-0.1.0.tgz
```

The package's local import name is `@pushnow/sdk`. This is a local tarball install, not a claim that `npm install @pushnow/sdk` works from a public registry. The package is ESM and includes TypeScript declarations; there is no CommonJS entry.

For an unbundled browser, serve the built `dist/browser.js` from your application and import it as an ES module. It includes the HPKE dependency. Use HTTPS or loopback HTTP and a runtime with WebCrypto, `fetch`, `AbortController` and `structuredClone`.

## Authorize once

The following example assumes `trustedAccountFingerprint` was obtained independently from your signed-in trusted app. It must not be the new sender fingerprint printed by `beginLogin`.

```ts
import { beginLogin, finishLogin } from '@pushnow/sdk';

const pending = await beginLogin('https://api.pushnow.dev', 'My integration');
// Display these two public values for comparison and approval in the app.
console.log(pending.authorization.user_code);
console.log(pending.fingerprint);

const config = await finishLogin(pending, {
  expectedIdentityFingerprint: trustedAccountFingerprint,
});
```

Alternatively supply `confirmIdentity: async ({ fingerprint, userID }) => boolean` and require the person to compare it with their phone. Choose exactly one verification mechanism. A mismatch or omitted verification fails closed.

`config` includes secrets. Keep it in memory for a browser session or a secure server-side secret store. Never embed it in public JavaScript, URLs or plaintext browser storage. For Dashboard integration, compare its `user_id` to the signed-in account and its `api_url` to the expected API origin, then call `recipientsV2(config)` to verify the directory. Clear it on logout or account change.

## Send text and files

```ts
import { sendNotification } from '@pushnow/sdk';

const result = await sendNotification(config, {
  title: 'Build complete',
  body: 'The report is ready.',
  links: ['https://example.com/reports/latest'],
  files: [{
    data: new Blob(['Build passed']),
    name: 'build.txt',
    mime: 'text/plain',
  }],
}, {
  inboxOnly: true,
});
console.log(result.message_id, result.deduplicated);
```

Remove `inboxOnly` to notify all eligible devices. For selected devices, use `deviceIds: [selectedDeviceID]`; do not combine it with `inboxOnly: true`. `scheduledAt` and `expiresAt` are options in the third argument.

Use `image` or `icon` in the content argument with `{data,name,mime}` to upload and reference an image. File data may be a `Blob`, `Uint8Array` or `ArrayBuffer`.

The finalized `MessageOptions.sound` accepts `'default' | 'silent' | 'chime'`. Pass it in the third argument to `sendNotification`, or the options argument to `prepareMessageV2`, not in `MessageContent`:

```ts
await sendNotification(config, { title: 'Quiet update', body: 'Ready to review.' }, {
  sound: 'silent',
});
```

Omission preserves default sound. Silent still requests a visible alert; chime requests the new app's bundled `pushnow-chime.wav`. Sound is public top-level routing metadata; content and files remain encrypted. No arbitrary filename, audio upload or critical-alert option is supported. iOS settings and Focus/DND apply. This contract is being implemented; migration, deployment and audible-device verification are pending. See [rollout status](/docs/message-content/#sound-and-notification-permissions).

## Prepare and retry

```ts
import { recipientsV2, prepareMessageV2, submitMessageV2 } from '@pushnow/sdk';

const directory = await recipientsV2(config);
const prepared = await prepareMessageV2(config, directory, {
  title: 'Report ready', body: 'Open the app to review.',
}, { inboxOnly: true });

const result = await submitMessageV2(config, prepared);
// On an uncertain result, retry submitMessageV2(config, prepared).
```

Retain the exact `prepared` object. The SDK binds it to the account and source in memory; JSON serialization, cloning and re-import lose that binding and are rejected. This version does not provide durable outbox import. Use the CLI or a documented binding outbox workflow when you need restart-safe retries.

## Redacted request events

```ts
await sendNotification(config, { title: 'Ready', body: 'Done' }, {
  onRequest(event) {
    console.log(event.method, event.path, event.status, event.durationMs, event.outcome);
  },
});
```

Events contain no headers, tokens, plaintext or raw response body. Paths use templates instead of IDs. A custom `fetcher` receives credentials and ciphertext and must be trusted; it is not a redacted logging hook.

HTTP errors expose `APIError.status`. Requests reject redirects and use a timeout. Pass an `AbortSignal` to cancel; cancellation does not prove a submission was rejected by the server.
