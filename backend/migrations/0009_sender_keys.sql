ALTER TABLE source_keys ADD COLUMN expires_at TEXT;
ALTER TABLE v2_messages ADD COLUMN source_key_id TEXT REFERENCES source_keys(id);
CREATE INDEX v2_message_key_history ON v2_messages(user_id,source_key_id,created_at,id);
CREATE INDEX source_key_owner ON source_keys(user_id,created_at,id);
