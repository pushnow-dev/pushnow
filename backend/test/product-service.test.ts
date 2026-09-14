import { describe, expect, it } from "vitest";
import { ProductService } from "../src/product-service";
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
} from "../src/product-contracts";
import type { ProductStore } from "../src/product-store";

class MemoryProductStore implements ProductStore {
  async isSourceEncryptionRequired(): Promise<boolean> { return false; }
  sources: SourceRecord[] = [];
  sourceKeys: SourceKeyRecord[] = [];
  items: ItemRecord[] = [];
  blocks: ContentBlockRecord[] = [];
  reminders: ReminderPlanRecord[] = [];
  devices: DevicePushTokenRecord[] = [];
  plans: MembershipPlanRecord[] = [];
  usage: UsageCounterRecord[] = [];

  async listSources(userID: string): Promise<SourceRecord[]> {
    return this.sources.filter((source) => source.userId === userID);
  }

  async findSource(userID: string, sourceID: string): Promise<SourceRecord | null> {
    return this.sources.find((source) => source.userId === userID && source.id === sourceID) ?? null;
  }

  async findSourceByID(sourceID: string): Promise<SourceRecord | null> {
    return this.sources.find((source) => source.id === sourceID) ?? null;
  }

  async createSource(source: SourceRecord): Promise<void> {
    this.sources.push(source);
  }

  async createSourceKey(key: SourceKeyRecord): Promise<void> {
    this.sourceKeys.push(key);
  }

  async countActiveSourceKeys(userID: string, sourceID: string, now: string): Promise<number> {
    const nowMs = Date.parse(now);
    return this.sourceKeys.filter((key) => key.userId === userID && key.sourceId === sourceID && key.revokedAt === null && (key.expiresAt == null || Date.parse(key.expiresAt) > nowMs)).length;
  }

  async findActiveSourceKeyByPrefix(keyPrefix: string): Promise<SourceKeyRecord | null> {
    return this.sourceKeys.find((key) => key.keyPrefix === keyPrefix && key.revokedAt === null) ?? null;
  }

  async touchSourceKey(keyID: string, usedAt: string): Promise<void> {
    const key = this.sourceKeys.find((item) => item.id === keyID);
    if (key) key.lastUsedAt = usedAt;
  }

  async findItemBySourceIdempotency(sourceID: string, idempotencyKey: string): Promise<ItemRecord | null> {
    return this.items.find((item) => item.sourceId === sourceID && item.idempotencyKey === idempotencyKey) ?? null;
  }

  async createItemWithBlocksAndReminder(item: ItemRecord, blocks: ContentBlockRecord[], reminder: ReminderPlanRecord | null): Promise<void> {
    if (await this.findItemBySourceIdempotency(item.sourceId, item.idempotencyKey)) return;
    this.items.push(item);
    this.blocks.push(...blocks);
    if (reminder) this.reminders.push(reminder);
  }

  async listItems(userID: string, limit: number): Promise<ItemRecord[]> {
    return this.items.filter((item) => item.userId === userID).slice(0, limit);
  }

  async findItem(userID: string, itemID: string): Promise<ItemRecord | null> {
    return this.items.find((item) => item.userId === userID && item.id === itemID) ?? null;
  }

  async updateItemState(userID: string, itemID: string, status: ItemStatus | null, acknowledgedAt: string | null, updatedAt: string): Promise<ItemRecord | null> {
    const item = await this.findItem(userID, itemID);
    if (!item) return null;
    if (status) item.status = status;
    if (acknowledgedAt) item.acknowledgedAt = acknowledgedAt;
    item.updatedAt = updatedAt;
    return item;
  }

  async createReminderPlan(reminder: ReminderPlanRecord): Promise<void> {
    this.reminders.push(reminder);
  }

  async listReminderPlans(userID: string, limit: number): Promise<ReminderPlanRecord[]> {
    return this.reminders.filter((reminder) => reminder.userId === userID).slice(0, limit);
  }

  async upsertDevicePushToken(token: DevicePushTokenRecord): Promise<void> {
    this.devices = this.devices.filter((device) => device.tokenHash !== token.tokenHash);
    this.devices.push(token);
  }

  async getMembershipPlan(userID: string, now: string): Promise<MembershipPlanRecord | null> {
    return this.plans.find((plan) => plan.userId === userID && (!plan.expiresAt || plan.expiresAt > now)) ?? null;
  }

  async getUsageCounter(userID: string, featureKey: UsageFeatureKey, windowStart: string): Promise<UsageCounterRecord | null> {
    return this.usage.find((item) => item.userId === userID && item.featureKey === featureKey && item.windowStart === windowStart) ?? null;
  }

  async incrementUsageCounter(userID: string, featureKey: UsageFeatureKey, windowStart: string, windowEnd: string, updatedAt: string): Promise<UsageCounterRecord> {
    let counter = await this.getUsageCounter(userID, featureKey, windowStart);
    if (!counter) {
      counter = { userId: userID, featureKey, windowStart, windowEnd, usedCount: 0, updatedAt };
      this.usage.push(counter);
    }
    counter.usedCount += 1;
    counter.windowEnd = windowEnd;
    counter.updatedAt = updatedAt;
    return counter;
  }
}

function makeService(store = new MemoryProductStore()): { service: ProductService; store: MemoryProductStore } {
  return {
    service: new ProductService(store, { authTokenPepper: "test-pepper" }, () => new Date("2026-09-12T05:00:00.000Z")),
    store
  };
}

