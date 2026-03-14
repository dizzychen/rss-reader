import { DatabaseHelper } from '../database/DatabaseHelper';
import { RssService } from './RssService';
import { SettingsService } from './SettingsService';
import { Feed } from '../model/Models';
import notificationManager from '@ohos.notificationManager';

export class FeedRefreshService {
  private static instance: FeedRefreshService;

  static getInstance(): FeedRefreshService {
    if (!FeedRefreshService.instance) {
      FeedRefreshService.instance = new FeedRefreshService();
    }
    return FeedRefreshService.instance;
  }

  /**
   * 刷新所有订阅源
   */
  async refreshAll(context: Context): Promise<number> {
    const db = DatabaseHelper.getInstance();
    const rss = RssService.getInstance();
    const settings = await SettingsService.getInstance().getSettings();

    const feeds = await db.getAllFeeds();
    let newArticleCount = 0;

    for (const feed of feeds) {
      try {
        const count = await this.refreshSingleFeed(feed, context);
        newArticleCount += count;
        // 清理旧缓存
        await db.cleanOldCache(feed.id!, settings.cacheCountPerFeed);
      } catch (e) {
        console.error('FeedRefreshService', `刷新失败 ${feed.url}: ${e}`);
      }
    }

    if (newArticleCount > 0 && settings.notificationEnabled) {
      await this.sendNotification(newArticleCount);
    }

    return newArticleCount;
  }

  /**
   * 刷新单个订阅源，返回新增文章数
   */
  async refreshSingleFeed(feed: Feed, context?: Context): Promise<number> {
    const db = DatabaseHelper.getInstance();
    const rss = RssService.getInstance();

    const parsed = await rss.refreshFeed(feed.url);
    let newCount = 0;

    for (const pa of parsed.articles) {
      const coverImage = pa.coverImage || rss.extractFirstImage(pa.content);
      const rowId = await db.insertOrUpdateArticle({
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
    await db.updateFeed({
      ...feed,
      title: parsed.title || feed.title,
      siteUrl: parsed.siteUrl || feed.siteUrl,
      description: parsed.description || feed.description,
      lastUpdated: Date.now()
    });

    return newCount;
  }

  private async sendNotification(count: number): Promise<void> {
    try {
      const request: notificationManager.NotificationRequest = {
        id: 1001,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: 'RSS阅读器',
            text: `有 ${count} 篇新文章`,
            additionalText: '点击查看'
          }
        }
      };
      await notificationManager.publish(request);
    } catch (e) {
      console.error('FeedRefreshService', `通知发送失败: ${e}`);
    }
  }
}
