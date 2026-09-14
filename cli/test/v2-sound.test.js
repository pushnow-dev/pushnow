import test from 'node:test';
import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { fileURLToPath } from 'node:url';
import { prepareMessageV2, submitMessageV2 } from '../src/v2-client.js';
import { sendNotification } from '../src/sdk.js';
import { fixtureV2, openV2 } from './v2-fixtures.js';

test('sound is optional public routing metadata, never encrypted message or preview content', async () => {
  const f = await fixtureV2(), full = { title: 'Private title', body: 'Private body', links: [], attachments: [] };
  for (const sound of [undefined, 'default', 'silent', 'chime']) {
    const envelope = await prepareMessageV2(f.config, f.directory, full, { sound });
    assert.equal(Object.hasOwn(envelope, 'sound'), sound !== undefined);
    assert.equal(envelope.sound, sound);
    assert.deepEqual(await openV2(f, envelope), full);
    assert.ok(!Object.hasOwn(await openV2(f, envelope, 'preview'), 'sound'));
    const wires = [];
    const options = { fetcher: async (_url, request) => {
      wires.push({ body: JSON.parse(request.body), key: request.headers['idempotency-key'] });
      return Response.json({ message_id: envelope.message_id, deduplicated: wires.length > 1 });
    } };
    await submitMessageV2(f.config, envelope, options);
    await submitMessageV2(f.config, JSON.parse(JSON.stringify(envelope)), options);
    assert.deepEqual(wires[0], wires[1]);
    assert.equal(wires[0].body.sound, sound);
  }
});

test('invalid sound fails before any high-level upload and cannot be hidden in plaintext', async () => {
  const f = await fixtureV2(); let requests = 0;
  for (const sound of [null, '', 'custom', 'pushnow-chime.wav', 'DEFAULT', false, {}, []]) {
    await assert.rejects(sendNotification(f.config, { title: 'Private', sound,
      attachments: [{ data: Buffer.from('private file'), name: 'secret.txt' }] }, {
      fetcher: async () => { requests++; throw new Error('Unexpected network call'); },
    }), /sound must be/);
    await assert.rejects(prepareMessageV2(f.config, f.directory, { title: 'Hi', body: '' }, { sound }), /sound must be/);
  }
  assert.equal(requests, 0);
  await assert.rejects(prepareMessageV2(f.config, f.directory, { title: 'Hi', body: '', sound: 'silent' }), /routing option/);
});

test('high-level SDK forwards valid sounds before encrypted file submission', async () => {
  const f = await fixtureV2();
  for (const sound of ['default', 'silent', 'chime']) {
    let envelope;
    await sendNotification(f.config, { title: 'Hello', sound }, { fetcher: async (url, request) => {
      if (url.pathname === '/v2/recipients') return Response.json(f.directory);
      envelope = JSON.parse(request.body); return Response.json({ message_id: envelope.message_id });
    } });
    assert.equal(envelope.sound, sound);
    assert.ok(!Object.hasOwn(await openV2(f, envelope), 'sound'));
  }
});

test('CLI documents --sound, validates it before credentials, and refuses retry overrides or legacy use', async () => {
  const run = promisify(execFile), main = fileURLToPath(new URL('../src/main.js', import.meta.url));
  const help = await run(process.execPath, [main, '--help']);
  assert.match(help.stdout, /--sound <default\|silent\|chime>/);
  assert.match(help.stdout, /silent keeps the notification visible/);
  for (const [args, message] of [
    [['send', '--sound', 'custom'], /sound must be default, silent, or chime/],
    [['retry', '--outbox', 'unused.json', '--sound', 'silent'], /retry preserves the outbox sound/],
    [['send', '--config', 'unused.json', '--sound', 'chime'], /requires login-based v2/],
  ]) {
    await assert.rejects(run(process.execPath, [main, ...args]), error => error.code === 1 && message.test(error.stderr));
  }
});
