import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AuthSession } from '../models/JiZhiModels';
import { apiClient } from './ApiClient';
import { deviceService } from './DeviceService';
import { secureStorage } from './SecureStorage';
import { secureDeviceEnrollmentService } from './SecureDeviceEnrollmentService';

interface ApiUser { id: string; email: string; email_verified_at?: string; }
interface SessionResponse {
  access_token: string; refresh_token: string; expires_in_seconds: number; user: ApiUser;
}
interface StartResponse { status: string; }
interface RefreshPayload { refresh_token: string; }
interface ClientPayload { platform: string; device_id: string; app_version: string; }
interface EmailPayload { email: string; client: ClientPayload; code?: string; password?: string; }
interface SavedSession { session: AuthSession; expiresAt: number; }

export class AuthService {
  private session: AuthSession = new AuthSession();
  private expiresAt: number = 0;
  private refreshing?: Promise<void>;
  private persistence: Promise<void> = Promise.resolve();
  generation: number = 0;
  private acceptedTokens: string[] = [];

  get current(): AuthSession { return this.session; }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    await secureStorage.initialize(context);
    const saved = await secureStorage.read('auth-session');
    if (saved.length > 0) {
      const snapshot = JSON.parse(saved) as SavedSession;
      this.session = snapshot.session;
      this.expiresAt = snapshot.expiresAt;
    } else {
      const legacy = await preferences.getPreferences(context, 'jizhi_auth');
      const migrated = new AuthSession();
      migrated.accessToken = String(legacy.getSync('accessToken', ''));
      migrated.refreshToken = String(legacy.getSync('refreshToken', ''));
      migrated.userID = String(legacy.getSync('userID', ''));
      migrated.email = String(legacy.getSync('email', ''));
      migrated.verified = migrated.accessToken.length > 0 && migrated.refreshToken.length > 0 && migrated.userID.length > 0;
      if (migrated.verified) {
        this.session = migrated;
        this.expiresAt = 0; // Force server validation/rotation before use.
        await this.persist();
      }
      await legacy.clear();
      await legacy.flush();
    }
    if (this.session.verified) {
      this.acceptedTokens = [this.session.accessToken];
      await deviceService.activateUserDevice(this.session.userID);
    }
    apiClient.resolveToken = async (token: string): Promise<string> => {
      if (!this.acceptedTokens.includes(token) || !this.session.verified) throw new Error('session_changed');
      return await this.requireAccessToken();
    };
    apiClient.sessionGeneration = (): number => this.generation;
  }

  async startEmail(email: string): Promise<void> {
    const payload: EmailPayload = { email: email.trim().toLowerCase(), client: this.client() };
    await apiClient.post<StartResponse>('/v1/auth/email/start', payload);
  }

  async verifyEmail(email: string, code: string): Promise<AuthSession> {
    const epoch = this.generation;
    const payload: EmailPayload = { email: email.trim().toLowerCase(), code: code.trim(), client: this.client() };
    const result = await apiClient.post<SessionResponse>('/v1/auth/email/verify', payload);
    await this.apply(result, epoch, false);
    return this.session;
  }

  async loginWithPassword(email: string, password: string): Promise<AuthSession> {
    const epoch = this.generation;
    const payload: EmailPayload = { email: email.trim().toLowerCase(), password, client: this.client() };
    const result = await apiClient.post<SessionResponse>('/v1/auth/password/login', payload);
    await this.apply(result, epoch, false);
    return this.session;
  }

  async requireAccessToken(): Promise<string> {
    if (!this.session.verified) throw new Error('login_required');
    if (this.expiresAt - Date.now() < 60000) {
      if (!this.refreshing) this.refreshing = this.performRefresh();
      const task = this.refreshing;
      try { await task; } finally { if (this.refreshing === task) this.refreshing = undefined; }
    }
    if (!this.session.verified) throw new Error('session_changed');
    return this.session.accessToken;
  }

  private async performRefresh(): Promise<void> {
    const epoch = this.generation;
    const payload: RefreshPayload = { refresh_token: this.session.refreshToken };
    const result = await apiClient.post<SessionResponse>('/v1/auth/refresh', payload);
    await this.apply(result, epoch, true);
  }

  async logout(): Promise<void> {
    const payload: RefreshPayload = { refresh_token: this.session.refreshToken };
    this.generation++;
    this.refreshing = undefined;
    this.acceptedTokens = [];
    secureDeviceEnrollmentService.clear();
    this.session = new AuthSession();
    this.expiresAt = 0;
    deviceService.useInstallationDevice();
    await this.persist();
    // Refresh-token logout also works after the access token expires.
    if (payload.refresh_token.length > 0) {
      try { await apiClient.post<object>('/v1/auth/logout', payload); }
      catch { throw new Error('Signed out locally. Server sign-out failed; reconnect and sign in to stop this device’s remote delivery.'); }
    }
  }

  private async apply(result: SessionResponse, epoch: number, refresh: boolean): Promise<void> {
    if (epoch !== this.generation || (refresh && result.user.id !== this.session.userID)) {
      const payload: RefreshPayload = { refresh_token: result.refresh_token };
      await apiClient.post<object>('/v1/auth/logout', payload);
      throw new Error('session_changed');
    }
    if (!result.access_token || !result.refresh_token || !result.user.email_verified_at) throw new Error('invalid_session');
    if (!refresh) {
      this.generation++; this.refreshing = undefined; this.acceptedTokens = [];
      secureDeviceEnrollmentService.clear();
    }
    this.acceptedTokens.push(result.access_token);
    const next = new AuthSession();
    next.accessToken = result.access_token;
    next.refreshToken = result.refresh_token;
    next.userID = result.user.id;
    next.email = result.user.email;
    next.verified = true;
    this.session = next;
    this.expiresAt = Date.now() + result.expires_in_seconds * 1000;
    const activeEpoch = this.generation;
    await deviceService.activateUserDevice(next.userID);
    if (activeEpoch !== this.generation) throw new Error('session_changed');
    await this.persist();
  }

  private client(): ClientPayload {
    return { platform: 'harmony', device_id: deviceService.deviceId, app_version: '0.1.0' };
  }

  private async persist(): Promise<void> {
    const snapshot: SavedSession = { session: this.session, expiresAt: this.expiresAt };
    const raw = this.session.verified ? JSON.stringify(snapshot) : '';
    this.persistence = this.persistence.catch(() => {}).then(async (): Promise<void> => {
      if (raw.length > 0) await secureStorage.write('auth-session', raw);
      else await secureStorage.remove('auth-session');
    });
    await this.persistence;
  }
}
export const authService = new AuthService();
