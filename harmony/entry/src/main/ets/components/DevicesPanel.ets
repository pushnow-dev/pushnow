import { tr } from '../support/Localization';
import { HarmonyModel } from '../viewmodels/HarmonyModel';
import { SecureDevice } from '../models/JiZhiModels';

@Component
export struct DevicesPanel {
  @ObjectLink model: HarmonyModel;
  @State private renameId: string = '';
  @State private newName: string = '';

  build() {
    Column({ space: 14 }) {
      Text(tr('Devices')).fontSize(28).fontWeight(FontWeight.Bold)
      Text(tr('Your iOS and HarmonyOS devices share one account. Approve new devices only after comparing their pairing codes.'))
      Row({ space: 10 }) {
        Button(tr('Bind this device')).onClick(() => { void this.model.bind(); })
        Button(tr('Check approval')).onClick(() => { void this.model.accept(); })
      }
      if (this.model.pairingCode) Text(tr('Pairing code: {0}', [this.model.pairingCode])).fontSize(18).fontWeight(FontWeight.Bold)
      ForEach(this.model.devices, (device: SecureDevice) => {
        this.deviceCard(device)
      }, (device: SecureDevice) => device.id)
    }.width('100%').alignItems(HorizontalAlign.Start).enabled(this.model.session.verified && !this.model.busy)
  }

  @Builder
  private deviceCard(device: SecureDevice) {
    Column({ space: 10 }) {
      Text(`${device.name}${device.current ? ` · ${tr('This device')}` : ''}`).fontSize(18).fontWeight(FontWeight.Bold)
      Text(`${device.platform} · ${tr(device.status)}`).fontSize(14)
      Text(device.id).fontSize(12).copyOption(CopyOptions.LocalDevice)
      if (device.status === 'pending' && !device.current) {
        Button(tr('Show pairing code')).onClick(() => { void this.model.showPairing(device); })
        Button(tr('Approve device')).enabled(this.model.pairingDeviceID === device.id && this.model.pairingCode.length > 0).onClick(() => {
          AlertDialog.show({ title: tr('Approve device?'), message: tr('Confirm that the pairing code matches the code on the new device.'),
            primaryButton: { value: tr('Cancel'), action: () => {} },
            secondaryButton: { value: tr('Codes match'), action: () => { void this.model.approve(device); } } });
        })
      }
      if (device.status === 'active') {
        Row({ space: 12 }) {
          Text(tr('Notifications')).layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: device.notificationsEnabled })
            .onChange((enabled: boolean) => { void this.model.notifications(device, enabled); })
        }
        if (!device.current) Button(tr('Grant history access')).onClick(() => { void this.model.grantHistory(device); })
      }
      if (this.renameId === device.id) {
        TextInput({ text: this.newName, placeholder: tr('Device name') }).maxLength(80)
          .onChange((value: string) => { this.newName = value; })
        Button(tr('Save name')).onClick(() => { void this.model.rename(device, this.newName); this.renameId = ''; })
      } else {
        Button(tr('Rename')).onClick(() => { this.renameId = device.id; this.newName = device.name; })
      }
    }.padding(16).width('100%').alignItems(HorizontalAlign.Start).border({ width: 1, color: '#88888844' }).borderRadius(16)
  }
}
