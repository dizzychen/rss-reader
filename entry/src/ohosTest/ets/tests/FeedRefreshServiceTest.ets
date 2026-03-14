import { describe, it, expect } from '@ohos/hypium';
import { Feed, AppSettings } from '../../../main/ets/model/Models';
import { ParsedFeedInfo } from '../../../main/ets/service/RssService';

/**
 * FeedRefreshService 业务逻辑单元测试
 * 覆盖：刷新计数、通知判断、feed元信息更新、缓存清理逻辑
 */

// 工具函数：创建测试 Feed
function createTestFeed(id: number, url: string): Feed {
  return {
    id,
    title: `Feed ${id}`,
    url,
    siteUrl: `https://feed${id}.com`,
    iconUrl: '',
    description: `Feed ${id} description`,
    groupId: 1,
    lastUpdated: 0
  };
}

// 工具函数：创建测试 ParsedFeedInfo
function createParsedFeedInfo(articleCount: number): ParsedFeedInfo {
  const articles = Array.from({ length: articleCount }, (_, i) => ({
    guid: `guid-${i}`,
    title: `文章${i}`,
    summary: `摘要${i}`,
    content: `内容${i}`,
    url: `https://example.com/article${i}`,
    author: `作者${i}`,
    publishedAt: Date.now() - i * 3600000,
    coverImage: ''
  }));
  return {
    title: '测试源',
    siteUrl: 'https://example.com',
    description: '描述',
    iconUrl: '',
    articles
  };
}

// 模拟 refreshAll 中的核心计数逻辑
function simulateRefreshAll(
  feeds: Feed[],
  refreshResults: Map<number, number>, // feedId -> newArticleCount, -1表示失败
  settings: AppSettings
): { totalNew: number; shouldNotify: boolean } {
  let newArticleCount = 0;
  for (const feed of feeds) {
    try {
      const count = refreshResults.get(feed.id!) ?? 0;
      if (count < 0) throw new Error('refresh failed');
      newArticleCount += count;
    } catch (e) {
      // 忽略单个 feed 刷新失败
    }
  }
  return {
    totalNew: newArticleCount,
    shouldNotify: newArticleCount > 0 && settings.notificationEnabled
  };
}

// 模拟 Feed 元信息更新逻辑
function simulateFeedMetaUpdate(feed: Feed, parsed: ParsedFeedInfo): Feed {
  return {
    ...feed,
    title: parsed.title || feed.title,
    siteUrl: parsed.siteUrl || feed.siteUrl,
    description: parsed.description || feed.description,
    lastUpdated: Date.now()
  };
}

// 模拟缓存清理逻辑
function simulateCleanOldCache(articleIds: number[], keepCount: number): number[] {
  if (articleIds.length > keepCount) {
    return articleIds.slice(keepCount); // 需要删除的ids
  }
  return [];
}

