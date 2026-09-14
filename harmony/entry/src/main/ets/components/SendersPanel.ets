import { tr } from '../support/Localization';
import { HarmonyModel } from '../viewmodels/HarmonyModel';
import { AuthorizedSender } from '../services/SenderAuthorizationService';

@Component
export struct SendersPanel {
  @ObjectLink model: HarmonyModel;
  @State private code: string = '';

  build() {
    Column({ space: 14 }) {
      Text(tr('Senders')).fontSize(28).fontWeight(FontWeight.Bold)
      Text(tr('Enter the authorization code shown by your HTTP sender. Verify its name and public key before granting access.'))
      TextInput({ placeholder: tr('8-character authorization code'), text: this.code }).maxLength(12)
        .onChange((value: string) => { this.code = value; })
      Button(tr('Look up sender')).onClick(() => { void this.model.lookup(this.code); })
      if (this.model.authorization) {
        Text(this.model.authorization.name).fontSize(20).fontWeight(FontWeight.Bold)
        Text(tr('Account fingerprint: {0}', [this.model.accountFingerprint])).fontSize(12).copyOption(CopyOptions.LocalDevice)
        Text(tr('Sender fingerprint: {0}', [this.model.senderFingerprint])).fontSize(12).copyOption(CopyOptions.LocalDevice)
        Text(tr('Expires: {0}', [this.model.authorization.expires_at])).fontSize(12)
        Button(tr('Authorize this sender')).onClick(() => {
          AlertDialog.show({ title: tr('Authorize sender?'), message: tr('Confirm the sender name and both fingerprints match your HTTP sender.'),
            primaryButton: { value: tr('Cancel'), action: () => {} },
            secondaryButton: { value: tr('Fingerprints match'), action: () => { void this.model.authorize(); } } });
        })
      }
      if (this.model.senders.length === 0) Text(tr('No authorized senders'))
      ForEach(this.model.senders, (sender: AuthorizedSender) => {
        Column({ space: 8 }) {
          Text(sender.name).fontSize(18).fontWeight(FontWeight.Bold)
          Text(tr(sender.status)).fontSize(13)
          Button(tr('Revoke access')).enabled(sender.status === 'active').onClick(() => {
            AlertDialog.show({ title: tr('Revoke sender?'), message: tr('Stop future requests from {0}?', [sender.name]),
              primaryButton: { value: tr('Cancel'), action: () => {} },
              secondaryButton: { value: tr('Revoke'), action: () => { void this.model.revokeSender(sender.id); } } });
          })
        }.padding(16).width('100%').alignItems(HorizontalAlign.Start).border({ width: 1, color: '#88888844' }).borderRadius(16)
      }, (sender: AuthorizedSender) => sender.id)
    }.width('100%').alignItems(HorizontalAlign.Start).enabled(this.model.session.verified && !this.model.busy)
  }
}
