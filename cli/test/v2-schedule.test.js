import test from 'node:test';
import assert from 'node:assert/strict';
import { prepareMessageV2, sendNotification } from '../src/sdk.js';
import { fixtureV2, openV2 } from './v2-fixtures.js';

test('v2 preparation preserves schedule/expiry and keeps old omitted defaults', async () => {
 const f = await fixtureV2(), plaintext = { title: 'Scheduled secret', body: 'Private body' };
 const scheduledAt = new Date(Date.now() + 60000).toISOString(), expiresAt = new Date(Date.now() + 120000).toISOString();
 const message = await prepareMessageV2(f.config, f.directory, plaintext, { scheduledAt, expiresAt });
 assert.equal(message.scheduled_at, scheduledAt); assert.equal(message.expires_at, expiresAt);
 assert.equal((await openV2(f, message)).title, plaintext.title);
 assert.ok(!JSON.stringify(message).includes(plaintext.title));
 const immediate = await prepareMessageV2(f.config, f.directory, plaintext);
 assert.ok(!('scheduled_at' in immediate)); assert.ok(!('expires_at' in immediate));
 await assert.rejects(prepareMessageV2(f.config, f.directory, plaintext, { deviceIds: ['foreign'] }));
});

test('high-level SDK verifies directory, encrypts uploads and submits scheduled inbox-only messages', async () => {
 const f = await fixtureV2(); let wire, upload; const calls = [];
 const scheduledAt = new Date(Date.now() + 60000).toISOString();
 const result = await sendNotification(f.config, { title: 'Private SDK title', body: 'Private SDK body',
  pushEnabled: false, scheduledAt, attachments: [{ data: Buffer.from('Secret file'), name: 'secret.txt', mime: 'text/plain' }] }, {
  fetcher: async (url, options) => {
   calls.push([url.pathname, options.method]);
   if (url.pathname === '/v2/recipients') return Response.json(f.directory);
   if (options.method === 'PUT') { upload = Buffer.from(options.body); return new Response(null, { status: 204 }); }
   if (url.pathname === '/v2/messages') {
    wire = JSON.parse(options.body); assert.equal(options.headers['idempotency-key'], wire.message_id);
    return Response.json({ message_id: wire.message_id, deduplicated: false });
   }
   return Response.json({});
  },
 });
 assert.equal(result.message_id, wire.message_id);
 assert.equal(wire.scheduled_at, scheduledAt); assert.deepEqual(wire.notify_device_ids, []);
 const plaintext = await openV2(f, wire);
 assert.equal(plaintext.title, 'Private SDK title'); assert.equal(plaintext.attachments[0].name, 'secret.txt');
 assert.ok(!upload.includes(Buffer.from('Secret file')));
 assert.equal(calls.length, 4);
});

test('high-level SDK defaults to all devices and supports one explicit device', async () => {
 const f = await fixtureV2();
 for (const deviceIds of [undefined, [f.devices[0].id]]) {
  let wire;
  await sendNotification(f.config, { title: 'Hello', deviceIds }, { fetcher: async (url, options) => {
   if (url.pathname === '/v2/recipients') return Response.json(f.directory);
   wire = JSON.parse(options.body); return Response.json({ message_id: wire.message_id });
  } });
  assert.deepEqual(wire.notify_device_ids, deviceIds);
 }
});
