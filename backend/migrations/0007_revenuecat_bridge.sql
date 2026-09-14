CREATE UNIQUE INDEX users_revenuecat_identity ON users(revenuecat_app_user_id) WHERE revenuecat_app_user_id IS NOT NULL;
CREATE TABLE revenuecat_events(id TEXT PRIMARY KEY,payload_hash TEXT NOT NULL,event_ms INTEGER NOT NULL,status TEXT NOT NULL,created_at TEXT NOT NULL);
CREATE TABLE revenuecat_sync(user_id TEXT PRIMARY KEY REFERENCES users(id),last_event_ms INTEGER NOT NULL DEFAULT 0,last_snapshot_ms INTEGER NOT NULL DEFAULT 0,lease_id TEXT,lease_until TEXT,transfer_blocked INTEGER NOT NULL DEFAULT 0);
CREATE TABLE revenuecat_entitlement_states(user_id TEXT NOT NULL REFERENCES users(id),plan TEXT NOT NULL CHECK(plan IN ('plus','pro')),entitlement_id TEXT NOT NULL,product_id TEXT NOT NULL,expires_at TEXT NOT NULL,updated_at TEXT NOT NULL,PRIMARY KEY(user_id,plan));
