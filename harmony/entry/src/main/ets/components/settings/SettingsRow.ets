import { palette, JZTheme } from '../../theme/JZTheme';
@Component
export struct SettingsRow {
  @StorageProp('systemColorMode') private systemColorMode: number = 1;
  @StorageProp('appearance') private appearance: string = 'system';
  private get colors(): JZTheme { return palette(this.appearance === 'dark' || (this.appearance === 'system' && this.systemColorMode === 0)); }
  title: string = '';
  value: string = '';
  icon: string = '';
  disclosure: boolean = true;
  selected: boolean = false;
  action: () => void = () => {};
  build() {
    Row({ space: 12 }) {
      if (this.icon) Text(this.icon).fontSize(22).fontColor(this.colors.text).width(26)
      Text(this.title).fontSize(17).fontColor(this.colors.text).layoutWeight(1)
      if (this.value) Text(this.value).fontSize(16).fontColor(this.colors.muted).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).constraintSize({ maxWidth: '55%' })
      if (this.selected) Text('✓').fontSize(19).fontColor(this.colors.blue)
      if (this.disclosure) Text('›').fontSize(23).fontColor('#B8B8BD')
    }.width('100%').constraintSize({ minHeight: 46 }).padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor(this.colors.card).onClick(this.action)
  }
}
