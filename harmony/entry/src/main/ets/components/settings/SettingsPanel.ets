import { common, bundleManager } from '@kit.AbilityKit';
import { i18n } from '@kit.LocalizationKit';
import { HarmonyModel } from '../../viewmodels/HarmonyModel';
import { tr } from '../../support/Localization';
import { palette, JZTheme } from '../../theme/JZTheme';
import { preferenceService } from '../../services/preferences/PreferenceService';
import { SettingsRow } from './SettingsRow';
import { AuthParityPanel } from './AuthParityPanel';
import { DevicesPanel } from '../DevicesPanel';
import { SenderKeysPanel } from './SenderKeysPanel';
import { NotificationLogsPanel } from './NotificationLogsPanel';

@Component
export struct SettingsPanel {
  @StorageProp('systemColorMode') private systemColorMode: number = 1;
  @StorageProp('appearance') private appearance: string = 'system';
  private get colors(): JZTheme { return palette(this.appearance === 'dark' || (this.appearance === 'system' && this.systemColorMode === 0)); }
  @ObjectLink model: HarmonyModel;
  onBack: () => void = () => {};
  @State private route: string = '';
  @State private search: string = '';
  @State private revision: number = 0;
  @State private failure: string = '';
  private appVersion(): string {
    try {
      const info = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      return `${info.versionName} (${info.versionCode})`;
    } catch { return '—'; }
  }
  private languageCodes: string[] = ['system', 'en', 'zh-Hans', 'ja', 'ko', 'es', 'de'];
  private languageNames: string[] = ['Follow system', 'English', '简体中文', '日本語', '한국어', 'Español', 'Deutsch'];
  private languageTitle(): string {
    return tr(this.languageNames[Math.max(0, this.languageCodes.indexOf(preferenceService.language))]);
  }
  private async select(kind: string, value: string): Promise<void> {
    try { await preferenceService.select(kind, value); this.revision++; }
    catch (error) { this.failure = (error as Error).message; }
  }
  private openLegal(path: string): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    context.openLink(`https://pushnow.dev/${path}`).catch((error: Error) => { this.failure = error.message; });
  }
  @Builder private heading(title: string) {
    Text(tr(title)).fontSize(13).fontColor(this.colors.muted).padding({ left: 16, top: 22, bottom: 7 }).width('100%')
  }
  @Builder private line() { Divider().color(this.colors.line).margin({ left: 16 }).width('94%') }
  @Builder private root() {
    Column() {
      SettingsRow({ title: tr('Account'), icon: '◎', action: () => { this.route = 'Account'; } })
      this.line()
      SettingsRow({ title: tr('Membership'), icon: '♔', action: () => { this.route = 'Membership'; } })
    }.borderRadius(10).clip(true)
    this.heading('Preferences')
    Column() {
      SettingsRow({ title: tr('Time zone'), icon: '◷', value: preferenceService.timezoneIdentifier === 'system' ? tr('Follow system') : preferenceService.timezoneIdentifier, action: () => { this.route = 'Time zone'; } })
      this.line()
      SettingsRow({ title: tr('Language'), icon: '◎', value: this.languageTitle(), action: () => { this.route = 'Language'; } })
      this.line()
      SettingsRow({ title: tr('Appearance'), icon: '◐', value: tr(preferenceService.appearance === 'system' ? 'Follow system' : preferenceService.appearance === 'dark' ? 'Dark' : 'Light'), action: () => { this.route = 'Appearance'; } })
    }.borderRadius(10).clip(true)
    this.heading('App')
    SettingsRow({ title: tr('About'), icon: 'ⓘ', action: () => { this.route = 'About'; } })
    this.heading('Legal')
    Column() {
      SettingsRow({ title: tr('Privacy Policy'), disclosure: false, action: () => { this.openLegal('privacy'); } })
      this.line()
      SettingsRow({ title: tr('Terms of Use'), disclosure: false, action: () => { this.openLegal('terms'); } })
    }.borderRadius(10).clip(true)
  }
  @Builder private account() {
    this.heading('Account')
    Column() {
      SettingsRow({ title: this.model.session.verified ? this.model.session.email : tr('Not signed in'), icon: '◎', disclosure: false })
      if (this.model.session.verified) {
        this.line()
        SettingsRow({ title: tr('Email'), value: this.model.session.email, disclosure: false })
        this.line()
        SettingsRow({ title: tr('User ID'), value: this.model.session.userID, disclosure: false })
        this.line()
        SettingsRow({ title: tr('Sign-in status'), value: tr('Verified'), disclosure: false })
      } else {
        this.line()
        SettingsRow({ title: tr('Email sign in'), disclosure: false, action: () => { this.route = 'Email sign in'; } })
      }
    }.borderRadius(10).clip(true)
    if (this.model.session.verified) {
      this.heading('Notifications')
      Column() {
        SettingsRow({ title: tr('Devices & Encryption'), action: () => { this.route = 'Devices & Encryption'; } })
        this.line()
        SettingsRow({ title: tr('Sender keys'), action: () => { this.route = 'Sender keys'; } })
        this.line()
        SettingsRow({ title: tr('Notification logs'), action: () => { this.route = 'Notification logs'; } })
        this.line()
        SettingsRow({ title: tr('App push'), value: this.model.pushState, disclosure: false })
        this.line()
        SettingsRow({ title: tr('Enable App push'), disclosure: false, action: () => { void this.model.registerPush(); } })
      }.borderRadius(10).clip(true)
      Button(tr('Sign out')).fontColor(this.colors.text).backgroundColor(this.colors.chrome).borderRadius(8).width('100%').height(48).margin({ top: 32 }).enabled(!this.model.busy).onClick(() => { void this.model.logout(); })
    }
  }
  @Builder private choices() {
    if (this.route === 'Language') {
      ForEach(this.languageCodes, (code: string, index: number) => {
        SettingsRow({ title: tr(this.languageNames[index]), disclosure: false, selected: preferenceService.language === code, action: () => { void this.select('language', code); } })
        this.line()
      })
    } else if (this.route === 'Appearance') {
      ForEach(['system', 'light', 'dark'], (appearance: string) => {
        SettingsRow({ title: tr(appearance === 'system' ? 'Follow system' : appearance === 'light' ? 'Light' : 'Dark'), icon: appearance === 'dark' ? '☾' : appearance === 'light' ? '☼' : '◐', disclosure: false, selected: preferenceService.appearance === appearance, action: () => { void this.select('appearance', appearance); } })
        this.line()
      })
    } else {
      TextInput({ placeholder: tr('Search time zones'), text: this.search }).onChange((value: string) => { this.search = value; }).margin({ bottom: 20 })
      SettingsRow({ title: tr('Follow system'), disclosure: false, selected: preferenceService.timezoneIdentifier === 'system', action: () => { void this.select('timezone', 'system'); } })
      ForEach(i18n.TimeZone.getAvailableIDs().sort().filter((zone: string) => zone.replace(/_/g, ' ').toLowerCase().includes(this.search.toLowerCase())), (zone: string) => {
        SettingsRow({ title: zone.replace(/_/g, ' '), disclosure: false, selected: preferenceService.timezoneIdentifier === zone, action: () => { void this.select('timezone', zone); } })
        this.line()
      })
    }
  }
  build() {
    Column() {
      Row() {
        Text('‹ ' + tr('Back')).fontSize(17).fontColor(this.colors.blue).width(76).height(44).onClick(() => {
          if (!this.route) this.onBack();
          else if (['Email sign in', 'Devices & Encryption', 'Sender keys', 'Notification logs'].includes(this.route)) this.route = 'Account';
          else this.route = '';
        })
        Text(tr(this.route || 'Settings')).fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.colors.text).layoutWeight(1).textAlign(TextAlign.Center)
        Blank().width(76)
      }.height(48).padding({ left: 8, right: 8 })
      Scroll() {
        Column() {
          if (!this.route) {
            this.root()
          } else if (this.route === 'Account') this.account()
          else if (this.route === 'Email sign in') AuthParityPanel({ model: this.model, onComplete: () => { this.route = 'Account'; } })
          else if (this.route === 'Devices & Encryption') DevicesPanel({ model: this.model })
          else if (this.route === 'Sender keys') SenderKeysPanel({ model: this.model })
          else if (this.route === 'About') {
            SettingsRow({ title: tr('Name'), value: 'Pushnow', disclosure: false })
            this.line()
            SettingsRow({ title: tr('Version'), value: this.appVersion(), disclosure: false })
          } else if (this.route === 'Membership') {
            Text(tr('Pushnow Membership')).fontSize(28).fontWeight(FontWeight.Bold).fontColor(this.colors.text).width('100%')
            Text(tr('Membership purchasing is not available on HarmonyOS yet.')).fontSize(16).fontColor(this.colors.muted).margin({ top: 16 })
          } else if (this.route === 'Notification logs') {
            NotificationLogsPanel({ model: this.model })
          } else this.choices()
          if (this.failure) Text(this.failure).fontSize(13).fontColor(this.colors.red).margin({ top: 20 })
          if (this.model.error && this.route !== 'Email sign in') Text(this.model.error).fontSize(13).fontColor(this.colors.red).margin({ top: 20 })
          Blank().height(this.revision >= 0 ? 32 : 32)
        }.width('100%').alignItems(HorizontalAlign.Start).padding({ left: 16, right: 16, top: 16 })
      }.layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(this.colors.background)
  }
}
