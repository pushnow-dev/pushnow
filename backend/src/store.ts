import type {
  AuthChallengeRecord,
  ChallengeType,
  EmailDeliveryRecord,
  SessionRecord,
  UserRecord
} from "./contracts";

export interface AuthStore {
  countRecentChallenges(emailHash: string, challengeType: ChallengeType, since: string): Promise<number>;
  createChallenge(challenge: AuthChallengeRecord): Promise<void>;
  findActiveChallenge(emailHash: string, challengeType: ChallengeType): Promise<AuthChallengeRecord | null>;
  incrementChallengeAttempts(id: string): Promise<void>;
  consumeChallenge(id: string, consumedAt: string): Promise<void>;
  findUserByID(userID: string): Promise<UserRecord | null>;
  findUserByEmailHash(emailHash: string): Promise<UserRecord | null>;
  createUser(user: UserRecord): Promise<void>;
  updateUserEmail(userID: string, email: string, emailHash: string, verifiedAt: string, updatedAt: string): Promise<void>;
  updateUserPassword(userID: string, passwordHash: string, passwordSetAt: string, updatedAt: string): Promise<void>;
  findSessionByAccessHash(accessTokenHash: string): Promise<SessionRecord | null>;
  findSessionByRefreshHash(refreshTokenHash: string): Promise<SessionRecord | null>;
  createSession(session: SessionRecord): Promise<void>;
  rotateSession(sessionID: string, accessTokenHash: string, refreshTokenHash: string, expiresAt: string, updatedAt: string): Promise<void>;
  revokeSession(sessionID: string, revokedAt: string): Promise<void>;
  revokeAllUserSessions(userID: string, revokedAt: string): Promise<void>;
  markDeletionRequested(userID: string, requestedAt: string): Promise<void>;
  recordEmailDelivery(delivery: EmailDeliveryRecord): Promise<void>;
}

type D1UserRow = {
  id: string;
  email: string;
  email_hash: string;
  email_verified_at: string;
  locale: string;
  timezone: string;
  revenuecat_app_user_id: string | null;
  password_hash: string | null;
  password_set_at: string | null;
  created_at: string;
  updated_at: string;
  deletion_requested_at: string | null;
};

type D1ChallengeRow = {
  id: string;
  challenge_type: ChallengeType;
  email: string;
  email_hash: string;
  user_id: string | null;
  code_hash: string;
  locale: string;
  timezone: string;
  client_platform: string | null;
  device_id: string | null;
  app_version: string | null;
  attempts: number;
  expires_at: string;
  consumed_at: string | null;
  created_at: string;
  sent_at: string | null;
};

type D1SessionRow = {
  id: string;
  user_id: string;
  access_token_hash: string;
  refresh_token_hash: string;
  client_platform: string | null;
  device_id: string | null;
  app_version: string | null;
  expires_at: string;
  refresh_expires_at: string;
  revoked_at: string | null;
  created_at: string;
  updated_at: string;
};

export class D1AuthStore implements AuthStore {
  constructor(private readonly db: D1Database) {}

  async countRecentChallenges(emailHash: string, challengeType: ChallengeType, since: string): Promise<number> {
    const result = await this.db
      .prepare("SELECT COUNT(*) AS count FROM auth_challenges WHERE email_hash = ? AND challenge_type = ? AND created_at >= ?")
      .bind(emailHash, challengeType, since)
      .first<{ count: number }>();
    return result?.count ?? 0;
  }

  async createChallenge(challenge: AuthChallengeRecord): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO auth_challenges (
          id, challenge_type, email, email_hash, user_id, code_hash, locale, timezone,
          client_platform, device_id, app_version, attempts, expires_at, consumed_at, created_at, sent_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .bind(
        challenge.id,
        challenge.challengeType,
        challenge.email,
        challenge.emailHash,
        challenge.userId,
        challenge.codeHash,
        challenge.locale,
        challenge.timezone,
        challenge.clientPlatform,
        challenge.deviceId,
        challenge.appVersion,
        challenge.attempts,
        challenge.expiresAt,
        challenge.consumedAt,
        challenge.createdAt,
        challenge.sentAt
      )
      .run();
  }

  async findActiveChallenge(emailHash: string, challengeType: ChallengeType): Promise<AuthChallengeRecord | null> {
    const row = await this.db
      .prepare(
        `SELECT * FROM auth_challenges
         WHERE email_hash = ? AND challenge_type = ? AND consumed_at IS NULL
         ORDER BY created_at DESC LIMIT 1`
      )
      .bind(emailHash, challengeType)
      .first<D1ChallengeRow>();
    return row ? mapChallenge(row) : null;
  }

  async incrementChallengeAttempts(id: string): Promise<void> {
    await this.db.prepare("UPDATE auth_challenges SET attempts = attempts + 1 WHERE id = ?").bind(id).run();
  }

  async consumeChallenge(id: string, consumedAt: string): Promise<void> {
    await this.db.prepare("UPDATE auth_challenges SET consumed_at = ? WHERE id = ?").bind(consumedAt, id).run();
  }

  async findUserByID(userID: string): Promise<UserRecord | null> {
    const row = await this.db.prepare("SELECT * FROM users WHERE id = ?").bind(userID).first<D1UserRow>();
    return row ? mapUser(row) : null;
  }

  async findUserByEmailHash(emailHash: string): Promise<UserRecord | null> {
    const row = await this.db.prepare("SELECT * FROM users WHERE email_hash = ?").bind(emailHash).first<D1UserRow>();
    return row ? mapUser(row) : null;
  }

