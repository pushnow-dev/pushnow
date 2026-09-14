CREATE TABLE sender_security_state (
 key_id TEXT PRIMARY KEY REFERENCES source_keys(id) ON DELETE CASCADE,
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 suspended_until INTEGER NOT NULL DEFAULT 0,
 suspension_event_id TEXT
);
CREATE INDEX sender_security_owner ON sender_security_state(user_id);
CREATE TABLE sender_security_events (
 id TEXT PRIMARY KEY,
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 key_id TEXT,
 kind TEXT NOT NULL CHECK(kind IN ('key_request','notification','email','email_attempt')),
 occurred_at INTEGER NOT NULL
);
CREATE INDEX sender_security_key_window ON sender_security_events(key_id,kind,occurred_at);
CREATE INDEX sender_security_user_window ON sender_security_events(user_id,kind,occurred_at);

CREATE TABLE sender_security_mail (
 id TEXT PRIMARY KEY,
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 suspended_until INTEGER NOT NULL,
 created_at INTEGER NOT NULL,
 next_attempt_at INTEGER NOT NULL,
 attempts INTEGER NOT NULL DEFAULT 0,
 lease_id TEXT,
 lease_until INTEGER,
 sent_at INTEGER
);
CREATE INDEX sender_security_mail_due ON sender_security_mail(sent_at,next_attempt_at,lease_until);
