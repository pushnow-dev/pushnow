import { AccountPasswordService } from './AccountPasswordService';
import { HarmonyModel } from '../../viewmodels/HarmonyModel';
import { tr } from '../../support/Localization';
import { palette, JZTheme } from '../../theme/JZTheme';
@Component
export struct AuthParityPanel {
  @StorageProp('systemColorMode') private systemColorMode: number = 1;
  @StorageProp('appearance') private appearance: string = 'system';
  private get colors(): JZTheme { return palette(this.appearance === 'dark' || (this.appearance === 'system' && this.systemColorMode === 0)); }
  @ObjectLink model: HarmonyModel;
  onComplete: () => void = () => {};
  @State private setup: boolean = false;
  @State private confirmation: string = '';
  @State private localError: string = '';
  @State private working: boolean = false;
  private passwords: AccountPasswordService = new AccountPasswordService();
  @State private mode: string = 'password';
  @State private codeSent: boolean = false;
  @State private email: string = '';
  @State private password: string = '';
  @State private code: string = '';
  private async submit(): Promise<void> {
    this.localError = ''; this.working = true;
    try {
      if (this.setup) await this.passwords.save(this.password, this.confirmation);
      else if (this.mode === 'password') await this.model.passwordLogin(this.email, this.password);
      else if (!this.codeSent) {
        await this.model.sendCode(this.email);
        if (!this.model.error) this.codeSent = true;
        return;
      } else await this.model.login(this.email, this.code);
      if (this.model.session.verified) {
        if (!this.setup && this.mode === 'code' && await this.passwords.needsSetup()) {
          this.setup = true; this.password = ''; return;
        }
        await this.model.registerPush(); this.onComplete();
      }
    } catch (error) { this.localError = tr((error as Error).message); }
    finally { this.working = false; }
  }
  build() {
    Column({ space: 22 }) {
      Column({ space: 10 }) {
        Text('♧').fontSize(36).fontColor(this.colors.blue).width(64).height(64).backgroundColor(this.colors.chrome).borderRadius(16).textAlign(TextAlign.Center)
        Text(tr('Use email to identify your notification space')).fontSize(23).fontWeight(FontWeight.Bold).fontColor(this.colors.text)
        Text(tr('After verification, sender keys, device tokens, reminder rules, subscriptions, and attachments belong to the same user.')).fontSize(16).fontColor(this.colors.muted).lineHeight(23)
      }.alignItems(HorizontalAlign.Start).width('100%')
      Row({ space: 2 }) {
        ForEach(['password', 'code'], (mode: string) => {
          Text(tr(mode === 'password' ? 'Password' : 'Verification code')).fontSize(14).textAlign(TextAlign.Center).layoutWeight(1).height(30)
            .backgroundColor(this.mode === mode ? this.colors.card : Color.Transparent).borderRadius(7).fontColor(this.colors.text)
            .onClick(() => { this.mode = mode; })
        })
      }.enabled(!this.setup).padding(3).backgroundColor(this.colors.chrome).borderRadius(9)
      Column({ space: 12 }) {
        TextInput({ placeholder: tr('Email address'), text: this.email }).type(InputType.Email).height(52).borderRadius(12).onChange((value: string) => { this.email = value; this.codeSent = false; })
        if (this.mode === 'password' || this.setup) TextInput({ placeholder: tr('Password'), text: this.password }).type(InputType.Password).height(52).borderRadius(12).onChange((value: string) => { this.password = value; })
        if (this.mode === 'code' && this.codeSent && !this.setup) TextInput({ placeholder: tr('6-digit verification code'), text: this.code }).type(InputType.Number).maxLength(6).height(52).borderRadius(12).onChange((value: string) => { this.code = value; })
      }
      if (this.setup) TextInput({ placeholder: tr('Confirm password'), text: this.confirmation }).type(InputType.Password).height(52).borderRadius(12).onChange((value: string) => { this.confirmation = value; })
      Button(tr(this.model.busy || this.working ? 'Please wait' : this.setup ? 'Set password' : this.mode === 'password' ? 'Sign in' : this.codeSent ? 'Verify email' : 'Send code'))
        .width('100%').height(52).borderRadius(14).backgroundColor(this.colors.text).fontColor(this.colors.card).onClick(() => { void this.submit(); })
      if (this.localError) Text(this.localError).fontSize(13).fontColor(this.colors.red)
      if (this.model.error) Text(this.model.error).fontSize(13).fontColor(this.colors.red)
      else if (this.codeSent) Text(tr('If this email is available, you will receive a verification email. For privacy, we do not disclose whether an email is registered.')).fontSize(13).fontColor(this.colors.muted)
    }.alignItems(HorizontalAlign.Start).padding({ left: 6, right: 6, top: 10 }).enabled(!this.model.busy && !this.working)
  }
}
