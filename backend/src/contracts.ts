export type ChallengeType = "login" | "email_change";

export type AuthClientContext = {
  platform?: "ios" | "harmony" | "web" | "cli";
  deviceId?: string;
  appVersion?: string;
};

export type StartEmailAuthRequest = {
  email: string;
  locale?: string;
  timezone?: string;
  turnstileToken?: string;
  client?: AuthClientContext;
};

export type VerifyEmailAuthRequest = {
  email: string;
  code: string;
  client?: AuthClientContext;
};

export type PasswordLoginRequest = {
  email: string;
  password: string;
  turnstileToken?: string;
  client?: AuthClientContext;
};

export type SetPasswordRequest = {
  password: string;
};

export type RefreshSessionRequest = {
  refreshToken: string;
};

export type LogoutRequest = {
  refreshToken?: string;
};

export type UserRecord = {
  id: string;
  email: string;
  emailHash: string;
  emailVerifiedAt: string;
  locale: string;
  timezone: string;
  revenuecatAppUserId: string | null;
  passwordHash: string | null;
  passwordSetAt: string | null;
  createdAt: string;
  updatedAt: string;
  deletionRequestedAt: string | null;
};

export type AuthChallengeRecord = {
  id: string;
  challengeType: ChallengeType;
  email: string;
  emailHash: string;
  userId: string | null;
  codeHash: string;
  locale: string;
  timezone: string;
  clientPlatform: string | null;
  deviceId: string | null;
  appVersion: string | null;
  attempts: number;
  expiresAt: string;
  consumedAt: string | null;
  createdAt: string;
  sentAt: string | null;
};

export type SessionRecord = {
  id: string;
  userId: string;
  accessTokenHash: string;
  refreshTokenHash: string;
  clientPlatform: string | null;
  deviceId: string | null;
  appVersion: string | null;
  expiresAt: string;
  refreshExpiresAt: string;
  revokedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type AuthSessionResponse = {
  user: ApiUser;
  accessToken: string;
  refreshToken: string;
  expiresInSeconds: number;
};

export type ApiUser = {
  id: string;
  email: string;
  emailVerifiedAt: string;
  locale: string;
  timezone: string;
  revenuecatAppUserId: string | null;
  hasPassword: boolean;
  passwordSetAt: string | null;
  createdAt: string;
};

export type EmailDeliveryRecord = {
  id: string;
  userId: string | null;
  email: string;
  emailHash: string;
  purpose: string;
  providerMessageId: string | null;
  status: "sent" | "failed";
  errorMessage: string | null;
  createdAt: string;
};
