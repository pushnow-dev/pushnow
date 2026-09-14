import { AuthHttpError, constantTimeEqualHex, createOpaqueToken, hashSecret } from "./crypto";
import { membershipPlans, membershipStatus, usageWindowFor } from "./membership";
import type {
  ContentBlockRecord,
  CreateSourceKeyRequest,
  CreateSourceRequest,
  DevicePushTokenRecord,
  IngestContentBlockInput,
  IngestItemRequest,
  ItemRecord,
  ItemStatus,
  MembershipStatus,
  ReminderInput,
  ReminderMode,
  ReminderPlanRecord,
  SourceKeyRecord,
  SourceRecord,
  SourceType,
  UpdateItemStateRequest,
  UpsertDevicePushTokenRequest
} from "./product-contracts";
import type { ProductStore } from "./product-store";

export type ProductRuntimeConfig = {
  authTokenPepper: string;
};

type SourceKeySession = {
  key: SourceKeyRecord;
  source: SourceRecord;
};

const sourceTypes: SourceType[] = ["agent", "cli", "webhook", "subscription"];
const itemStatuses: ItemStatus[] = ["unread", "read", "archived"];
const reminderModes: ReminderMode[] = ["now", "scheduled", "delay", "in_app_only"];
const maxActiveSourceKeys = 2;

export class ProductService {
  constructor(
    private readonly store: ProductStore,
    private readonly config: ProductRuntimeConfig,
    private readonly now: () => Date = () => new Date()
  ) {}

  listSources(userID: string): Promise<SourceRecord[]> {
    return this.store.listSources(userID);
  }

  async getMembershipStatus(userID: string): Promise<MembershipStatus> {
    const now = this.now();
    const window = usageWindowFor(now);
    const planRecord = await this.store.getMembershipPlan(userID, now.toISOString());
    const usage = await this.store.getUsageCounter(userID, "notification_events", window.windowStart);
    return membershipStatus(planRecord?.plan ?? "free", usage, window);
  }

  async createSource(userID: string, input: CreateSourceRequest): Promise<SourceRecord> {
    const timestamp = this.now().toISOString();
    const source: SourceRecord = {
      id: crypto.randomUUID(),
      userId: userID,
      name: requiredString(input.name, "name", 80),
      sourceType: sourceTypes.includes(input.sourceType ?? "agent") ? input.sourceType ?? "agent" : "agent",
      defaultPriority: normalizePriority(input.defaultPriority),
      defaultPushEnabled: input.defaultPushEnabled ?? true,
      status: "active",
      createdAt: timestamp,
      updatedAt: timestamp
    };
    await this.store.createSource(source);
    return source;
  }

  async createSourceKey(userID: string, sourceID: string, input: CreateSourceKeyRequest): Promise<{ sourceKey: string; record: SourceKeyRecord }> {
    const source = await this.requireSource(userID, sourceID);
    const timestamp = this.now().toISOString();
    const expiresAt = validateKeyExpiry(input.expiresAt ?? input.expires_at ?? null, this.now());
    const activeCount = await this.store.countActiveSourceKeys(userID, source.id, timestamp);
    if (activeCount >= maxActiveSourceKeys) {
      throw new AuthHttpError(409, "source_key_limit_exceeded", "最多只能保留 2 个有效 Key，请先删除或重新生成旧 Key");
    }
    const sourceKey = createOpaqueToken("jzs");
    const record: SourceKeyRecord = {
      expiresAt,
      id: crypto.randomUUID(),
      sourceId: source.id,
      userId: userID,
      keyPrefix: sourceKey.slice(0, 18),
      keyHash: await hashSecret(sourceKey, this.config.authTokenPepper),
      scopes: normalizeScopes(input.scopes),
      createdAt: timestamp,
      lastUsedAt: null,
      revokedAt: null
    };
    await this.store.createSourceKey(record);
    return { sourceKey, record };
  }

