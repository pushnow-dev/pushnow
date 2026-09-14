import { SecureAttachment } from '../services/SecureAttachmentService';
export type MainTab = 'inbox' | 'sources' | 'reminders' | 'devices' | 'settings';

export class InboxItem {
  id: string = '';
  userId: string = '';
  sourceId: string = '';
  iconId: string = '';
  imageId: string = '';
  attachments: SecureAttachment[] = [];
  links: string[] = [];
  source: string = '';
  category: string = '';
  title: string = '';
  summary: string = '';
  time: string = '';
  priority: string = 'normal';
  unread: boolean = true;
  requiresAck: boolean = false;
  pushEnabled: boolean = true;
  reminderBadge?: string;
}

export class SourceItem {
  id: string = '';
  name: string = '';
  sourceType: string = 'agent';
  defaultPriority: string = 'normal';
  defaultPushEnabled: boolean = true;
  status: string = 'active';
}

export class ReminderItem {
  id: string = '';
  title: string = '';
  time: string = '';
  mode: string = 'scheduled';
  priority: string = 'normal';
  pushEnabled: boolean = true;
}

export class SecureDevice {
  id: string = '';
  userId: string = '';
  name: string = '';
  platform: string = 'harmony';
  publicKey: string = '';
  certificate: string = '';
  status: string = 'active';
  notificationsEnabled: boolean = true;
  lastSeenAt: string = '';
  createdAt: string = '';
  current: boolean = false;
}

export class SecureMessage {
  message_id?: string;
  messageId?: string;
  source_id?: string;
  sourceId?: string;
  created_at?: string;
  createdAt?: string;
}

export class AuthSession {
  userID: string = '';
  accessToken: string = '';
  refreshToken: string = '';
  email: string = '';
  verified: boolean = false;
}

export class ApiEnvelope<T> {
  value?: T;
}

