import { describe, expect, it } from "vitest";
import { readJsonBody } from "../src/http";

describe("readJsonBody", () => {
  it("converts public snake_case request fields to internal camelCase", async () => {
    const request = new Request("https://api.pushnow.dev/v1/ingest/items", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        source_type: "agent",
        push_enabled: false,
        requires_ack: true,
        content_blocks: [{ type: "json", body: { keep_snake_case: true } }],
        reminder: { scheduled_at: "2026-09-13T09:00:00.000Z" }
      })
    });

    await expect(readJsonBody(request)).resolves.toEqual({
      sourceType: "agent",
      pushEnabled: false,
      requiresAck: true,
      contentBlocks: [{ type: "json", body: { keep_snake_case: true } }],
      reminder: { scheduledAt: "2026-09-13T09:00:00.000Z" }
    });
  });
});
