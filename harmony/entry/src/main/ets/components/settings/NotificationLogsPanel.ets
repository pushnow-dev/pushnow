import { HarmonyModel } from '../../viewmodels/HarmonyModel';
import { SenderManagementModel, NotificationLog, DeliveryLog } from './SenderManagementModel';
import { SettingsRow } from './SettingsRow';
import { tr } from '../../support/Localization';
import { palette, JZTheme } from '../../theme/JZTheme';
@Component
export struct NotificationLogsPanel {
  @ObjectLink model: HarmonyModel;
  keyId: string = '';
  @State private data: SenderManagementModel = new SenderManagementModel();
  @State private selected?: NotificationLog;
  @StorageProp('systemColorMode') private systemColorMode: number = 1;
  @StorageProp('appearance') private appearance: string = 'system';
  private get colors(): JZTheme { return palette(this.appearance === 'dark' || (this.appearance === 'system' && this.systemColorMode === 0)); }
  aboutToAppear(): void { void this.data.loadLogs(this.keyId); }
  aboutToDisappear(): void { this.data.clear(); this.selected = undefined; }
  @Builder private detail(log: NotificationLog) {
    Button(tr('Back')).onClick(() => { this.selected = undefined; })
    SettingsRow({ title: tr('Source'), value: log.source_name || log.source_id, disclosure: false })
    SettingsRow({ title: tr('Message ID'), value: log.message_id, disclosure: false })
    if (log.key_id) SettingsRow({ title: tr('Key ID'), value: log.key_id, disclosure: false })
    SettingsRow({ title: tr('Created'), value: log.created_at, disclosure: false })
    SettingsRow({ title: tr('Scheduled'), value: log.scheduled_at || tr('Immediately'), disclosure: false })
    SettingsRow({ title: tr('Expires'), value: log.expires_at || tr('Never'), disclosure: false })
    SettingsRow({ title: tr('Read'), value: log.read_at || tr('Unread'), disclosure: false })
    Text(tr('Device deliveries')).fontSize(13).fontColor(this.colors.muted).margin({ top: 22, bottom: 10 })
    if (!log.deliveries.length) Text(tr('No device deliveries')).fontColor(this.colors.muted)
    ForEach(log.deliveries, (delivery: DeliveryLog) => {
      Column({ space: 8 }) {
        Text(delivery.device_name || delivery.device_id).fontSize(17).fontWeight(FontWeight.Bold)
        Text(delivery.device_id).fontSize(12).copyOption(CopyOptions.LocalDevice)
        SettingsRow({ title: tr('Status'), value: tr(delivery.status === 'accepted' ? 'Accepted by push service' : delivery.status), disclosure: false })
        SettingsRow({ title: tr('Attempts'), value: String(delivery.attempts), disclosure: false })
        SettingsRow({ title: tr('Accepted by push service'), value: delivery.accepted_at || tr('Not available'), disclosure: false })
        if (delivery.last_error) Text(delivery.last_error).fontSize(12).fontColor(this.colors.red)
      }.alignItems(HorizontalAlign.Start).padding(12).backgroundColor(this.colors.card).borderRadius(10)
    })
  }
  build() {
    Column({ space: 12 }) {
      if (!this.model.session.verified) Text(tr('Sign in to continue.')).fontColor(this.colors.muted)
      else if (this.selected) this.detail(this.selected)
      else {
        Button(tr('Refresh')).onClick(() => { void this.data.loadLogs(this.keyId); }).enabled(!this.data.busy)
        if (this.data.loaded && !this.data.logs.length) Text(tr('No notification logs')).fontSize(20).fontColor(this.colors.muted).margin(32)
        ForEach(this.data.logs, (log: NotificationLog) => {
          Column({ space: 6 }) {
            Text(log.source_name || log.source_id).fontSize(17).fontWeight(FontWeight.Bold)
            Text(log.message_id).fontSize(12).maxLines(1)
            Text(log.created_at).fontSize(12).fontColor(this.colors.muted)
            Text(log.deliveries.length ? `${tr('Devices')}: ${log.deliveries.length}` : tr('No device deliveries')).fontSize(12).fontColor(this.colors.muted)
          }.alignItems(HorizontalAlign.Start).width('100%').padding(16).backgroundColor(this.colors.card).onClick(() => { this.selected = log; })
        })
        if (this.data.cursor) Button(tr('Load more')).enabled(!this.data.busy).onClick(() => { void this.data.loadLogs(this.keyId, true); })
      }
      if (this.data.busy) LoadingProgress().width(28).height(28)
      if (this.data.error) {
        Text(this.data.error).fontColor(this.colors.red)
        Button(tr('Retry')).onClick(() => { void this.data.loadLogs(this.keyId); })
      }
    }.width('100%').alignItems(HorizontalAlign.Start).foregroundColor(this.colors.text)
  }
}
