export type SourceType = "agent" | "cli" | "webhook" | "subscription";
export type SourceStatus = "active" | "paused" | "revoked";
export type ItemStatus = "unread" | "read" | "archived";
export type ReminderMode = "now" | "scheduled" | "delay" | "in_app_only";
export type ReminderStatus = "scheduled" | "paused" | "cancelled" | "triggered";
export type PushPlatform = "ios" | "harmony";
export type PushEnvironment = "sandbox" | "production";
export type MembershipPlanID = "free" | "plus" | "pro";
export type UsageFeatureKey = "notification_events";

export type MembershipPlanRecord = {
  userId: string;
  plan: MembershipPlanID;
  source: "default" | "revenuecat" | "admin";
  revenuecatEntitlementId: string | null;
  revenuecatProductId: string | null;
  expiresAt: string | null;
  updatedAt: string;
};

export type UsageCounterRecord = {
  userId: string;
  featureKey: UsageFeatureKey;
  windowStart: string;
  windowEnd: string;
  usedCount: number;
  updatedAt: string;
};

export type PlanQuota = {
  plan: MembershipPlanID;
  displayName: string;
  dailyNotificationLimit: number | null;
};

export type MembershipStatus = {
  plan: MembershipPlanID;
  displayName: string;
  dailyNotificationLimit: number | null;
  usedToday: number;
  remainingToday: number | null;
  windowStart: string;
  windowEnd: string;
};

export type SourceRecord = {
  id: string;
  userId: string;
  name: string;
  sourceType: SourceType;
  defaultPriority: string;
  defaultPushEnabled: boolean;
  status: SourceStatus;
  createdAt: string;
  updatedAt: string;
};

export type SourceKeyRecord = {
  expiresAt?: string | null;
  id: string;
  sourceId: string;
  userId: string;
  keyPrefix: string;
  keyHash: string;
  scopes: string[];
  createdAt: string;
  lastUsedAt: string | null;
  revokedAt: string | null;
};

export type ItemRecord = {
  id: string;
  userId: string;
  sourceId: string;
  externalId: string | null;
  idempotencyKey: string;
  title: string;
  summary: string | null;
  status: ItemStatus;
  priority: string;
  pushEnabled: boolean;
  requiresAck: boolean;
  receivedAt: string;
  readAt: string | null;
  archivedAt: string | null;
  acknowledgedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type ContentBlockRecord = {
  id: string;
  itemId: string;
  blockType: "markdown" | "text" | "json";
  body: string;
  sortOrder: number;
  createdAt: string;
};

export type ReminderPlanRecord = {
  id: string;
  userId: string;
  itemId: string;
  mode: ReminderMode;
  scheduledAt: string | null;
  timezone: string;
  repeatRule: string | null;
  priority: string;
  pushEnabled: boolean;
  requiresAck: boolean;
  status: ReminderStatus;
  nextFireAt: string | null;
  createdAt: string;
  updatedAt: string;
  cancelledAt: string | null;
};

export type DevicePushTokenRecord = {
  id: string;
  userId: string;
  platform: PushPlatform;
  tokenHash: string;
  tokenEncrypted: string | null;
  appVersion: string | null;
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
  revokedAt: string | null;
};

export type CreateSourceRequest = {
  name: string;
  sourceType?: SourceType;
  defaultPriority?: string;
  defaultPushEnabled?: boolean;
};

export type CreateSourceKeyRequest = {
  expiresAt?: string | null;
  expires_at?: string | null;
  scopes?: string[];
};

export type IngestContentBlockInput = {
  type?: "markdown" | "text" | "json";
  body: unknown;
};

export type ReminderInput = {
  mode?: ReminderMode;
  scheduledAt?: string;
  timezone?: string;
  repeatRule?: string;
  priority?: string;
  pushEnabled?: boolean;
  requiresAck?: boolean;
};

export type IngestItemRequest = {
  title: string;
  summary?: string;
  externalId?: string;
  priority?: string;
  pushEnabled?: boolean;
  requiresAck?: boolean;
  contentBlocks?: IngestContentBlockInput[];
  reminder?: ReminderInput;
};

export type UpdateItemStateRequest = {
  status?: ItemStatus;
  acknowledged?: boolean;
};

export type UpsertDevicePushTokenRequest = {
  token: string;
  platform?: PushPlatform;
  environment?: PushEnvironment;
  appVersion?: string;
};
