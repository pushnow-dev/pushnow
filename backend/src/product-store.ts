import type {
  ContentBlockRecord,
  DevicePushTokenRecord,
  ItemRecord,
  ItemStatus,
  MembershipPlanRecord,
  ReminderPlanRecord,
  SourceKeyRecord,
  SourceRecord,
  UsageCounterRecord,
  UsageFeatureKey
} from "./product-contracts";

export interface ProductStore {
  isSourceEncryptionRequired(sourceID: string): Promise<boolean>;
  listSources(userID: string): Promise<SourceRecord[]>;
  findSource(userID: string, sourceID: string): Promise<SourceRecord | null>;
  findSourceByID(sourceID: string): Promise<SourceRecord | null>;
  createSource(source: SourceRecord): Promise<void>;
  createSourceKey(key: SourceKeyRecord): Promise<void>;
  countActiveSourceKeys(userID: string, sourceID: string, now: string): Promise<number>;
  findActiveSourceKeyByPrefix(keyPrefix: string): Promise<SourceKeyRecord | null>;
  touchSourceKey(keyID: string, usedAt: string): Promise<void>;
  findItemBySourceIdempotency(sourceID: string, idempotencyKey: string): Promise<ItemRecord | null>;
  createItemWithBlocksAndReminder(item: ItemRecord, blocks: ContentBlockRecord[], reminder: ReminderPlanRecord | null): Promise<void>;
  listItems(userID: string, limit: number): Promise<ItemRecord[]>;
  findItem(userID: string, itemID: string): Promise<ItemRecord | null>;
  updateItemState(userID: string, itemID: string, status: ItemStatus | null, acknowledgedAt: string | null, updatedAt: string): Promise<ItemRecord | null>;
  createReminderPlan(reminder: ReminderPlanRecord): Promise<void>;
  listReminderPlans(userID: string, limit: number): Promise<ReminderPlanRecord[]>;
  upsertDevicePushToken(token: DevicePushTokenRecord): Promise<void>;
  getMembershipPlan(userID: string, now: string): Promise<MembershipPlanRecord | null>;
  getUsageCounter(userID: string, featureKey: UsageFeatureKey, windowStart: string): Promise<UsageCounterRecord | null>;
  incrementUsageCounter(userID: string, featureKey: UsageFeatureKey, windowStart: string, windowEnd: string, updatedAt: string): Promise<UsageCounterRecord>;
}

type D1SourceRow = {
  id: string;
  user_id: string;
  name: string;
  source_type: SourceRecord["sourceType"];
  default_priority: string;
  default_push_enabled: number;
  status: SourceRecord["status"];
  created_at: string;
  updated_at: string;
};

type D1SourceKeyRow = {
  expires_at: string | null;
  id: string;
  source_id: string;
  user_id: string;
  key_prefix: string;
  key_hash: string;
  scopes: string;
  created_at: string;
  last_used_at: string | null;
  revoked_at: string | null;
};

type D1ItemRow = {
  id: string;
  user_id: string;
  source_id: string;
  external_id: string | null;
  idempotency_key: string;
  title: string;
  summary: string | null;
  status: ItemStatus;
  priority: string;
  push_enabled: number;
  requires_ack: number;
  received_at: string;
  read_at: string | null;
  archived_at: string | null;
  acknowledged_at: string | null;
  created_at: string;
  updated_at: string;
};

type D1ReminderRow = {
  id: string;
  user_id: string;
  item_id: string;
  mode: ReminderPlanRecord["mode"];
  scheduled_at: string | null;
  timezone: string;
  repeat_rule: string | null;
  priority: string;
  push_enabled: number;
  requires_ack: number;
  status: ReminderPlanRecord["status"];
  next_fire_at: string | null;
  created_at: string;
  updated_at: string;
  cancelled_at: string | null;
};

type D1MembershipPlanRow = {
  user_id: string;
  plan: MembershipPlanRecord["plan"];
  source: MembershipPlanRecord["source"];
  revenuecat_entitlement_id: string | null;
  revenuecat_product_id: string | null;
  expires_at: string | null;
  updated_at: string;
};

type D1UsageCounterRow = {
  user_id: string;
  feature_key: UsageFeatureKey;
  window_start: string;
  window_end: string;
  used_count: number;
  updated_at: string;
};

