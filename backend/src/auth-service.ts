import { revenueCatIdentity,type PaymentEnvironment } from './revenuecat-identity';
import type {
  ApiUser,
  AuthChallengeRecord,
  AuthClientContext,
  AuthSessionResponse,
  ChallengeType,
  PasswordLoginRequest,
  SessionRecord,
  SetPasswordRequest,
  StartEmailAuthRequest,
  UserRecord,
  VerifyEmailAuthRequest
} from "./contracts";
import type { AuthMailer } from "./email";
import type { AuthStore } from "./store";
import { assertValidPasswordInput } from "./auth-validation";
import {
  addSeconds,
  assertValidEmail,
  AuthHttpError,
  constantTimeEqualHex,
  createNumericCode,
  createOpaqueToken,
  createPasswordSalt,
  hashEmail,
  hashPassword,
  hashSecret,
  normalizeEmail,
  parsePositiveSeconds,
  verifyPassword
} from "./crypto";

type AuthRuntimeConfig = {
  paymentEnvironment?: PaymentEnvironment;
  appBaseURL: string;
  authEmailFrom: string;
  authTokenPepper: string;
  accessTokenTTLSeconds: number;
  refreshTokenTTLSeconds: number;
  authCodeTTLSeconds: number;
};

type AuthEnv = Env & {
  AUTH_TOKEN_PEPPER?: string;
};

type AuthenticatedSession = {
  user: UserRecord;
  session: SessionRecord;
};

export class EmailAuthService {
  constructor(
    private readonly store: AuthStore,
    private readonly mailer: AuthMailer,
    private readonly config: AuthRuntimeConfig,
    private readonly now: () => Date = () => new Date()
  ) {}

  async startLogin(input: StartEmailAuthRequest): Promise<{ expiresInSeconds: number }> {
    await this.createAndSendChallenge("login", input);
    return { expiresInSeconds: this.config.authCodeTTLSeconds };
  }

  async verifyLogin(input: VerifyEmailAuthRequest): Promise<AuthSessionResponse> {
    const challenge = await this.verifyChallenge("login", input.email, input.code);
    let user = await this.store.findUserByEmailHash(challenge.emailHash);
    const timestamp = this.now().toISOString();
    if (!user) {
      user = {
        id: crypto.randomUUID(),
        email: challenge.email,
        emailHash: challenge.emailHash,
        emailVerifiedAt: timestamp,
        locale: challenge.locale,
        timezone: challenge.timezone,
        revenuecatAppUserId: null,
        passwordHash: null,
        passwordSetAt: null,
        createdAt: timestamp,
        updatedAt: timestamp,
        deletionRequestedAt: null
      };
      user.revenuecatAppUserId = revenueCatIdentity(user.id,this.config.paymentEnvironment);
      try {
        await this.store.createUser(user);
      } catch (error) {
        user = await this.store.findUserByEmailHash(challenge.emailHash);
        if (!user) {
          throw error;
        }
      }
    }

    await this.store.consumeChallenge(challenge.id, timestamp);
    return this.createSession(user, input.client);
  }

  async loginWithPassword(input: PasswordLoginRequest): Promise<AuthSessionResponse> {
    const email = normalizeEmail(input.email);
    assertValidEmail(email);
    const password = assertValidPasswordInput(input.password);
    const emailHash = await hashEmail(email, this.config.authTokenPepper);
    const user = await this.store.findUserByEmailHash(emailHash);

    if (!user || !user.passwordHash || !(await verifyPassword(password, user.passwordHash, this.config.authTokenPepper))) {
      throw new AuthHttpError(401, "invalid_credentials", "邮箱或密码不正确");
    }

    return this.createSession(user, input.client);
  }

  async setPassword(user: UserRecord, input: SetPasswordRequest): Promise<ApiUser> {
    const password = assertValidPasswordInput(input.password);
    const timestamp = this.now().toISOString();
    const passwordHash = await hashPassword(password, createPasswordSalt(), this.config.authTokenPepper);
    await this.store.updateUserPassword(user.id, passwordHash, timestamp, timestamp);
    return toApiUser({ ...user, passwordHash, passwordSetAt: timestamp, updatedAt: timestamp });
  }

  async refresh(refreshToken: string): Promise<AuthSessionResponse> {
    const refreshHash = await hashSecret(refreshToken, this.config.authTokenPepper);
    const session = await this.store.findSessionByRefreshHash(refreshHash);
    if (!session || new Date(session.refreshExpiresAt) <= this.now()) {
      throw new AuthHttpError(401, "session_expired", "请重新登录");
    }
    const user = await this.findUserForSession(session);
    const accessToken = createOpaqueToken("jza");
    const newRefreshToken = createOpaqueToken("jzr");
    const timestamp = this.now();
    await this.store.rotateSession(
      session.id,
      await hashSecret(accessToken, this.config.authTokenPepper),
      await hashSecret(newRefreshToken, this.config.authTokenPepper),
      addSeconds(timestamp, this.config.accessTokenTTLSeconds),
      timestamp.toISOString()
    );
    return {
      user: toApiUser(user),
      accessToken,
      refreshToken: newRefreshToken,
      expiresInSeconds: this.config.accessTokenTTLSeconds
    };
  }

