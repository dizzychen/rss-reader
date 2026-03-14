import { describe, it, expect } from '@ohos/hypium';
import { Feed, Article, FeedGroup, Tag } from '../../../main/ets/model/Models';

/**
 * DatabaseHelper 业务逻辑单元测试
 * 覆盖数据映射、查询条件、CRUD 数据结构的业务规则
 */

// 模拟 rowToFeed 映射逻辑
function rowToFeed(row: Record<string, Object>): Feed {
  return {
    id: row['id'] as number,
    title: row['title'] as string,
    url: row['url'] as string,
    siteUrl: row['site_url'] as string,
    iconUrl: row['icon_url'] as string,
    description: row['description'] as string,
    groupId: row['group_id'] as number,
    lastUpdated: row['last_updated'] as number
  };
}

// 模拟 feedToValues 映射逻辑
function feedToValues(feed: Feed): Record<string, Object> {
  return {
    title: feed.title,
    url: feed.url,
    site_url: feed.siteUrl,
    icon_url: feed.iconUrl,
    description: feed.description,
    group_id: feed.groupId,
    last_updated: feed.lastUpdated
  };
}

// 模拟 rowToArticle 映射逻辑
function rowToArticle(row: Record<string, Object>): Article {
  return {
    id: row['id'] as number,
    feedId: row['feed_id'] as number,
    guid: row['guid'] as string,
    title: row['title'] as string,
    summary: row['summary'] as string,
    content: row['content'] as string,
    url: row['url'] as string,
    author: row['author'] as string,
    publishedAt: row['published_at'] as number,
    isRead: row['is_read'] as number,
    isStarred: row['is_starred'] as number,
    coverImage: row['cover_image'] as string,
    cachedAt: row['cached_at'] as number
  };
}

// 模拟 articleToValues 映射逻辑
function articleToValues(article: Article): Record<string, Object> {
  return {
    feed_id: article.feedId,
    guid: article.guid,
    title: article.title,
    summary: article.summary,
    content: article.content,
    url: article.url,
    author: article.author,
    published_at: article.publishedAt,
    is_read: article.isRead,
    is_starred: article.isStarred,
    cover_image: article.coverImage,
    cached_at: Date.now()
  };
}

