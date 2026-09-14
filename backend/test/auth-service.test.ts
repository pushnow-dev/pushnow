import { describe, expect, it } from "vitest";
import { EmailAuthService } from "../src/auth-service";
import type {
  AuthChallengeRecord,
  ChallengeType,
  EmailDeliveryRecord,
  SessionRecord,
  UserRecord
} from "../src/contracts";
import type { AuthMailer, VerificationEmailInput } from "../src/email";
import type { AuthStore } from "../src/store";

class MemoryStore implements AuthStore {
  challenges: AuthChallengeRecord[] = [];
  users: UserRecord[] = [];
  sessions: SessionRecord[] = [];
  deliveries: EmailDeliveryRecord[] = [];

  async countRecentChallenges(emailHash: string, challengeType: ChallengeType, since: string): Promise<number> {
    return this.challenges.filter((item) => item.emailHash === emailHash && item.challengeType === challengeType && item.createdAt >= since).length;
  }

  async createChallenge(challenge: AuthChallengeRecord): Promise<void> {
    this.challenges.push(challenge);
  }

  async findActiveChallenge(emailHash: string, challengeType: ChallengeType): Promise<AuthChallengeRecord | null> {
    return (
      this.challenges
        .filter((item) => item.emailHash === emailHash && item.challengeType === challengeType && item.consumedAt === null)
        .sort((left, right) => right.createdAt.localeCompare(left.createdAt))[0] ?? null
    );
  }

  async incrementChallengeAttempts(id: string): Promise<void> {
    const challenge = this.challenges.find((item) => item.id === id);
    if (challenge) challenge.attempts += 1;
  }

  async consumeChallenge(id: string, consumedAt: string): Promise<void> {
    const challenge = this.challenges.find((item) => item.id === id);
    if (challenge) challenge.consumedAt = consumedAt;
  }

  async findUserByID(userID: string): Promise<UserRecord | null> {
    return this.users.find((item) => item.id === userID) ?? null;
  }

  async findUserByEmailHash(emailHash: string): Promise<UserRecord | null> {
    return this.users.find((item) => item.emailHash === emailHash) ?? null;
  }

  async createUser(user: UserRecord): Promise<void> {
    this.users.push(user);
  }

  async updateUserEmail(userID: string, email: string, emailHash: string, verifiedAt: string, updatedAt: string): Promise<void> {
    const user = this.users.find((item) => item.id === userID);
    if (user) {
      user.email = email;
      user.emailHash = emailHash;
      user.emailVerifiedAt = verifiedAt;
      user.updatedAt = updatedAt;
    }
  }

  async updateUserPassword(userID: string, passwordHash: string, passwordSetAt: string, updatedAt: string): Promise<void> {
    const user = this.users.find((item) => item.id === userID);
    if (user) {
      user.passwordHash = passwordHash;
      user.passwordSetAt = passwordSetAt;
      user.updatedAt = updatedAt;
    }
  }

  async findSessionByAccessHash(accessTokenHash: string): Promise<SessionRecord | null> {
    return this.sessions.find((item) => item.accessTokenHash === accessTokenHash && item.revokedAt === null) ?? null;
  }

  async findSessionByRefreshHash(refreshTokenHash: string): Promise<SessionRecord | null> {
    return this.sessions.find((item) => item.refreshTokenHash === refreshTokenHash && item.revokedAt === null) ?? null;
  }

  async createSession(session: SessionRecord): Promise<void> {
    this.sessions.push(session);
  }

  async rotateSession(sessionID: string, accessTokenHash: string, refreshTokenHash: string, expiresAt: string, updatedAt: string): Promise<void> {
    const session = this.sessions.find((item) => item.id === sessionID);
    if (session) {
      session.accessTokenHash = accessTokenHash;
      session.refreshTokenHash = refreshTokenHash;
      session.expiresAt = expiresAt;
      session.updatedAt = updatedAt;
    }
  }

  async revokeSession(sessionID: string, revokedAt: string): Promise<void> {
    const session = this.sessions.find((item) => item.id === sessionID);
    if (session) session.revokedAt = revokedAt;
  }

  async revokeAllUserSessions(userID: string, revokedAt: string): Promise<void> {
    this.sessions.filter((item) => item.userId === userID).forEach((item) => {
      item.revokedAt = revokedAt;
    });
  }

