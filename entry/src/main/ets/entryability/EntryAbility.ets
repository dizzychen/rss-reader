import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { SettingsService } from '../service/SettingsService';

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(0x0000, 'RSSReader', 'onCreate');
    // 初始化数据库
    await DatabaseHelper.getInstance().init(this.context);
    // 初始化设置
    await SettingsService.getInstance().init(this.context);
  }

  onDestroy(): void {
    hilog.info(0x0000, 'RSSReader', 'onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'RSSReader', 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'RSSReader', `loadContent failed: ${err.message}`);
      }
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'RSSReader', 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'RSSReader', 'onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'RSSReader', 'onBackground');
  }
}
