import { common } from '@kit.AbilityKit';
import { HarmonyModel } from '../../viewmodels/HarmonyModel';
import { InboxItem } from '../../models/JiZhiModels';
import { tr } from '../../support/Localization';
import { palette } from '../../theme/JZTheme';
import { RoundIcon } from '../shared/AppChrome';
import { SecureMessageImage } from './SecureMessageImage';
import { AttachmentPanel } from '../AttachmentPanel';

@Component
export struct MessageDetailPanel {
  @ObjectLink model: HarmonyModel;
  @Prop item: InboxItem;
  dark: boolean = false;
  onBack: () => void = () => {};
  aboutToAppear(): void {
    if (this.item.unread) void this.model.read(this.item);
  }
  private confirmDelete(): void {
    AlertDialog.show({ title: tr('Delete message'), message: tr('This removes the message from all devices.'),
      primaryButton: { value: tr('Cancel'), action: () => {} },
      secondaryButton: { value: tr('Delete message'), action: () => {
        this.model.remove(this.item).then(() => { if (!this.model.error) this.onBack(); });
      } } });
  }
  build() {
    Column() {
      Row() {
        RoundIcon({ icon: $r('app.media.ui_back'), label: tr('Back'), dark: this.dark, action: this.onBack })
        Text(tr('Encrypted message')).fontSize(17).fontWeight(FontWeight.Medium).layoutWeight(1).textAlign(TextAlign.Center)
        if (this.item.id.startsWith('v2:')) {
          RoundIcon({ icon: $r('app.media.ui_trash'), label: tr('Delete message'), dark: this.dark, action: () => this.confirmDelete() })
        } else { Blank().width(38) }
      }.padding({ left: 18, right: 18, top: 8, bottom: 10 })
      Scroll() {
        Column({ space: 18 }) {
          if (this.model.error) Text(this.model.error).fontColor(palette(this.dark).red)
          if (this.item.iconId) SecureMessageImage({ item: this.item, attachmentID: this.item.iconId, compact: true })
          if (this.item.imageId) SecureMessageImage({ item: this.item, attachmentID: this.item.imageId })
          Text(this.item.title).fontColor(palette(this.dark).text).fontSize(22).fontWeight(FontWeight.Bold).copyOption(CopyOptions.LocalDevice)
          Text(this.item.time).fontSize(12).fontColor(palette(this.dark).muted).copyOption(CopyOptions.LocalDevice)
          Text(this.item.summary).fontColor(palette(this.dark).text).fontSize(17).copyOption(CopyOptions.LocalDevice)
          ForEach(this.item.links.filter((url: string) => /^https?:\/\//i.test(url)), (url: string) => {
            Text(url).fontSize(17).fontColor(palette(this.dark).blue).maxLines(3)
              .onClick(() => {
                const context = getContext(this) as common.UIAbilityContext;
                context.openLink(url).catch(() => { this.model.error = tr('Unable to open link'); });
              })
          })
          AttachmentPanel({ item: this.item })
        }.width('100%').alignItems(HorizontalAlign.Start).padding(20)
      }.layoutWeight(1)
    }.width('100%').height('100%').backgroundColor(palette(this.dark).background)
  }
}
