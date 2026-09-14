import { apiClient } from '../../services/ApiClient';
import { authService } from '../../services/AuthService';
interface AccountUser { hasPassword: boolean; }
interface MeResponse { user: AccountUser; }
interface PasswordBody { password: string; }
export class AccountPasswordService {
  async needsSetup(): Promise<boolean> {
    const result = await apiClient.get<MeResponse>('/v1/me', await authService.requireAccessToken());
    return result.user.hasPassword !== true;
  }
  async save(password: string, confirmation: string): Promise<void> {
    if (password !== confirmation) throw new Error('Passwords do not match');
    if (password.length < 8 || password.length > 128 || !/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) throw new Error('Use 8–128 characters including letters and numbers');
    const body: PasswordBody = { password };
    const result = await apiClient.post<MeResponse>('/v1/me/password', body, await authService.requireAccessToken());
    if (!result.user.hasPassword) throw new Error('Password setup could not be verified');
  }
}
