import { HarmonyModel } from '../../viewmodels/HarmonyModel';
import { secureDeviceEnrollmentService } from '../../services/SecureDeviceEnrollmentService';
import { SecureDevice } from '../../models/JiZhiModels';
import { tr } from '../../support/Localization';
import { palette, JZTheme } from '../../theme/JZTheme';

@Component
export struct SourcePendingDevicePanel {
  @ObjectLink model: HarmonyModel;
  onApproved: () => void = () => {};
  @StorageProp('systemColorMode') private systemColorMode: number = 1;
  @StorageProp('appearance') private appearance: string = 'system';
  private poll: number = -1;
  private get colors(): JZTheme { return palette(this.appearance === 'dark' || (this.appearance === 'system' && this.systemColorMode === 0)); }
  aboutToAppear(): void {
    void this.check();
    this.poll = setInterval(() => { void this.check(); }, 3000);
  }
  aboutToDisappear(): void { if (this.poll >= 0) clearInterval(this.poll); }
  private async check(): Promise<void> {
    if (this.model.busy || !this.model.session.verified) return;
    if (secureDeviceEnrollmentService.identityEstablished()) { this.onApproved(); return; }
    await this.model.bind();
    if (secureDeviceEnrollmentService.identityEstablished()) this.onApproved();
  }
  build() {
    Scroll() {
      Column({ space: 12 }) {
        if (this.model.error) Text(this.model.error).fontSize(13).fontColor(this.colors.red)
        Text(tr('This device')).fontSize(13).fontColor(this.colors.muted).padding({ left: 16, top: 20 }).width('100%')
        Column({ space: 0 }) {
          Row({ space: 12 }) {
            Text(tr('Pairing code')).fontSize(17).fontColor(this.colors.text).layoutWeight(1)
            Text(this.model.pairingCode).fontSize(16).fontFamily('monospace').fontColor(this.colors.text).copyOption(CopyOptions.LocalDevice)
          }.padding(16).width('100%')
          Divider().color(this.colors.line).margin({ left: 16 })
          Text(tr('Waiting for device approval')).fontSize(17).fontColor(this.colors.text).padding(16).width('100%')
        }.width('100%').backgroundColor(this.colors.card).borderRadius(10)
        Text(tr('Account devices')).fontSize(13).fontColor(this.colors.muted).padding({ left: 16, top: 20 }).width('100%')
        Column({ space: 0 }) {
          ForEach(this.model.devices.filter((device: SecureDevice) => device.status !== 'revoked'), (device: SecureDevice) => {
            Column({ space: 8 }) {
              Text(device.name).fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.colors.text)
              Text(tr(device.current ? 'Current' : device.status === 'pending' ? 'Pending approval' : 'Active')).fontSize(13).fontColor(this.colors.muted)
              Text(device.id).fontSize(12).fontFamily('monospace').fontColor(this.colors.muted).copyOption(CopyOptions.LocalDevice)
            }.padding(16).width('100%').alignItems(HorizontalAlign.Start)
          }, (device: SecureDevice) => device.id)
        }.width('100%').backgroundColor(this.colors.card).borderRadius(10)
      }.padding(18).width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').layoutWeight(1)
  }
}