describe("ProductService", () => {
  it("creates user-scoped sources and source keys without storing raw keys", async () => {
    const { service, store } = makeService();

    const source = await service.createSource("user-1", {
      name: "Research Agent",
      sourceType: "agent",
      defaultPriority: "P1",
      defaultPushEnabled: false
    });
    const key = await service.createSourceKey("user-1", source.id, { scopes: ["items:write"] });

    expect(await service.listSources("user-1")).toHaveLength(1);
    expect(await service.listSources("user-2")).toHaveLength(0);
    expect(key.sourceKey).toMatch(/^jzs_/);
    expect(key.record.keyPrefix).toBe(key.sourceKey.slice(0, 18));
    expect(key.record.keyHash).not.toContain(key.sourceKey);
    expect(store.sourceKeys[0].userId).toBe("user-1");
  });

  it("limits each source to two active keys", async () => {
    const { service, store } = makeService();
    const source = await service.createSource("user-1", { name: "Dashboard" });

    await service.createSourceKey("user-1", source.id, {});
    await service.createSourceKey("user-1", source.id, {});
    await expect(service.createSourceKey("user-1", source.id, {})).rejects.toMatchObject({ status: 409, code: "source_key_limit_exceeded" });

    store.sourceKeys[0].revokedAt = "2026-09-12T05:01:00.000Z";
    await expect(service.createSourceKey("user-1", source.id, {})).resolves.toMatchObject({ record: { sourceId: source.id } });
  });

  it("ingests source-key items idempotently and binds them to the owner user", async () => {
    const { service, store } = makeService();
    const source = await service.createSource("user-1", { name: "CLI", defaultPriority: "重要" });
    const key = await service.createSourceKey("user-1", source.id, {});

    const first = await service.ingestItem(key.sourceKey, "run-123", {
      title: "Deploy finished",
      summary: "Production smoke passed",
      priority: "P0",
      pushEnabled: true,
      requiresAck: true,
      contentBlocks: [{ type: "markdown", body: "## Result" }],
      reminder: { mode: "scheduled", scheduledAt: "2026-09-13T09:00:00.000Z", timezone: "Asia/Shanghai", pushEnabled: false }
    });
    const second = await service.ingestItem(key.sourceKey, "run-123", { title: "Deploy finished again" });

    expect(first.deduplicated).toBe(false);
    expect(second.deduplicated).toBe(true);
    expect(second.item.id).toBe(first.item.id);
    expect(store.items).toHaveLength(1);
    expect(store.items[0].userId).toBe("user-1");
    expect(store.items[0].priority).toBe("P0");
    expect(store.reminders[0].pushEnabled).toBe(false);
    expect(await service.listItems("user-2")).toHaveLength(0);
  });

  it("updates item state, creates reminders, and upserts APNs tokens by user", async () => {
    const { service, store } = makeService();
    const source = await service.createSource("user-1", { name: "Monitor" });
    const key = await service.createSourceKey("user-1", source.id, {});
    const ingest = await service.ingestItem(key.sourceKey, "alert-1", { title: "CPU alert", pushEnabled: true });

    const updated = await service.updateItemState("user-1", ingest.item.id, { status: "read", acknowledged: true });
    const reminder = await service.createReminder("user-1", ingest.item.id, { mode: "now", priority: "P1", requiresAck: true });
    const device = await service.upsertDevicePushToken("user-1", { token: "apns-token", environment: "sandbox", appVersion: "1.0" });

    expect(updated.status).toBe("read");
    expect(updated.acknowledgedAt).not.toBeNull();
    expect(reminder.priority).toBe("P1");
    expect(reminder.pushEnabled).toBe(true);
    expect(device.platform).toBe("ios");
    expect(store.devices[0].userId).toBe("user-1");
  });

  it("accepts Harmony as a user-bound push platform", async () => {
    const { service, store } = makeService();

    const device = await service.upsertDevicePushToken("user-1", {
      token: "harmony-push-token-0123456789",
      platform: "harmony",
      environment: "production",
      appVersion: "1.0.0"
    });

    expect(device.platform).toBe("harmony");
    expect(store.devices[0].platform).toBe("harmony");
    expect(store.devices[0].userId).toBe("user-1");
  });

  it("limits Free users to 50 notification events per UTC day", async () => {
    const { service } = makeService();
    const source = await service.createSource("user-1", { name: "Quota" });
    const key = await service.createSourceKey("user-1", source.id, {});

    for (let index = 0; index < 50; index += 1) {
      await service.ingestItem(key.sourceKey, `item-${index}`, { title: `Alert ${index}` });
    }

    await expect(service.ingestItem(key.sourceKey, "item-50", { title: "Alert 50" })).rejects.toMatchObject({
      status: 402,
      code: "quota_exceeded"
    });
  });

  it("does not limit Pro users", async () => {
    const { service, store } = makeService();
    store.plans.push({
      userId: "user-1",
      plan: "pro",
      source: "revenuecat",
      revenuecatEntitlementId: "pro",
      revenuecatProductId: "com.createitv.pushnow.pro.monthly",
      expiresAt: null,
      updatedAt: "2026-09-12T05:00:00.000Z"
    });
    const source = await service.createSource("user-1", { name: "Quota" });
    const key = await service.createSourceKey("user-1", source.id, {});

    for (let index = 0; index < 55; index += 1) {
      await service.ingestItem(key.sourceKey, `pro-item-${index}`, { title: `Alert ${index}` });
    }

    expect(store.items).toHaveLength(55);
  });
});
