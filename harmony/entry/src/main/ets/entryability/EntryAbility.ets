import { AbilityConstant, Configuration, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { pushService } from '@kit.PushKit';
import { authService } from '../services/AuthService';
import { deviceService } from '../services/DeviceService';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x20260912;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    void want;
    void launchParam;
    AppStorage.setOrCreate('pushRefresh', 0);
    try {
      pushService.on('tokenUpdate', this, (token: string) => {
        void this.registerRotatedToken(token);
      });
    } catch { AppStorage.setOrCreate('pushRegistrationError', 'Push token updates unavailable'); }
    AppStorage.setOrCreate('systemColorMode', this.context.config.colorMode);
    hilog.info(DOMAIN, 'JiZhiHarmony', 'created');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (error) => {
      if (error.code) {
        hilog.error(DOMAIN, 'JiZhiHarmony', `loadContent failed: ${JSON.stringify(error)}`);
      }
    });
  }

  onForeground(): void { this.refreshInbox(); }

  onNewWant(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    // Routing hints are untrusted: refresh authenticated history and decrypt locally.
    this.refreshInbox();
  }

  onDestroy(): void {
    try { pushService.off('tokenUpdate'); } catch {}
  }

  private refreshInbox(): void {
    AppStorage.setOrCreate('pushRefresh', (AppStorage.get<number>('pushRefresh') ?? 0) + 1);
  }

  private async registerRotatedToken(token: string): Promise<void> {
    if (!authService.current.verified) return;
    try {
      await deviceService.updatePushToken(await authService.requireAccessToken(), token);
      AppStorage.setOrCreate('pushRegistrationError', '');
    } catch { AppStorage.setOrCreate('pushRegistrationError', 'Push registration needs retry in Devices'); }
  }

  onConfigurationUpdate(config: Configuration): void {
    AppStorage.setOrCreate('systemColorMode', config.colorMode);
  }
}
