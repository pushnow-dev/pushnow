ALTER TABLE users ADD COLUMN password_hash TEXT;
ALTER TABLE users ADD COLUMN password_set_at TEXT;

CREATE TABLE IF NOT EXISTS entitlements (
  user_id TEXT PRIMARY KEY,
  plan TEXT NOT NULL DEFAULT 'free',
  source TEXT NOT NULL DEFAULT 'default',
  revenuecat_entitlement_id TEXT,
  revenuecat_product_id TEXT,
  expires_at TEXT,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_entitlements_plan_expires
  ON entitlements(plan, expires_at);

CREATE TABLE IF NOT EXISTS usage_counters (
  user_id TEXT NOT NULL,
  feature_key TEXT NOT NULL,
  window_start TEXT NOT NULL,
  window_end TEXT NOT NULL,
  used_count INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (user_id, feature_key, window_start),
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_usage_counters_window
  ON usage_counters(feature_key, window_start, window_end);
