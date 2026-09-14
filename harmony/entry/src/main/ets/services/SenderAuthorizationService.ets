import { apiClient } from './ApiClient';
import { authService } from './AuthService';
import { API_BASE_URL } from './AppConfig';
import { secureCrypto } from './SecureCrypto';
import { secureDeviceEnrollmentService as enrollment } from './SecureDeviceEnrollmentService';
import { secureArchiveService, ArchiveRecord } from './SecureArchiveService';

export interface SenderAuthorization { id: string; name: string; public_key: string; expires_at: string; }
export interface AuthorizedSender { id: string; name: string; public_key: string; created_at: string; status: string; }
interface LookupResponse { authorization: SenderAuthorization; }
interface SendersResponse { senders: AuthorizedSender[]; }
interface SourceResponse { source: SourceID; }
interface SourceID { id: string; }
interface SourcePayload { name: string; source_type: string; default_priority: string; default_push_enabled: boolean; }
interface KeyPayload { scopes: string[]; }
interface KeyResponse { source_key: string; }
interface SetupPayload { public_key: string; certificate: string; }
interface SenderGrant {
  api_url: string; user_id: string; source_id: string; source_key: string; identity_public_key: string; archive: ArchiveRecord;
}
interface ApprovalPayload { source_id: string; enc: string; ciphertext: string; expires_at: string | null; }

export class SenderAuthorizationService {
  private approving: boolean = false;
  private lookedUp?: SenderAuthorization;
  private lookupEpoch: number = -1;

  async lookup(code: string): Promise<SenderAuthorization> {
    this.lookedUp = undefined;
    const normalized = code.toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (normalized.length !== 8) throw new Error('invalid_authorization_code');
    const epoch = authService.generation;
    const user = authService.current.userID;
    await secureArchiveService.ensure();
    this.check(epoch, user);
    const result = await apiClient.get<LookupResponse>(`/v2/authorizations/lookup?code=${normalized}`, await authService.requireAccessToken());
    this.check(epoch, user);
    if (!Number.isFinite(Date.parse(result.authorization.expires_at)) || Date.parse(result.authorization.expires_at) <= Date.now()) {
      throw new Error('authorization_expired');
    }
    this.lookedUp = result.authorization;
    this.lookupEpoch = epoch;
    return result.authorization;
  }

  async approve(request: SenderAuthorization, confirmed: boolean, expiresAt: string | null = null): Promise<void> {
    if (expiresAt !== null && (!Number.isFinite(Date.parse(expiresAt)) || Date.parse(expiresAt) <= Date.now())) throw new Error('invalid_expiry');
    if (this.approving) throw new Error('authorization_in_progress');
    if (!confirmed || !this.lookedUp || this.lookupEpoch !== authService.generation ||
      request.id !== this.lookedUp.id || request.public_key !== this.lookedUp.public_key ||
      !Number.isFinite(Date.parse(request.expires_at)) || Date.parse(request.expires_at) <= Date.now()) {
      throw new Error('fingerprint_confirmation_required');
    }
    this.approving = true;
    const epoch = authService.generation;
    const user = authService.current.userID;
    let createdSource = '';
    try {
      const archive = await secureArchiveService.ensure();
      this.check(epoch, user);
      const token = await authService.requireAccessToken();
      const sourcePayload: SourcePayload = { name: request.name, source_type: 'agent', default_priority: 'normal', default_push_enabled: true };
      const result = await apiClient.post<SourceResponse>('/v1/sources', sourcePayload, token);
      createdSource = result.source.id;
      this.check(epoch, user);
      const certificate = await secureCrypto.sign(enrollment.identityPrivateKey(), secureCrypto.text('source', user, createdSource, request.public_key));
      const setup: SetupPayload = { public_key: request.public_key, certificate };
      // Require encryption before creating a usable credential.
      await apiClient.put<object>(`/v1/secure/sources/${createdSource}`, setup, token);
      this.check(epoch, user);
      const keyPayload: KeyPayload = { scopes: ['items:write'] };
      const key = await apiClient.post<KeyResponse>(`/v1/sources/${createdSource}/keys`, keyPayload, token);
      this.check(epoch, user);
      const transfer: SenderGrant = { api_url: API_BASE_URL, user_id: user, source_id: createdSource,
        source_key: key.source_key, identity_public_key: enrollment.identityPublicKey(), archive: archive.archive };
      const aad = `[2,"sender-grant",${JSON.stringify(request.id)},${JSON.stringify(request.public_key)}]`;
      const grant = await secureCrypto.seal(request.public_key, JSON.stringify(transfer), 'pushnow-sender-grant-v2', aad);
      this.check(epoch, user);
      const payload: ApprovalPayload = { source_id: createdSource, enc: grant.enc, ciphertext: grant.ciphertext, expires_at: expiresAt };
      await apiClient.post<object>(`/v2/authorizations/${request.id}/approve`, payload, token);
      this.check(epoch, user);
      this.lookedUp = undefined;
    } finally {
      // Do not automatically revoke here: an interrupted response may have successfully approved the sender.
      // The sender list provides explicit revocation for a completed or interrupted authorization.
      this.approving = false;
    }
  }

  async list(): Promise<AuthorizedSender[]> {
    const result = await apiClient.get<SendersResponse>('/v2/senders', await authService.requireAccessToken());
    return result.senders;
  }

  async revoke(id: string): Promise<void> {
    await apiClient.delete(`/v2/senders/${encodeURIComponent(id)}`, await authService.requireAccessToken());
  }

  private check(epoch: number, user: string): void {
    if (epoch !== authService.generation || !authService.current.verified || authService.current.userID !== user ||
      enrollment.userId !== user || !enrollment.identityEstablished()) throw new Error('trusted_device_required');
  }
}
export const senderAuthorizationService = new SenderAuthorizationService();
