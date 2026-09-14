import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { pushService } from '@kit.PushKit';
import { notificationManager } from '@kit.NotificationKit';
import { SecureDevice } from '../models/JiZhiModels';
import { apiClient } from './ApiClient';

interface DevicesResponse {
  identityPublicKey?: string;
  identity_public_key?: string;
  devices: RawSecureDevice[];
}

interface RawSecureDevice {
  id: string;
  user_id?: string;
  userId?: string;
  name: string;
  platform: string;
  public_key?: string;
  publicKey?: string;
  certificate?: string;
  status: string;
  notifications_enabled?: boolean;
  notificationsEnabled?: boolean;
  last_seen_at?: string;
  lastSeenAt?: string;
  created_at?: string;
  createdAt?: string;
}

class SecurePushPayload {
  token: string;
  environment: string = 'production';
  appVersion: string = '0.1.0';

  constructor(token: string) {
    this.token = token;
  }
}

class DeviceUpdatePayload {
  name?: string;
  notificationsEnabled?: boolean;

  constructor(notificationsEnabled?: boolean) {
    this.notificationsEnabled = notificationsEnabled;
  }
}

export class DeviceService {
  private store?: preferences.Preferences;
  private installationId: string = '';
  private context?: common.UIAbilityContext;
  deviceId: string = '';

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.context = context;
    this.store = await preferences.getPreferences(context, 'jizhi_device');
    this.installationId = String(this.store.getSync('installationId', this.store.getSync('deviceId', '')));
    if (!this.isUUID(this.installationId)) {
      this.installationId = this.makeUUID();
      this.store.putSync('installationId', this.installationId);
      await this.store.flush();
    }
    this.deviceId = this.installationId;
  }

  async activateUserDevice(userId: string): Promise<void> {
    if (!this.store || userId.length === 0) return;
    const key = `secureDeviceId:${userId}`;
    let userDeviceId = String(this.store.getSync(key, ''));
    if (!this.isUUID(userDeviceId)) {
      userDeviceId = this.makeUUID();
      this.store.putSync(key, userDeviceId);
      await this.store.flush();
    }
    this.deviceId = userDeviceId;
  }

  async restoreUserDevice(userId: string, id: string): Promise<void> {
    if (!this.store || !this.isUUID(id) || !userId) throw new Error('invalid_device_id');
    this.store.putSync(`secureDeviceId:${userId}`, id);
    await this.store.flush();
    this.deviceId = id;
  }

  useInstallationDevice(): void {
    this.deviceId = this.installationId;
  }

  async list(token: string): Promise<SecureDevice[]> {
    if (token.length === 0) throw new Error('login_required');
    const response = await apiClient.get<DevicesResponse>('/v1/secure/devices', token);
    return response.devices.map((device: RawSecureDevice) => this.present(device));
  }

  async registerSecurePush(token: string): Promise<string> {
    if (token.length === 0 || this.deviceId.length === 0) throw new Error('login_required');
    const targetId = this.deviceId;
    const current = await this.currentRemoteDevice(token);
    if (!current || current.status !== 'active') {
      throw new Error('device_not_approved');
    }
    if (!current.notificationsEnabled) throw new Error('device_notifications_disabled');
    if (!this.context) throw new Error('device_not_initialized');
    await notificationManager.requestEnableNotification(this.context);
    if (!await notificationManager.isNotificationEnabled()) throw new Error('notification_permission_denied');
    const pushToken = await pushService.getToken();
    if (targetId !== this.deviceId) throw new Error('session_changed');
    if (pushToken.length === 0) throw new Error('push_token_unavailable');
    await apiClient.put<object>(`/v1/secure/devices/${this.deviceId}/push`, new SecurePushPayload(pushToken), token);
    return pushToken;
  }

  async updateNotifications(token: string, deviceId: string, enabled: boolean): Promise<void> {
    if (token.length === 0 || deviceId.length === 0) return;
    await apiClient.patch<object>(`/v1/secure/devices/${deviceId}`, new DeviceUpdatePayload(enabled), token);
  }

  async rename(token: string, deviceId: string, name: string): Promise<void> {
    const trimmed = name.trim();
    if (trimmed.length === 0 || trimmed.length > 80) throw new Error('invalid_device_name');
    const payload = new DeviceUpdatePayload();
    payload.name = trimmed;
    await apiClient.patch<object>(`/v1/secure/devices/${deviceId}`, payload, token);
  }

  async updatePushToken(token: string, pushToken: string): Promise<void> {
    if (pushToken.length === 0) throw new Error('push_token_unavailable');
    const current = await this.currentRemoteDevice(token);
    if (!current || current.status !== 'active') throw new Error('device_not_approved');
    await apiClient.put<object>(`/v1/secure/devices/${current.id}/push`, new SecurePushPayload(pushToken), token);
  }

  private async currentRemoteDevice(token: string): Promise<SecureDevice | undefined> {
    const response = await apiClient.get<DevicesResponse>('/v1/secure/devices', token);
    return response.devices.map((device: RawSecureDevice) => this.present(device))
      .find((device: SecureDevice) => device.current);
  }

  private present(raw: RawSecureDevice): SecureDevice {
    const device = new SecureDevice();
    device.id = raw.id;
    device.userId = raw.userId ?? raw.user_id ?? '';
    device.name = raw.name;
    device.platform = raw.platform;
    device.publicKey = raw.publicKey ?? raw.public_key ?? '';
    device.certificate = raw.certificate ?? '';
    device.status = raw.status;
    device.notificationsEnabled = raw.notificationsEnabled ?? raw.notifications_enabled ?? true;
    device.lastSeenAt = raw.lastSeenAt ?? raw.last_seen_at ?? '';
    device.createdAt = raw.createdAt ?? raw.created_at ?? '';
    device.current = raw.id === this.deviceId;
    return device;
  }

  private isUUID(value: string): boolean {
    return /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(value);
  }

  private makeUUID(): string {
    const bytes = cryptoFramework.createRandom().generateRandomSync(16).data;
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    return `${this.hex(bytes, 0, 4)}-${this.hex(bytes, 4, 6)}-${this.hex(bytes, 6, 8)}-${this.hex(bytes, 8, 10)}-${this.hex(bytes, 10, 16)}`;
  }

  private hex(bytes: Uint8Array, start: number, end: number): string {
    let value = '';
    for (let index = start; index < end; index++) {
      value += bytes[index].toString(16).padStart(2, '0');
    }
    return value;
  }
}

export const deviceService = new DeviceService();
