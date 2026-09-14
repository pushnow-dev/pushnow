import { i18n } from '@kit.LocalizationKit';
import { DiscoveryModel } from '../../viewmodels/DiscoveryModel';
import { DiscoveryChannel, discoveryChannels } from '../../services/discovery/DiscoveryCatalog';
import { DiscoverySubscription } from '../../services/discovery/DiscoveryStore';
import { dc } from '../../services/discovery/DiscoveryCopy';
import { JZTheme, palette } from '../../theme/JZTheme';

@Component
export struct DiscoveryEditor {
  @StorageProp('systemColorMode') private systemColorMode: number = 1;
  @StorageProp('appearance') private appearance: string = 'system';
  private get colors(): JZTheme { return palette(this.appearance === 'dark' || (this.appearance === 'system' && this.systemColorMode === 0)); }
  @ObjectLink model: DiscoveryModel;
  channel: DiscoveryChannel = discoveryChannels[0];
  onClose: () => void = () => {};
  @State private wantsNotification: boolean = true;
  @State private hour: number = 9;
  @State private minute: number = 0;
  @State private zone: string = i18n.getTimeZone().getID();
  @State private showZones: boolean = false;
  @State private search: string = '';
  aboutToAppear(): void {
    const saved = this.model.subscription(this.channel.id);
    if (saved) { this.wantsNotification = saved.wantsNotification; this.hour = saved.hour; this.minute = saved.minute; this.zone = saved.timeZoneID; }
  }
  private async save(): Promise<void> {
    const draft = new DiscoverySubscription();
    draft.channelID = this.channel.id; draft.wantsNotification = this.wantsNotification;
    draft.hour = this.hour; draft.minute = this.minute; draft.timeZoneID = this.zone;
    if (await this.model.save(draft)) this.onClose();
  }
  private remove(): void {
    this.getUIContext().showAlertDialog({
      title: dc('Remove saved subscription?'), message: dc('This removes the preference from this device only.'),
      primaryButton: { value: dc('Cancel'), action: () => {} },
      secondaryButton: { value: dc('Unsubscribe'), fontColor: this.colors.red, action: () => { void this.performRemove(); } }
    });
  }
  private async performRemove(): Promise<void> { if (await this.model.remove(this.channel.id)) this.onClose(); }
  @Builder
  private zones() {
    Column({ space: 12 }) {
      Row() {
        Text('‹').fontSize(28).fontColor(this.colors.text).onClick(() => { this.showZones = false; })
        Text(dc('Timezone')).fontColor(this.colors.text).fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.colors.text).layoutWeight(1).textAlign(TextAlign.Center)
      }.width('100%')
      TextInput({ text: this.search, placeholder: dc('Search timezones') }).fontColor(this.colors.text).placeholderColor(this.colors.muted).backgroundColor(this.colors.card).onChange((value: string) => { this.search = value; })
      List() {
        ForEach(i18n.TimeZone.getAvailableIDs().sort().filter((zone: string) => zone.toLowerCase().includes(this.search.toLowerCase())), (zone: string) => {
          ListItem() {
            Row() { Text(zone).fontColor(this.colors.text).layoutWeight(1); if (zone === this.zone) { Text('✓').fontColor(this.colors.blue) } }
              .width('100%').padding(14).onClick(() => { this.zone = zone; this.showZones = false; })
          }
        }, (zone: string) => zone)
      }.layoutWeight(1)
    }.padding(18).height('100%')
  }
  build() {
    Column() {
      if (this.showZones) { this.zones() }
      else {
        Row() {
          Text(dc('Cancel')).fontColor(this.colors.blue).onClick(this.onClose)
          Text(dc(this.model.subscription(this.channel.id) ? 'Edit subscription' : 'Save subscription'))
            .fontWeight(FontWeight.Bold).fontColor(this.colors.text).layoutWeight(1).textAlign(TextAlign.Center)
        }.padding(18).width('100%')
        Scroll() {
          Column({ space: 18 }) {
            Column({ space: 10 }) {
              Text(dc(this.channel.title)).fontWeight(FontWeight.Bold).fontSize(17).fontColor(this.colors.text)
              Text(dc(this.channel.summary)).fontColor(this.colors.muted)
              Text(dc('Delivery is not active. These preferences are saved only on this device for your account.')).fontSize(13).fontColor(this.colors.muted)
              if (this.model.subscription(this.channel.id)) { Text(dc('Saved locally - pending activation')).fontSize(14).fontColor(this.colors.muted) }
            }.alignItems(HorizontalAlign.Start).width('100%').padding(16).backgroundColor(this.colors.card).borderRadius(12)
            Column({ space: 14 }) {
              Row() {
                Text(dc('Daily notification')).fontColor(this.colors.text).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.wantsNotification }).onChange((value: boolean) => { this.wantsNotification = value; })
              }.width('100%')
              if (this.wantsNotification) {
                Row() {
                  Text(dc('Daily time')).fontColor(this.colors.text).layoutWeight(1)
                  Button(`${this.hour.toString().padStart(2, '0')}:${this.minute.toString().padStart(2, '0')}`)
                    .fontColor(this.colors.text).backgroundColor(this.colors.paper).onClick(() => {
                      this.getUIContext().showTimePickerDialog({ selected: new Date(2001, 0, 1, this.hour, this.minute), useMilitaryTime: true,
                        onAccept: (value: TimePickerResult) => { this.hour = value.hour ?? 9; this.minute = value.minute ?? 0; } });
                    })
                }.width('100%')
              } else { Text(dc('In-app only')).fontColor(this.colors.muted) }
              Row() { Text(dc('Timezone')).fontColor(this.colors.text); Text(this.zone).layoutWeight(1).textAlign(TextAlign.End).fontColor(this.colors.muted); Text('›').fontColor(this.colors.muted) }
                .width('100%').onClick(() => { this.showZones = true; })
            }.width('100%').padding(16).backgroundColor(this.colors.card).borderRadius(12)
            if (this.model.error) { Text(this.model.error).fontColor(this.colors.red) }
            Column({ space: 18 }) {
              Text(dc(this.model.subscription(this.channel.id) ? 'Save changes' : 'Save subscription')).fontColor(this.colors.blue)
                .width('100%').onClick(() => { void this.save(); })
              if (this.model.subscription(this.channel.id)) {
                Divider()
                Text(dc('Unsubscribe')).fontColor(this.colors.red).width('100%').onClick(() => { this.remove(); })
              }
            }.padding(16).width('100%').backgroundColor(this.colors.card).borderRadius(12).enabled(this.model.loaded && this.model.current && !this.model.busy)
          }.padding(18).width('100%')
        }.layoutWeight(1).width('100%')
      }
    }.height('100%').width('100%').backgroundColor(this.colors.paper)
  }
}
