export { beginLogin, finishLogin, revokeSender } from './v2-auth.js';
export { recipientsV2, uploadAttachment, prepareMessageV2, submitMessageV2 } from './v2-client.js';
export { generateAgreementKey, fingerprint, encryptAttachment } from './v2-crypto.js';
export { APIError } from './v2-http.js';
export { recipients, prepareMessage, submitMessage } from './client.js';

import { recipientsV2, uploadAttachment, prepareMessageV2, submitMessageV2, validateSound } from './v2-client.js';

// Attachments may be existing encrypted descriptors or {data, name, mime} uploads.
// For durable retries, save prepareMessageV2's result and use submitMessageV2 instead.
// scheduledAt/expiresAt use timezone-qualified ISO timestamps (maximum 30 days).
// Scheduled messages appear in history immediately; reading does not cancel them.
// sound is optional public routing metadata: default, silent, or chime.
export async function sendNotification(config, { title, body = '', deviceIds, pushEnabled = true,
  scheduledAt, expiresAt, sound, attachments = [] }, options = {}) {
  validateSound(sound);
  if (typeof title !== 'string' || typeof body !== 'string') throw new Error('Message needs title and body');
  if (typeof pushEnabled !== 'boolean') throw new Error('pushEnabled must be a boolean');
  if (!Array.isArray(attachments) || attachments.length > 20) throw new Error('Maximum 20 attachments');
  const directory = await recipientsV2(config, options);
  const descriptors = [];
  for (const attachment of attachments) {
    if (!attachment || typeof attachment !== 'object') throw new Error('Invalid attachment');
    descriptors.push(attachment.data === undefined ? attachment : await uploadAttachment(config,
      attachment.data, { name: attachment.name, mime: attachment.mime }, options));
  }
  const message = await prepareMessageV2(config, directory, { title, body, attachments: descriptors }, {
    deviceIds: pushEnabled ? deviceIds : [], scheduledAt, expiresAt, sound,
  });
  return submitMessageV2(config, message, options);
}
