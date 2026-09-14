import { tr, localizedError } from '../support/Localization';
import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { InboxItem } from '../models/JiZhiModels';
import { SecureAttachment, secureAttachmentService } from '../services/SecureAttachmentService';
import { authService } from '../services/AuthService';

@Component
export struct AttachmentPanel {
  @Prop item: InboxItem;
  @State private preview: image.PixelMap | undefined = undefined;
  @State private text: string = '';
  @State private error: string = '';
  @State private busy: boolean = false;
  private revision: number = 0;

  aboutToDisappear(): void {
    this.revision++;
    if (this.preview) this.preview.release();
    this.preview = undefined;
    this.text = '';
  }

  private async open(attachment: SecureAttachment, save: boolean): Promise<void> {
    if (this.busy) return;
    const epoch = authService.generation;
    const revision = ++this.revision;
    this.busy = true; this.error = ''; this.text = '';
    if (this.preview) this.preview.release();
    this.preview = undefined;
    try {
      const bytes = await secureAttachmentService.bytes(attachment, this.item.userId, this.item.sourceId);
      if (epoch !== authService.generation || revision !== this.revision || authService.current.userID !== this.item.userId) return;
      if (save) {
        await secureAttachmentService.save(bytes, attachment.name, getContext(this) as common.UIAbilityContext);
      } else if (attachment.mime.startsWith('image/')) {
        const preview = await secureAttachmentService.image(bytes);
        if (epoch !== authService.generation || revision !== this.revision) { preview.release(); return; }
        this.preview = preview;
      } else {
        this.text = secureAttachmentService.text(bytes);
      }
    } catch (error) {
      if (revision === this.revision) this.error = localizedError(error as Error);
    } finally { if (revision === this.revision) this.busy = false; }
  }

  build() {
    Column({ space: 10 }) {
      ForEach(this.item.attachments, (attachment: SecureAttachment) => {
        Column({ space: 8 }) {
          Text(tr('{0} · {1} bytes', [attachment.name, attachment.size.toString()])).fontSize(13)
          Row({ space: 8 }) {
            if (attachment.mime.startsWith('image/') || attachment.mime.startsWith('text/') || attachment.mime === 'application/json') {
              Button(tr('Preview')).onClick(() => { void this.open(attachment, false); })
            }
            Button(tr('Save file')).onClick(() => { void this.open(attachment, true); })
          }.enabled(!this.busy)
        }.alignItems(HorizontalAlign.Start)
      }, (attachment: SecureAttachment) => attachment.id)
      if (this.busy) LoadingProgress().width(24).height(24)
      if (this.error) Text(this.error).fontColor('#DC5353')
      if (this.preview) Image(this.preview).width('100%').height(260).objectFit(ImageFit.Contain)
      if (this.text) Text(this.text).fontSize(14).copyOption(CopyOptions.LocalDevice)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }
}
