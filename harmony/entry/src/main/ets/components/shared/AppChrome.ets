import { tr } from '../../support/Localization';
import { palette } from '../../theme/JZTheme';

@Component
export struct RoundIcon {
  icon: Resource = $r('app.media.ui_plus');
  label: string = '';
  dark: boolean = false;
  action: () => void = () => {};
  build() {
    Button({ type: ButtonType.Circle }) {
      Image(this.icon).width(20).height(20).fillColor(palette(this.dark).text)
    }.width(38).height(38).backgroundColor(palette(this.dark).paper)
      .accessibilityText(this.label).onClick(this.action)
  }
}

@Component
export struct AppTabBar {
  @Link selected: number;
  dark: boolean = false;
  private titles: string[] = ['Home', 'Inbox', 'Discover', 'Reminders'];
  private icons: Resource[] = [$r('app.media.ui_home'), $r('app.media.ui_inbox'), $r('app.media.ui_compass'), $r('app.media.ui_bell')];
  build() {
    Row({ space: 4 }) {
      ForEach(this.titles, (title: string, index: number) => {
        Column({ space: 4 }) {
          Image(this.icons[index]).width(22).height(22)
            .fillColor(this.selected === index ? palette(this.dark).blue : palette(this.dark).muted)
          Text(tr(title)).fontSize(10).fontWeight(FontWeight.Medium)
            .fontColor(this.selected === index ? palette(this.dark).blue : palette(this.dark).muted)
        }.layoutWeight(1).padding({ top: 8, bottom: 8 }).borderRadius(12)
          .backgroundColor(this.selected === index ? palette(this.dark).paper : Color.Transparent)
          .onClick(() => { this.selected = index; }).accessibilityText(tr(title))
      })
    }.padding(6).height(66).borderRadius(18)
      .backgroundColor(this.dark ? '#EE161B22' : '#EEF6F8FA')
      .border({ width: 0.6, color: palette(this.dark).line })
      .margin({ left: 22, right: 22, bottom: 8 })
  }
}

@Component
export struct AuthRequiredPanel {
  dark: boolean = false;
  onSignIn: () => void = () => {};
  build() {
    Column({ space: 14 }) {
      Image($r('app.media.ui_person')).width(42).height(42).fillColor(palette(this.dark).muted)
      Text(tr('Sign in to continue')).fontSize(20).fontWeight(FontWeight.Medium)
      Text(tr('Sign in to receive your encrypted messages.')).fontSize(14)
        .fontColor(palette(this.dark).muted).textAlign(TextAlign.Center)
      Button(tr('Sign in')).backgroundColor(palette(this.dark).primary)
        .fontColor(palette(this.dark).inverse).onClick(this.onSignIn)
    }.width('100%').padding(32).margin({ top: 70 })
  }
}
