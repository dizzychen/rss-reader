import { DatabaseHelper } from '../database/DatabaseHelper';
import { RssService } from './RssService';
import { SettingsService } from './SettingsService';
import { Feed } from '../model/Models';
import { notificationManager } from '@kit.NotificationKit';
import { common, wantAgent, WantAgent, Want } from '@kit.AbilityKit';

const TAG = 'FeedRefreshService';

export class FeedRefreshService {
  private static instance: FeedRefreshService;
  // 记录上次刷新时间，用于调试
  private lastRefreshTime: number = 0;

  static getInstance(): FeedRefreshService {
    if (!FeedRefreshService.instance) {
      FeedRefreshService.instance = new FeedRefreshService();
    }
    return FeedRefreshService.instance;
  }

  /**
   * 获取上次刷新时间（用于调试）
   */
  getLastRefreshTime(): number {
    return this.lastRefreshTime;
  }

  /**
   * 刷新所有订阅源
   */
  async refreshAll(context: common.Context): Promise<number> {
    const startTime = Date.now();
    console.info(TAG, `===== 开始刷新所有订阅源 =====`);
    console.info(TAG, `刷新时间: ${new Date().toISOString()}`);

    const db = DatabaseHelper.getInstance();
    const settings = await SettingsService.getInstance().getSettings();

    const feeds = await db.getAllFeeds();
    console.info(TAG, `共 ${feeds.length} 个订阅源待刷新`);

    let newArticleCount = 0;
    let successCount = 0;
    let failCount = 0;

    for (const feed of feeds) {
      try {
        const count = await this.refreshSingleFeed(feed);
        newArticleCount += count;
        successCount++;
        if (count > 0) {
          console.info(TAG, `[${feed.title}] 新增 ${count} 篇文章`);
        }
        // 清理旧缓存
        await db.cleanOldCache(feed.id!, settings.cacheCountPerFeed);
      } catch (e) {
        failCount++;
        console.error(TAG, `[${feed.title}] 刷新失败: ${e}`);
      }
    }

    this.lastRefreshTime = Date.now();
    const duration = this.lastRefreshTime - startTime;
    console.info(TAG, `===== 刷新完成 =====`);
    console.info(TAG, `成功: ${successCount}, 失败: ${failCount}, 新文章: ${newArticleCount}, 耗时: ${duration}ms`);

    if (newArticleCount > 0 && settings.notificationEnabled) {
      await this.sendNotification(newArticleCount);
    }

    return newArticleCount;
  }

  /**
   * 刷新单个订阅源，返回新增文章数
   */
  async refreshSingleFeed(feed: Feed): Promise<number> {
    const rss = RssService.getInstance();

    const parsed = await rss.refreshFeed(feed.url);
    let newCount = 0;

    for (const pa of parsed.articles) {
      const coverImage = pa.coverImage || rss.extractFirstImage(pa.content);
      const rowId = await DatabaseHelper.getInstance().insertOrUpdateArticle({
        feedId: feed.id!,
        guid: pa.guid,
        title: pa.title,
        summary: pa.summary,
        content: pa.content,
        url: pa.url,
        author: pa.author,
        publishedAt: pa.publishedAt,
        isRead: 0,
        isStarred: 0,
        coverImage: coverImage
      });
      if (rowId > 0) newCount++;
    }

    // 更新订阅源元信息
    await DatabaseHelper.getInstance().updateFeed({
      id: feed.id,
      url: feed.url,
      groupId: feed.groupId,
      title: parsed.title || feed.title,
      siteUrl: parsed.siteUrl || feed.siteUrl,
      description: parsed.description || feed.description,
      iconUrl: feed.iconUrl,
      lastUpdated: Date.now()
    });

    return newCount;
  }

  private async sendNotification(count: number): Promise<void> {
    try {
      console.info(TAG, `发送通知: ${count} 篇新文章`);

      // 创建 Want 对象，指定要启动的 Ability
      const want: Want = {
        bundleName: 'com.dizzy.myapplication',
        abilityName: 'EntryAbility',
        parameters: {
          from: 'notification'
        }
      };

      // 创建 WantAgent，点击通知时启动应用首页
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [want],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        wantAgentFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };

      const agent: WantAgent = await wantAgent.getWantAgent(wantAgentInfo);

      const request: notificationManager.NotificationRequest = {
        id: 1001,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: 'AIRSS',
            text: `有 ${count} 篇新文章`,
            additionalText: '点击查看'
          }
        },
        // 设置点击通知的行为
        wantAgent: agent
      };

      await notificationManager.publish(request);
      console.info(TAG, '通知发送成功');
    } catch (e) {
      console.error(TAG, `通知发送失败: ${e}`);
    }
  }
}