  async authenticate(accessToken: string): Promise<AuthenticatedSession> {
    const accessHash = await hashSecret(accessToken, this.config.authTokenPepper);
    const session = await this.store.findSessionByAccessHash(accessHash);
    if (!session || new Date(session.expiresAt) <= this.now()) {
      throw new AuthHttpError(401, "session_expired", "请重新登录");
    }
    return { user: await this.findUserForSession(session), session };
  }

  async authenticateLogout(accessToken?: string, refreshToken?: string): Promise<AuthenticatedSession> {
    const accessSession = accessToken ? await this.store.findSessionByAccessHash(await hashSecret(accessToken, this.config.authTokenPepper)) : null;
    const refreshSession = refreshToken ? await this.store.findSessionByRefreshHash(await hashSecret(refreshToken, this.config.authTokenPepper)) : null;
    if (accessSession && refreshSession && accessSession.id !== refreshSession.id) {
      throw new AuthHttpError(401, "session_mismatch", "Session credentials do not match");
    }
    const session = accessSession && new Date(accessSession.expiresAt) > this.now()
      ? accessSession : refreshSession && new Date(refreshSession.refreshExpiresAt) > this.now() ? refreshSession : null;
    if (!session) throw new AuthHttpError(401, "session_expired", "Please sign in again");
    return { user: await this.findUserForSession(session), session };
  }

  async logout(sessionID: string, _refreshToken?: string): Promise<void> {
    await this.store.revokeSession(sessionID, this.now().toISOString());
  }

  async startEmailChange(user: UserRecord, input: StartEmailAuthRequest): Promise<{ expiresInSeconds: number }> {
    await this.createAndSendChallenge("email_change", input, user.id);
    return { expiresInSeconds: this.config.authCodeTTLSeconds };
  }

  async verifyEmailChange(user: UserRecord, input: VerifyEmailAuthRequest): Promise<ApiUser> {
    const challenge = await this.verifyChallenge("email_change", input.email, input.code);
    if (challenge.userId !== user.id) {
      throw new AuthHttpError(401, "auth_failed", "验证码无效或已过期");
    }
    const existing = await this.store.findUserByEmailHash(challenge.emailHash);
    if (existing && existing.id !== user.id) {
      throw new AuthHttpError(409, "email_already_used", "该邮箱已绑定其他账号");
    }
    const timestamp = this.now().toISOString();
    await this.store.updateUserEmail(user.id, challenge.email, challenge.emailHash, timestamp, timestamp);
    await this.store.consumeChallenge(challenge.id, timestamp);
    return toApiUser({ ...user, email: challenge.email, emailHash: challenge.emailHash, emailVerifiedAt: timestamp, updatedAt: timestamp });
  }

  async requestDeletion(userID: string): Promise<void> {
    const timestamp = this.now().toISOString();
    await this.store.markDeletionRequested(userID, timestamp);
    await this.store.revokeAllUserSessions(userID, timestamp);
  }

  private async createAndSendChallenge(challengeType: ChallengeType, input: StartEmailAuthRequest, userID: string | null = null): Promise<void> {
    const email = normalizeEmail(input.email);
    assertValidEmail(email);
    const emailHash = await hashEmail(email, this.config.authTokenPepper);
    const since = addSeconds(this.now(), -15 * 60);
    if ((await this.store.countRecentChallenges(emailHash, challengeType, since)) >= 3) {
      throw new AuthHttpError(429, "auth_rate_limited", "请求太频繁，请稍后再试");
    }

    const code = createNumericCode();
    const timestamp = this.now();
    const challenge: AuthChallengeRecord = {
      id: crypto.randomUUID(),
      challengeType,
      email,
      emailHash,
      userId: userID,
      codeHash: await hashSecret(code, this.config.authTokenPepper),
      locale: input.locale ?? "en",
      timezone: input.timezone ?? "UTC",
      clientPlatform: input.client?.platform ?? null,
      deviceId: input.client?.deviceId ?? null,
      appVersion: input.client?.appVersion ?? null,
      attempts: 0,
      expiresAt: addSeconds(timestamp, this.config.authCodeTTLSeconds),
      consumedAt: null,
      createdAt: timestamp.toISOString(),
      sentAt: timestamp.toISOString()
    };

    await this.store.createChallenge(challenge);
    await this.sendAndRecordEmail(challenge, code);
  }

