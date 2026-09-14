import { readFile, stat, writeFile } from 'node:fs/promises';
import { basename, extname } from 'node:path';
import { hostname } from 'node:os';
import { createInterface } from 'node:readline/promises';
import { credentialStore } from './credentials.js';
import { beginLogin, finishLogin, revokeSender } from './v2-auth.js';
import { recipientsV2, uploadAttachment, prepareMessageV2, submitMessageV2, validateSound } from './v2-client.js';

const types = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif',
  '.webp': 'image/webp', '.heic': 'image/heic', '.pdf': 'application/pdf', '.md': 'text/markdown',
  '.txt': 'text/plain', '.json': 'application/json', '.mp4': 'video/mp4' };

export async function v2Command(command, values) {
  if (command === 'send') validateSound(values.sound);
  else if (values.sound !== undefined) throw new Error('--sound is only valid for send; retry preserves the outbox sound');
  const store = credentialStore();
  if (command === 'login') {
    if (!values.api) throw new Error('login requires --api <https://api-origin>');
    if (await store.read()) throw new Error('Already authorized; logout before authorizing another sender');
    const pending = await beginLogin(values.api, values.name ?? hostname());
    console.log(`Authorization code: ${pending.authorization.user_code}\nSender fingerprint: ${pending.fingerprint}\nConfirm this fingerprint in the app before approving.`);
    const controller = new AbortController();
    const cancel = () => controller.abort();
    process.once('SIGINT', cancel);
    try {
      const config = await finishLogin(pending, { signal: controller.signal, confirmIdentity: async ({ fingerprint }) => {
        if (!process.stdin.isTTY) throw new Error('Interactive terminal required to verify account identity');
        console.log(`Account fingerprint: ${fingerprint}\nCompare the complete fingerprint with your trusted phone.`);
        const terminal = createInterface({ input: process.stdin, output: process.stdout });
        try { return (await terminal.question('Do the account fingerprints match? Type yes: ', { signal: controller.signal })).trim() === 'yes'; }
        finally { terminal.close(); }
      } });
      try { await store.write(config); }
      catch {
        await revokeSender(config).catch(() => {});
        throw new Error('Could not save authorization. Remove this sender in the app before retrying.');
      }
      console.log('Sender authorized.');
    } finally { process.removeListener('SIGINT', cancel); }
    return;
  }
  const config = await store.read();
  if (!config) throw new Error('Not authorized; run login first');
  if (command === 'logout') {
    await revokeSender(config);
    await store.delete(); console.log('Sender revoked and local credentials removed.'); return;
  }
  if (command === 'devices') {
    const directory = await recipientsV2(config);
    console.log(JSON.stringify(directory.devices.map(({ id, name, platform, notifications_enabled,
      system_version, app_version, model, last_seen_at }) =>
      ({ id, name, platform, notifications_enabled, system_version, app_version, model, last_seen_at })), null, 2)); return;
  }
  if (command === 'retry') {
    if (!values.outbox) throw new Error('retry requires --outbox');
    await submitMessageV2(config, JSON.parse(await readFile(values.outbox, 'utf8')));
    console.log(JSON.stringify({ status: 'accepted', delivery_confirmed: false })); return;
  }
  if (command !== 'send') throw new Error('Unknown command; use --help');
  const plaintext = values.input ? JSON.parse(await readFile(values.input, 'utf8')) : { title: values.title, body: values.body ?? '' };
  if (Object.hasOwn(plaintext, 'sound')) throw new Error('Use --sound instead of sound in the input JSON');
  if (typeof plaintext.title !== 'string' || typeof plaintext.body !== 'string') throw new Error('Use --input JSON or --title with --body');
  plaintext.links = [...(plaintext.links ?? []), ...(values.link ?? [])];
  plaintext.attachments = plaintext.attachments ?? [];
  const paths = [...(values.file ?? []).map(path => ({ path })),
    ...(values.image ? [{ path: values.image, role: 'image_id' }] : []),
    ...(values.icon ? [{ path: values.icon, role: 'icon_id' }] : [])];
  if (paths.length + plaintext.attachments.length > 20) throw new Error('Maximum 20 attachments');
  for (const { path } of paths) {
    const info = await stat(path);
    if (!info.isFile() || info.size > 20 * 1024 * 1024 - 16) throw new Error('Attachment must be a file under 20 MiB');
  }
  const directory = await recipientsV2(config);
  for (const { path, role } of paths) {
    const mime = types[extname(path).toLowerCase()] ?? 'application/octet-stream';
    if (role && !mime.startsWith('image/')) throw new Error('Icon and image require a recognized image file');
    const attachment = await uploadAttachment(config, await readFile(path), { name: basename(path), mime });
    plaintext.attachments.push(attachment);
    if (role) plaintext[role] = attachment.id;
  }
  const message = await prepareMessageV2(config, directory, plaintext, {
    sourceKind: 'cli', deviceIds: values['inbox-only'] ? [] : values.device, scheduledAt: values.at, expiresAt: values.expires, sound: values.sound,
  });
  if (values.outbox) await writeFile(values.outbox, JSON.stringify(message), { mode: 0o600, flag: 'wx' });
  await submitMessageV2(config, message);
  console.log(JSON.stringify({ status: 'accepted', message_id: message.message_id, delivery_confirmed: false }));
}
