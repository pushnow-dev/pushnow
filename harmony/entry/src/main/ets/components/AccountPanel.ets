import { tr } from '../support/Localization';
import { HarmonyModel } from '../viewmodels/HarmonyModel';

@Component
export struct AccountPanel {
  @ObjectLink model: HarmonyModel;
  @State private email: string = '';
  @State private code: string = '';
  @State private password: string = '';

  build() {
    Column({ space: 16 }) {
      Text(tr('Account')).fontSize(28).fontWeight(FontWeight.Bold)
      if (!this.model.session.verified) {
        TextInput({ placeholder: tr('Email'), text: this.email }).type(InputType.Email).onChange((value: string) => { this.email = value; })
        TextInput({ placeholder: tr('Verification code'), text: this.code }).onChange((value: string) => { this.code = value; })
        Row({ space: 12 }) {
          Button(tr('Send code')).onClick(() => { void this.model.sendCode(this.email); })
          Button(tr('Sign in')).onClick(() => { void this.model.login(this.email, this.code); })
        }
        TextInput({ placeholder: tr('Password'), text: this.password }).type(InputType.Password)
          .onChange((value: string) => { this.password = value; })
        Button(tr('Sign in with password')).onClick(() => { void this.model.passwordLogin(this.email, this.password); })
      } else {
        Text(this.model.session.email).fontSize(18)
        Text(tr('Harmony Push: {0}', [this.model.pushState]))
        Button(tr('Register push notifications')).onClick(() => { void this.model.registerPush(); })
        Button(tr('Sign out')).onClick(() => { void this.model.logout(); })
      }
    }.width('100%').alignItems(HorizontalAlign.Start).enabled(!this.model.busy)
  }
}
