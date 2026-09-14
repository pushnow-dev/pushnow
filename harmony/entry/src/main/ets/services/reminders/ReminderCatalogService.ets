import { apiClient } from '../ApiClient';
import { authService } from '../AuthService';
import { SourceRecord } from '../sources/SourceCatalogService';

export interface ReminderRecord {
  id: string; itemId: string; mode: string; scheduledAt?: string;
  priority: string; pushEnabled: boolean; status: string; nextFireAt?: string;
}
export interface ReminderItem { id: string; sourceId: string; title: string; }
interface ReminderResponse { reminders: ReminderRecord[]; }
interface ItemResponse { items: ReminderItem[]; }
interface SourceResponse { sources: SourceRecord[]; }
export class ReminderData {
  reminders: ReminderRecord[] = [];
  items: ReminderItem[] = [];
  sources: SourceRecord[] = [];
}
export class ReminderCatalogService {
  async load(): Promise<ReminderData> {
    const epoch = authService.generation;
    const user = authService.current.userID;
    const token = await authService.requireAccessToken();
    const reminders = await apiClient.get<ReminderResponse>('/v1/reminders?limit=100', token);
    const items = await apiClient.get<ItemResponse>('/v1/items?limit=100', token);
    const sources = await apiClient.get<SourceResponse>('/v1/sources', token);
    if (epoch !== authService.generation || user !== authService.current.userID) throw new Error('session_changed');
    const result = new ReminderData();
    result.reminders = reminders.reminders; result.items = items.items; result.sources = sources.sources;
    return result;
  }
}
export const reminderCatalogService = new ReminderCatalogService();
