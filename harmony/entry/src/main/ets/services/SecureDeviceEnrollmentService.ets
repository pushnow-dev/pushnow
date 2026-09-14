import { common } from '@kit.AbilityKit';
import deviceInfo from '@ohos.deviceInfo';
import { bundleManager } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { AuthSession, SecureDevice } from '../models/JiZhiModels';
import { apiClient } from './ApiClient';
import { HARMONY_PLATFORM } from './AppConfig';
import { deviceService } from './DeviceService';
import { secureCrypto, SecureGrant, SecureKey } from './SecureCrypto';
import { secureStorage } from './SecureStorage';
import { secureArchiveService } from './SecureArchiveService';

interface RawDevice {
  id: string; user_id?: string; userId?: string; name: string; platform: string;
  public_key?: string; publicKey?: string; certificate?: string; status: string;
  notifications_enabled?: boolean; notificationsEnabled?: boolean;
  last_seen_at?: string; lastSeenAt?: string; created_at?: string; createdAt?: string;
}
function present(raw: RawDevice): SecureDevice {
  const device = new SecureDevice();
  device.id = raw.id; device.userId = raw.user_id ?? raw.userId ?? '';
  device.name = raw.name; device.platform = raw.platform;
  device.publicKey = raw.public_key ?? raw.publicKey ?? '';
  device.certificate = raw.certificate ?? ''; device.status = raw.status;
  device.notificationsEnabled = raw.notifications_enabled ?? raw.notificationsEnabled ?? false;
  device.lastSeenAt = raw.last_seen_at ?? raw.lastSeenAt ?? '';
  device.createdAt = raw.created_at ?? raw.createdAt ?? '';
  device.current = device.id === deviceService.deviceId;
  return device;
}
interface DevicesResponse { identity_public_key?: string; identityPublicKey?: string; devices: RawDevice[]; }
interface ChallengeResponse { challenge: string; }
interface RegistrationResponse { identity_public_key?: string; identityPublicKey?: string; device: RawDevice; }
interface ApprovalResponse { approval?: SecureGrant; }
interface ApprovalPayload { identity_private_key: string; archive_id?: string; archive_private_key?: string; }
export interface ArchiveTransfer { archiveId: string; archivePrivateKey: string; }
class LegacyKeys {
  devicePublicDer: string = '';
  devicePrivateDer: string = '';
  identityPublicDer: string = '';
  identityPrivateDer: string = '';
}
class LocalState {
  device: SecureKey = new SecureKey();
  identity: SecureKey = new SecureKey();
  trusted: boolean = false;
  archiveTransfer?: ArchiveTransfer;
}
class DeviceRegistrationPayload {
  deviceId: string = '';
  name: string = deviceInfo.marketName || deviceInfo.productModel || 'HarmonyOS Device';
  model: string = deviceInfo.productModel;
  systemVersion: string = deviceInfo.osFullName;
  appVersion: string = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT).versionName;
  platform: string = HARMONY_PLATFORM;
  publicKey: string = '';
  proof: string = '';
  challenge: string = '';
  identityPublicKey?: string;
  certificate?: string;
}
interface DeviceApprovalPayload { certificate: string; approval: SecureGrant; }

export class SecureDeviceEnrollmentService {
  userId: string = '';
  generation: number = 0;
  private state: LocalState = new LocalState();
  private initialized: boolean = false;
  get archiveTransfer(): ArchiveTransfer | undefined { return this.state.archiveTransfer; }