export class D1ProductStore implements ProductStore {
  constructor(private readonly db: D1Database) {}
  async isSourceEncryptionRequired(sourceID: string): Promise<boolean> {
    return Boolean(await this.db.prepare('SELECT source_id FROM secure_sources WHERE source_id=?').bind(sourceID).first());
  }
  async listSources(userID: string): Promise<SourceRecord[]> {
    const result = await this.db.prepare("SELECT * FROM sources WHERE user_id = ? ORDER BY created_at DESC").bind(userID).all<D1SourceRow>();
    return result.results.map(mapSource);
  }

  async findSource(userID: string, sourceID: string): Promise<SourceRecord | null> {
    const row = await this.db.prepare("SELECT * FROM sources WHERE user_id = ? AND id = ?").bind(userID, sourceID).first<D1SourceRow>();
    return row ? mapSource(row) : null;
  }
  async findSourceByID(sourceID: string): Promise<SourceRecord | null> {
    const row = await this.db.prepare("SELECT * FROM sources WHERE id = ?").bind(sourceID).first<D1SourceRow>();
    return row ? mapSource(row) : null;
  }

  async createSource(source: SourceRecord): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO sources (
          id, user_id, name, source_type, default_priority, default_push_enabled, status, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .bind(source.id, source.userId, source.name, source.sourceType, source.defaultPriority, boolToInt(source.defaultPushEnabled), source.status, source.createdAt, source.updatedAt)
      .run();
  }

  async createSourceKey(key: SourceKeyRecord): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO source_keys (
          id, source_id, user_id, key_prefix, key_hash, scopes, created_at, last_used_at, revoked_at, expires_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .bind(key.id, key.sourceId, key.userId, key.keyPrefix, key.keyHash, JSON.stringify(key.scopes), key.createdAt, key.lastUsedAt, key.revokedAt, key.expiresAt ?? null)
      .run();
  }

  async countActiveSourceKeys(userID: string, sourceID: string, now: string): Promise<number> {
    const row = await this.db
      .prepare("SELECT COUNT(*) AS count FROM source_keys WHERE user_id = ? AND source_id = ? AND revoked_at IS NULL AND (expires_at IS NULL OR expires_at > ?)")
      .bind(userID, sourceID, now)
      .first<{ count: number }>();
    return row?.count ?? 0;
  }

  async findActiveSourceKeyByPrefix(keyPrefix: string): Promise<SourceKeyRecord | null> {
    const row = await this.db
      .prepare("SELECT * FROM source_keys WHERE key_prefix = ? AND revoked_at IS NULL")
      .bind(keyPrefix)
      .first<D1SourceKeyRow>();
    return row ? mapSourceKey(row) : null;
  }

  async touchSourceKey(keyID: string, usedAt: string): Promise<void> {
    await this.db.prepare("UPDATE source_keys SET last_used_at = ? WHERE id = ?").bind(usedAt, keyID).run();
  }
  async findItemBySourceIdempotency(sourceID: string, idempotencyKey: string): Promise<ItemRecord | null> {
    const row = await this.db
      .prepare("SELECT * FROM items WHERE source_id = ? AND idempotency_key = ?")
      .bind(sourceID, idempotencyKey)
      .first<D1ItemRow>();
    return row ? mapItem(row) : null;
  }

