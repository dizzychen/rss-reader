import { UIAbility, Want, AbilityConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { SettingsService } from '../service/SettingsService';

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(0x0000, 'RSSReader', '%{public}s', 'onCreate');
    // 初始化数据库
    await DatabaseHelper.getInstance().init(this.context);
    // 初始化设置
    await SettingsService.getInstance().init(this.context);
  }

  onDestroy(): void {
    hilog.info(0x0000, 'RSSReader', '%{public}s', 'onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'RSSReader', '%{public}s', 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err && err.code) {
        hilog.error(0x0000, 'RSSReader', 'loadContent failed: %{public}s', err.message);
      }
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'RSSReader', '%{public}s', 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'RSSReader', '%{public}s', 'onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'RSSReader', '%{public}s', 'onBackground');
  }
}
