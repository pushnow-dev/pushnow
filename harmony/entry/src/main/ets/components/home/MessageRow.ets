import { InboxItem } from '../../models/JiZhiModels';
import { palette } from '../../theme/JZTheme';
import { tr } from '../../support/Localization';
import { SecureMessageImage } from './SecureMessageImage';

export function relativeTime(value: string): string {
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) return value;
  const minutes = Math.max(0, Math.floor((Date.now() - timestamp) / 60000));
  if (minutes < 1) return tr('Just now');
  if (minutes < 60) return tr('{0} minutes ago', [minutes.toString()]);
  if (minutes < 1440) return tr('{0} hours ago', [Math.floor(minutes / 60).toString()]);
  return tr('{0} days ago', [Math.floor(minutes / 1440).toString()]);
}

@Component
export struct MessageRow {
  @Prop item: InboxItem;
  dark: boolean = false;
  onOpen: () => void = () => {};
  build() {
    Row({ space: 12 }) {
      Circle().width(8).height(8).fill(this.item.unread ? palette(this.dark).blue : Color.Transparent)
        .margin({ top: 20 })
      if (this.item.iconId) {
        SecureMessageImage({ item: this.item, attachmentID: this.item.iconId, compact: true })
      } else {
        Image($r('app.media.ui_message')).width(38).height(38).padding(9)
          .fillColor(palette(this.dark).text).backgroundColor(palette(this.dark).paper)
          .borderRadius(19).border({ width: 0.6, color: palette(this.dark).line })
      }
      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(this.item.title).fontSize(15).fontWeight(FontWeight.Medium)
            .fontColor(palette(this.dark).text).maxLines(2).layoutWeight(1)
          Text(relativeTime(this.item.time)).fontSize(12).fontColor(palette(this.dark).muted)
        }.width('100%').alignItems(VerticalAlign.Top)
        Text(this.item.summary).fontSize(12).fontColor(palette(this.dark).muted)
          .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
        if (this.item.reminderBadge) Text(this.item.reminderBadge).fontSize(12)
          .fontColor(palette(this.dark).amber).backgroundColor(palette(this.dark).amberSoft)
      }.alignItems(HorizontalAlign.Start).layoutWeight(1)
    }.alignItems(VerticalAlign.Top).padding({ top: 14, bottom: 14 }).width('100%')
      .border({ width: { bottom: 0.5 }, color: palette(this.dark).line })
      .onClick(this.onOpen)
  }
}
