-- Additions after the deployed 0004 baseline. Existing device/session bindings stay intact.
CREATE TABLE secure_registration_challenges (
 session_id TEXT PRIMARY KEY REFERENCES sessions(id),
 challenge_hash TEXT NOT NULL,
 expires_at TEXT NOT NULL
);
ALTER TABLE secure_messages ADD COLUMN quota_remaining INTEGER NOT NULL DEFAULT 0 CHECK(quota_remaining>=0);
