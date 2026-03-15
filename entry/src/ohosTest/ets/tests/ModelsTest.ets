import { describe, it, expect } from '@ohos/hypium';
import { Feed, Article, FeedGroup, Tag, ArticleTag, AppSettings } from '../../../main/ets/model/Models';

export default function ModelsTest() {
  describe('ModelsTest', () => {

    // ==================== FeedGroup 模型测试 ====================

    describe('FeedGroup', () => {
      it('should_create_feed_group_with_required_fields', 0, () => {
        const group: FeedGroup = { name: '科技', sortOrder: 0 };
        expect(group.name).assertEqual('科技');
        expect(group.sortOrder).assertEqual(0);
        expect(group.id).assertUndefined();
      });

      it('should_create_feed_group_with_id', 0, () => {
        const group: FeedGroup = { id: 1, name: '默认', sortOrder: 0 };
        expect(group.id).assertEqual(1);
      });

      it('should_support_sort_order', 0, () => {
        const group1: FeedGroup = { name: '分组A', sortOrder: 1 };
        const group2: FeedGroup = { name: '分组B', sortOrder: 2 };
        expect(group1.sortOrder < group2.sortOrder).assertTrue();
      });
    });

    // ==================== Feed 模型测试 ====================

    describe('Feed', () => {
      it('should_create_feed_with_all_fields', 0, () => {
        const feed: Feed = {
          id: 1,
          title: '测试RSS',
          url: 'https://example.com/feed.xml',
          siteUrl: 'https://example.com',
          iconUrl: 'https://example.com/favicon.ico',
          description: '测试订阅源',
          groupId: 1,
          lastUpdated: 1704067200000
        };
        expect(feed.title).assertEqual('测试RSS');
        expect(feed.url).assertEqual('https://example.com/feed.xml');
        expect(feed.groupId).assertEqual(1);
        expect(feed.lastUpdated).assertEqual(1704067200000);
      });

      it('should_have_optional_unread_count', 0, () => {
        const feed: Feed = {
          title: 'Test', url: 'https://test.com/feed', siteUrl: '',
          iconUrl: '', description: '', groupId: 1, lastUpdated: 0
        };
        expect(feed.unreadCount).assertUndefined();

        feed.unreadCount = 5;
        expect(feed.unreadCount).assertEqual(5);
      });

      it('should_support_zero_unread_count', 0, () => {
        const feed: Feed = {
          title: 'Test', url: 'https://test.com/feed', siteUrl: '',
          iconUrl: '', description: '', groupId: 1, lastUpdated: 0,
          unreadCount: 0
        };
        expect(feed.unreadCount).assertEqual(0);
      });
    });

    // ==================== Article 模型测试 ====================

    describe('Article', () => {
      it('should_create_article_with_all_fields', 0, () => {
        const article: Article = {
          id: 1,
          feedId: 2,
          feedTitle: '测试源',
          guid: 'unique-guid-001',
          title: '文章标题',
          summary: '文章摘要',
          content: '<p>文章内容</p>',
          url: 'https://example.com/article1',
          author: '作者',
          publishedAt: 1704067200000,
          isRead: 0,
          isStarred: 0,
          coverImage: 'https://example.com/cover.jpg',
          cachedAt: 1704067200000
        };
        expect(article.guid).assertEqual('unique-guid-001');
        expect(article.isRead).assertEqual(0);
        expect(article.isStarred).assertEqual(0);
      });

      it('should_support_is_read_as_0_or_1', 0, () => {
        const unread: Article = {
          feedId: 1, guid: 'g1', title: '', summary: '', content: '',
          url: '', author: '', publishedAt: 0, isRead: 0, isStarred: 0, coverImage: ''
        };
        const read: Article = { ...unread, isRead: 1 };
        expect(unread.isRead).assertEqual(0);
        expect(read.isRead).assertEqual(1);
      });

      it('should_support_is_starred_as_0_or_1', 0, () => {
        const normal: Article = {
          feedId: 1, guid: 'g1', title: '', summary: '', content: '',
          url: '', author: '', publishedAt: 0, isRead: 0, isStarred: 0, coverImage: ''
        };
        const starred: Article = { ...normal, isStarred: 1 };
        expect(normal.isStarred).assertEqual(0);
        expect(starred.isStarred).assertEqual(1);
      });

      it('should_have_optional_feed_title', 0, () => {
        const article: Article = {
          feedId: 1, guid: 'g1', title: 'T', summary: '', content: '',
          url: '', author: '', publishedAt: 0, isRead: 0, isStarred: 0, coverImage: ''
        };
        expect(article.feedTitle).assertUndefined();
      });
    });

    // ==================== Tag 模型测试 ====================

    describe('Tag', () => {
      it('should_create_tag_with_name', 0, () => {
        const tag: Tag = { name: '科技' };
        expect(tag.name).assertEqual('科技');
        expect(tag.id).assertUndefined();
      });

      it('should_create_tag_with_id', 0, () => {
        const tag: Tag = { id: 1, name: '生活' };
        expect(tag.id).assertEqual(1);
        expect(tag.name).assertEqual('生活');
      });
    });

    // ==================== ArticleTag 模型测试 ====================

    describe('ArticleTag', () => {
      it('should_create_article_tag_relation', 0, () => {
        const at: ArticleTag = { articleId: 10, tagId: 3 };
        expect(at.articleId).assertEqual(10);
        expect(at.tagId).assertEqual(3);
      });
    });

    // ==================== AppSettings 模型测试 ====================

    describe('AppSettings', () => {
      it('should_create_settings_with_all_fields', 0, () => {
        const settings: AppSettings = {
          refreshInterval: 30,
          bgRefreshEnabled: true,
          notificationEnabled: true,
          fontSize: 16,
          openOriginalInApp: true,
          cacheCountPerFeed: 50
        };
        expect(settings.refreshInterval).assertEqual(30);
        expect(settings.bgRefreshEnabled).assertTrue();
        expect(settings.notificationEnabled).assertTrue();
        expect(settings.fontSize).assertEqual(16);
        expect(settings.openOriginalInApp).assertTrue();
        expect(settings.cacheCountPerFeed).assertEqual(50);
      });

      it('should_support_disabled_settings', 0, () => {
        const settings: AppSettings = {
          refreshInterval: 0,
          bgRefreshEnabled: false,
          notificationEnabled: false,
          fontSize: 13,
          openOriginalInApp: false,
          cacheCountPerFeed: 20
        };
        expect(settings.refreshInterval).assertEqual(0);
        expect(settings.bgRefreshEnabled).assertFalse();
        expect(settings.notificationEnabled).assertFalse();
      });
    });
  });
}
