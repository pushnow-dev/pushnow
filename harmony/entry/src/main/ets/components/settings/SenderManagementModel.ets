import { apiClient } from '../../services/ApiClient';
import { authService } from '../../services/AuthService';
export interface SenderKey { id: string; source_id: string; source_name?: string; key_prefix: string; created_at: string; expires_at?: string; last_used_at?: string; revoked_at?: string; }
export interface DeliveryLog { device_id: string; device_name?: string; status: string; last_error?: string; attempts: number; accepted_at?: string; }
export interface NotificationLog { message_id: string; source_id: string; key_id?: string; source_name?: string; created_at: string; scheduled_at?: string; expires_at?: string; read_at?: string; deliveries: DeliveryLog[]; }
interface KeysResponse { keys: SenderKey[]; }
interface LogsResponse { logs: NotificationLog[]; next_cursor?: string; }
interface CreatedResponse { sourceKey: string; key: SenderKey; }
interface ExpiryBody { expiresAt: string | null; }
@Observed
export class SenderManagementModel {
  keys: SenderKey[] = [];
  logs: NotificationLog[] = [];
  cursor: string = '';
  secret: string = '';
  busy: boolean = false;
  loaded: boolean = false;
  error: string = '';
  private epoch: number = -1;
  clear(): void { this.keys = []; this.logs = []; this.cursor = ''; this.secret = ''; this.loaded = false; this.error = ''; }
  private async perform(action: (token: string) => Promise<void>): Promise<void> {
    if (this.busy) return;
    if (this.epoch !== authService.generation) { this.clear(); this.epoch = authService.generation; }
    this.busy = true; this.error = '';
    try { await action(await authService.requireAccessToken()); }
    catch (error) { this.error = (error as Error).message; }
    finally { if (this.epoch !== authService.generation) this.clear(); this.busy = false; }
  }
  async loadKeys(): Promise<void> {
    await this.perform(async (token: string) => { this.keys = (await apiClient.get<KeysResponse>('/v2/keys', token)).keys; this.loaded = true; });
  }
  async save(key: SenderKey, days: number, create: boolean): Promise<void> {
    await this.perform(async (token: string) => {
      const body: ExpiryBody = { expiresAt: days ? new Date(Date.now() + days * 86400000).toISOString() : null };
      if (create) {
        const result = await apiClient.post<CreatedResponse>(`/v1/sources/${encodeURIComponent(key.source_id)}/keys`, body, token);
        this.secret = result.sourceKey;
      } else await apiClient.patch<KeysResponse>(`/v2/keys/${encodeURIComponent(key.id)}`, body, token);
      this.keys = (await apiClient.get<KeysResponse>('/v2/keys', token)).keys;
    });
  }
  async revoke(key: SenderKey): Promise<void> {
    await this.perform(async (token: string) => {
      await apiClient.delete(`/v2/keys/${encodeURIComponent(key.id)}`, token);
      this.keys = (await apiClient.get<KeysResponse>('/v2/keys', token)).keys;
    });
  }
  async loadLogs(keyID: string = '', more: boolean = false): Promise<void> {
    if (more && !this.cursor) return;
    await this.perform(async (token: string) => {
      let path = '/v2/logs?limit=30';
      if (keyID) path += `&key_id=${encodeURIComponent(keyID)}`;
      if (more) path += `&cursor=${encodeURIComponent(this.cursor)}`;
      const result = await apiClient.get<LogsResponse>(path, token);
      this.logs = more ? this.logs.concat(result.logs.filter((log: NotificationLog) => !this.logs.some((old: NotificationLog) => old.message_id === log.message_id))) : result.logs;
      this.cursor = result.next_cursor || ''; this.loaded = true;
    });
  }
}