  async initialize(context: common.UIAbilityContext): Promise<void> {
    await secureStorage.initialize(context);
    // Quarantine the old unscoped material in the vault before removing plaintext.
    // Ownership is resolved against the authenticated server directory on login.
    const legacy = await preferences.getPreferences(context, 'jizhi_secure_device');
    const migrated = new LegacyKeys();
    migrated.devicePublicDer = String(legacy.getSync('devicePublicDer', ''));
    migrated.devicePrivateDer = String(legacy.getSync('devicePrivateDer', ''));
    migrated.identityPublicDer = String(legacy.getSync('identityPublicDer', ''));
    migrated.identityPrivateDer = String(legacy.getSync('identityPrivateDer', ''));
    if (migrated.devicePrivateDer || migrated.identityPrivateDer) {
      const serialized = JSON.stringify(migrated);
      const existing = await secureStorage.read('legacy-device-keys');
      if (existing && existing !== serialized) throw new Error('legacy_migration_conflict');
      await secureStorage.write('legacy-device-keys', serialized);
      if (await secureStorage.read('legacy-device-keys') !== serialized) throw new Error('legacy_migration_failed');
      await legacy.clear();
      await legacy.flush();
    }
    this.initialized = true;
  }
  clear(): void {
    this.generation++;
    this.userId = '';
    this.state = new LocalState();
  }
  keys(): SecureKey { return this.state.device; }
  identityPrivateKey(): string { return this.state.identity.privateKey; }
  identityPublicKey(): string { return this.state.identity.publicKey; }
  identityEstablished(): boolean { return this.state.trusted && this.identityPrivateKey().length > 0; }
  private check(user: string, generation: number): void {
    if (this.userId !== user || this.generation !== generation) throw new Error('session_changed');
  }
  async activate(session: AuthSession): Promise<void> {
    if (!this.initialized) throw new Error('secure_device_store_not_ready');
    if (!session.verified || !session.accessToken || !session.userID) throw new Error('login_required');
    if (this.userId === session.userID && this.state.device.privateKey.length > 0) return;
    this.clear();
    this.userId = session.userID;
    const epoch = this.generation;
    await deviceService.activateUserDevice(session.userID);
    this.check(session.userID, epoch);
    const saved = await secureStorage.read(`device-keys:${session.userID}`);
    this.check(session.userID, epoch);
    const state = saved ? JSON.parse(saved) as LocalState : new LocalState();
    if (!saved) await this.migrateLegacy(state, session, epoch);
    if (!state.device.privateKey) state.device = await secureCrypto.generateKey();
    this.check(session.userID, epoch);
    this.state = state;
    await this.save(epoch);
  }
  private async migrateLegacy(state: LocalState, session: AuthSession, epoch: number): Promise<void> {
    const saved = await secureStorage.read('legacy-device-keys');
    this.check(session.userID, epoch);
    if (!saved) return;
    const legacy = JSON.parse(saved) as LegacyKeys;
    const directory = await apiClient.get<DevicesResponse>('/v1/secure/devices', session.accessToken);
    this.check(session.userID, epoch);
    const identity = directory.identity_public_key ?? directory.identityPublicKey ?? '';
    if (legacy.devicePrivateDer && legacy.devicePublicDer) {
      const key = await secureCrypto.importLegacy(legacy.devicePublicDer, legacy.devicePrivateDer);
      this.check(session.userID, epoch);
      const ownedDevices = directory.devices.map(present).filter(device => device.publicKey === key.publicKey &&
        device.userId === session.userID && device.status !== 'revoked');
      const owned = ownedDevices.find(device => device.id === deviceService.deviceId) ?? ownedDevices[0];
      if (owned) {
        await deviceService.restoreUserDevice(session.userID, owned.id);
        this.check(session.userID, epoch);
        state.device = key;
      }
    }
    if (identity && legacy.identityPrivateDer && legacy.identityPublicDer) {
      const key = await secureCrypto.importLegacy(legacy.identityPublicDer, legacy.identityPrivateDer);
      this.check(session.userID, epoch);
      if (key.publicKey === identity) state.identity = key;
    }
    // Retain encrypted quarantine for other accounts and crash recovery.
  }
  private async save(epoch: number): Promise<void> {
    const user = this.userId;
    this.check(user, epoch);
    await secureStorage.write(`device-keys:${user}`, JSON.stringify(this.state));
    this.check(user, epoch);
  }
  async enroll(session: AuthSession): Promise<SecureDevice> {
    await this.activate(session);
    const epoch = this.generation;
    await deviceService.activateUserDevice(session.userID);
    this.check(session.userID, epoch);
    const directory = await apiClient.get<DevicesResponse>('/v1/secure/devices', session.accessToken);
    this.check(session.userID, epoch);
    const identity = directory.identity_public_key ?? directory.identityPublicKey ?? '';
    if (this.identityPublicKey() && identity !== this.identityPublicKey() &&
      (identity.length > 0 || this.state.trusted || !this.identityPrivateKey())) throw new Error('identity_changed');
    if (identity) {
      this.state.identity.publicKey = identity;
      await this.save(epoch);
    }
    const challenge = await apiClient.get<ChallengeResponse>('/v1/secure/device-challenge', session.accessToken);
    this.check(session.userID, epoch);
    const payload = new DeviceRegistrationPayload();
    payload.deviceId = deviceService.deviceId;
    const existing = directory.devices.map(present).find(device => device.id === payload.deviceId);
    payload.name = existing?.name || `${payload.name} (${payload.deviceId.slice(0, 6)})`;
    payload.publicKey = this.state.device.publicKey;
    payload.challenge = challenge.challenge;
    payload.proof = await secureCrypto.sign(this.state.device.privateKey,
      `pushnow-register-v1\n${session.userID}\n${payload.deviceId}\n${payload.publicKey}\n${payload.challenge}`);
    this.check(session.userID, epoch);
    if (!identity) {
      if (!this.state.identity.privateKey) this.state.identity = await secureCrypto.generateKey();
      this.check(session.userID, epoch);
      // Persist before remote mutation so a lost response cannot lose authority.
      await this.save(epoch);
      payload.identityPublicKey = this.state.identity.publicKey;
      payload.certificate = await secureCrypto.sign(this.state.identity.privateKey,
        secureCrypto.text('device', session.userID, payload.deviceId, payload.publicKey));
    }
    this.check(session.userID, epoch);
    const response = await apiClient.post<RegistrationResponse>('/v1/secure/devices', payload, session.accessToken);
    this.check(session.userID, epoch);
    const registered = present(response.device);
    const confirmed = response.identity_public_key ?? response.identityPublicKey ?? identity;
    if ((identity && confirmed !== identity) || !confirmed || registered.id !== payload.deviceId || registered.publicKey !== payload.publicKey ||
      registered.userId !== session.userID) throw new Error('invalid_registration');
    if (this.state.identity.publicKey && this.state.identity.publicKey !== confirmed && this.state.identity.privateKey) {
      throw new Error('identity_changed');
    }
    this.state.identity.publicKey = confirmed;
    this.state.trusted = false;
    if (registered.status === 'active' && this.state.identity.privateKey) {
      await this.verifyOwnAuthority(registered, confirmed);
      this.check(session.userID, epoch);
      this.state.trusted = true;
    }
    await this.save(epoch);
    return registered;
  }
  private async verifyOwnAuthority(device: SecureDevice, identity: string): Promise<void> {
    await secureCrypto.verify(device.certificate,
      secureCrypto.text('device', this.userId, device.id, device.publicKey), identity);
    const probe = `pushnow-identity-check-v1\n${this.userId}`;
    await secureCrypto.verify(await secureCrypto.sign(this.identityPrivateKey(), probe), probe, identity);
  }
  async acceptApproval(session: AuthSession): Promise<SecureDevice> {
    await this.activate(session);
    const epoch = this.generation;
    const directory = await apiClient.get<DevicesResponse>('/v1/secure/devices', session.accessToken);
    this.check(session.userID, epoch);
    const device = directory.devices.map(present).find(item => item.id === deviceService.deviceId);
    const identity = directory.identity_public_key ?? directory.identityPublicKey ?? '';
    if (!device || device.status !== 'active' || device.userId !== session.userID ||
      device.publicKey !== this.keys().publicKey || !identity ||
      (!this.identityPublicKey() || identity !== this.identityPublicKey())) throw new Error('device_approval_pending');
    await secureCrypto.verify(device.certificate, secureCrypto.text('device', session.userID, device.id, device.publicKey), identity);
    const result = await apiClient.get<ApprovalResponse>(`/v1/secure/devices/${encodeURIComponent(device.id)}/approval`, session.accessToken);
    this.check(session.userID, epoch);
    if (!result.approval) throw new Error('device_approval_pending');
    const clear = await secureCrypto.open(this.keys().privateKey, this.keys().publicKey, result.approval,
      'pushnow-approval-v1', secureCrypto.text('approval', session.userID, device.id, device.publicKey));
    this.check(session.userID, epoch);
    const payload = JSON.parse(clear) as ApprovalPayload;
    const probe = `pushnow-identity-check-v1\n${session.userID}`;
    await secureCrypto.verify(await secureCrypto.sign(payload.identity_private_key, probe), probe, identity);
    this.check(session.userID, epoch);
    this.state.identity.publicKey = identity;
    this.state.identity.privateKey = payload.identity_private_key;
    this.state.trusted = true;
    if (payload.archive_id && payload.archive_private_key) {
      this.state.archiveTransfer = { archiveId: payload.archive_id, archivePrivateKey: payload.archive_private_key };
    }
    await this.save(epoch);
    return device;
  }
  async pairingCode(session: AuthSession, device?: SecureDevice): Promise<string> {
    await this.activate(session);
    const digest = await secureCrypto.digest(`pushnow-pairing-v1\n${session.userID}\n${device?.id ?? deviceService.deviceId}\n${device?.publicKey ?? this.keys().publicKey}\n${this.identityPublicKey()}`);
    return digest.slice(0, 16).toUpperCase().match(/.{1,4}/g)?.join('-') ?? '';
  }
  async approveDevice(session: AuthSession, device: SecureDevice): Promise<void> {
    await this.activate(session);
    const epoch = this.generation;
    if (!this.identityEstablished() || device.userId !== session.userID || device.status !== 'pending') {
      throw new Error('device_approval_invalid');
    }
    const certificate = await secureCrypto.sign(this.identityPrivateKey(),
      secureCrypto.text('device', session.userID, device.id, device.publicKey));
    const archive = await secureArchiveService.ensure();
    this.check(session.userID, epoch);
    const transfer: ArchiveTransfer = { archiveId: archive.archive.id, archivePrivateKey: archive.privateKey };
    const payload: ApprovalPayload = { identity_private_key: this.identityPrivateKey(),
      archive_id: transfer?.archiveId, archive_private_key: transfer?.archivePrivateKey };
    const approval = await secureCrypto.seal(device.publicKey, JSON.stringify(payload), 'pushnow-approval-v1',
      secureCrypto.text('approval', session.userID, device.id, device.publicKey));
    this.check(session.userID, epoch);
    const body: DeviceApprovalPayload = { certificate, approval };
    await apiClient.post<object>(`/v1/secure/devices/${encodeURIComponent(device.id)}/approve`, body, session.accessToken);
    this.check(session.userID, epoch);
  }
}
export const secureDeviceEnrollmentService = new SecureDeviceEnrollmentService();
