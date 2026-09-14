CREATE TABLE secure_identities (user_id TEXT PRIMARY KEY REFERENCES users(id), public_key TEXT NOT NULL, created_at TEXT NOT NULL);
CREATE TABLE secure_devices (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), name TEXT NOT NULL, platform TEXT NOT NULL,
 public_key TEXT NOT NULL, certificate TEXT, status TEXT NOT NULL CHECK(status IN ('pending','active','revoked')),
 notifications_enabled INTEGER NOT NULL DEFAULT 1, last_seen_at TEXT NOT NULL, created_at TEXT NOT NULL,
 approval_enc TEXT, approval_ciphertext TEXT
);
CREATE INDEX secure_devices_owner ON secure_devices(user_id,status);
CREATE TABLE secure_push_tokens (
 device_id TEXT PRIMARY KEY REFERENCES secure_devices(id), environment TEXT NOT NULL,
 token_hash TEXT NOT NULL UNIQUE, token_encrypted TEXT NOT NULL, app_version TEXT, updated_at TEXT NOT NULL
);
CREATE TABLE secure_sources (source_id TEXT PRIMARY KEY REFERENCES sources(id), user_id TEXT NOT NULL REFERENCES users(id), public_key TEXT NOT NULL, certificate TEXT NOT NULL);
CREATE TABLE secure_messages (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), source_id TEXT NOT NULL REFERENCES sources(id),
 request_hash TEXT NOT NULL, expires_at TEXT NOT NULL, scheduled_at TEXT NOT NULL, created_at TEXT NOT NULL
);
CREATE TABLE secure_deliveries (
 message_id TEXT NOT NULL REFERENCES secure_messages(id), device_id TEXT NOT NULL REFERENCES secure_devices(id),
 enc TEXT NOT NULL, ciphertext TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'pending', attempts INTEGER NOT NULL DEFAULT 0,
 next_attempt_at TEXT NOT NULL, lease_until TEXT, lease_id TEXT, last_error TEXT, accepted_at TEXT, acknowledged_at TEXT,
 PRIMARY KEY(message_id,device_id)
);
CREATE INDEX secure_delivery_due ON secure_deliveries(status,next_attempt_at);
-- Previously supplied client device IDs were not cryptographically authenticated.
UPDATE sessions SET device_id = NULL;
