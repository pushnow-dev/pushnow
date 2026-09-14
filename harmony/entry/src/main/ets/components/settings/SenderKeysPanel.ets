import { HarmonyModel } from '../../viewmodels/HarmonyModel';
import { SenderManagementModel, SenderKey } from './SenderManagementModel';
import { NotificationLogsPanel } from './NotificationLogsPanel';
import { SettingsRow } from './SettingsRow';
import { tr } from '../../support/Localization';
import { palette, JZTheme } from '../../theme/JZTheme';
@Component
export struct SenderKeysPanel {
  @ObjectLink model: HarmonyModel;
  @State private data: SenderManagementModel = new SenderManagementModel();
  @State private editor?: SenderKey;
  @State private creating: boolean = false;
  @State private days: number = 0;
  @State private logKey: string = '';
  @StorageProp('systemColorMode') private systemColorMode: number = 1;
  @StorageProp('appearance') private appearance: string = 'system';
  private get colors(): JZTheme { return palette(this.appearance === 'dark' || (this.appearance === 'system' && this.systemColorMode === 0)); }
  aboutToAppear(): void { void this.data.loadKeys(); }
  aboutToDisappear(): void { this.data.clear(); this.editor = undefined; }
  private edit(key: SenderKey, create: boolean): void { this.editor = key; this.creating = create; this.days = 0; this.data.secret = ''; }
  private async save(): Promise<void> {
    if (!this.editor) return;
    await this.data.save(this.editor, this.days, this.creating);
    if (!this.data.error && !this.creating) this.editor = undefined;
  }
  private confirmRevoke(key: SenderKey): void {
    this.getUIContext().showAlertDialog({ title: tr('Revoke key?'), message: tr('This key will no longer be able to send notifications.'),
      primaryButton: { value: tr('Cancel'), action: () => {} }, secondaryButton: { value: tr('Revoke key'), fontColor: this.colors.red, action: () => { void this.data.revoke(key); } } });
  }
  @Builder private summary(key: SenderKey) {
    Text(key.source_name || key.source_id).fontSize(17).fontWeight(FontWeight.Bold).padding(16)
    Text(key.key_prefix).fontSize(12).fontFamily('monospace').copyOption(CopyOptions.LocalDevice).padding({ left: 16 })
    SettingsRow({ title: tr('Status'), value: tr(key.revoked_at ? 'Revoked' : key.expires_at && Date.parse(key.expires_at) <= Date.now() ? 'Expired' : 'Active'), disclosure: false })
    SettingsRow({ title: tr('Created'), value: key.created_at, disclosure: false })
    SettingsRow({ title: tr('Expires'), value: key.expires_at || tr('Never'), disclosure: false })
    SettingsRow({ title: tr('Last used'), value: key.last_used_at || tr('Not used yet'), disclosure: false })
    if (key.revoked_at) SettingsRow({ title: tr('Revoked'), value: key.revoked_at, disclosure: false })
    SettingsRow({ title: tr('Notification logs'), action: () => { this.logKey = key.id; } })
    if (!key.revoked_at) {
      SettingsRow({ title: tr('Edit expiry'), action: () => { this.edit(key, false); } })
      SettingsRow({ title: tr('Create another key'), action: () => { this.edit(key, true); } })
      SettingsRow({ title: tr('Revoke key'), action: () => { this.confirmRevoke(key); } })
    }
  }
  build() {
    Column({ space: 12 }) {
      if (!this.model.session.verified) Text(tr('Sign in to continue.'))
      else if (this.logKey) {
        Button(tr('Back')).onClick(() => { this.logKey = ''; })
        NotificationLogsPanel({ model: this.model, keyId: this.logKey })
      } else if (this.editor) {
        Text(tr(this.creating ? 'Create key' : 'Edit expiry')).fontSize(22).fontWeight(FontWeight.Bold)
        if (this.data.secret) {
          Text(tr('New sender key')).fontSize(17)
          Text(this.data.secret).fontSize(14).fontFamily('monospace').copyOption(CopyOptions.LocalDevice)
          Text(tr('Keep this key safe. It will only be shown once.')).fontColor(this.colors.muted)
        } else {
          Text(this.editor.source_name || this.editor.source_id)
          if (!this.creating) SettingsRow({ title: tr('Current expiry'), value: this.editor.expires_at || tr('Never'), disclosure: false })
          ForEach([0, 7, 30, 90], (days: number) => {
            SettingsRow({ title: tr(days === 0 ? 'Never' : `${days} days`), disclosure: false, selected: this.days === days, action: () => { this.days = days; } })
          })
          Button(tr(this.creating ? 'Create key' : 'Save')).enabled(!this.data.busy).onClick(() => { void this.save(); })
        }
        Button(tr('Done')).enabled(!this.data.busy).onClick(() => { this.data.secret = ''; this.editor = undefined; })
      } else {
        Button(tr('Refresh')).enabled(!this.data.busy).onClick(() => { void this.data.loadKeys(); })
        if (this.data.loaded && !this.data.keys.length) Text(tr('No sender keys')).fontSize(20).fontColor(this.colors.muted).margin(32)
        ForEach(this.data.keys, (key: SenderKey) => {
          Column() { this.summary(key) }.alignItems(HorizontalAlign.Start).width('100%').backgroundColor(this.colors.card).borderRadius(10).enabled(!this.data.busy)
        })
      }
      if (this.data.busy) LoadingProgress().width(28).height(28)
      if (this.data.error) {
        Text(this.data.error).fontColor(this.colors.red)
        if (!this.editor) Button(tr('Retry')).onClick(() => { void this.data.loadKeys(); })
      }
    }.width('100%').alignItems(HorizontalAlign.Start).foregroundColor(this.colors.text)
  }
}
