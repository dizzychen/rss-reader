// WorkScheduler 后台任务管理器
// 负责注册、注销、查询 RSS 定时刷新后台任务
// 注意：HarmonyOS WorkScheduler 受系统应用分组限制，实际执行间隔可能大于设置值

import { workScheduler } from '@kit.BackgroundTasksKit';

const TAG = 'WorkSchedulerManager';

// 任务唯一 ID（需与 module.json5 中 abilityName 对应）
const FEED_REFRESH_TASK_ID = 1001;
const FEED_REFRESH_ABILITY_NAME = 'RssRefreshExtension';

export class WorkSchedulerManager {
  private static instance: WorkSchedulerManager;
  // 缓存 bundleName，stopWork 时需要传入非空包名
  private bundleName: string = '';

  static getInstance(): WorkSchedulerManager {
    if (!WorkSchedulerManager.instance) {
      WorkSchedulerManager.instance = new WorkSchedulerManager();
    }
    return WorkSchedulerManager.instance;
  }

  /**
   * 注册（或更新）定时刷新任务
   * @param bundleName - 应用包名（如 'com.dizzy.rssreader'）
   * @param intervalMinutes - 刷新间隔（分钟），0 表示关闭
   * @returns 是否成功
   *
   * 重要提示：
   * - HarmonyOS WorkScheduler 最小间隔为 20 分钟
   * - 实际执行间隔受应用分组限制（活跃应用最小 2 小时，非活跃更长）
   * - 任务需要网络连接才会触发
   */
  async registerFeedRefreshTask(bundleName: string, intervalMinutes: number): Promise<boolean> {
    if (!bundleName) {
      console.error(TAG, '❌ bundleName 不能为空');
      return false;
    }
    // 缓存包名供 stop 方法使用
    this.bundleName = bundleName;

    if (intervalMinutes <= 0) {
      console.info(TAG, '间隔为 0，停止后台任务');
      return this.unregisterFeedRefreshTask();
    }

    // HarmonyOS WorkScheduler 要求 repeatCycleTime >= 20 分钟
    const MIN_INTERVAL = 20;
    const originalInterval = intervalMinutes;
    if (intervalMinutes < MIN_INTERVAL) {
      console.warn(TAG, `间隔 ${intervalMinutes} 分钟低于系统最小值，自动调整为 ${MIN_INTERVAL} 分钟`);
      intervalMinutes = MIN_INTERVAL;
    }

    try {
      // 先停止已有任务（若存在），再重新创建（更新间隔）
      await this.stopExistingTaskIfNeeded();

      const workInfo: workScheduler.WorkInfo = {
        workId: FEED_REFRESH_TASK_ID,
        bundleName: bundleName,
        abilityName: FEED_REFRESH_ABILITY_NAME,

        // 重复配置
        isRepeat: true,
        repeatCycleTime: intervalMinutes * 60 * 1000,

        // 需要有网络才触发（任意网络）
        networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,

        // 设备重启后保留任务
        isPersisted: true
      };

      workScheduler.startWork(workInfo);
      console.info(TAG, `✅ 后台刷新任务已注册`);
      console.info(TAG, `   - 设置间隔: ${originalInterval} 分钟`);
      console.info(TAG, `   - 实际间隔: ${intervalMinutes} 分钟（系统最小 20 分钟）`);
      console.info(TAG, `   - 任务ID: ${FEED_REFRESH_TASK_ID}`);
      console.info(TAG, `   - 包名: ${bundleName}`);
      console.info(TAG, `   - 注意: 实际执行受系统应用分组限制，活跃应用最小间隔约 2 小时`);
      return true;

    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(TAG, `注册任务失败: ${msg}`);
      return false;
    }
  }

  /**
   * 注销定时刷新任务
   * @returns 是否成功
   */
  async unregisterFeedRefreshTask(): Promise<boolean> {
    if (!this.bundleName) {
      console.warn(TAG, 'bundleName 未初始化，跳过注销');
      return false;
    }
    try {
      const stopWorkInfo: workScheduler.WorkInfo = {
        workId: FEED_REFRESH_TASK_ID,
        bundleName: this.bundleName,
        abilityName: FEED_REFRESH_ABILITY_NAME,
        isRepeat: true,
        repeatCycleTime: 20 * 60 * 1000,  // 占位值，最小 20 分钟
        networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY  // 必须包含条件字段
      };

      // needCancel=true：彻底删除任务，不再触发
      workScheduler.stopWork(stopWorkInfo, true);
      console.info(TAG, '✅ 后台刷新任务已注销');
      return true;

    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error(TAG, `注销任务失败: ${msg}`);
      return false;
    }
  }

  /**
   * 查询后台刷新任务是否存在
   * @returns 任务是否已注册
   */
  async isTaskRegistered(): Promise<boolean> {
    try {
      const works = await workScheduler.obtainAllWorks();
      const exists = works.some(w => w.workId === FEED_REFRESH_TASK_ID);
      console.info(TAG, `任务状态: ${exists ? '已注册' : '未注册'}`);
      return exists;
    } catch (e) {
      console.error(TAG, `查询任务失败: ${e}`);
      return false;
    }
  }

  // ===== 内部方法 =====

  private async stopExistingTaskIfNeeded(): Promise<void> {
    try {
      const works = await workScheduler.obtainAllWorks();
      const exists = works.some(w => w.workId === FEED_REFRESH_TASK_ID);
      if (exists && this.bundleName.length > 0) {
        try {
          const stopWorkInfo: workScheduler.WorkInfo = {
            workId: FEED_REFRESH_TASK_ID,
            bundleName: this.bundleName,
            abilityName: FEED_REFRESH_ABILITY_NAME,
            isRepeat: true,
            repeatCycleTime: 20 * 60 * 1000,  // 占位值，最小 20 分钟
            networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY  // 必须包含条件字段
          };
          workScheduler.stopWork(stopWorkInfo, true);
          console.info(TAG, '已停止旧任务');
        } catch (stopErr) {
          const msg = stopErr instanceof Error ? stopErr.message : String(stopErr);
          console.warn(TAG, `停止旧任务失败（继续注册）: ${msg}`);
        }
      }
    } catch (e) {
      // 查询或停止失败不影响注册
      console.warn(TAG, `停止旧任务查询失败（可忽略）: ${e}`);
    }
  }
}