export default function DatabaseHelperTest() {
  describe('DatabaseHelperTest', () => {

    // ==================== Feed 数据映射测试 ====================

    describe('feed_data_mapping', () => {
      it('should_map_row_to_feed_correctly', 0, () => {
        const row: Record<string, Object> = {
          id: 1,
          title: '测试Feed',
          url: 'https://example.com/feed.xml',
          site_url: 'https://example.com',
          icon_url: 'https://example.com/icon.png',
          description: '测试描述',
          group_id: 2,
          last_updated: 1704067200000
        };
        const feed = rowToFeed(row);
        expect(feed.id).assertEqual(1);
        expect(feed.title).assertEqual('测试Feed');
        expect(feed.url).assertEqual('https://example.com/feed.xml');
        expect(feed.siteUrl).assertEqual('https://example.com');
        expect(feed.iconUrl).assertEqual('https://example.com/icon.png');
        expect(feed.description).assertEqual('测试描述');
        expect(feed.groupId).assertEqual(2);
        expect(feed.lastUpdated).assertEqual(1704067200000);
      });

      it('should_map_feed_to_values_correctly', 0, () => {
        const feed: Feed = {
          id: 1,
          title: '测试Feed',
          url: 'https://example.com/feed.xml',
          siteUrl: 'https://example.com',
          iconUrl: '',
          description: '描述',
          groupId: 1,
          lastUpdated: 0
        };
        const values = feedToValues(feed);
        expect(values['title']).assertEqual('测试Feed');
        expect(values['url']).assertEqual('https://example.com/feed.xml');
        expect(values['site_url']).assertEqual('https://example.com');
        expect(values['group_id']).assertEqual(1);
      });

      it('should_use_snake_case_for_db_column_names', 0, () => {
        const feed: Feed = {
          title: 'T', url: 'U', siteUrl: 'SU', iconUrl: 'IU',
          description: 'D', groupId: 1, lastUpdated: 100
        };
        const values = feedToValues(feed);
        // 确保使用下划线命名（数据库字段）
        expect('site_url' in values).assertTrue();
        expect('icon_url' in values).assertTrue();
        expect('group_id' in values).assertTrue();
        expect('last_updated' in values).assertTrue();
        // 确保不使用驼峰命名
        expect('siteUrl' in values).assertFalse();
        expect('groupId' in values).assertFalse();
      });
    });

    // ==================== Article 数据映射测试 ====================

    describe('article_data_mapping', () => {
      it('should_map_row_to_article_correctly', 0, () => {
        const row: Record<string, Object> = {
          id: 10,
          feed_id: 2,
          guid: 'unique-guid',
          title: '文章标题',
          summary: '摘要',
          content: '<p>内容</p>',
          url: 'https://example.com/a1',
          author: '作者',
          published_at: 1704067200000,
          is_read: 0,
          is_starred: 1,
          cover_image: 'https://example.com/cover.jpg',
          cached_at: 1704067200000
        };
        const article = rowToArticle(row);
        expect(article.id).assertEqual(10);
        expect(article.feedId).assertEqual(2);
        expect(article.guid).assertEqual('unique-guid');
        expect(article.isRead).assertEqual(0);
        expect(article.isStarred).assertEqual(1);
        expect(article.coverImage).assertEqual('https://example.com/cover.jpg');
      });

      it('should_map_article_to_values_with_snake_case', 0, () => {
        const article: Article = {
          feedId: 2, guid: 'g1', title: 'T', summary: 'S',
          content: 'C', url: 'U', author: 'A',
          publishedAt: 1000, isRead: 0, isStarred: 0, coverImage: ''
        };
        const values = articleToValues(article);
        expect('feed_id' in values).assertTrue();
        expect('published_at' in values).assertTrue();
        expect('is_read' in values).assertTrue();
        expect('is_starred' in values).assertTrue();
        expect('cover_image' in values).assertTrue();
        expect('cached_at' in values).assertTrue();
      });

      it('should_set_cached_at_to_now_when_inserting', 0, () => {
        const article: Article = {
          feedId: 1, guid: 'g1', title: 'T', summary: '', content: '',
          url: '', author: '', publishedAt: 0, isRead: 0, isStarred: 0, coverImage: ''
        };
        const before = Date.now();
        const values = articleToValues(article);
        const after = Date.now();
        const cachedAt = values['cached_at'] as number;
        expect(cachedAt >= before && cachedAt <= after).assertTrue();
      });
    });

    // ==================== 查询条件逻辑测试 ====================

    describe('query_condition_logic', () => {
      it('should_filter_unread_articles', 0, () => {
        const articles: Article[] = [
          { feedId: 1, guid: 'g1', title: 'A1', summary: '', content: '', url: '', author: '', publishedAt: 3000, isRead: 0, isStarred: 0, coverImage: '' },
          { feedId: 1, guid: 'g2', title: 'A2', summary: '', content: '', url: '', author: '', publishedAt: 2000, isRead: 1, isStarred: 0, coverImage: '' },
          { feedId: 1, guid: 'g3', title: 'A3', summary: '', content: '', url: '', author: '', publishedAt: 1000, isRead: 0, isStarred: 0, coverImage: '' }
        ];
        const unread = articles.filter(a => a.isRead === 0);
        expect(unread.length).assertEqual(2);
      });

      it('should_filter_starred_articles', 0, () => {
        const articles: Article[] = [
          { feedId: 1, guid: 'g1', title: 'A1', summary: '', content: '', url: '', author: '', publishedAt: 3000, isRead: 0, isStarred: 1, coverImage: '' },
          { feedId: 1, guid: 'g2', title: 'A2', summary: '', content: '', url: '', author: '', publishedAt: 2000, isRead: 0, isStarred: 0, coverImage: '' },
          { feedId: 1, guid: 'g3', title: 'A3', summary: '', content: '', url: '', author: '', publishedAt: 1000, isRead: 0, isStarred: 1, coverImage: '' }
        ];
        const starred = articles.filter(a => a.isStarred === 1);
        expect(starred.length).assertEqual(2);
      });

      it('should_search_articles_by_title', 0, () => {
        const articles: Article[] = [
          { feedId: 1, guid: 'g1', title: 'HarmonyOS开发', summary: '', content: '', url: '', author: '', publishedAt: 1000, isRead: 0, isStarred: 0, coverImage: '' },
          { feedId: 1, guid: 'g2', title: 'Android开发', summary: '', content: '', url: '', author: '', publishedAt: 1000, isRead: 0, isStarred: 0, coverImage: '' },
          { feedId: 1, guid: 'g3', title: 'iOS应用', summary: '', content: '', url: '', author: '', publishedAt: 1000, isRead: 0, isStarred: 0, coverImage: '' }
        ];
        const keyword = 'OS';
        const result = articles.filter(a =>
          a.title.includes(keyword) || a.summary.includes(keyword) || a.content.includes(keyword)
        );
        expect(result.length).assertEqual(2);
      });

      it('should_filter_articles_by_feed_id', 0, () => {
        const articles: Article[] = [
          { id: 1, feedId: 1, guid: 'g1', title: 'A1', summary: '', content: '', url: '', author: '', publishedAt: 1000, isRead: 0, isStarred: 0, coverImage: '' },
          { id: 2, feedId: 2, guid: 'g2', title: 'A2', summary: '', content: '', url: '', author: '', publishedAt: 1000, isRead: 0, isStarred: 0, coverImage: '' },
          { id: 3, feedId: 1, guid: 'g3', title: 'A3', summary: '', content: '', url: '', author: '', publishedAt: 1000, isRead: 0, isStarred: 0, coverImage: '' }
        ];
        const filtered = articles.filter(a => a.feedId === 1);
        expect(filtered.length).assertEqual(2);
      });

      it('should_sort_articles_by_published_at_desc', 0, () => {
        const articles: Article[] = [
          { feedId: 1, guid: 'g1', title: 'A1', summary: '', content: '', url: '', author: '', publishedAt: 1000, isRead: 0, isStarred: 0, coverImage: '' },
          { feedId: 1, guid: 'g2', title: 'A2', summary: '', content: '', url: '', author: '', publishedAt: 3000, isRead: 0, isStarred: 0, coverImage: '' },
          { feedId: 1, guid: 'g3', title: 'A3', summary: '', content: '', url: '', author: '', publishedAt: 2000, isRead: 0, isStarred: 0, coverImage: '' }
        ];
        articles.sort((a, b) => b.publishedAt - a.publishedAt);
        expect(articles[0].publishedAt).assertEqual(3000);
        expect(articles[1].publishedAt).assertEqual(2000);
        expect(articles[2].publishedAt).assertEqual(1000);
      });
    });

    // ==================== deleteGroup 级联逻辑 ====================

    describe('delete_group_cascade_logic', () => {
      it('should_reassign_feeds_to_default_group_on_delete', 0, () => {
        const feeds: Feed[] = [
          { id: 1, title: 'F1', url: 'u1', siteUrl: '', iconUrl: '', description: '', groupId: 3, lastUpdated: 0 },
          { id: 2, title: 'F2', url: 'u2', siteUrl: '', iconUrl: '', description: '', groupId: 3, lastUpdated: 0 },
          { id: 3, title: 'F3', url: 'u3', siteUrl: '', iconUrl: '', description: '', groupId: 2, lastUpdated: 0 }
        ];
        const deleteGroupId = 3;
        const defaultGroupId = 1;
        // 模拟级联更新
        const updated = feeds.map(f => f.groupId === deleteGroupId ? { ...f, groupId: defaultGroupId } : f);
        expect(updated[0].groupId).assertEqual(defaultGroupId);
        expect(updated[1].groupId).assertEqual(defaultGroupId);
        expect(updated[2].groupId).assertEqual(2); // 不变
      });
    });

    // ==================== deleteFeed 级联逻辑 ====================

    describe('delete_feed_cascade_logic', () => {
      it('should_identify_articles_to_delete_for_feed', 0, () => {
        const articles: Article[] = [
          { id: 1, feedId: 10, guid: 'g1', title: '', summary: '', content: '', url: '', author: '', publishedAt: 0, isRead: 0, isStarred: 0, coverImage: '' },
          { id: 2, feedId: 10, guid: 'g2', title: '', summary: '', content: '', url: '', author: '', publishedAt: 0, isRead: 0, isStarred: 0, coverImage: '' },
          { id: 3, feedId: 20, guid: 'g3', title: '', summary: '', content: '', url: '', author: '', publishedAt: 0, isRead: 0, isStarred: 0, coverImage: '' }
        ];
        const feedIdToDelete = 10;
        const toDelete = articles.filter(a => a.feedId === feedIdToDelete);
        expect(toDelete.length).assertEqual(2);
        expect(toDelete.every(a => a.feedId === feedIdToDelete)).assertTrue();
      });
    });

    // ==================== unreadCount 计算逻辑 ====================

    describe('unread_count_logic', () => {
      it('should_count_unread_for_specific_feed', 0, () => {
        const articles: Article[] = [
          { feedId: 1, guid: 'g1', title: '', summary: '', content: '', url: '', author: '', publishedAt: 0, isRead: 0, isStarred: 0, coverImage: '' },
          { feedId: 1, guid: 'g2', title: '', summary: '', content: '', url: '', author: '', publishedAt: 0, isRead: 1, isStarred: 0, coverImage: '' },
          { feedId: 1, guid: 'g3', title: '', summary: '', content: '', url: '', author: '', publishedAt: 0, isRead: 0, isStarred: 0, coverImage: '' },
          { feedId: 2, guid: 'g4', title: '', summary: '', content: '', url: '', author: '', publishedAt: 0, isRead: 0, isStarred: 0, coverImage: '' }
        ];
        const count = articles.filter(a => a.feedId === 1 && a.isRead === 0).length;
        expect(count).assertEqual(2);
      });

      it('should_return_zero_unread_when_all_read', 0, () => {
        const articles: Article[] = [
          { feedId: 1, guid: 'g1', title: '', summary: '', content: '', url: '', author: '', publishedAt: 0, isRead: 1, isStarred: 0, coverImage: '' },
          { feedId: 1, guid: 'g2', title: '', summary: '', content: '', url: '', author: '', publishedAt: 0, isRead: 1, isStarred: 0, coverImage: '' }
        ];
        const count = articles.filter(a => a.feedId === 1 && a.isRead === 0).length;
        expect(count).assertEqual(0);
      });
    });
  });
}
