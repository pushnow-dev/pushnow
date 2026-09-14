import { ConfigurationConstant } from '@kit.AbilityKit';
import { HarmonyModel } from '../../viewmodels/HarmonyModel';
import { authService } from '../../services/AuthService';
import { ReminderData, ReminderRecord, reminderCatalogService } from '../../services/reminders/ReminderCatalogService';
import { tr, localizedError } from '../../support/Localization';

@Component
export struct RemindersPanel {
  @ObjectLink model: HarmonyModel;
  onSignIn: () => void = () => {};
  @State private data: ReminderData = new ReminderData();
  @State private selected: string = 'Upcoming';
  @State private busy: boolean = false;
  @State private error: string = '';
  @StorageProp('systemColorMode') systemColorMode: number = -1;
  @StorageProp('appearance') private appearance: string = 'system';
  private epoch: number = -1;
  private dark(): boolean { return this.appearance === 'dark' || (this.appearance === 'system' && this.systemColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK); }
  private foreground(): string { return this.dark() ? '#F0F6FC' : '#1F2328'; }
  private muted(): string { return this.dark() ? '#8B949E' : '#59636E'; }
  private grouped(): string { return this.dark() ? '#161B22' : '#F6F8FA'; }
  aboutToAppear(): void { void this.load(); }
  aboutToDisappear(): void { this.epoch = -1; this.data = new ReminderData(); }
  private async load(): Promise<void> {
    const epoch = authService.generation; this.epoch = epoch;
    this.data = new ReminderData(); this.error = '';
    if (!authService.current.verified) return;
    this.busy = true;
    try {
      const data = await reminderCatalogService.load();
      if (this.epoch === epoch && authService.generation === epoch) this.data = data;
    } catch (error) { if (this.epoch === epoch) this.error = localizedError(error as Error); }
    finally { if (this.epoch === epoch) this.busy = false; }
  }
  private cancelled(value: ReminderRecord): boolean { return value.status === 'cancelled' || value.mode === 'in_app_only'; }
  private day(value: ReminderRecord): string {
    const date = new Date(value.nextFireAt ?? value.scheduledAt ?? '');
    if (Number.isNaN(date.getTime())) return tr('Unscheduled');
    const today = new Date();
    return date.toDateString() === today.toDateString() ? tr('Today') : date.toLocaleDateString();
  }
  private time(value: ReminderRecord): string {
    const date = new Date(value.nextFireAt ?? value.scheduledAt ?? '');
    return Number.isNaN(date.getTime()) ? '--:--' : `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
  }
  private days(): string[] {
    const result: string[] = [];
    this.data.reminders.filter((entry: ReminderRecord) => !this.cancelled(entry)).forEach((entry: ReminderRecord) => {
      const day = this.day(entry); if (!result.includes(day)) result.push(day);
    });
    return result;
  }
  private title(value: ReminderRecord): string { return this.data.items.find((item) => item.id === value.itemId)?.title ?? tr('Reminder'); }
  private source(value: ReminderRecord): string {
    const item = this.data.items.find((item) => item.id === value.itemId);
    return this.data.sources.find((source) => source.id === item?.sourceId)?.name ?? 'Agent';
  }
  build() {
    Column({ space: 0 }) {
      Row() {
        Blank().width(38)
        Text(tr('Reminders')).fontSize(17).fontWeight(FontWeight.Medium).fontColor(this.foreground()).layoutWeight(1).textAlign(TextAlign.Center)
        Text('···').fontSize(22).width(38).height(38).textAlign(TextAlign.Center).fontColor(this.foreground()).backgroundColor(this.grouped()).borderRadius(19)
      }.padding({ left: 18, right: 18, top: 8, bottom: 10 }).width('100%')
      Scroll() {
        Column({ space: 16 }) {
          if (!this.model.session.verified) {
            Text(tr('Sign in to receive your encrypted messages.')).fontColor(this.muted()).padding({ top: 60 })
            Button(tr('Sign in')).onClick(this.onSignIn)
          } else {
            Scroll() {
              Row({ space: 8 }) {
                ForEach(['Upcoming', 'Snoozed', 'Repeating', 'History'], (filter: string) => {
                  Text(tr(filter)).fontSize(12).fontWeight(FontWeight.Medium).height(32).padding({ left: 12, right: 12 })
                    .fontColor(this.selected === filter ? (this.dark() ? '#0D1117' : '#FFFFFF') : this.muted())
                    .backgroundColor(this.selected === filter ? (this.dark() ? '#F0F6FC' : '#25292E') : this.grouped()).borderRadius(16)
                    .onClick(() => { this.selected = filter; })
                })
              }
            }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
            if (this.busy) LoadingProgress().width(24).height(24)
            if (this.error) {
              Text(this.error).fontSize(13).fontColor('#D1242F')
              Button(tr('Retry')).onClick(() => { void this.load(); })
            }
            ForEach(this.days(), (day: string) => {
              Text(day).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.foreground()).width('100%')
              ForEach(this.data.reminders.filter((entry: ReminderRecord) => !this.cancelled(entry) && this.day(entry) === day),
                (entry: ReminderRecord) => { this.reminderRow(entry) }, (entry: ReminderRecord) => entry.id)
            })
            Text(tr('Cancelled')).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.foreground()).width('100%')
            ForEach(this.data.reminders.filter((entry: ReminderRecord) => this.cancelled(entry)),
              (entry: ReminderRecord) => { this.reminderRow(entry) }, (entry: ReminderRecord) => entry.id)
          }
        }.padding({ left: 18, right: 18, bottom: 110 }).width('100%').alignItems(HorizontalAlign.Start)
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%')
  }
  @Builder private reminderRow(entry: ReminderRecord) {
    Row({ space: 14 }) {
      Text(this.time(entry)).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.foreground()).width(54)
      Column({ space: 6 }) {
        Text(this.title(entry)).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.foreground())
        Text(this.source(entry)).fontSize(12).fontColor(this.muted())
        Text(this.cancelled(entry) ? tr('Cancelled') : tr('App notifications')).fontSize(12).fontColor(this.muted())
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Text(entry.pushEnabled ? entry.priority : tr('In-app only')).fontSize(12).fontColor('#9A6700')
        .backgroundColor('#FFF8C5').padding(6).borderRadius(7)
    }.alignItems(VerticalAlign.Top).padding(14).width('100%').borderRadius(8)
      .border({ width: 1, color: this.dark() ? '#30363D' : '#D1D9E0' }).opacity(this.cancelled(entry) ? 0.72 : 1)
  }
}
