import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { notificationManager } from '@kit.NotificationKit';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { SettingsService } from '../service/SettingsService';
import { MemoryService, setProfileRegenerateCallback, setProfileQuickRefreshCallback } from '../service/MemoryService';
import { ProfileService } from '../service/ProfileService';
import { AIService } from '../service/AIService';
import { DateUtil } from '../utils/DateUtil';
import { WorkSchedulerManager } from '../service/WorkSchedulerManager';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  // 暂存冷启动时的通知来源标记，等 onWindowStageCreate 页面就绪后再 emit
  private pendingNotificationTap: boolean = false;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'RSSReader', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'RSSReader', '%{public}s', 'Ability onCreate');
    // 冷启动：检查是否来自通知点击，暂存标记（页面尚未加载，不能直接 emit）
    if (want?.parameters?.from === 'notification') {
      hilog.info(DOMAIN, 'RSSReader', '冷启动来自通知点击，暂存标记');
      this.pendingNotificationTap = true;
      AppStorage.setOrCreate('notification_cold_start', true);
    }
    // 初始化数据库
    await DatabaseHelper.getInstance().init(this.context);
    // 初始化设置
    await SettingsService.getInstance().init(this.context);
    // 初始化记忆系统（预加载 rawfile 模板，确保首次启动时写入沙箱目录）
    const soulTemplate = await this.loadRawfileAsString('memory/SOUL.md');
    const profileTemplate = await this.loadRawfileAsString('memory/PROFILE.md');
    const lessonsTemplate = await this.loadRawfileAsString('memory/LESSONS.md');
    await MemoryService.getInstance().init(this.context, soulTemplate, profileTemplate, lessonsTemplate);
    // 注入 ProfileService.regenerate 回调，避免 MemoryService 与 ProfileService 循环依赖
    setProfileRegenerateCallback(() => ProfileService.getInstance().regenerate());
    setProfileQuickRefreshCallback(() => ProfileService.getInstance().quickRefresh());
    // 加载 AI API Key
    const apiKey = await SettingsService.getInstance().getAIApiKey();
    if (apiKey) {
      AIService.getInstance().setApiKey(apiKey);
    }
    // 加载 AI 提供商配置
    const aiProvider = await SettingsService.getInstance().getAIProvider();
    AIService.getInstance().setProvider(aiProvider);
    let aiBaseUrl = await SettingsService.getInstance().getAIBaseUrl();
    // 自动修正已知的错误域名（coding.dashscope 是无效域名）
    if (aiBaseUrl.includes('coding.dashscope.aliyuncs.com')) {
      aiBaseUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
      await SettingsService.getInstance().setAIBaseUrl(aiBaseUrl);
      hilog.info(DOMAIN, 'RSSReader', 'AI Base URL 已自动修正为 DashScope 兼容模式端点');
    }
    AIService.getInstance().setBaseUrl(aiBaseUrl);
    const aiModelName = await SettingsService.getInstance().getAIModelName();
    AIService.getInstance().setModel(aiModelName);
    // 每日维护（检查是否需要执行）
    this.runDailyMaintenance();
    // 恢复后台刷新任务（设备重启后保持周期任务）
    this.restoreBackgroundRefreshTask();
  }

  /**
   * 从 rawfile 读取文本文件内容（读取失败时返回空字符串）
   */
  private async loadRawfileAsString(path: string): Promise<string> {
    try {
      const rawData = await this.context.resourceManager.getRawFileContent(path);
      const decoder = new util.TextDecoder('utf-8');
      const text = decoder.decodeToString(rawData);
      hilog.info(DOMAIN, 'RSSReader', `rawfile loaded: ${path} (${rawData.length} bytes)`);
      return text;
    } catch (e) {
      hilog.warn(DOMAIN, 'RSSReader', `rawfile load failed: ${path}: %{public}s`, String(e));
      return '';
    }
  }

  private async restoreBackgroundRefreshTask(): Promise<void> {
    try {
      const settings = await SettingsService.getInstance().getSettings();
      if (settings.bgRefreshEnabled && settings.refreshInterval > 0) {
        await WorkSchedulerManager.getInstance().registerFeedRefreshTask(
          this.context.abilityInfo.bundleName,
          settings.refreshInterval
        );
        hilog.info(DOMAIN, 'RSSReader', '后台刷新任务已恢复，间隔 %{public}d 分钟', settings.refreshInterval);
      }
    } catch (e) {
      hilog.warn(DOMAIN, 'RSSReader', '恢复后台刷新任务失败: %{public}s', String(e));
    }
  }

  private async runDailyMaintenance(): Promise<void> {
    try {
      const today = DateUtil.today();
      const lastDate = await SettingsService.getInstance().getLastMaintenanceDate();
      if (lastDate !== today) {
        await MemoryService.getInstance().dailyMaintenance();
        await SettingsService.getInstance().setLastMaintenanceDate(today);
        hilog.info(DOMAIN, 'RSSReader', 'dailyMaintenance completed for %{public}s', today);
      }
    } catch (e) {
      hilog.warn(DOMAIN, 'RSSReader', 'dailyMaintenance failed: %{public}s', String(e));
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'RSSReader', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'RSSReader', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'RSSReader', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'RSSReader', 'Succeeded in loading the content.');
      // 页面加载完毕，如果是通知冷启动，延迟 emit 确保 Index aboutToAppear 已注册监听
      if (this.pendingNotificationTap) {
        this.pendingNotificationTap = false;
        setTimeout(() => {
          this.context.eventHub.emit('notification_tap');
          hilog.info(DOMAIN, 'RSSReader', '冷启动通知事件已发送: notification_tap');
        }, 600);
      }
    });

    // 请求通知权限（首次会弹窗，用户选择后不再弹窗）
    this.requestNotificationPermission();
  }

  private async requestNotificationPermission(): Promise<void> {
    try {
      // 先检查是否已授权
      const isEnabled = await notificationManager.isNotificationEnabled();
      if (isEnabled) {
        hilog.info(DOMAIN, 'RSSReader', '通知权限已授权');
        return;
      }
      // 请求授权（首次调用会弹窗）
      await notificationManager.requestEnableNotification(this.context);
      hilog.info(DOMAIN, 'RSSReader', '通知权限请求成功');
    } catch (e) {
      // 错误码 1600004 表示用户拒绝授权，这是正常情况
      hilog.warn(DOMAIN, 'RSSReader', '通知权限请求: %{public}s', String(e));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'RSSReader', '%{public}s', 'Ability onWindowStageDestroy');
  }

  /**
   * 热启动：应用已在后台（singleton），用户点击通知时系统调用此方法
   * 此时页面已加载，可直接通过 EventHub 通知 Index 刷新数据
   */
  onNewWant(want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'RSSReader', 'Ability onNewWant, from=%{public}s',
      String(want?.parameters?.from ?? 'unknown'));
    if (want?.parameters?.from === 'notification') {
      this.context.eventHub.emit('notification_tap');
      hilog.info(DOMAIN, 'RSSReader', '热启动通知事件已发送: notification_tap');
    }
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'RSSReader', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'RSSReader', '%{public}s', 'Ability onBackground');
  }
}