  async ingestItem(sourceToken: string, idempotencyKey: string, input: IngestItemRequest): Promise<{ item: ItemRecord; deduplicated: boolean }> {
    const session = await this.authenticateSourceKey(sourceToken);
    if (await this.store.isSourceEncryptionRequired(session.source.id)) {
      throw new AuthHttpError(403, "encryption_required", "Use the encrypted message endpoint");
    }
    const normalizedIdempotencyKey = requiredString(idempotencyKey, "idempotency_key", 160);
    const existing = await this.store.findItemBySourceIdempotency(session.source.id, normalizedIdempotencyKey);
    if (existing) {
      return { item: existing, deduplicated: true };
    }

    await this.consumeNotificationUsage(session.key.userId);

    const timestamp = this.now().toISOString();
    const item: ItemRecord = {
      id: crypto.randomUUID(),
      userId: session.key.userId,
      sourceId: session.source.id,
      externalId: optionalString(input.externalId, 160),
      idempotencyKey: normalizedIdempotencyKey,
      title: requiredString(input.title, "title", 180),
      summary: optionalString(input.summary, 1000),
      status: "unread",
      priority: normalizePriority(input.priority ?? session.source.defaultPriority),
      pushEnabled: input.pushEnabled ?? session.source.defaultPushEnabled,
      requiresAck: input.requiresAck ?? false,
      receivedAt: timestamp,
      readAt: null,
      archivedAt: null,
      acknowledgedAt: null,
      createdAt: timestamp,
      updatedAt: timestamp
    };
    const blocks = normalizeBlocks(item.id, input.contentBlocks, timestamp);
    const reminder = input.reminder ? this.makeReminder(item, input.reminder, timestamp) : null;
    try {
      await this.store.createItemWithBlocksAndReminder(item, blocks, reminder);
    } catch (error) {
      const duplicate = await this.store.findItemBySourceIdempotency(session.source.id, normalizedIdempotencyKey);
      if (duplicate) {
        return { item: duplicate, deduplicated: true };
      }
      throw error;
    }
    return { item, deduplicated: false };
  }

  listItems(userID: string, limitInput?: string | null): Promise<ItemRecord[]> {
    return this.store.listItems(userID, parseLimit(limitInput, 50, 100));
  }

  async getItem(userID: string, itemID: string): Promise<ItemRecord> {
    const item = await this.store.findItem(userID, itemID);
    if (!item) throw new AuthHttpError(404, "item_not_found", "事项不存在");
    return item;
  }

  async updateItemState(userID: string, itemID: string, input: UpdateItemStateRequest): Promise<ItemRecord> {
    const status = input.status && itemStatuses.includes(input.status) ? input.status : null;
    const acknowledgedAt = input.acknowledged ? this.now().toISOString() : null;
    if (!status && !acknowledgedAt) throw new AuthHttpError(400, "empty_state_update", "缺少要更新的事项状态");
    const item = await this.store.updateItemState(userID, itemID, status, acknowledgedAt, this.now().toISOString());
    if (!item) throw new AuthHttpError(404, "item_not_found", "事项不存在");
    return item;
  }

  async createReminder(userID: string, itemID: string, input: ReminderInput): Promise<ReminderPlanRecord> {
    const item = await this.getItem(userID, itemID);
    const reminder = this.makeReminder(item, input, this.now().toISOString());
    await this.store.createReminderPlan(reminder);
    return reminder;
  }

  listReminders(userID: string, limitInput?: string | null): Promise<ReminderPlanRecord[]> {
    return this.store.listReminderPlans(userID, parseLimit(limitInput, 50, 100));
  }

  async upsertDevicePushToken(userID: string, input: UpsertDevicePushTokenRequest): Promise<DevicePushTokenRecord> {
    const timestamp = this.now().toISOString();
    const token = requiredString(input.token, "token", 4096);
    const record: DevicePushTokenRecord = {
      id: crypto.randomUUID(),
      userId: userID,
      platform: input.platform ?? "ios",
      tokenHash: await hashSecret(`${input.environment ?? "production"}.${token}`, this.config.authTokenPepper),
      tokenEncrypted: null,
      appVersion: optionalString(input.appVersion, 40),
      enabled: true,
      createdAt: timestamp,
      updatedAt: timestamp,
      revokedAt: null
    };
    await this.store.upsertDevicePushToken(record);
    return record;
  }

  async authenticateSourceKey(sourceToken: string): Promise<SourceKeySession> {
    const keyPrefix = requiredString(sourceToken, "source_key", 256).slice(0, 18);
    const key = await this.store.findActiveSourceKeyByPrefix(keyPrefix);
    const keyHash = await hashSecret(sourceToken, this.config.authTokenPepper);
    if (!key || key.revokedAt || (key.expiresAt != null && !(Date.parse(key.expiresAt) > this.now().getTime())) || !constantTimeEqualHex(key.keyHash, keyHash) || !key.scopes.includes("items:write")) {
      throw new AuthHttpError(401, "invalid_source_key", "来源密钥无效");
    }
    const source = await this.store.findSourceByID(key.sourceId);
    if (!source || source.status !== "active") {
      throw new AuthHttpError(401, "source_inactive", "来源不可用");
    }
    await this.store.touchSourceKey(key.id, this.now().toISOString());
    return { key, source };
  }

