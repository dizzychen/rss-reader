// 后台刷新 WorkScheduler Worker
import workScheduler from '@ohos.resourceschedule.workScheduler';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { SettingsService } from '../service/SettingsService';
import { FeedRefreshService } from '../service/FeedRefreshService';

export default class RssRefreshWorker {
  onWorkStart(workInfo: workScheduler.WorkInfo): void {
    console.info('RssRefreshWorker', `后台刷新任务启动 workId=${workInfo.workId}`);
    // 注意：WorkScheduler 回调中 context 需通过 ability 获取，此处简化示意
  }

  onWorkStop(workInfo: workScheduler.WorkInfo): void {
    console.info('RssRefreshWorker', `后台刷新任务停止 workId=${workInfo.workId}`);
  }
}