  async markDeletionRequested(userID: string, requestedAt: string): Promise<void> {
    const user = this.users.find((item) => item.id === userID);
    if (user) user.deletionRequestedAt = requestedAt;
  }

  async recordEmailDelivery(delivery: EmailDeliveryRecord): Promise<void> {
    this.deliveries.push(delivery);
  }
}

class CaptureMailer implements AuthMailer {
  sent: VerificationEmailInput[] = [];

  async sendVerificationEmail(input: VerificationEmailInput): Promise<string> {
    this.sent.push(input);
    return "email-message-1";
  }
}

function makeService(store = new MemoryStore(), mailer = new CaptureMailer()): {
  service: EmailAuthService;
  store: MemoryStore;
  mailer: CaptureMailer;
} {
  return {
    service: new EmailAuthService(
      store,
      mailer,
      {
        appBaseURL: "https://pushnow.dev",
        authEmailFrom: "JiZhi <login@pushnow.dev>",
        authTokenPepper: "test-pepper",
        accessTokenTTLSeconds: 900,
        refreshTokenTTLSeconds: 2_592_000,
        authCodeTTLSeconds: 600
      },
      () => new Date("2026-09-12T05:00:00.000Z")
    ),
    store,
    mailer
  };
}

describe("EmailAuthService", () => {
  it("starts email login without exposing whether the user exists", async () => {
    const { service, store, mailer } = makeService();

    await expect(service.startLogin({ email: "USER@example.com", locale: "zh-Hans", timezone: "Asia/Shanghai" })).resolves.toEqual({
      expiresInSeconds: 600
    });

    expect(store.challenges).toHaveLength(1);
    expect(store.challenges[0].email).toBe("user@example.com");
    expect(mailer.sent[0].code).toMatch(/^[0-9]{6}$/);
    expect(store.deliveries[0].status).toBe("sent");
  });

  it("verifies code, creates a user, and binds a session to user id", async () => {
    const { service, store, mailer } = makeService();

    await service.startLogin({ email: "user@example.com", client: { platform: "ios", deviceId: "sim" } });
    const response = await service.verifyLogin({ email: "user@example.com", code: mailer.sent[0].code });

    expect(response.user.email).toBe("user@example.com");
    expect(response.user.id).toBe(store.users[0].id);
    expect(response.accessToken).toMatch(/^jza_/);
    expect(response.refreshToken).toMatch(/^jzr_/);
    expect(store.sessions[0].userId).toBe(response.user.id);
    expect(store.challenges[0].consumedAt).not.toBeNull();
  });

  it("sets a password after email verification and supports password login", async () => {
    const { service, mailer } = makeService();

    await service.startLogin({ email: "user@example.com", client: { platform: "ios", deviceId: "sim" } });
    const verified = await service.verifyLogin({ email: "user@example.com", code: mailer.sent[0].code });
    expect(verified.user.hasPassword).toBe(false);

    const updatedUser = await service.setPassword(
      {
        id: verified.user.id,
        email: verified.user.email,
        emailHash: "unused",
        emailVerifiedAt: verified.user.emailVerifiedAt,
        locale: verified.user.locale,
        timezone: verified.user.timezone,
        revenuecatAppUserId: verified.user.revenuecatAppUserId,
        passwordHash: null,
        passwordSetAt: null,
        createdAt: verified.user.createdAt,
        updatedAt: verified.user.createdAt,
        deletionRequestedAt: null
      },
      { password: "Secure123" }
    );

    expect(updatedUser.hasPassword).toBe(true);
    await expect(service.loginWithPassword({ email: "user@example.com", password: "Secure123" })).resolves.toMatchObject({
      user: { email: "user@example.com", hasPassword: true }
    });
  });

  it("rejects password login before a password is set", async () => {
    const { service, mailer } = makeService();

    await service.startLogin({ email: "user@example.com" });
    await service.verifyLogin({ email: "user@example.com", code: mailer.sent[0].code });

    await expect(service.loginWithPassword({ email: "user@example.com", password: "Secure123" })).rejects.toMatchObject({
      status: 401,
      code: "invalid_credentials"
    });
  });

  it("rejects bad codes and records attempts", async () => {
    const { service, store } = makeService();

    await service.startLogin({ email: "user@example.com" });
    await expect(service.verifyLogin({ email: "user@example.com", code: "000000" })).rejects.toMatchObject({ status: 401 });

    expect(store.challenges[0].attempts).toBe(1);
  });
});
