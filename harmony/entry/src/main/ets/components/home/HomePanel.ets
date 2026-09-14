import { HarmonyModel } from '../../viewmodels/HarmonyModel';
import { InboxItem } from '../../models/JiZhiModels';
import { tr } from '../../support/Localization';
import { palette } from '../../theme/JZTheme';
import { RoundIcon, AuthRequiredPanel } from '../shared/AppChrome';
import { MessageRow } from './MessageRow';

@Component
export struct HomePanel {
  @ObjectLink model: HarmonyModel;
  dark: boolean = false;
  onSettings: () => void = () => {};
  onSources: () => void = () => {};
  onSignIn: () => void = () => {};
  onOpen: (item: InboxItem) => void = () => {};
  @State private filter: number = 0;
  @State private refreshing: boolean = false;
  private filters: string[] = ['All', 'Unread', 'New results', 'Upcoming', 'P0/P1', 'Sources'];
  private items(): InboxItem[] {
    return this.model.items.filter((item: InboxItem) => {
      if (this.filter === 1) return item.unread;
      if (this.filter === 3) return !!item.reminderBadge;
      if (this.filter === 4) return ['urgent', 'custom', 'P0', 'P1'].includes(item.priority);
      return true;
    });
  }
  build() {
    Column() {
      Row() {
        RoundIcon({ icon: $r('app.media.ui_person'), label: tr('Settings'), dark: this.dark, action: this.onSettings })
        Blank()
        Text('Pushnow').fontSize(17).fontWeight(FontWeight.Medium).fontColor(palette(this.dark).text)
        Blank()
        Row({ space: 10 }) {
          RoundIcon({ icon: $r('app.media.ui_search'), label: tr('Search'), dark: this.dark })
          RoundIcon({ icon: $r('app.media.ui_plus'), label: tr('Add'), dark: this.dark,
            action: () => { if (this.model.session.verified) this.onSources(); else this.onSignIn(); } })
        }
      }.padding({ left: 18, right: 18, top: 8, bottom: 10 }).width('100%')
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.filters, (title: string, index: number) => {
            Text(tr(title)).fontSize(12).fontWeight(FontWeight.Medium).height(32)
              .padding({ left: 12, right: 12 }).borderRadius(16)
              .fontColor(this.filter === index ? palette(this.dark).inverse : palette(this.dark).muted)
              .backgroundColor(this.filter === index ? palette(this.dark).primary : palette(this.dark).paper)
              .onClick(() => { this.filter = index; })
          })
        }.padding({ left: 18, right: 18, bottom: 8 })
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
      if (!this.model.session.verified) {
        AuthRequiredPanel({ dark: this.dark, onSignIn: this.onSignIn })
      } else {
        Refresh({ refreshing: $$this.refreshing }) {
          List({ space: 0 }) {
            ForEach(this.items(), (item: InboxItem) => {
              ListItem() { MessageRow({ item: item, dark: this.dark, onOpen: () => this.onOpen(item) }) }
            }, (item: InboxItem) => item.id)
          }.width('100%').height('100%').padding({ left: 18, right: 18, bottom: 100 })
        }.layoutWeight(1).onRefreshing(() => {
          this.model.refresh().finally(() => { this.refreshing = false; });
        })
      }
    }.width('100%').height('100%').backgroundColor(palette(this.dark).background)
  }
}
