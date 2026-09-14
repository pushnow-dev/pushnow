import { HarmonyModel } from '../../viewmodels/HarmonyModel';
import { SourceRecord, sourceCatalogService } from '../../services/sources/SourceCatalogService';
import { authService } from '../../services/AuthService';
import { tr, localizedError } from '../../support/Localization';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { SourceEntryPanel } from './SourceEntryPanel';

@Component
export struct SourcesPanel {
  @ObjectLink model: HarmonyModel;
  onDiscover: () => void = () => {};
  onSignIn: () => void = () => {};
  @State private sources: SourceRecord[] = [];
  @State private loading: boolean = false;
  @State private error: string = '';
  @State private entry: boolean = false;
  @StorageProp('systemColorMode') systemColorMode: number = -1;
  @StorageProp('appearance') private appearance: string = 'system';
  private epoch: number = -1;

  private dark(): boolean { return this.appearance === 'dark' || (this.appearance === 'system' && this.systemColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK); }
  private foreground(): string { return this.dark() ? '#F0F6FC' : '#1F2328'; }
  private muted(): string { return this.dark() ? '#8B949E' : '#59636E'; }
  private grouped(): string { return this.dark() ? '#161B22' : '#F6F8FA'; }
  aboutToAppear(): void { void this.load(); }
  aboutToDisappear(): void { this.epoch = -1; this.sources = []; }

  private async load(): Promise<void> {
    const epoch = authService.generation;
    this.epoch = epoch;
    this.sources = []; this.error = '';
    if (!authService.current.verified) return;
    this.loading = true;
    try {
      const sources = await sourceCatalogService.load();
      if (this.epoch === epoch && authService.generation === epoch) this.sources = sources;
    } catch (error) {
      if (this.epoch === epoch) this.error = localizedError(error as Error);
    } finally { if (this.epoch === epoch) this.loading = false; }
  }

  build() {
    Column({ space: 0 }) {
      Row() {
        Blank().width(38)
        Text(tr('Subscriptions')).fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.foreground()).layoutWeight(1).textAlign(TextAlign.Center)
        Button('+').width(38).height(38).fontSize(25).fontColor(this.foreground()).backgroundColor(this.grouped())
          .onClick(() => { if (this.model.session.verified) this.entry = true; else this.onSignIn(); })
      }.padding({ left: 18, right: 18, top: 8, bottom: 10 }).width('100%')
      Scroll() {
        Column({ space: 18 }) {
          Row({ space: 0 }) {
            Text(tr('My sources')).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.dark() ? '#0D1117' : '#FFFFFF')
              .height(38).layoutWeight(1).textAlign(TextAlign.Center).backgroundColor(this.dark() ? '#F0F6FC' : '#25292E').borderRadius(22)
            Text(tr('Discover sources')).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.muted())
              .height(38).layoutWeight(1).textAlign(TextAlign.Center).onClick(this.onDiscover)
          }.padding(4).borderRadius(24).backgroundColor(this.grouped()).width('100%')
          if (!this.model.session.verified) {
            Column({ space: 12 }) {
              Text(tr('Sign in to receive your encrypted messages.')).fontColor(this.muted()).fontSize(15)
              Button(tr('Sign in')).onClick(this.onSignIn)
            }.padding({ top: 60 }).width('100%')
          } else {
            Text(tr('Personal access')).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.foreground()).width('100%')
            if (this.loading) LoadingProgress().width(24).height(24)
            if (this.error) {
              Text(this.error).fontSize(13).fontColor('#D1242F')
              Button(tr('Retry')).onClick(() => { void this.load(); })
            }
            ForEach(this.sources, (source: SourceRecord) => {
              Row({ space: 10 }) {
                Text(source.sourceType === 'cli' ? '>_' : '↗').fontSize(20).fontColor(this.foreground())
                Column({ space: 4 }) {
                  Text(source.name).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.foreground())
                  Text(source.status === 'active' ? tr('Enabled') : tr('Paused')).fontSize(12).fontColor('#1A7F37')
                }.alignItems(HorizontalAlign.Start).layoutWeight(1)
                Text('›').fontSize(20).fontColor(this.muted())
              }.padding(14).width('100%').border({ width: 1, color: this.dark() ? '#30363D' : '#D1D9E0' }).borderRadius(8)
            }, (source: SourceRecord) => source.id)
            Text(tr('Subscribed')).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.foreground()).width('100%')
          }
        }.padding({ left: 18, right: 18, bottom: 110 }).width('100%').alignItems(HorizontalAlign.Start)
      }.layoutWeight(1).width('100%')
    }.width('100%').height('100%')
      .bindSheet($$this.entry, this.sourceEntry, { height: SheetSize.LARGE, showClose: false })
  }

  @Builder private sourceEntry() {
    SourceEntryPanel({ model: this.model, onClose: () => { this.entry = false; void this.load(); } })
  }
}
