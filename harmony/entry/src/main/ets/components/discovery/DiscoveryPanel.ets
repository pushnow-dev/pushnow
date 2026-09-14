import { HarmonyModel } from '../../viewmodels/HarmonyModel';
import { DiscoveryModel } from '../../viewmodels/DiscoveryModel';
import { discoveryChannels, DiscoveryChannel } from '../../services/discovery/DiscoveryCatalog';
import { dc } from '../../services/discovery/DiscoveryCopy';
import { DiscoveryEditor } from './DiscoveryEditor';
import { JZTheme, palette } from '../../theme/JZTheme';

@Component
export struct DiscoveryPanel {
  @StorageProp('systemColorMode') private systemColorMode: number = 1;
  @StorageProp('appearance') private appearance: string = 'system';
  private get colors(): JZTheme { return palette(this.appearance === 'dark' || (this.appearance === 'system' && this.systemColorMode === 0)); }
  @ObjectLink model: HarmonyModel;
  onSignIn: () => void = () => {};
  @State private discovery: DiscoveryModel = new DiscoveryModel();
  @State private search: string = '';
  @State private filter: string = 'All';
  @State private selected: DiscoveryChannel = discoveryChannels[0];
  @State private editing: boolean = false;
  private filters: string[] = ['All', 'Saved channels', 'Trending', 'Daily picks', 'Prices', 'Technology', 'Development'];
  aboutToAppear(): void { void this.discovery.load(); }
  private visible(): DiscoveryChannel[] {
    const groups: Record<string, string[]> = {
      'Trending': ['weibo', 'zhihu', 'bilibili', 'youtube', 'reddit'],
      'Daily picks': ['rss', 'telegram', 'hackernews', 'ai'], 'Prices': ['gold'],
      'Technology': ['github', 'hackernews', 'stackoverflow', 'ai'],
      'Development': ['github', 'stackoverflow', 'hackernews', 'rss']
    };
    return discoveryChannels.filter((channel: DiscoveryChannel) => {
      const matches = this.filter === 'Saved channels' ? this.discovery.subscription(channel.id) !== undefined :
        (!groups[this.filter] || groups[this.filter].includes(channel.id));
      return matches && `${channel.title} ${dc(channel.title)} ${dc(channel.summary)}`.toLowerCase().includes(this.search.trim().toLowerCase());
    });
  }
  @Builder
  private editor() { DiscoveryEditor({ model: this.discovery, channel: this.selected, onClose: () => { this.editing = false; } }) }
  @Builder
  private card(channel: DiscoveryChannel) {
    Row({ space: 12 }) {
      if (channel.icon) {
        Image(channel.icon).width(44).height(44).padding(10).objectFit(ImageFit.Contain)
          .fillColor(channel.id === 'hackernews' ? undefined : Color.White).backgroundColor(channel.color).borderRadius(10)
      } else {
        Text(channel.id === 'ai' ? '✧' : '▥').fontSize(26).width(44).height(44).textAlign(TextAlign.Center)
          .backgroundColor(this.colors.paper).borderRadius(10).fontColor(this.colors.text)
      }
      Column({ space: 5 }) {
        Text(dc(channel.title)).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.colors.text).maxLines(2)
        Text(dc(channel.summary)).fontSize(12).fontColor(this.colors.muted).maxLines(2)
        Text(dc(channel.badge)).fontSize(10).fontColor(this.colors.muted)
        if (this.discovery.subscription(channel.id)) {
          Text(dc('Saved locally - pending activation')).fontSize(12).fontColor(this.colors.muted)
          if (this.discovery.subscription(channel.id)?.wantsNotification) {
            Text(`${this.discovery.subscription(channel.id)?.hour.toString().padStart(2, '0')}:${this.discovery.subscription(channel.id)?.minute.toString().padStart(2, '0')}`).fontSize(12).fontColor(this.colors.text)
            Text(this.discovery.subscription(channel.id)?.timeZoneID).fontSize(12).fontColor(this.colors.muted)
          } else { Text(dc('In-app only')).fontSize(12).fontColor(this.colors.text) }
        }
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(this.discovery.subscription(channel.id) ? '☷' : '⊕').fontSize(23).fontColor(this.colors.muted)
    }.padding(14).width('100%').backgroundColor(this.colors.card).borderRadius(8).border({ width: 1, color: this.colors.line })
      .enabled(this.discovery.loaded && this.discovery.current)
      .onClick(() => { this.selected = channel; this.editing = true; })
  }
  build() {
    Column() {
      Text(dc('Discover')).fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.colors.text).height(48).width('100%').textAlign(TextAlign.Center)
      if (!this.model.session.verified) {
        Column({ space: 14 }) {
          Text(dc('Sign in to save subscriptions')).fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.colors.text)
          Text(dc('A verified email account is required.')).fontColor(this.colors.muted)
          Button(dc('Sign in')).backgroundColor(this.colors.primary).fontColor(this.colors.inverse).onClick(this.onSignIn)
        }.layoutWeight(1).justifyContent(FlexAlign.Center).width('100%')
      } else {
        Scroll() {
          Column({ space: 14 }) {
            Row({ space: 8 }) {
              Text('⌕').fontSize(23).fontColor(this.colors.muted)
              TextInput({ text: this.search, placeholder: dc('Search channels') }).fontSize(15).layoutWeight(1)
                .backgroundColor(Color.Transparent).fontColor(this.colors.text).placeholderColor(this.colors.muted).padding(0).height(42).onChange((value: string) => { this.search = value; })
            }.padding({ left: 12, right: 12 }).height(42).width('100%').backgroundColor(this.colors.paper).borderRadius(10)
            Scroll() {
              Row({ space: 8 }) {
                ForEach(this.filters, (filter: string) => {
                  Text(dc(filter)).fontSize(13).fontWeight(this.filter === filter ? FontWeight.Medium : FontWeight.Normal)
                    .fontColor(this.filter === filter ? this.colors.inverse : this.colors.muted).padding({ left: 12, right: 12 }).height(32)
                    .backgroundColor(this.filter === filter ? this.colors.primary : this.colors.paper).borderRadius(16)
                    .onClick(() => { this.filter = filter; })
                }, (filter: string) => filter)
              }
            }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
            if (this.discovery.error) {
              Text(this.discovery.error).fontColor(this.colors.red)
              Text(dc('Retry')).fontColor(this.colors.blue).onClick(() => { void this.discovery.load(); })
            }
            Column({ space: 10 }) {
              ForEach(this.visible(), (channel: DiscoveryChannel) => { this.card(channel) }, (channel: DiscoveryChannel) => channel.id)
              if (this.visible().length === 0) {
                Text(this.filter === 'Saved channels' && !this.search ? dc('No saved channels') : `${dc('Search channels')}: ${this.search}`)
                  .fontColor(this.colors.muted).padding(32)
              }
            }.width('100%')
          }.padding({ left: 18, right: 18, bottom: 30 }).width('100%')
        }.layoutWeight(1).scrollBar(BarState.Off).width('100%')
      }
    }.height('100%').width('100%').backgroundColor(this.colors.background)
      .bindSheet($$this.editing, this.editor, { height: SheetSize.LARGE, showClose: false })
  }
}
