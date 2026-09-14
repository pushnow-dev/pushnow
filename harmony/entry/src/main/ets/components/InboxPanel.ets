import { tr } from '../support/Localization';
import { AttachmentPanel } from './AttachmentPanel';
import { InboxItem } from '../models/JiZhiModels';
import { HarmonyModel } from '../viewmodels/HarmonyModel';

@Component
export struct InboxPanel {
  @ObjectLink model: HarmonyModel;
  @State private selected: string = '';

  build() {
    Column({ space: 12 }) {
      Text(tr('Inbox')).fontSize(28).fontWeight(FontWeight.Bold)
      if (this.model.items.length === 0) {
        Text(this.model.session.verified ? tr('No decrypted messages available. Refresh after this device is approved.') : tr('Sign in to receive your encrypted messages.'))
          .fontSize(15).padding(20)
      }
      ForEach(this.model.items, (item: InboxItem) => {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            Text(item.unread ? '●' : '○').fontColor('#0969DA')
            Text(item.title).fontSize(18).fontWeight(FontWeight.Bold).layoutWeight(1)
          }
          Text(item.time).fontSize(12).opacity(0.65)
          Text(item.summary).fontSize(15).maxLines(this.selected === item.id ? 1000 : 3)
            .copyOption(CopyOptions.LocalDevice)
          if (this.selected === item.id) {
            ForEach(item.links, (url: string) => {
              Text(url).fontSize(13).fontColor('#0969DA').copyOption(CopyOptions.LocalDevice)
            })
            AttachmentPanel({ item: item })
          }
          Row({ space: 10 }) {
            Button(this.selected === item.id ? tr('Collapse') : tr('Open')).onClick(() => { this.selected = this.selected === item.id ? '' : item.id; })
            if (item.unread) Button(item.requiresAck ? tr('Acknowledge') : tr('Mark read')).onClick(() => { void this.model.read(item); })
            if (item.id.startsWith('v2:')) Button(tr('Delete')).onClick(() => {
              AlertDialog.show({ title: tr('Delete message?'), message: tr('This removes the message from all devices.'),
                primaryButton: { value: tr('Cancel'), action: () => {} },
                secondaryButton: { value: tr('Delete'), action: () => { void this.model.remove(item); } } });
            })
          }.enabled(!this.model.busy)
        }.width('100%').alignItems(HorizontalAlign.Start).padding(16)
          .border({ width: 1, color: '#88888844' }).borderRadius(16)
      }, (item: InboxItem) => item.id)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
