import { common } from '@kit.AbilityKit';
import asset from '@ohos.security.asset';
import util from '@ohos.util';
import { BusinessError } from '@kit.BasicServicesKit';

// The OS Asset service protects secrets with the device security subsystem.
// Never fall back to Preferences when the secure vault is unavailable.
export class SecureStorage {
  async initialize(_context: common.UIAbilityContext): Promise<void> {}

  private query(key: string): asset.AssetMap {
    const query: asset.AssetMap = new Map();
    query.set(asset.Tag.ALIAS, new util.TextEncoder().encodeInto(`pushnow:${key}`));
    return query;
  }

  async read(key: string): Promise<string> {
    const query = this.query(key);
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);
    try {
      const entries = await asset.query(query);
      if (entries.length === 0) return '';
      const value = entries[0].get(asset.Tag.SECRET) as Uint8Array;
      return util.TextDecoder.create('utf-8', { fatal: true }).decodeWithStream(value);
    } catch (error) {
      if ((error as BusinessError).code === asset.ErrorCode.NOT_FOUND) return '';
      throw error as Error;
    }
  }

  async write(key: string, value: string): Promise<void> {
    const secret = new util.TextEncoder().encodeInto(value);
    const attributes = this.query(key);
    attributes.set(asset.Tag.SECRET, secret);
    attributes.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);
    attributes.set(asset.Tag.SYNC_TYPE, asset.SyncType.NEVER);
    try { await asset.add(attributes); }
    catch (error) {
      if ((error as BusinessError).code !== asset.ErrorCode.DUPLICATED) throw error as Error;
      const update: asset.AssetMap = new Map();
      update.set(asset.Tag.SECRET, secret);
      await asset.update(this.query(key), update);
    }
  }

  async remove(key: string): Promise<void> {
    try { await asset.remove(this.query(key)); }
    catch (error) {
      if ((error as BusinessError).code !== asset.ErrorCode.NOT_FOUND) throw error as Error;
    }
  }
}
export const secureStorage = new SecureStorage();
