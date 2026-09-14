import { i18n } from '@kit.LocalizationKit';
import { secureStorage } from '../SecureStorage';

export class DiscoverySubscription {
  channelID: string = '';
  wantsNotification: boolean = true;
  hour: number = 9;
  minute: number = 0;
  timeZoneID: string = i18n.getTimeZone().getID();
}
interface Envelope { version: number; accountID: string; subscriptions: DiscoverySubscription[]; }
export function validSubscription(value: DiscoverySubscription): boolean {
  return value.channelID.length > 0 && Number.isInteger(value.hour) && value.hour >= 0 && value.hour <= 23 &&
    Number.isInteger(value.minute) && value.minute >= 0 && value.minute <= 59 &&
    typeof value.wantsNotification === 'boolean' && i18n.TimeZone.getAvailableIDs().includes(value.timeZoneID);
}
export class DiscoveryStore {
  async load(accountID: string): Promise<DiscoverySubscription[]> {
    if (!accountID) throw new Error('account_changed');
    const raw = await secureStorage.read(`discovery.v1.${accountID}`);
    if (!raw) return [];
    const envelope = JSON.parse(raw) as Envelope;
    if (envelope.version !== 1 || envelope.accountID !== accountID || !Array.isArray(envelope.subscriptions) ||
      !envelope.subscriptions.every(validSubscription) ||
      new Set(envelope.subscriptions.map((v: DiscoverySubscription): string => v.channelID)).size !== envelope.subscriptions.length) {
      throw new Error('unreadable_storage');
    }
    return envelope.subscriptions;
  }
  async save(values: DiscoverySubscription[], accountID: string): Promise<void> {
    const envelope: Envelope = { version: 1, accountID: accountID, subscriptions: values };
    await secureStorage.write(`discovery.v1.${accountID}`, JSON.stringify(envelope));
  }
}
