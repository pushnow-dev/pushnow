import { SecureAttachment } from './SecureAttachmentService';
import { AuthSession, InboxItem } from '../models/JiZhiModels';
import { apiClient } from './ApiClient';
import { deviceService } from './DeviceService';
import { authService } from './AuthService';
import { secureArchiveService } from './SecureArchiveService';
import { secureCrypto, SecureGrant } from './SecureCrypto';
import { secureDeviceEnrollmentService } from './SecureDeviceEnrollmentService';

interface MessageWire {
  message_id: string;
  user_id: string;
  source_id: string;
  archive_id: string;
  enc: string;
  ciphertext: string;
  source_public_key: string;
  source_certificate: string;
  created_at?: string;
  read_at?: string;
}
interface MessagePage { messages: MessageWire[]; next_cursor?: string; deleted_ids?: string[]; }
interface DeletionPage { deleted_ids: string[]; next_cursor?: string; }
interface LegacyMessage {
  message_id: string; user_id: string; source_id: string; device_id: string;
  expires_at: string; enc: string; ciphertext: string; source_public_key: string;
  source_certificate: string; created_at: string;
}
interface LegacyPage { messages: LegacyMessage[]; }
interface MessageContent { icon_id?: string; image_id?: string; title: string; body: string; attachments?: SecureAttachment[]; links?: string[]; }
class EmptyPayload {}

export class InboxService {
  async items(session: AuthSession): Promise<InboxItem[]> {
    if (!session.verified) return [];
    const generation = authService.generation;
    const archive = await secureArchiveService.ensure();
    const result: InboxItem[] = [];
    const seen: string[] = [];
    const deleted: string[] = [];
    let cursor = '';
    const cursors: string[] = [];
    do {
      const page = await apiClient.get<MessagePage>(`/v2/messages?limit=50${cursor ? `&cursor=${encodeURIComponent(cursor)}` : ''}`, session.accessToken);
      this.check(generation, session.userID);
      for (const message of page.messages) {
        if (seen.includes(message.message_id)) continue;
        if (message.user_id !== session.userID || message.archive_id !== archive.archive.id) {
          throw new Error('Encrypted message account or archive mismatch');
        }
        await secureCrypto.verify(message.source_certificate,
          secureCrypto.text('source', session.userID, message.source_id, message.source_public_key),
          secureDeviceEnrollmentService.identityPublicKey());
        const envelope = new SecureGrant();
        envelope.enc = message.enc;
        envelope.ciphertext = message.ciphertext;
        const clear = await secureCrypto.open(archive.privateKey, archive.archive.public_key, envelope, 'pushnow-v2',
          JSON.stringify([2, 'message', message.user_id, message.source_id, message.message_id, message.archive_id]),
          message.source_public_key);
        const content = JSON.parse(clear) as MessageContent;
        if (typeof content.title !== 'string' || typeof content.body !== 'string') throw new Error('Invalid encrypted content');
        this.validateManifest(content);
        const item = new InboxItem();
        item.id = `v2:${message.message_id}`;
        item.userId = message.user_id;
        item.sourceId = message.source_id;
        item.attachments = content.attachments ?? [];
        item.iconId = content.icon_id ?? '';
        item.imageId = content.image_id ?? '';
        item.links = content.links ?? [];
        item.source = 'Encrypted source';
        item.category = 'End-to-end encrypted';
        item.title = content.title;
        item.summary = content.body;
        item.time = message.created_at ?? '';
        item.unread = !message.read_at;
        result.push(item);
        seen.push(message.message_id);
      }
      deleted.push(...(page.deleted_ids ?? []));
      cursor = page.next_cursor ?? '';
      if (cursor && cursors.includes(cursor)) throw new Error('Invalid message pagination');
      cursors.push(cursor);
    } while (cursor);
    const deletionCursors: string[] = [];
    do {
      const page = await apiClient.get<DeletionPage>(`/v2/deletions${cursor ? `?cursor=${encodeURIComponent(cursor)}` : ''}`, session.accessToken);
      deleted.push(...page.deleted_ids);
      cursor = page.next_cursor ?? '';
      if (cursor && deletionCursors.includes(cursor)) throw new Error('Invalid deletion pagination');
      deletionCursors.push(cursor);
      this.check(generation, session.userID);
    } while (cursor);
    this.check(generation, session.userID);
    const legacy = await this.legacyItems(session, generation);
    this.check(generation, session.userID);
    return [...result.filter((item: InboxItem) => !deleted.includes(item.id.substring(3))), ...legacy];
  }

