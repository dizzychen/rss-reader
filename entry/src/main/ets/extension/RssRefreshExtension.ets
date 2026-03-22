// RSS 后台刷新扩展
// 基于 WorkSchedulerExtensionAbility 实现周期性后台 RSS 订阅源刷新
// 注意：实际执行间隔受系统应用分组限制，活跃应用最小 2 小时，非活跃应用更长

import { WorkSchedulerExtensionAbility } from '@kit.BackgroundTasksKit';
import { workScheduler } from '@kit.BackgroundTasksKit';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { FeedRefreshService } from '../service/FeedRefreshService';
import { SettingsService } from '../service/SettingsService';

const TAG = 'RssRefreshExtension';

export default class RssRefreshExtension extends WorkSchedulerExtensionAbility {
  private retryCount: number = 0;
  private readonly MAX_RETRIES: number = 3;
  private readonly RETRY_DELAY_MS: number = 5000;

  /**
   * 系统调度触发后台任务时回调
   * 注意：最长执行时间 120 秒，超时系统强制终止
   */
  async onWorkStart(workInfo: workScheduler.WorkInfo): Promise<void> {
    const startTime = Date.now();
    console.info(TAG, `========== 后台刷新任务开始 ==========`);
    console.info(TAG, `onWorkStart workId=${workInfo.workId}, time=${new Date().toISOString()}`);
    this.retryCount = 0;
    await this.doRefreshWithRetry(workInfo);
    const duration = Date.now() - startTime;
    console.info(TAG, `========== 后台刷新任务结束，耗时 ${duration}ms ==========`);
  }

  /**
   * 系统强制停止任务时回调
   */
  onWorkStop(workInfo: workScheduler.WorkInfo): void {
    console.info(TAG, `onWorkStop workId=${workInfo.workId}, time=${new Date().toISOString()}`);
  }

  // ===== 内部方法 =====

  private async doRefreshWithRetry(workInfo: workScheduler.WorkInfo): Promise<void> {
    while (this.retryCount <= this.MAX_RETRIES) {
      try {
        if (this.retryCount > 0) {
          console.info(TAG, `重试 ${this.retryCount}/${this.MAX_RETRIES}，等待 ${this.RETRY_DELAY_MS}ms`);
          await this.delay(this.RETRY_DELAY_MS);
        }

        await this.doRefresh();
        console.info(TAG, '✅ 后台刷新成功');
        return;

      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        console.error(TAG, `❌ 刷新失败（第 ${this.retryCount + 1} 次）: ${msg}`);

        this.retryCount++;

        if (this.retryCount > this.MAX_RETRIES) {
          console.warn(TAG, `已达最大重试次数 ${this.MAX_RETRIES}，放弃此次刷新`);
          return;
        }
      }
    }
  }

  private async doRefresh(): Promise<void> {
    const context = this.context;

    // 初始化数据库（扩展进程每次启动都需要）
    await DatabaseHelper.getInstance().init(context);

    // 初始化设置
    await SettingsService.getInstance().init(context);

    // 检查后台刷新是否开启
    const settings = await SettingsService.getInstance().getSettings();
    if (!settings.bgRefreshEnabled) {
      console.info(TAG, '后台刷新已关闭，跳过');
      return;
    }

    // 执行刷新
    const newCount = await FeedRefreshService.getInstance().refreshAll(context);
    console.info(TAG, `后台刷新完成：新增 ${newCount} 篇文章`);
  }

  private delay(ms: number): Promise<void> {
    return new Promise<void>(resolve => {
      setTimeout(resolve, ms);
    });
  }
}
