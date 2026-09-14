#!/usr/bin/env node
import { readFile, stat, writeFile } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { prepareMessage, recipients, submitMessage, validateConfig } from './client.js';
import { v2Command } from './v2-command.js';

const usage = `pushnow login --api <https://api-origin> [--name <sender-name>]
pushnow logout
pushnow devices
pushnow send --input <message.json> [--file <path>] [--image <path>] [--icon <path>] [--link <url>] [--device <id>] [--inbox-only] [--sound <default|silent|chime>] [--outbox <encrypted.json>]
pushnow send --title <text> --body <text> [--sound <default|silent|chime>]
pushnow retry --outbox <encrypted.json>

Login prints a one-time code and public fingerprint for confirmation on your phone.
macOS credentials use Keychain; other systems use a private credentials file.
Device targeting affects notifications only; approved account devices share history.
Files are encrypted locally before uploading. Repeat --file, --link or --device.
--sound is public v2 routing metadata: default uses the system sound,
silent keeps the notification visible without sound, chime uses pushnow-chime.wav.
Omit --sound to preserve legacy behavior. Retry retains the saved outbox sound.
Use --sound as a send flag, not a field inside --input message JSON.

Legacy compatibility:
pushnow devices --config <private-config.json>
pushnow send --config <private-config.json> --input <message.json> [--device <id>] [--at <ISO8601>] [--expires <ISO8601>] [--outbox <encrypted.json>]
pushnow retry --config <private-config.json> --outbox <encrypted.json>

Export a sender configuration from the app and restrict its permissions (chmod 600).
Input JSON: {"title":"Build finished","body":"Your result is ready"}.
Default recipients: all approved devices with notifications enabled.
--device may be repeated. A disabled device explicitly selected receives inbox-only content.
The outbox contains ciphertext for exact idempotent retries. It never contains message plaintext.
An accepted API response does not prove notification delivery.`;

try {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      config: { type: 'string' }, input: { type: 'string' }, device: { type: 'string', multiple: true },
      at: { type: 'string' }, expires: { type: 'string' }, sound: { type: 'string' }, outbox: { type: 'string' }, help: { type: 'boolean' },
      api: { type: 'string' }, name: { type: 'string' }, title: { type: 'string' }, body: { type: 'string' },
      file: { type: 'string', multiple: true }, image: { type: 'string' }, icon: { type: 'string' },
      link: { type: 'string', multiple: true }, 'inbox-only': { type: 'boolean' },
    },
  });
  const command = positionals[0];
  if (values.help || !command) {
    console.log(usage);
  } else if (!values.config) {
    if (positionals.length !== 1) throw new Error('Unknown command; use --help');
    await v2Command(command, values);
  } else {
    if (values.sound !== undefined) throw new Error('--sound requires login-based v2 sending; omit --config');
    if (values.file || values.image || values.icon || values.link || values['inbox-only']) {
      throw new Error('Attachments, links and inbox-only flags require login-based v2 sending; omit --config');
    }
    if (!['devices', 'send', 'retry'].includes(command) || positionals.length !== 1) throw new Error('Unknown command; use --help');
    if (!values.config) throw new Error('--config is required');
    const file = await stat(values.config);
    if ((file.mode & 0o077) !== 0) throw new Error('Sender configuration must be private: chmod 600 <config>');
    const config = validateConfig(JSON.parse(await readFile(values.config, 'utf8')));
    if (command === 'devices') {
      const devices = await recipients(config);
      console.log(JSON.stringify(devices.map(({ id, name, platform, notifications_enabled }) =>
        ({ id, name, platform, notifications_enabled })), null, 2));
    } else {
      let message;
      if (command === 'retry') {
        if (!values.outbox) throw new Error('--outbox is required for retry');
        message = JSON.parse(await readFile(values.outbox, 'utf8'));
      } else {
        if (!values.input) throw new Error('--input is required');
        const plaintext = JSON.parse(await readFile(values.input, 'utf8'));
        message = await prepareMessage(config, await recipients(config), plaintext, {
          sourceKind: 'cli', deviceIds: values.device, scheduledAt: values.at, expiresAt: values.expires,
        });
        if (values.outbox) await writeFile(values.outbox, JSON.stringify(message), { mode: 0o600, flag: 'wx' });
      }
      await submitMessage(config, message);
      console.log(JSON.stringify({ status: 'accepted', message_id: message.message_id, delivery_confirmed: false }));
    }
  }
} catch (error) {
  // Do not echo API response bodies, message content, URLs or credentials.
  console.error(error instanceof SyntaxError ? 'Invalid JSON input' : error.message);
  process.exitCode = 1;
}