  private async legacyItems(session: AuthSession, generation: number): Promise<InboxItem[]> {
    const page = await apiClient.get<LegacyPage>('/v1/secure/messages', session.accessToken);
    const result: InboxItem[] = [];
    const key = secureDeviceEnrollmentService.keys();
    for (const message of page.messages) {
      this.check(generation, session.userID);
      if (message.user_id !== session.userID || message.device_id !== deviceService.deviceId ||
        !Number.isFinite(Date.parse(message.expires_at)) || Date.parse(message.expires_at) <= Date.now()) {
        throw new Error('Invalid encrypted message recipient or expiry');
      }
      await secureCrypto.verify(message.source_certificate,
        secureCrypto.text('source', message.user_id, message.source_id, message.source_public_key),
        secureDeviceEnrollmentService.identityPublicKey());
      const grant = new SecureGrant(); grant.enc = message.enc; grant.ciphertext = message.ciphertext;
      const aad = `pushnow-message-v1\n${message.user_id}\n${message.source_id}\n${message.device_id}\n${message.message_id}\n${message.expires_at}`;
      const clear = await secureCrypto.open(key.privateKey, key.publicKey, grant, 'pushnow-message-v1', aad, message.source_public_key);
      const content = JSON.parse(clear) as MessageContent;
      if (typeof content.title !== 'string' || typeof content.body !== 'string') throw new Error('Invalid encrypted content');
      const item = new InboxItem(); item.id = `secure:${message.message_id}`;
      item.title = content.title; item.summary = content.body; item.time = message.created_at;
      item.source = 'Encrypted source'; item.category = 'End-to-end encrypted'; item.requiresAck = true;
      result.push(item);
    }
    return result;
  }

  async markRead(token: string, id: string): Promise<void> {
    if (id.startsWith('secure:')) {
      await apiClient.post<object>(`/v1/secure/messages/${encodeURIComponent(id.substring(7))}/ack`, new EmptyPayload(), token);
      return;
    }
    await apiClient.post<object>(`/v2/messages/${encodeURIComponent(id.replace('v2:', ''))}/read`, new EmptyPayload(), token);
  }

  async remove(token: string, id: string): Promise<void> {
    if (!id.startsWith('v2:')) throw new Error('Deletion unavailable for legacy messages');
    await apiClient.delete(`/v2/messages/${encodeURIComponent(id.replace('v2:', ''))}`, token);
  }

  private validateManifest(content: MessageContent): void {
    if (content.attachments !== undefined && (!Array.isArray(content.attachments) || content.attachments.length > 20)) {
      throw new Error('Invalid encrypted attachments');
    }
    if (content.links !== undefined && (!Array.isArray(content.links) || content.links.some((link: string) => typeof link !== 'string'))) {
      throw new Error('Invalid encrypted links');
    }
    for (const attachment of content.attachments ?? []) {
      if (!attachment || typeof attachment.id !== 'string' || typeof attachment.name !== 'string' ||
        typeof attachment.mime !== 'string' || typeof attachment.key !== 'string' || typeof attachment.nonce !== 'string' ||
        typeof attachment.sha256 !== 'string' || !Number.isInteger(attachment.size)) throw new Error('Invalid encrypted attachment');
    }
  }

  private check(generation: number, user: string): void {
    if (authService.generation !== generation || authService.current.userID !== user) throw new Error('Account changed; refresh again');
  }
}
export const inboxService = new InboxService();
