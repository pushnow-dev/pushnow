import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { HarmonyModel } from '../viewmodels/HarmonyModel';
import { InboxItem } from '../models/JiZhiModels';
import { HomePanel } from '../components/home/HomePanel';
import { MessageDetailPanel } from '../components/home/MessageDetailPanel';
import { DiscoveryPanel } from '../components/discovery/DiscoveryPanel';
import { SettingsPanel } from '../components/settings/SettingsPanel';
import { SourcesPanel } from '../components/sources/SourcesPanel';
import { RemindersPanel } from '../components/reminders/RemindersPanel';
import { AppTabBar } from '../components/shared/AppChrome';
import { palette } from '../theme/JZTheme';
import { preferenceService } from '../services/preferences/PreferenceService';

@Entry
@Component
struct Index {
  @State private model: HarmonyModel = new HarmonyModel();
  @State private tab: number = 0;
  @State private route: string = '';
  @State private selected: InboxItem = new InboxItem();
  @StorageProp('pushRefresh') @Watch('pushChanged') pushRefresh: number = 0;
  @StorageProp('systemColorMode') systemColorMode: number = -1;
  @StorageProp('appearance') appearance: string = 'system';
  private dark(): boolean {
    return this.appearance === 'dark' || (this.appearance === 'system' && this.systemColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
  }
  private pushChanged(): void { if (this.model.session.verified) void this.model.refresh(); }
  aboutToAppear(): void { void this.initialize(); }
  private async initialize(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    await preferenceService.initialize(context);
    await this.model.initialize(context);
  }
  onPageShow(): void { if (this.model.session.verified) void this.model.refresh(); }
  onBackPress(): boolean { if (this.route) { this.route = ''; return true; } return false; }
  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      if (this.route === 'settings') {
        SettingsPanel({ model: this.model, onBack: () => { this.route = ''; } })
      } else if (this.route === 'detail') {
        MessageDetailPanel({ model: this.model, item: this.selected, dark: this.dark(), onBack: () => { this.route = ''; } })
      } else {
        Column() {
          if (this.model.error) Text(this.model.error).fontSize(12).fontColor(palette(this.dark()).red).padding(8)
          if (this.model.notice) Text(this.model.notice).fontSize(12).fontColor(palette(this.dark()).muted).padding(8)
          if (this.tab === 0) {
            HomePanel({ model: this.model, dark: this.dark(), onSettings: () => { this.route = 'settings'; },
              onSignIn: () => { this.route = 'settings'; }, onSources: () => { this.tab = 1; },
              onOpen: (item: InboxItem) => { this.selected = item; this.route = 'detail'; } })
          } else if (this.tab === 1) {
            SourcesPanel({ model: this.model, onDiscover: () => { this.tab = 2; }, onSignIn: () => { this.route = 'settings'; } })
          } else if (this.tab === 2) {
            DiscoveryPanel({ model: this.model, onSignIn: () => { this.route = 'settings'; } })
          } else {
            RemindersPanel({ model: this.model, onSignIn: () => { this.route = 'settings'; } })
          }
        }.width('100%').height('100%')
        AppTabBar({ selected: $tab, dark: this.dark() })
      }
    }.width('100%').height('100%').backgroundColor(palette(this.dark()).background)
  }
}
