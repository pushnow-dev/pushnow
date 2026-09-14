import { HarmonyModel } from '../../viewmodels/HarmonyModel';
import { secureDeviceEnrollmentService } from '../../services/SecureDeviceEnrollmentService';
import { senderAuthorizationService, AuthorizedSender } from '../../services/SenderAuthorizationService';
import { authService } from '../../services/AuthService';
import { secureCrypto } from '../../services/SecureCrypto';
import { tr, localizedError } from '../../support/Localization';
import { palette, JZTheme } from '../../theme/JZTheme';
import { SourcePendingDevicePanel } from './SourcePendingDevicePanel';
import { SenderKeysPanel } from '../settings/SenderKeysPanel';
import { NotificationLogsPanel } from '../settings/NotificationLogsPanel';

@Component
export struct SourceEntryPanel {
  @ObjectLink model: HarmonyModel;
  onClose: () => void = () => {};
  @StorageProp('systemColorMode') private systemColorMode: number = 1;
  @StorageProp('appearance') private appearance: string = 'system';
  @State private page: string = '';
  @State private code: string = '';
  @State private confirmed: boolean = false;
  @State private expiry: number = 0;
  @State private busy: boolean = false;
  @State private error: string = '';
  @State private fingerprint: string = '';
  @State private trusted: boolean = false;
  private get colors(): JZTheme { return palette(this.appearance === 'dark' || (this.appearance === 'system' && this.systemColorMode === 0)); }
  aboutToAppear(): void {
    this.trusted = secureDeviceEnrollmentService.identityEstablished();
    if (this.trusted) void this.loadFingerprint();
  }
  private async loadFingerprint(): Promise<void> {
    const epoch = authService.generation;
    try {
      const value = await secureCrypto.fingerprint(secureDeviceEnrollmentService.identityPublicKey());
      if (epoch === authService.generation) this.fingerprint = value;
    } catch (error) { this.error = localizedError(error as Error); }
  }
  private async authorize(): Promise<void> {
    if (!this.confirmed || !this.model.authorization || this.busy) return;
    this.busy = true; this.error = '';
    try {
      const days = [0, 7, 30, 90][this.expiry];
      await senderAuthorizationService.approve(this.model.authorization, this.confirmed,
        days === 0 ? null : new Date(Date.now() + days * 86400000).toISOString());
      this.model.authorization = undefined; this.confirmed = false; this.code = '';
      await this.model.refresh();
    } catch (error) { this.error = localizedError(error as Error); }
    finally { this.busy = false; }
  }
  @Builder private navigationRow(title: string, page: string) {
    Row() {
      Text(tr(title)).fontSize(17).fontColor(this.colors.text).layoutWeight(1)
      Text('›').fontSize(22).fontColor(this.colors.muted)
    }.padding(16).width('100%').onClick(() => { this.page = page; })
  }
  build() {
    Column({ space: 0 }) {
      Row() {
        if (this.page) Button('‹').width(38).height(38).fontSize(26).fontColor(this.colors.blue).backgroundColor(Color.Transparent).onClick(() => { this.page = ''; })
        else Blank().width(38)
        Text(tr(this.page === 'keys' ? 'Sender keys' : this.page === 'logs' ? 'Notification logs' : this.trusted ? 'Senders' : 'Devices & Encryption')).fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.colors.text).layoutWeight(1).textAlign(TextAlign.Center)
        Button('×').fontSize(24).width(38).height(38).backgroundColor(this.colors.paper)
          .fontColor(this.colors.muted).onClick(this.onClose)
      }.padding({ left: 18, right: 18, top: 8, bottom: 10 }).width('100%')
      if (this.page === 'keys') {
        SenderKeysPanel({ model: this.model })
      } else if (this.page === 'logs') {
        NotificationLogsPanel({ model: this.model })
      } else if (!this.trusted) {
        SourcePendingDevicePanel({ model: this.model, onApproved: () => { this.trusted = true; void this.loadFingerprint(); } })
      } else {
        Scroll() {
          Column({ space: 12 }) {
            Column({ space: 0 }) {
              this.navigationRow('Sender keys', 'keys')
              Divider().color(this.colors.line).margin({ left: 16 })
              this.navigationRow('Notification logs', 'logs')
            }.width('100%').backgroundColor(this.colors.card).borderRadius(10).margin({ top: 18 })
            if (this.model.error || this.error) Text(this.error || this.model.error).fontSize(13).fontColor(this.colors.red)
            if (this.model.notice) Text(this.model.notice).fontSize(13).fontColor(this.colors.green)
            Text(tr('Authorize sender')).fontSize(13).fontColor(this.colors.muted).padding({ left: 16, top: 20 }).width('100%')
            Column({ space: 0 }) {
              Row({ space: 10 }) {
                Text(tr('Account fingerprint')).fontSize(16).fontColor(this.colors.text).layoutWeight(1)
                Text(this.fingerprint).fontSize(12).fontFamily('monospace').fontColor(this.colors.text).copyOption(CopyOptions.LocalDevice).constraintSize({ maxWidth: '52%' })
              }.padding(16).width('100%')
              Divider().color(this.colors.line).margin({ left: 16 })
              TextInput({ text: this.code, placeholder: tr('Authorization code') }).fontSize(17).backgroundColor(Color.Transparent)
                .onChange((value: string) => { this.code = value; this.confirmed = false; }).height(46)
              Divider().color(this.colors.line).margin({ left: 16 })
              Text(tr('Look up code')).fontSize(17).fontColor(this.colors.blue).padding(16).width('100%')
                .enabled(!this.model.busy && this.code.length > 0).onClick(() => { this.confirmed = false; void this.model.lookup(this.code); })
              if (this.model.authorization) {
                Divider().color(this.colors.line).margin({ left: 16 })
                Row() {
                  Text(tr('Name')).fontSize(17).fontColor(this.colors.text).layoutWeight(1)
                  Text(this.model.authorization.name).fontSize(17).fontColor(this.colors.muted)
                }.padding(16).width('100%')
                Text(this.model.senderFingerprint).fontSize(13).fontFamily('monospace').fontColor(this.colors.text).copyOption(CopyOptions.LocalDevice).padding(16).width('100%')
                Row({ space: 12 }) {
                  Text(tr('Fingerprint matches my sender')).fontSize(17).fontColor(this.colors.text).layoutWeight(1)
                  Toggle({ type: ToggleType.Switch, isOn: this.confirmed }).onChange((value: boolean) => { this.confirmed = value; })
                }.padding(16).width('100%')
                Divider().color(this.colors.line).margin({ left: 16 })
                Row() {
                  Text(tr('Key expiry')).fontSize(17).fontColor(this.colors.text).layoutWeight(1)
                  Select([{ value: tr('Never') }, { value: tr('7 days') }, { value: tr('30 days') }, { value: tr('90 days') }])
                    .selected(this.expiry).onSelect((index: number) => { this.expiry = index; })
                }.padding(16).width('100%')
                Divider().color(this.colors.line).margin({ left: 16 })
                Text(tr('Authorize sender')).fontSize(17).fontColor(this.colors.blue).padding(16).width('100%')
                  .opacity(this.confirmed ? 1 : 0.4).enabled(this.confirmed && !this.busy).onClick(() => { void this.authorize(); })
              }
            }.backgroundColor(this.colors.card).borderRadius(10).width('100%')
            Text(tr('Authorized senders')).fontSize(13).fontColor(this.colors.muted).padding({ left: 16, top: 20 }).width('100%')
            Column({ space: 0 }) {
              ForEach(this.model.senders.filter((sender: AuthorizedSender) => sender.status !== 'revoked'), (sender: AuthorizedSender) => {
                Row() {
                  Text(sender.name).fontSize(17).fontColor(this.colors.text).layoutWeight(1)
                  Button('⌫').fontSize(20).fontColor(this.colors.red).backgroundColor(Color.Transparent).onClick(() => {
                    AlertDialog.show({ title: tr('Revoke sender'), message: sender.name,
                      primaryButton: { value: tr('Cancel'), action: () => {} },
                      secondaryButton: { value: tr('Revoke'), action: () => { void this.model.revokeSender(sender.id); } } });
                  })
                }.padding(16).width('100%')
              }, (sender: AuthorizedSender) => sender.id)
            }.backgroundColor(this.colors.card).borderRadius(10).width('100%')
            if (this.busy || this.model.busy) LoadingProgress().width(24).height(24)
          }.padding({ left: 18, right: 18, bottom: 30 }).width('100%').alignItems(HorizontalAlign.Start)
        }.layoutWeight(1).width('100%')
      }
    }.height('100%').width('100%').backgroundColor(this.colors.paper)
  }
}
