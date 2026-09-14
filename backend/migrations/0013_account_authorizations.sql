ALTER TABLE v2_authorizations ADD COLUMN account_user_id TEXT REFERENCES users(id);
CREATE INDEX v2_account_authorizations_pending ON v2_authorizations(account_user_id,expires_at) WHERE source_id IS NULL;
