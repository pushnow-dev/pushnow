import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import assert from 'node:assert/strict';
import { createInterface } from 'node:readline/promises';
import { credentialStore } from '../src/credentials.js';
import { beginLogin, finishLogin } from '../src/v2-auth.js';
import { recipientsV2, uploadAttachment, prepareMessageV2, submitMessageV2 } from '../src/v2-client.js';

// Deliberately isolated QA storage. Never reads the production/default CLI keychain.
const [command, directory, argument, accountFingerprint] = process.argv.slice(2);
if (!directory?.startsWith('/tmp/pushnow-qa-')) throw new Error('Use an isolated /tmp/pushnow-qa-* directory');
const store = credentialStore({ platform: 'linux', directory });
if (command === 'login') {
  if (await store.read()) throw new Error('QA sender is already authorized');
  const pending = await beginLogin(argument, 'Simulator QA sender');
  console.log(JSON.stringify({ user_code: pending.authorization.user_code, sender_fingerprint: pending.fingerprint }));
  let trustedFingerprint = accountFingerprint;
  if (!trustedFingerprint) {
    const input = createInterface({ input: process.stdin, output: process.stdout });
    try { trustedFingerprint = (await input.question('Account fingerprint read from trusted phone: ')).trim(); }
    finally { input.close(); }
  }
  if (!/^[a-f0-9]{64}$/i.test(trustedFingerprint ?? '')) throw new Error('Provide the full account fingerprint read from the phone');
  const config = await finishLogin(pending, { expectedIdentityFingerprint: trustedFingerprint });
  await store.write(config);
  console.log('PASS phone-approved sender grant matches account fingerprint read from Simulator');
} else if (command === 'send') {
  const config = await store.read();
  if (!config) throw new Error('Authorize the isolated QA sender first');
  const imageBytes = await readFile(argument);
  const markdown = await uploadAttachment(config, Buffer.from('# Release notes\n\nEncrypted Markdown attachment.\n\n- Review the build\n- Confirm the image\n'), { name: 'release-notes.md', mime: 'text/markdown' });
  const image = await uploadAttachment(config, imageBytes, { name: 'preview.png', mime: 'image/png' });
  const icon = await uploadAttachment(config, imageBytes, { name: 'icon.png', mime: 'image/png' });
  const directoryResult = await recipientsV2(config);
  const content = { title: 'Encrypted rich reminder', body: 'Private full message from the authorized CLI.\n\nReview the Markdown, image and link below.',
    links: ['https://example.com/release'], attachments: [markdown, image, icon], image_id: image.id, icon_id: icon.id };
  const message = await prepareMessageV2(config, directoryResult, content);
  await submitMessageV2(config, message);
  await writeFile(join(directory, 'outbox.json'), JSON.stringify(message), { mode: 0o600, flag: 'wx' });
  await writeFile(join(directory, 'attachment-checks.json'), JSON.stringify(content.attachments), { mode: 0o600, flag: 'wx' });
  console.log(JSON.stringify({ message_id: message.message_id, attachment_ids: message.attachment_ids,
    api_accepted: true, device_delivery_confirmed: false }));
} else if (command === 'send-text') {
  const config = await store.read();
  const target = await recipientsV2(config);
  const message = await prepareMessageV2(config, target, { title: 'Immediate deletion check', body: 'Final Simulator list refresh regression.', links: [], attachments: [] });
  await submitMessageV2(config, message);
  await writeFile(join(directory, 'text-outbox.json'), JSON.stringify(message), { mode: 0o600, flag: 'wx' });
  console.log(JSON.stringify({ message_id: message.message_id, api_accepted: true, device_delivery_confirmed: false }));
} else if (command === 'check-text-deleted') {
  const config = await store.read();
  const message = JSON.parse(await readFile(join(directory, 'text-outbox.json'), 'utf8'));
  await assert.rejects(submitMessageV2(config, message), error => error.status === 409 || error.status === 410);
  console.log('PASS final text message cannot be recreated by retry after Simulator deletion');
} else if (command === 'check-deleted') {
  const config = await store.read();
  const message = JSON.parse(await readFile(join(directory, 'outbox.json'), 'utf8'));
  const descriptors = JSON.parse(await readFile(join(directory, 'attachment-checks.json'), 'utf8'));
  await assert.rejects(submitMessageV2(config, message), error => error.status === 409 || error.status === 410);
  for (const descriptor of descriptors) {
    const response = await fetch(new URL(`/v2/attachments/${descriptor.id}`, config.api_url), {
      headers: { authorization: `Attachment ${descriptor.read_token}` }, redirect: 'error', signal: AbortSignal.timeout(10000),
    });
    assert.equal(response.status, 404);
  }
  console.log('PASS deleted message cannot be recreated by retry and all three attachment capabilities are invalid');
} else { throw new Error('Use login, send or check-deleted'); }