  private async consumeNotificationUsage(userID: string): Promise<void> {
    const now = this.now();
    const window = usageWindowFor(now);
    const planRecord = await this.store.getMembershipPlan(userID, now.toISOString());
    const plan = planRecord?.plan ?? "free";
    const limit = membershipPlans[plan].dailyNotificationLimit;
    if (limit === null) return;

    const existingUsage = await this.store.getUsageCounter(userID, "notification_events", window.windowStart);
    if ((existingUsage?.usedCount ?? 0) >= limit) {
      throw new AuthHttpError(402, "quota_exceeded", "今日通知额度已用完，请升级会员计划或明天再试");
    }

    const usage = await this.store.incrementUsageCounter(userID, "notification_events", window.windowStart, window.windowEnd, now.toISOString());
    if (usage.usedCount > limit) {
      throw new AuthHttpError(402, "quota_exceeded", "今日通知额度已用完，请升级会员计划或明天再试");
    }
  }

  private async requireSource(userID: string, sourceID: string): Promise<SourceRecord> {
    const source = await this.store.findSource(userID, sourceID);
    if (!source) throw new AuthHttpError(404, "source_not_found", "来源不存在");
    return source;
  }

  private makeReminder(item: ItemRecord, input: ReminderInput, timestamp: string): ReminderPlanRecord {
    const mode = reminderModes.includes(input.mode ?? "scheduled") ? input.mode ?? "scheduled" : "scheduled";
    const scheduledAt = optionalString(input.scheduledAt, 64);
    if (mode === "scheduled" && !scheduledAt) {
      throw new AuthHttpError(400, "missing_scheduled_at", "定时提醒需要 scheduled_at");
    }
    return {
      id: crypto.randomUUID(),
      userId: item.userId,
      itemId: item.id,
      mode,
      scheduledAt,
      timezone: optionalString(input.timezone, 64) ?? "UTC",
      repeatRule: optionalString(input.repeatRule, 280),
      priority: normalizePriority(input.priority ?? item.priority),
      pushEnabled: input.pushEnabled ?? item.pushEnabled,
      requiresAck: input.requiresAck ?? item.requiresAck,
      status: mode === "in_app_only" ? "paused" : "scheduled",
      nextFireAt: mode === "now" ? timestamp : scheduledAt,
      createdAt: timestamp,
      updatedAt: timestamp,
      cancelledAt: null
    };
  }
}

export function validateKeyExpiry(value: unknown, now = new Date()): string | null {
  if (value === null) return null;
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(value) || !Number.isFinite(Date.parse(value)) || Date.parse(value) <= now.getTime()) {
    throw new AuthHttpError(400, 'invalid_expires_at', 'expires_at must be a future UTC ISO timestamp or null');
  }
  const normalized = new Date(value).toISOString();
  if (normalized.slice(0, 19) !== value.slice(0, 19)) throw new AuthHttpError(400, 'invalid_expires_at', 'Invalid calendar date');
  return normalized;
}

function requiredString(value: unknown, field: string, maxLength: number): string {
  if (typeof value !== "string") throw new AuthHttpError(400, "invalid_request", `${field} 无效`);
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > maxLength) throw new AuthHttpError(400, "invalid_request", `${field} 无效`);
  return trimmed;
}

function optionalString(value: unknown, maxLength: number): string | null {
  if (value === undefined || value === null || value === "") return null;
  if (typeof value !== "string") throw new AuthHttpError(400, "invalid_request", "请求字段无效");
  const trimmed = value.trim();
  if (!trimmed || trimmed.length > maxLength) throw new AuthHttpError(400, "invalid_request", "请求字段无效");
  return trimmed;
}

function normalizePriority(value: unknown): string {
  const priority = optionalString(value, 32) ?? "normal";
  if (!/^[\p{L}\p{N}_-]{1,32}$/u.test(priority)) {
    throw new AuthHttpError(400, "invalid_priority", "提醒级别无效");
  }
  return priority;
}

function normalizeScopes(scopes: string[] | undefined): string[] {
  const normalized = scopes?.filter((scope) => scope === "items:write" || scope === "items:read") ?? ["items:write"];
  return normalized.length > 0 ? [...new Set(normalized)] : ["items:write"];
}

function normalizeBlocks(itemID: string, blocks: IngestContentBlockInput[] | undefined, timestamp: string): ContentBlockRecord[] {
  return (blocks ?? []).slice(0, 20).map((block, index) => ({
    id: crypto.randomUUID(),
    itemId: itemID,
    blockType: block.type ?? "text",
    body: typeof block.body === "string" ? block.body.slice(0, 20_000) : JSON.stringify(block.body).slice(0, 20_000),
    sortOrder: index,
    createdAt: timestamp
  }));
}

function parseLimit(value: string | null | undefined, fallback: number, maximum: number): number {
  const parsed = Number(value);
  if (!Number.isFinite(parsed) || parsed <= 0) return fallback;
  return Math.min(Math.trunc(parsed), maximum);
}
