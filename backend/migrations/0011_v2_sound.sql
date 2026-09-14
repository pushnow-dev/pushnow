ALTER TABLE v2_messages ADD COLUMN sound TEXT CHECK (sound IS NULL OR sound IN ('default', 'silent', 'chime'));
