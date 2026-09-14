export class JZTheme {
  background: string = '#FFFFFF';
  paper: string = '#F6F8FA';
  card: string = '#FFFFFF';
  text: string = '#1F2328';
  muted: string = '#59636E';
  line: string = '#D1D9E0';
  blue: string = '#0969DA';
  blueSoft: string = '#EAF3FF';
  amber: string = '#9A6700';
  amberSoft: string = '#FFF8C5';
  red: string = '#D1242F';
  green: string = '#1A7F37';
  chrome: string = '#F6F8FA';
  primary: string = '#25292E';
  inverse: string = '#FFFFFF';
}
export const JZLight = new JZTheme();
export const JZDark = new JZTheme();
JZDark.background = '#0D1117';
JZDark.paper = '#161B22';
JZDark.card = '#21262D';
JZDark.text = '#F0F6FC';
JZDark.muted = '#8B949E';
JZDark.line = '#30363D';
JZDark.blue = '#58A6FF';
JZDark.chrome = '#161B22';
JZDark.primary = '#F0F6FC';
JZDark.inverse = '#0D1117';
export function palette(dark: boolean): JZTheme { return dark ? JZDark : JZLight; }
export const JZ = JZLight;
