import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { SecureDevice } from '../models/JiZhiModels';
import { apiClient } from './ApiClient';
import { authService } from './AuthService';
import { secureCrypto, SecureGrant } from './SecureCrypto';
import { secureDeviceEnrollmentService as enrollment } from './SecureDeviceEnrollmentService';
import { secureStorage } from './SecureStorage';
import { deviceService } from './DeviceService';

export interface ArchiveRecord { id: string; public_key: string; certificate: string; }
export interface ArchiveKeys { archive: ArchiveRecord; privateKey: string; }
interface ArchiveResponse { archive: ArchiveRecord | null; }
interface GrantResponse { grant: SecureGrant | null; }
interface ArchiveTransfer { archive_id: string; archive_private_key: string; }

export class SecureArchiveService {
  private pending?: Promise<ArchiveKeys>;
  private pendingEpoch: number = -1;

  async ensure(): Promise<ArchiveKeys> {
    const epoch = authService.generation;
    if (this.pending && this.pendingEpoch === epoch) return this.pending;
    const task = this.performEnsure(epoch);
    this.pending = task;
    this.pendingEpoch = epoch;
    try { return await task; } finally { if (this.pending === task) this.pending = undefined; }
  }

  private async performEnsure(epoch: number): Promise<ArchiveKeys> {
    const user = authService.current.userID;
    this.check(epoch, user);
    const token = await authService.requireAccessToken();
    const result = await apiClient.get<ArchiveResponse>('/v2/archive', token);
    this.check(epoch, user);
    const saved = await secureStorage.read(`archive:${user}`);
    const provisional = await secureStorage.read(`archive-provisional:${user}`);
    if (result.archive) {
      const archive = result.archive;
      await this.verify(archive, user);
      this.check(epoch, user);
      if (saved.length > 0) {
        const keys = JSON.parse(saved) as ArchiveKeys;
        if (!this.same(keys.archive, archive)) throw new Error('archive_identity_changed');
        await this.validateKeys(keys, user);
        this.check(epoch, user);
        return keys;
      }
      if (provisional.length > 0) {
        const keys = JSON.parse(provisional) as ArchiveKeys;
        if (this.same(keys.archive, archive)) return await this.save(keys, epoch, user);
      }
      const transfer = enrollment.archiveTransfer;
      if (transfer) {
        if (transfer.archiveId !== archive.id) throw new Error('archive_identity_changed');
        return await this.save({ archive, privateKey: transfer.archivePrivateKey }, epoch, user);
      }
      const response = await apiClient.get<GrantResponse>(`/v2/archive/grants/${deviceService.deviceId}`, token);
      this.check(epoch, user);
      if (!response.grant) throw new Error('history_access_pending');
      const device = enrollment.keys();
      const aad = `[2,"archive-grant",${JSON.stringify(user)},${JSON.stringify(deviceService.deviceId)},${JSON.stringify(archive.id)}]`;
      const clear = await secureCrypto.open(device.privateKey, device.publicKey, response.grant, 'pushnow-archive-grant-v2', aad);
      const decoded = JSON.parse(clear) as ArchiveTransfer;
      if (decoded.archive_id !== archive.id) throw new Error('archive_identity_changed');
      return await this.save({ archive, privateKey: decoded.archive_private_key }, epoch, user);
    }
    if (saved.length > 0) throw new Error('archive_identity_changed');
    let candidate: ArchiveKeys;
    if (provisional.length > 0) candidate = JSON.parse(provisional) as ArchiveKeys;
    else {
      const key = await secureCrypto.generateKey();
      const id = this.uuid();
      const signature = await secureCrypto.sign(enrollment.identityPrivateKey(), secureCrypto.text('archive', user, id, key.publicKey));
      candidate = { archive: { id, public_key: key.publicKey, certificate: signature }, privateKey: key.privateKey };
      this.check(epoch, user);
      await secureStorage.write(`archive-provisional:${user}`, JSON.stringify(candidate));
    }
    this.check(epoch, user);
    let registered: ArchiveResponse;
    try { registered = await apiClient.post<ArchiveResponse>('/v2/archive', candidate.archive, token); }
    catch {
      this.check(epoch, user);
      registered = await apiClient.get<ArchiveResponse>('/v2/archive', token);
    }
    if (!registered.archive || !this.same(registered.archive, candidate.archive)) throw new Error('history_access_pending');
    return await this.save(candidate, epoch, user);
  }

  async grant(device: SecureDevice): Promise<void> {
    const epoch = authService.generation;
    const user = authService.current.userID;
    if (device.userId !== user || device.status !== 'active') throw new Error('invalid_device');
    const keys = await this.ensure();
    this.check(epoch, user);
    await secureCrypto.verify(device.certificate, secureCrypto.text('device', user, device.id, device.publicKey), enrollment.identityPublicKey());
    const transfer: ArchiveTransfer = { archive_id: keys.archive.id, archive_private_key: keys.privateKey };
    const aad = `[2,"archive-grant",${JSON.stringify(user)},${JSON.stringify(device.id)},${JSON.stringify(keys.archive.id)}]`;
    const grant = await secureCrypto.seal(device.publicKey, JSON.stringify(transfer), 'pushnow-archive-grant-v2', aad);
    this.check(epoch, user);
    await apiClient.post<object>(`/v2/archive/grants/${device.id}`, grant, await authService.requireAccessToken());
  }

  private async save(keys: ArchiveKeys, epoch: number, user: string): Promise<ArchiveKeys> {
    await this.validateKeys(keys, user);
    this.check(epoch, user);
    await secureStorage.write(`archive:${user}`, JSON.stringify(keys));
    await secureStorage.remove(`archive-provisional:${user}`);
    this.check(epoch, user);
    return keys;
  }

  private async validateKeys(keys: ArchiveKeys, user: string): Promise<void> {
    await this.verify(keys.archive, user);
    // A sign/verify possession check validates that transferred private material matches the signed public key.
    const proof = await secureCrypto.sign(keys.privateKey, 'pushnow-archive-local-key-check');
    await secureCrypto.verify(proof, 'pushnow-archive-local-key-check', keys.archive.public_key);
  }

  private async verify(archive: ArchiveRecord, user: string): Promise<void> {
    await secureCrypto.verify(archive.certificate, secureCrypto.text('archive', user, archive.id, archive.public_key), enrollment.identityPublicKey());
  }

  private check(epoch: number, user: string): void {
    if (epoch !== authService.generation || !authService.current.verified || user !== authService.current.userID ||
      enrollment.userId !== user || !enrollment.identityEstablished()) throw new Error('trusted_device_required');
  }

  private same(a: ArchiveRecord, b: ArchiveRecord): boolean {
    return a.id === b.id && a.public_key === b.public_key && a.certificate === b.certificate;
  }

  private uuid(): string {
    const bytes = cryptoFramework.createRandom().generateRandomSync(16).data;
    bytes[6] = (bytes[6] & 15) | 64; bytes[8] = (bytes[8] & 63) | 128;
    const hex = Array.from(bytes).map((byte: number) => byte.toString(16).padStart(2, '0')).join('');
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`;
  }
}
export const secureArchiveService = new SecureArchiveService();
