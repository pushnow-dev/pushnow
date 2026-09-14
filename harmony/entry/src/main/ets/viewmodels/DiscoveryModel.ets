import { authService } from '../services/AuthService';
import { DiscoveryStore, DiscoverySubscription, validSubscription } from '../services/discovery/DiscoveryStore';
import { discoveryChannels } from '../services/discovery/DiscoveryCatalog';
import { dc } from '../services/discovery/DiscoveryCopy';

@Observed
export class DiscoveryModel {
  subscriptions: DiscoverySubscription[] = [];
  loaded: boolean = false;
  busy: boolean = false;
  error: string = '';
  private accountID: string = authService.current.userID;
  private generation: number = authService.generation;
  private store: DiscoveryStore = new DiscoveryStore();
  get current(): boolean {
    return authService.current.verified && this.accountID === authService.current.userID && this.generation === authService.generation;
  }
  subscription(id: string): DiscoverySubscription | undefined {
    return this.current ? this.subscriptions.find((value: DiscoverySubscription) => value.channelID === id) : undefined;
  }
  async load(): Promise<void> {
    this.loaded = false;
    this.subscriptions = [];
    this.accountID = authService.current.userID;
    this.generation = authService.generation;
    try {
      if (!this.current) throw new Error('account_changed');
      const values = await this.store.load(this.accountID);
      if (!this.current) throw new Error('account_changed');
      this.subscriptions = values;
      this.loaded = true;
      this.error = '';
    } catch (_) { this.report(); }
  }
  async save(value: DiscoverySubscription): Promise<boolean> {
    if (!validSubscription(value) || !discoveryChannels.some((channel) => channel.id === value.channelID)) {
      this.error = dc('Choose a valid time and timezone.'); return false;
    }
    return this.mutate(value.channelID, value);
  }
  async remove(id: string): Promise<boolean> { return this.mutate(id); }
  private async mutate(id: string, value?: DiscoverySubscription): Promise<boolean> {
    if (this.busy) return false;
    this.busy = true;
    try {
      if (!this.loaded || !this.current) throw new Error('account_changed');
      const values = (await this.store.load(this.accountID)).filter((item: DiscoverySubscription) => item.channelID !== id);
      if (value) values.push(value);
      if (!this.current) throw new Error('account_changed');
      await this.store.save(values, this.accountID);
      if (!this.current) throw new Error('account_changed');
      this.subscriptions = values; this.error = ''; return true;
    } catch (_) { this.report(); return false; }
    finally { this.busy = false; }
  }
  private report(): void {
    this.error = dc(this.current ? 'Local preferences could not be loaded or saved. Try again.' : 'Your account changed. Reopen this channel.');
    if (!this.current) { this.subscriptions = []; this.loaded = false; }
  }
}
