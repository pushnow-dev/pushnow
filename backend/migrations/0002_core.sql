CREATE TABLE IF NOT EXISTS sources (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  source_type TEXT NOT NULL,
  default_priority TEXT NOT NULL DEFAULT 'normal',
  default_push_enabled INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL DEFAULT 'active',
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_sources_user_id ON sources(user_id, status, created_at);

CREATE TABLE IF NOT EXISTS source_keys (
  id TEXT PRIMARY KEY,
  source_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  key_prefix TEXT NOT NULL UNIQUE,
  key_hash TEXT NOT NULL UNIQUE,
  scopes TEXT NOT NULL,
  created_at TEXT NOT NULL,
  last_used_at TEXT,
  revoked_at TEXT,
  FOREIGN KEY (source_id) REFERENCES sources(id),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_source_keys_source_id ON source_keys(source_id, revoked_at);

CREATE TABLE IF NOT EXISTS items (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  source_id TEXT NOT NULL,
  external_id TEXT,
  idempotency_key TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT,
  status TEXT NOT NULL DEFAULT 'unread',
  priority TEXT NOT NULL DEFAULT 'normal',
  push_enabled INTEGER NOT NULL DEFAULT 1,
  requires_ack INTEGER NOT NULL DEFAULT 0,
  received_at TEXT NOT NULL,
  read_at TEXT,
  archived_at TEXT,
  acknowledged_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (source_id) REFERENCES sources(id),
  UNIQUE (source_id, idempotency_key),
  UNIQUE (source_id, external_id)
);

CREATE INDEX IF NOT EXISTS idx_items_user_status_received ON items(user_id, status, received_at);
CREATE INDEX IF NOT EXISTS idx_items_source_received ON items(source_id, received_at);

CREATE TABLE IF NOT EXISTS content_blocks (
  id TEXT PRIMARY KEY,
  item_id TEXT NOT NULL,
  block_type TEXT NOT NULL,
  body TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (item_id) REFERENCES items(id)
);

CREATE INDEX IF NOT EXISTS idx_content_blocks_item_id ON content_blocks(item_id, sort_order);

CREATE TABLE IF NOT EXISTS reminder_plans (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  item_id TEXT NOT NULL,
  mode TEXT NOT NULL,
  scheduled_at TEXT,
  timezone TEXT NOT NULL DEFAULT 'UTC',
  repeat_rule TEXT,
  priority TEXT NOT NULL DEFAULT 'normal',
  push_enabled INTEGER NOT NULL DEFAULT 1,
  requires_ack INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'scheduled',
  next_fire_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  cancelled_at TEXT,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (item_id) REFERENCES items(id)
);

CREATE INDEX IF NOT EXISTS idx_reminder_plans_user_status ON reminder_plans(user_id, status, next_fire_at);
CREATE INDEX IF NOT EXISTS idx_reminder_plans_due ON reminder_plans(status, next_fire_at);

CREATE TABLE IF NOT EXISTS deliveries (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  reminder_plan_id TEXT,
  channel TEXT NOT NULL,
  provider TEXT NOT NULL,
  status TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  triggered_at TEXT,
  completed_at TEXT,
  error_message TEXT,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (reminder_plan_id) REFERENCES reminder_plans(id)
);

CREATE INDEX IF NOT EXISTS idx_deliveries_user_id ON deliveries(user_id, created_at);