  async createUser(user: UserRecord): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO users (
          id, email, email_hash, email_verified_at, locale, timezone,
          revenuecat_app_user_id, password_hash, password_set_at, created_at, updated_at, deletion_requested_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .bind(
        user.id,
        user.email,
        user.emailHash,
        user.emailVerifiedAt,
        user.locale,
        user.timezone,
        user.revenuecatAppUserId,
        user.passwordHash,
        user.passwordSetAt,
        user.createdAt,
        user.updatedAt,
        user.deletionRequestedAt
      )
      .run();
  }

  async updateUserEmail(userID: string, email: string, emailHash: string, verifiedAt: string, updatedAt: string): Promise<void> {
    await this.db
      .prepare("UPDATE users SET email = ?, email_hash = ?, email_verified_at = ?, updated_at = ? WHERE id = ?")
      .bind(email, emailHash, verifiedAt, updatedAt, userID)
      .run();
  }

  async updateUserPassword(userID: string, passwordHash: string, passwordSetAt: string, updatedAt: string): Promise<void> {
    await this.db
      .prepare("UPDATE users SET password_hash = ?, password_set_at = ?, updated_at = ? WHERE id = ?")
      .bind(passwordHash, passwordSetAt, updatedAt, userID)
      .run();
  }

  async findSessionByAccessHash(accessTokenHash: string): Promise<SessionRecord | null> {
    const row = await this.db
      .prepare("SELECT * FROM sessions WHERE access_token_hash = ? AND revoked_at IS NULL")
      .bind(accessTokenHash)
      .first<D1SessionRow>();
    return row ? mapSession(row) : null;
  }

  async findSessionByRefreshHash(refreshTokenHash: string): Promise<SessionRecord | null> {
    const row = await this.db
      .prepare("SELECT * FROM sessions WHERE refresh_token_hash = ? AND revoked_at IS NULL")
      .bind(refreshTokenHash)
      .first<D1SessionRow>();
    return row ? mapSession(row) : null;
  }

  async createSession(session: SessionRecord): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO sessions (
          id, user_id, access_token_hash, refresh_token_hash, client_platform, device_id,
          app_version, expires_at, refresh_expires_at, revoked_at, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .bind(
        session.id,
        session.userId,
        session.accessTokenHash,
        session.refreshTokenHash,
        session.clientPlatform,
        session.deviceId,
        session.appVersion,
        session.expiresAt,
        session.refreshExpiresAt,
        session.revokedAt,
        session.createdAt,
        session.updatedAt
      )
      .run();
  }

  async rotateSession(sessionID: string, accessTokenHash: string, refreshTokenHash: string, expiresAt: string, updatedAt: string): Promise<void> {
    await this.db
      .prepare("UPDATE sessions SET access_token_hash = ?, refresh_token_hash = ?, expires_at = ?, updated_at = ? WHERE id = ?")
      .bind(accessTokenHash, refreshTokenHash, expiresAt, updatedAt, sessionID)
      .run();
  }

  async revokeSession(sessionID: string, revokedAt: string): Promise<void> {
    await this.db.prepare("UPDATE sessions SET revoked_at = ?, updated_at = ? WHERE id = ?").bind(revokedAt, revokedAt, sessionID).run();
  }

  async revokeAllUserSessions(userID: string, revokedAt: string): Promise<void> {
    await this.db
      .prepare("UPDATE sessions SET revoked_at = ?, updated_at = ? WHERE user_id = ? AND revoked_at IS NULL")
      .bind(revokedAt, revokedAt, userID)
      .run();
  }

  async markDeletionRequested(userID: string, requestedAt: string): Promise<void> {
    await this.db.prepare("UPDATE users SET deletion_requested_at = ?, updated_at = ? WHERE id = ?").bind(requestedAt, requestedAt, userID).run();
  }

  async recordEmailDelivery(delivery: EmailDeliveryRecord): Promise<void> {
    await this.db
      .prepare(
        `INSERT INTO email_deliveries (
          id, user_id, email, email_hash, purpose, provider_message_id, status, error_message, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
      )
      .bind(
        delivery.id,
        delivery.userId,
        delivery.email,
        delivery.emailHash,
        delivery.purpose,
        delivery.providerMessageId,
        delivery.status,
        delivery.errorMessage,
        delivery.createdAt
      )
      .run();
  }
}

function mapUser(row: D1UserRow): UserRecord {
  return {
    id: row.id,
    email: row.email,
    emailHash: row.email_hash,
    emailVerifiedAt: row.email_verified_at,
    locale: row.locale,
    timezone: row.timezone,
    revenuecatAppUserId: row.revenuecat_app_user_id,
    passwordHash: row.password_hash,
    passwordSetAt: row.password_set_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    deletionRequestedAt: row.deletion_requested_at
  };
}

function mapChallenge(row: D1ChallengeRow): AuthChallengeRecord {
  return {
    id: row.id,
    challengeType: row.challenge_type,
    email: row.email,
    emailHash: row.email_hash,
    userId: row.user_id,
    codeHash: row.code_hash,
    locale: row.locale,
    timezone: row.timezone,
    clientPlatform: row.client_platform,
    deviceId: row.device_id,
    appVersion: row.app_version,
    attempts: row.attempts,
    expiresAt: row.expires_at,
    consumedAt: row.consumed_at,
    createdAt: row.created_at,
    sentAt: row.sent_at
  };
}

function mapSession(row: D1SessionRow): SessionRecord {
  return {
    id: row.id,
    userId: row.user_id,
    accessTokenHash: row.access_token_hash,
    refreshTokenHash: row.refresh_token_hash,
    clientPlatform: row.client_platform,
    deviceId: row.device_id,
    appVersion: row.app_version,
    expiresAt: row.expires_at,
    refreshExpiresAt: row.refresh_expires_at,
    revokedAt: row.revoked_at,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}
