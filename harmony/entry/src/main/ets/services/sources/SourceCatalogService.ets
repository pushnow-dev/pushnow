import { apiClient } from '../ApiClient';
import { authService } from '../AuthService';

export interface SourceRecord {
  id: string;
  name: string;
  sourceType: string;
  status: string;
  defaultPushEnabled: boolean;
}
interface SourcesResponse { sources: SourceRecord[]; }

export class SourceCatalogService {
  async load(): Promise<SourceRecord[]> {
    const epoch = authService.generation;
    const user = authService.current.userID;
    const result = await apiClient.get<SourcesResponse>('/v1/sources', await authService.requireAccessToken());
    if (epoch !== authService.generation || user !== authService.current.userID) throw new Error('session_changed');
    return result.sources;
  }
}
export const sourceCatalogService = new SourceCatalogService();