export default function FeedRefreshServiceTest() {
  describe('FeedRefreshServiceTest', () => {

    // ==================== refreshAll 计数逻辑 ====================

    describe('refreshAll_count_logic', () => {
      const defaultSettings: AppSettings = {
        refreshInterval: 30, bgRefreshEnabled: true,
        notificationEnabled: true, fontSize: 16,
        openOriginalInApp: true, cacheCountPerFeed: 50
      };

      it('should_sum_new_articles_from_all_feeds', 0, () => {
        const feeds = [createTestFeed(1, 'https://f1.com'), createTestFeed(2, 'https://f2.com')];
        const results = new Map([[1, 3], [2, 5]]);
        const { totalNew } = simulateRefreshAll(feeds, results, defaultSettings);
        expect(totalNew).assertEqual(8);
      });

      it('should_return_zero_when_no_new_articles', 0, () => {
        const feeds = [createTestFeed(1, 'https://f1.com')];
        const results = new Map([[1, 0]]);
        const { totalNew } = simulateRefreshAll(feeds, results, defaultSettings);
        expect(totalNew).assertEqual(0);
      });

      it('should_ignore_failed_feed_and_continue_counting', 0, () => {
        const feeds = [
          createTestFeed(1, 'https://f1.com'),
          createTestFeed(2, 'https://f2.com'),
          createTestFeed(3, 'https://f3.com')
        ];
        const results = new Map([[1, 2], [2, -1], [3, 3]]); // feed2 失败
        const { totalNew } = simulateRefreshAll(feeds, results, defaultSettings);
        expect(totalNew).assertEqual(5);
      });

      it('should_return_zero_for_empty_feeds', 0, () => {
        const { totalNew } = simulateRefreshAll([], new Map(), defaultSettings);
        expect(totalNew).assertEqual(0);
      });

      it('should_handle_single_feed_with_many_articles', 0, () => {
        const feeds = [createTestFeed(1, 'https://f1.com')];
        const results = new Map([[1, 100]]);
        const { totalNew } = simulateRefreshAll(feeds, results, defaultSettings);
        expect(totalNew).assertEqual(100);
      });
    });

    // ==================== 通知判断逻辑 ====================

    describe('notification_logic', () => {
      it('should_notify_when_new_articles_and_notification_enabled', 0, () => {
        const feeds = [createTestFeed(1, 'https://f1.com')];
        const results = new Map([[1, 3]]);
        const settings: AppSettings = {
          refreshInterval: 30, bgRefreshEnabled: true,
          notificationEnabled: true, fontSize: 16,
          openOriginalInApp: true, cacheCountPerFeed: 50
        };
        const { shouldNotify } = simulateRefreshAll(feeds, results, settings);
        expect(shouldNotify).assertTrue();
      });

      it('should_not_notify_when_notification_disabled', 0, () => {
        const feeds = [createTestFeed(1, 'https://f1.com')];
        const results = new Map([[1, 5]]);
        const settings: AppSettings = {
          refreshInterval: 30, bgRefreshEnabled: true,
          notificationEnabled: false, fontSize: 16,
          openOriginalInApp: true, cacheCountPerFeed: 50
        };
        const { shouldNotify } = simulateRefreshAll(feeds, results, settings);
        expect(shouldNotify).assertFalse();
      });

      it('should_not_notify_when_no_new_articles', 0, () => {
        const feeds = [createTestFeed(1, 'https://f1.com')];
        const results = new Map([[1, 0]]);
        const settings: AppSettings = {
          refreshInterval: 30, bgRefreshEnabled: true,
          notificationEnabled: true, fontSize: 16,
          openOriginalInApp: true, cacheCountPerFeed: 50
        };
        const { shouldNotify } = simulateRefreshAll(feeds, results, settings);
        expect(shouldNotify).assertFalse();
      });
    });

    // ==================== Feed 元信息更新逻辑 ====================

    describe('feed_meta_update_logic', () => {
      it('should_update_title_from_parsed_if_not_empty', 0, () => {
        const feed = createTestFeed(1, 'https://f1.com');
        const parsed = createParsedFeedInfo(0);
        parsed.title = '新标题';
        const updated = simulateFeedMetaUpdate(feed, parsed);
        expect(updated.title).assertEqual('新标题');
      });

      it('should_keep_original_title_if_parsed_title_empty', 0, () => {
        const feed = createTestFeed(1, 'https://f1.com');
        const parsed = createParsedFeedInfo(0);
        parsed.title = '';
        const updated = simulateFeedMetaUpdate(feed, parsed);
        expect(updated.title).assertEqual('Feed 1');
      });

      it('should_update_site_url_from_parsed', 0, () => {
        const feed = createTestFeed(1, 'https://f1.com');
        const parsed = createParsedFeedInfo(0);
        parsed.siteUrl = 'https://newsite.com';
        const updated = simulateFeedMetaUpdate(feed, parsed);
        expect(updated.siteUrl).assertEqual('https://newsite.com');
      });

      it('should_keep_original_site_url_if_parsed_empty', 0, () => {
        const feed = createTestFeed(1, 'https://f1.com');
        const parsed = createParsedFeedInfo(0);
        parsed.siteUrl = '';
        const updated = simulateFeedMetaUpdate(feed, parsed);
        expect(updated.siteUrl).assertEqual('https://feed1.com');
      });

      it('should_update_last_updated_timestamp', 0, () => {
        const feed = createTestFeed(1, 'https://f1.com');
        const parsed = createParsedFeedInfo(0);
        const before = Date.now();
        const updated = simulateFeedMetaUpdate(feed, parsed);
        expect(updated.lastUpdated >= before).assertTrue();
      });

      it('should_preserve_feed_url_and_id', 0, () => {
        const feed = createTestFeed(42, 'https://original.com/feed');
        const parsed = createParsedFeedInfo(0);
        const updated = simulateFeedMetaUpdate(feed, parsed);
        expect(updated.id).assertEqual(42);
        expect(updated.url).assertEqual('https://original.com/feed');
      });
    });

    // ==================== 缓存清理逻辑 ====================

    describe('clean_old_cache_logic', () => {
      it('should_not_delete_when_under_keep_count', 0, () => {
        const ids = [1, 2, 3];
        const toDelete = simulateCleanOldCache(ids, 50);
        expect(toDelete.length).assertEqual(0);
      });

      it('should_delete_excess_articles', 0, () => {
        const ids = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
        const toDelete = simulateCleanOldCache(ids, 5);
        expect(toDelete.length).assertEqual(5);
      });

      it('should_delete_oldest_articles', 0, () => {
        // ids按published_at降序排列，所以靠后的是最旧的
        const ids = [100, 99, 98, 97, 96]; // 100最新，96最旧
        const toDelete = simulateCleanOldCache(ids, 3);
        expect(toDelete.length).assertEqual(2);
        expect(toDelete[0]).assertEqual(97);
        expect(toDelete[1]).assertEqual(96);
      });

      it('should_not_delete_when_exactly_at_keep_count', 0, () => {
        const ids = [1, 2, 3, 4, 5];
        const toDelete = simulateCleanOldCache(ids, 5);
        expect(toDelete.length).assertEqual(0);
      });

      it('should_delete_all_when_keep_count_is_zero', 0, () => {
        const ids = [1, 2, 3];
        const toDelete = simulateCleanOldCache(ids, 0);
        expect(toDelete.length).assertEqual(3);
      });

      it('should_handle_empty_article_list', 0, () => {
        const toDelete = simulateCleanOldCache([], 50);
        expect(toDelete.length).assertEqual(0);
      });
    });

    // ==================== ParsedFeedInfo 文章计数 ====================

    describe('parsed_article_counting', () => {
      it('should_count_articles_correctly', 0, () => {
        const parsed = createParsedFeedInfo(5);
        expect(parsed.articles.length).assertEqual(5);
      });

      it('should_have_correct_article_structure', 0, () => {
        const parsed = createParsedFeedInfo(1);
        const article = parsed.articles[0];
        expect(article.guid).assertEqual('guid-0');
        expect(article.title).assertEqual('文章0');
        expect(article.coverImage).assertEqual('');
      });

      it('should_handle_empty_articles', 0, () => {
        const parsed = createParsedFeedInfo(0);
        expect(parsed.articles.length).assertEqual(0);
      });
    });
  });
}
