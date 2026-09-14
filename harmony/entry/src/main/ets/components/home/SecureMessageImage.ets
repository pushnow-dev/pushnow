import { image } from '@kit.ImageKit';
import { InboxItem } from '../../models/JiZhiModels';
import { secureAttachmentService } from '../../services/SecureAttachmentService';
import { authService } from '../../services/AuthService';

@Component
export struct SecureMessageImage {
  @Prop item: InboxItem;
  attachmentID: string = '';
  compact: boolean = false;
  @State private bitmap: image.PixelMap | undefined = undefined;
  private revision: number = 0;
  aboutToAppear(): void { void this.load(); }
  aboutToDisappear(): void {
    this.revision++;
    if (this.bitmap) this.bitmap.release();
    this.bitmap = undefined;
  }
  private async load(): Promise<void> {
    const attachment = this.item.attachments.find(value => value.id === this.attachmentID);
    if (!attachment) return;
    const revision = ++this.revision;
    const generation = authService.generation;
    try {
      const bytes = await secureAttachmentService.bytes(attachment, this.item.userId, this.item.sourceId);
      const bitmap = await secureAttachmentService.image(bytes);
      if (revision !== this.revision || generation !== authService.generation) { bitmap.release(); return; }
      this.bitmap = bitmap;
    } catch { /* An unverified image never replaces the authenticated fallback. */ }
  }
  build() {
    if (this.bitmap) {
      Image(this.bitmap).width(this.compact ? 38 : '100%').height(this.compact ? 38 : 240)
        .objectFit(this.compact ? ImageFit.Cover : ImageFit.Contain).borderRadius(this.compact ? 19 : 8)
    } else if (this.compact) {
      Image($r('app.media.ui_message')).width(38).height(38).padding(9).backgroundColor('#F6F8FA').borderRadius(19)
    }
  }
}