  private async verifyChallenge(challengeType: ChallengeType, emailInput: string, codeInput: string): Promise<AuthChallengeRecord> {
    const email = normalizeEmail(emailInput);
    assertValidEmail(email);
    const code = codeInput.trim();
    if (!/^[0-9A-Za-z]{6,12}$/.test(code)) {
      throw new AuthHttpError(400, "invalid_auth_code", "请输入有效验证码");
    }

    const emailHash = await hashEmail(email, this.config.authTokenPepper);
    const challenge = await this.store.findActiveChallenge(emailHash, challengeType);
    const expectedHash = await hashSecret(code, this.config.authTokenPepper);
    if (!challenge || new Date(challenge.expiresAt) <= this.now() || challenge.attempts >= 5) {
      throw new AuthHttpError(401, "auth_code_expired", "验证码无效或已过期");
    }
    if (!constantTimeEqualHex(challenge.codeHash, expectedHash)) {
      await this.store.incrementChallengeAttempts(challenge.id);
      throw new AuthHttpError(401, "auth_failed", "验证码无效或已过期");
    }
    return challenge;
  }

  private async createSession(user: UserRecord, client: AuthClientContext | undefined): Promise<AuthSessionResponse> {
    const accessToken = createOpaqueToken("jza");
    const refreshToken = createOpaqueToken("jzr");
    const timestamp = this.now();
    const session: SessionRecord = {
      id: crypto.randomUUID(),
      userId: user.id,
      accessTokenHash: await hashSecret(accessToken, this.config.authTokenPepper),
      refreshTokenHash: await hashSecret(refreshToken, this.config.authTokenPepper),
      clientPlatform: client?.platform ?? null,
      deviceId: null,
      appVersion: client?.appVersion ?? null,
      expiresAt: addSeconds(timestamp, this.config.accessTokenTTLSeconds),
      refreshExpiresAt: addSeconds(timestamp, this.config.refreshTokenTTLSeconds),
      revokedAt: null,
      createdAt: timestamp.toISOString(),
      updatedAt: timestamp.toISOString()
    };
    await this.store.createSession(session);
    return {
      user: toApiUser(user),
      accessToken,
      refreshToken,
      expiresInSeconds: this.config.accessTokenTTLSeconds
    };
  }

  private async findUserForSession(session: SessionRecord): Promise<UserRecord> {
    const user = await this.store.findUserByID(session.userId);
    if (!user || user.deletionRequestedAt) {
      throw new AuthHttpError(401, "session_expired", "请重新登录");
    }
    return user;
  }

  private async sendAndRecordEmail(challenge: AuthChallengeRecord, code: string): Promise<void> {
    try {
      const messageID = await this.mailer.sendVerificationEmail({
        email: challenge.email,
        code,
        challengeType: challenge.challengeType,
        appBaseURL: this.config.appBaseURL,
        from: this.config.authEmailFrom,
        locale: challenge.locale
      });
      await this.recordEmail(challenge, "sent", messageID, null);
    } catch (error) {
      await this.recordEmail(challenge, "failed", null, error instanceof Error ? error.message : "unknown");
      throw new AuthHttpError(502, "email_delivery_failed", "验证邮件暂时无法发送");
    }
  }

  private async recordEmail(challenge: AuthChallengeRecord, status: "sent" | "failed", messageID: string | null, errorMessage: string | null): Promise<void> {
    await this.store.recordEmailDelivery({
      id: crypto.randomUUID(),
      userId: challenge.userId,
      email: challenge.email,
      emailHash: challenge.emailHash,
      purpose: challenge.challengeType,
      providerMessageId: messageID,
      status,
      errorMessage,
      createdAt: this.now().toISOString()
    });
  }
}

export function configFromEnv(env: AuthEnv): AuthRuntimeConfig {
  if (!env.AUTH_TOKEN_PEPPER) {
    throw new AuthHttpError(500, "missing_auth_secret", "认证服务缺少密钥配置");
  }
  return {
    appBaseURL: env.APP_BASE_URL,
    paymentEnvironment: env.REVENUECAT_ENVIRONMENT,
    authEmailFrom: env.AUTH_EMAIL_FROM,
    authTokenPepper: env.AUTH_TOKEN_PEPPER,
    accessTokenTTLSeconds: parsePositiveSeconds(env.ACCESS_TOKEN_TTL_SECONDS, 900),
    refreshTokenTTLSeconds: parsePositiveSeconds(env.REFRESH_TOKEN_TTL_SECONDS, 2_592_000),
    authCodeTTLSeconds: parsePositiveSeconds(env.AUTH_CODE_TTL_SECONDS, 600)
  };
}

export function toApiUser(user: UserRecord): ApiUser {
  return {
    id: user.id,
    email: user.email,
    emailVerifiedAt: user.emailVerifiedAt,
    locale: user.locale,
    timezone: user.timezone,
    revenuecatAppUserId: user.revenuecatAppUserId,
    hasPassword: Boolean(user.passwordHash),
    passwordSetAt: user.passwordSetAt,
    createdAt: user.createdAt
  };
}
