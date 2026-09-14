import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';

export class PreferenceService {
  language: string = 'system';
  appearance: string = 'system';
  timezoneIdentifier: string = 'system';
  onChange: () => void = () => {};
  private store?: preferences.Preferences;

  async initialize(context: common.UIAbilityContext): Promise<void> {
    this.store = await preferences.getPreferences(context, 'pushnow_preferences');
    this.language = String(this.store.getSync('language', 'system'));
    this.appearance = String(this.store.getSync('appearance', 'system'));
    this.timezoneIdentifier = String(this.store.getSync('timezone', 'system'));
    this.publish();
  }

  private publish(): void {
    AppStorage.setOrCreate('language', this.language);
    AppStorage.setOrCreate('appearance', this.appearance);
    AppStorage.setOrCreate('timezone', this.timezoneIdentifier);
    this.onChange();
  }

  async select(kind: string, value: string): Promise<void> {
    if (!this.store) throw new Error('Preferences are not initialized');
    await this.store.put(kind, value);
    await this.store.flush();
    if (kind === 'language') this.language = value;
    if (kind === 'appearance') this.appearance = value;
    if (kind === 'timezone') this.timezoneIdentifier = value;
    this.publish();
  }
}
export const preferenceService = new PreferenceService();