  async createItemWithBlocksAndReminder(item: ItemRecord, blocks: ContentBlockRecord[], reminder: ReminderPlanRecord | null): Promise<void> {
    const statements = [
      this.db
        .prepare(
          `INSERT INTO items (
            id, user_id, source_id, external_id, idempotency_key, title, summary, status, priority,
            push_enabled, requires_ack, received_at, read_at, archived_at, acknowledged_at, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
        )
        .bind(
          item.id,
          item.userId,
          item.sourceId,
          item.externalId,
          item.idempotencyKey,
          item.title,
          item.summary,
          item.status,
          item.priority,
          boolToInt(item.pushEnabled),
          boolToInt(item.requiresAck),
          item.receivedAt,
          item.readAt,
          item.archivedAt,
          item.acknowledgedAt,
          item.createdAt,
          item.updatedAt
        ),
      ...blocks.map((block) =>
        this.db
          .prepare("INSERT INTO content_blocks (id, item_id, block_type, body, sort_order, created_at) VALUES (?, ?, ?, ?, ?, ?)")
          .bind(block.id, block.itemId, block.blockType, block.body, block.sortOrder, block.createdAt)
      )
    ];
    if (reminder) {
      statements.push(reminderStatement(this.db, reminder));
    }
    await this.db.batch(statements);
  }
  async listItems(userID: string, limit: number): Promise<ItemRecord[]> {
    const result = await this.db
      .prepare("SELECT * FROM items WHERE user_id = ? ORDER BY received_at DESC LIMIT ?")
      .bind(userID, limit)
      .all<D1ItemRow>();
    return result.results.map(mapItem);
  }

  async findItem(userID: string, itemID: string): Promise<ItemRecord | null> {
    const row = await this.db.prepare("SELECT * FROM items WHERE user_id = ? AND id = ?").bind(userID, itemID).first<D1ItemRow>();
    return row ? mapItem(row) : null;
  }

  async updateItemState(userID: string, itemID: string, status: ItemStatus | null, acknowledgedAt: string | null, updatedAt: string): Promise<ItemRecord | null> {
    const readAt = status === "read" ? updatedAt : null;
    const archivedAt = status === "archived" ? updatedAt : null;
    await this.db
      .prepare(
        `UPDATE items
         SET status = COALESCE(?, status),
             read_at = COALESCE(?, read_at),
             archived_at = COALESCE(?, archived_at),
             acknowledged_at = COALESCE(?, acknowledged_at),
             updated_at = ?
         WHERE user_id = ? AND id = ?`
      )
      .bind(status, readAt, archivedAt, acknowledgedAt, updatedAt, userID, itemID)
      .run();
    return this.findItem(userID, itemID);
  }

  async createReminderPlan(reminder: ReminderPlanRecord): Promise<void> {
    await reminderStatement(this.db, reminder).run();
  }

  async listReminderPlans(userID: string, limit: number): Promise<ReminderPlanRecord[]> {
    const result = await this.db
      .prepare("SELECT * FROM reminder_plans WHERE user_id = ? ORDER BY COALESCE(next_fire_at, created_at) ASC LIMIT ?")
      .bind(userID, limit)
      .all<D1ReminderRow>();
    return result.results.map(mapReminder);
  }

  async upsertDevicePushToken(token: DevicePushTokenRecord): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO device_push_tokens (
          id, user_id, platform, token_hash, token_encrypted, app_version, enabled, created_at, updated_at, revoked_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(token_hash) DO UPDATE SET
          user_id = excluded.user_id,
          platform = excluded.platform,
          token_encrypted = excluded.token_encrypted,
          app_version = excluded.app_version,
          enabled = excluded.enabled,
          updated_at = excluded.updated_at,
          revoked_at = NULL`
      )
      .bind(token.id, token.userId, token.platform, token.tokenHash, token.tokenEncrypted, token.appVersion, boolToInt(token.enabled), token.createdAt, token.updatedAt, token.revokedAt)
      .run();
  }

  async getMembershipPlan(userID: string, now: string): Promise<MembershipPlanRecord | null> {
    const revenuecat = await this.db.prepare("SELECT user_id,plan,'revenuecat' AS source,entitlement_id AS revenuecat_entitlement_id,product_id AS revenuecat_product_id,expires_at,updated_at FROM revenuecat_entitlement_states WHERE user_id=? AND expires_at>? ORDER BY CASE plan WHEN 'pro' THEN 2 ELSE 1 END DESC LIMIT 1").bind(userID,now).first<D1MembershipPlanRow>();
    if(revenuecat)return mapMembershipPlan(revenuecat);
    const row = await this.db
      .prepare("SELECT * FROM entitlements WHERE user_id = ? AND (expires_at IS NULL OR expires_at > ?) ORDER BY updated_at DESC LIMIT 1")
      .bind(userID, now)
      .first<D1MembershipPlanRow>();
    return row ? mapMembershipPlan(row) : null;
  }

  async getUsageCounter(userID: string, featureKey: UsageFeatureKey, windowStart: string): Promise<UsageCounterRecord | null> {
    const row = await this.db
      .prepare("SELECT * FROM usage_counters WHERE user_id = ? AND feature_key = ? AND window_start = ?")
      .bind(userID, featureKey, windowStart)
      .first<D1UsageCounterRow>();
    return row ? mapUsageCounter(row) : null;
  }

  async incrementUsageCounter(userID: string, featureKey: UsageFeatureKey, windowStart: string, windowEnd: string, updatedAt: string): Promise<UsageCounterRecord> {
    await this.db
      .prepare(
        `INSERT INTO usage_counters (user_id, feature_key, window_start, window_end, used_count, updated_at)
         VALUES (?, ?, ?, ?, 1, ?)
         ON CONFLICT(user_id, feature_key, window_start)
         DO UPDATE SET used_count = used_count + 1, window_end = excluded.window_end, updated_at = excluded.updated_at`
      )
      .bind(userID, featureKey, windowStart, windowEnd, updatedAt)
      .run();
    const counter = await this.getUsageCounter(userID, featureKey, windowStart);
    if (!counter) throw new Error("usage counter write failed");
    return counter;
  }
}

function reminderStatement(db: D1Database, reminder: ReminderPlanRecord): D1PreparedStatement {
  return db
    .prepare(
      `INSERT INTO reminder_plans (
        id, user_id, item_id, mode, scheduled_at, timezone, repeat_rule, priority, push_enabled,
        requires_ack, status, next_fire_at, created_at, updated_at, cancelled_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .bind(
      reminder.id,
      reminder.userId,
      reminder.itemId,
      reminder.mode,
      reminder.scheduledAt,
      reminder.timezone,
      reminder.repeatRule,
      reminder.priority,
      boolToInt(reminder.pushEnabled),
      boolToInt(reminder.requiresAck),
      reminder.status,
      reminder.nextFireAt,
      reminder.createdAt,
      reminder.updatedAt,
      reminder.cancelledAt
    );
}

function mapSource(row: D1SourceRow): SourceRecord {
  return {
    id: row.id,
    userId: row.user_id,
    name: row.name,
    sourceType: row.source_type,
    defaultPriority: row.default_priority,
    defaultPushEnabled: Boolean(row.default_push_enabled),
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function mapSourceKey(row: D1SourceKeyRow): SourceKeyRecord {
  return {
    expiresAt: row.expires_at ?? null,
    id: row.id,
    sourceId: row.source_id,
    userId: row.user_id,
    keyPrefix: row.key_prefix,
    keyHash: row.key_hash,
    scopes: JSON.parse(row.scopes) as string[],
    createdAt: row.created_at,
    lastUsedAt: row.last_used_at,
    revokedAt: row.revoked_at
  };
}

function mapItem(row: D1ItemRow): ItemRecord {
  return {
    id: row.id,
    userId: row.user_id,
    sourceId: row.source_id,
    externalId: row.external_id,
    idempotencyKey: row.idempotency_key,
    title: row.title,
    summary: row.summary,
    status: row.status,
    priority: row.priority,
    pushEnabled: Boolean(row.push_enabled),
    requiresAck: Boolean(row.requires_ack),
    receivedAt: row.received_at,
    readAt: row.read_at,
    archivedAt: row.archived_at,
    acknowledgedAt: row.acknowledged_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function mapReminder(row: D1ReminderRow): ReminderPlanRecord {
  return {
    id: row.id,
    userId: row.user_id,
    itemId: row.item_id,
    mode: row.mode,
    scheduledAt: row.scheduled_at,
    timezone: row.timezone,
    repeatRule: row.repeat_rule,
    priority: row.priority,
    pushEnabled: Boolean(row.push_enabled),
    requiresAck: Boolean(row.requires_ack),
    status: row.status,
    nextFireAt: row.next_fire_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    cancelledAt: row.cancelled_at
  };
}

function mapMembershipPlan(row: D1MembershipPlanRow): MembershipPlanRecord {
  return {
    userId: row.user_id,
    plan: row.plan,
    source: row.source,
    revenuecatEntitlementId: row.revenuecat_entitlement_id,
    revenuecatProductId: row.revenuecat_product_id,
    expiresAt: row.expires_at,
    updatedAt: row.updated_at
  };
}

function mapUsageCounter(row: D1UsageCounterRow): UsageCounterRecord {
  return {
    userId: row.user_id,
    featureKey: row.feature_key,
    windowStart: row.window_start,
    windowEnd: row.window_end,
    usedCount: row.used_count,
    updatedAt: row.updated_at
  };
}

function boolToInt(value: boolean): number {
  return value ? 1 : 0;
}
