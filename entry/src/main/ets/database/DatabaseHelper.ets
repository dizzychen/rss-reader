import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Constants } from '../constants/Constants';
import { Feed, Article, FeedGroup, Tag } from '../model/Models';

const TAG = 'DatabaseHelper';

const DB_CONFIG: relationalStore.StoreConfig = {
  name: Constants.DB_NAME,
  securityLevel: relationalStore.SecurityLevel.S1
};

// DDL
const SQL_CREATE_GROUPS = `
  CREATE TABLE IF NOT EXISTS ${Constants.TABLE_GROUPS} (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    sort_order INTEGER DEFAULT 0
  )`;

const SQL_CREATE_FEEDS = `
  CREATE TABLE IF NOT EXISTS ${Constants.TABLE_FEEDS} (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    url TEXT NOT NULL UNIQUE,
    site_url TEXT DEFAULT '',
    icon_url TEXT DEFAULT '',
    description TEXT DEFAULT '',
    group_id INTEGER DEFAULT 0,
    last_updated INTEGER DEFAULT 0
  )`;

const SQL_CREATE_ARTICLES = `
  CREATE TABLE IF NOT EXISTS ${Constants.TABLE_ARTICLES} (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    feed_id INTEGER NOT NULL,
    guid TEXT NOT NULL,
    title TEXT DEFAULT '',
    summary TEXT DEFAULT '',
    content TEXT DEFAULT '',
    url TEXT DEFAULT '',
    author TEXT DEFAULT '',
    published_at INTEGER DEFAULT 0,
    is_read INTEGER DEFAULT 0,
    is_starred INTEGER DEFAULT 0,
    cover_image TEXT DEFAULT '',
    cached_at INTEGER DEFAULT 0,
    UNIQUE(feed_id, guid)
  )`;

const SQL_CREATE_TAGS = `
  CREATE TABLE IF NOT EXISTS ${Constants.TABLE_TAGS} (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
  )`;

const SQL_CREATE_ARTICLE_TAGS = `
  CREATE TABLE IF NOT EXISTS ${Constants.TABLE_ARTICLE_TAGS} (
    article_id INTEGER NOT NULL,
    tag_id INTEGER NOT NULL,
    PRIMARY KEY(article_id, tag_id)
  )`;

export class DatabaseHelper {
  private static instance: DatabaseHelper;
  private rdbStore: relationalStore.RdbStore | null = null;
  // 用 initPromise 防止并发调用 init()，保证数据库只初始化一次
  private initPromise: Promise<void> | null = null;

  static getInstance(): DatabaseHelper {
    if (!DatabaseHelper.instance) {
      DatabaseHelper.instance = new DatabaseHelper();
    }
    return DatabaseHelper.instance;
  }

  init(context: common.Context): Promise<void> {
    // 已经在初始化中或已完成：直接返回同一个 Promise，避免并发
    if (this.initPromise) {
      return this.initPromise;
    }
    this.initPromise = this.doInit(context);
    return this.initPromise;
  }

  private async doInit(context: common.Context): Promise<void> {
    if (this.rdbStore) return;
    try {
      this.rdbStore = await relationalStore.getRdbStore(context, DB_CONFIG);
      await this.rdbStore.executeSql(SQL_CREATE_GROUPS);
      await this.rdbStore.executeSql(SQL_CREATE_FEEDS);
      await this.rdbStore.executeSql(SQL_CREATE_ARTICLES);
      await this.rdbStore.executeSql(SQL_CREATE_TAGS);
      await this.rdbStore.executeSql(SQL_CREATE_ARTICLE_TAGS);
    } catch (e) {
      // Previewer 环境下 RDB 不可用，静默忽略（rdbStore 保持 null）
      const msg = e instanceof Error ? e.message : String(e);
      console.warn(TAG, `DB init skipped (Previewer?): ${msg}`);
      return;
    }
    // 只有成功打开 RDB 后才建默认分组
    await this.ensureDefaultGroup();
  }

  private async ensureDefaultGroup(): Promise<void> {
    if (!this.rdbStore) return;
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_GROUPS);
    predicates.equalTo('id', 1);
    const result = await this.rdbStore.query(predicates, ['id']);
    if (result.rowCount === 0) {
      await this.rdbStore.insert(Constants.TABLE_GROUPS, { name: '默认', sort_order: 0 });
    }
    result.close();
  }

  getStore(): relationalStore.RdbStore | null {
    return this.rdbStore;
  }

  // ==================== FeedGroup CRUD ====================

  async insertGroup(group: FeedGroup): Promise<number> {
    if (!this.rdbStore) return -1;
    const values: relationalStore.ValuesBucket = {
      name: group.name,
      sort_order: group.sortOrder
    };
    return await this.rdbStore.insert(Constants.TABLE_GROUPS, values);
  }

  async getAllGroups(): Promise<FeedGroup[]> {
    if (!this.rdbStore) return [];
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_GROUPS);
    predicates.orderByAsc('sort_order');
    const result = await this.rdbStore.query(predicates, ['id', 'name', 'sort_order']);
    const groups: FeedGroup[] = [];
    while (result.goToNextRow()) {
      groups.push({
        id: result.getLong(result.getColumnIndex('id')),
        name: result.getString(result.getColumnIndex('name')),
        sortOrder: result.getLong(result.getColumnIndex('sort_order'))
      });
    }
    result.close();
    return groups;
  }

  async updateGroup(group: FeedGroup): Promise<number> {
    if (!this.rdbStore) return 0;
    const values: relationalStore.ValuesBucket = { name: group.name, sort_order: group.sortOrder };
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_GROUPS);
    predicates.equalTo('id', group.id!);
    return await this.rdbStore.update(values, predicates);
  }

  async deleteGroup(id: number): Promise<number> {
    if (!this.rdbStore) return 0;
    // 将该分组下的订阅源移到默认分组
    const feedPred = new relationalStore.RdbPredicates(Constants.TABLE_FEEDS);
    feedPred.equalTo('group_id', id);
    await this.rdbStore.update({ group_id: 1 }, feedPred);
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_GROUPS);
    predicates.equalTo('id', id);
    return await this.rdbStore.delete(predicates);
  }

  // ==================== Feed CRUD ====================

  async insertFeed(feed: Feed): Promise<number> {
    if (!this.rdbStore) return -1;
    const values: relationalStore.ValuesBucket = {
      title: feed.title,
      url: feed.url,
      site_url: feed.siteUrl,
      icon_url: feed.iconUrl,
      description: feed.description,
      group_id: feed.groupId,
      last_updated: feed.lastUpdated
    };
    return await this.rdbStore.insert(Constants.TABLE_FEEDS, values,
      relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
  }

  async getFeedByUrl(url: string): Promise<Feed | null> {
    if (!this.rdbStore) return null;
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_FEEDS);
    predicates.equalTo('url', url);
    const result = await this.rdbStore.query(predicates,
      ['id', 'title', 'url', 'site_url', 'icon_url', 'description', 'group_id', 'last_updated']);
    let feed: Feed | null = null;
    if (result.goToNextRow()) {
      feed = this.rowToFeed(result);
    }
    result.close();
    return feed;
  }

  async getAllFeeds(): Promise<Feed[]> {
    if (!this.rdbStore) return [];
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_FEEDS);
    const result = await this.rdbStore.query(predicates,
      ['id', 'title', 'url', 'site_url', 'icon_url', 'description', 'group_id', 'last_updated']);
    const feeds: Feed[] = [];
    while (result.goToNextRow()) {
      feeds.push(this.rowToFeed(result));
    }
    result.close();
    return feeds;
  }

  async getFeedById(id: number): Promise<Feed | null> {
    if (!this.rdbStore) return null;
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_FEEDS);
    predicates.equalTo('id', id);
    const result = await this.rdbStore.query(predicates,
      ['id', 'title', 'url', 'site_url', 'icon_url', 'description', 'group_id', 'last_updated']);
    let feed: Feed | null = null;
    if (result.goToNextRow()) {
      feed = this.rowToFeed(result);
    }
    result.close();
    return feed;
  }

  async updateFeed(feed: Feed): Promise<number> {
    if (!this.rdbStore) return 0;
    const values: relationalStore.ValuesBucket = {
      title: feed.title,
      site_url: feed.siteUrl,
      icon_url: feed.iconUrl,
      description: feed.description,
      group_id: feed.groupId,
      last_updated: feed.lastUpdated
    };
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_FEEDS);
    predicates.equalTo('id', feed.id!);
    return await this.rdbStore.update(values, predicates);
  }

  async deleteFeed(id: number): Promise<void> {
    if (!this.rdbStore) return;
    // 删除文章及关联标签
    const articles = await this.getArticlesByFeedId(id);
    for (const a of articles) {
      if (a.id) await this.deleteArticleTags(a.id);
    }
    const artPred = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLES);
    artPred.equalTo('feed_id', id);
    await this.rdbStore.delete(artPred);

    const pred = new relationalStore.RdbPredicates(Constants.TABLE_FEEDS);
    pred.equalTo('id', id);
    await this.rdbStore.delete(pred);
  }

  async getUnreadCountByFeed(feedId: number): Promise<number> {
    if (!this.rdbStore) return 0;
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLES);
    predicates.equalTo('feed_id', feedId).and().equalTo('is_read', 0);
    const result = await this.rdbStore.query(predicates, ['id']);
    const count = result.rowCount;
    result.close();
    return count;
  }

  private rowToFeed(result: relationalStore.ResultSet): Feed {
    return {
      id: result.getLong(result.getColumnIndex('id')),
      title: result.getString(result.getColumnIndex('title')),
      url: result.getString(result.getColumnIndex('url')),
      siteUrl: result.getString(result.getColumnIndex('site_url')),
      iconUrl: result.getString(result.getColumnIndex('icon_url')),
      description: result.getString(result.getColumnIndex('description')),
      groupId: result.getLong(result.getColumnIndex('group_id')),
      lastUpdated: result.getLong(result.getColumnIndex('last_updated'))
    };
  }

  // ==================== Article CRUD ====================

  async insertOrUpdateArticle(article: Article): Promise<number> {
    if (!this.rdbStore) return -1;
    const values: relationalStore.ValuesBucket = {
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
    return await this.rdbStore.insert(Constants.TABLE_ARTICLES, values,
      relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
  }

  async getArticlesByFeedId(feedId: number, limit: number = 50, offset: number = 0): Promise<Article[]> {
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLES);
    predicates.equalTo('feed_id', feedId).orderByDesc('published_at').limitAs(limit).offsetAs(offset);
    return await this.queryArticles(predicates);
  }

  async getAllArticles(onlyUnread: boolean = false, limit: number = 50, offset: number = 0): Promise<Article[]> {
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLES);
    if (onlyUnread) predicates.equalTo('is_read', 0);
    predicates.orderByDesc('published_at').limitAs(limit).offsetAs(offset);
    return await this.queryArticles(predicates);
  }

  async getStarredArticles(limit: number = 50, offset: number = 0): Promise<Article[]> {
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLES);
    predicates.equalTo('is_starred', 1).orderByDesc('published_at').limitAs(limit).offsetAs(offset);
    return await this.queryArticles(predicates);
  }

  async searchArticles(keyword: string, feedId: number = -1): Promise<Article[]> {
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLES);
    predicates.beginWrap()
      .contains('title', keyword)
      .or()
      .contains('summary', keyword)
      .or()
      .contains('content', keyword)
      .endWrap();
    if (feedId > 0) predicates.and().equalTo('feed_id', feedId);
    predicates.orderByDesc('published_at').limitAs(100);
    return await this.queryArticles(predicates);
  }

  async getArticleById(id: number): Promise<Article | null> {
    const predicates = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLES);
    predicates.equalTo('id', id);
    const articles = await this.queryArticles(predicates);
    return articles.length > 0 ? articles[0] : null;
  }

  async markRead(articleId: number, isRead: number): Promise<void> {
    if (!this.rdbStore) return;
    const pred = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLES);
    pred.equalTo('id', articleId);
    await this.rdbStore.update({ is_read: isRead }, pred);
  }

  async markAllReadByFeed(feedId: number): Promise<void> {
    if (!this.rdbStore) return;
    const pred = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLES);
    pred.equalTo('feed_id', feedId);
    await this.rdbStore.update({ is_read: 1 }, pred);
  }

  async markAllRead(): Promise<void> {
    if (!this.rdbStore) return;
    const pred = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLES);
    await this.rdbStore.update({ is_read: 1 }, pred);
  }

  async toggleStar(articleId: number, isStarred: number): Promise<void> {
    if (!this.rdbStore) return;
    const pred = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLES);
    pred.equalTo('id', articleId);
    await this.rdbStore.update({ is_starred: isStarred }, pred);
  }

  async cleanOldCache(feedId: number, keepCount: number): Promise<void> {
    if (!this.rdbStore) return;
    // 保留最新 keepCount 篇（收藏的不删）
    const allPred = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLES);
    allPred.equalTo('feed_id', feedId).equalTo('is_starred', 0).orderByDesc('published_at');
    const result = await this.rdbStore.query(allPred, ['id']);
    const ids: number[] = [];
    while (result.goToNextRow()) {
      ids.push(result.getLong(result.getColumnIndex('id')));
    }
    result.close();
    if (ids.length > keepCount) {
      const toDelete = ids.slice(keepCount);
      for (const id of toDelete) {
        await this.deleteArticleTags(id);
        const p = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLES);
        p.equalTo('id', id);
        await this.rdbStore.delete(p);
      }
    }
  }

  private async queryArticles(predicates: relationalStore.RdbPredicates): Promise<Article[]> {
    if (!this.rdbStore) return [];
    const columns = ['id', 'feed_id', 'guid', 'title', 'summary', 'content', 'url',
      'author', 'published_at', 'is_read', 'is_starred', 'cover_image', 'cached_at'];
    const result = await this.rdbStore.query(predicates, columns);
    const articles: Article[] = [];
    try {
      while (result.goToNextRow()) {
        articles.push({
          id: result.getLong(result.getColumnIndex('id')),
          feedId: result.getLong(result.getColumnIndex('feed_id')),
          guid: result.getString(result.getColumnIndex('guid')),
          title: result.getString(result.getColumnIndex('title')),
          summary: result.getString(result.getColumnIndex('summary')),
          content: result.getString(result.getColumnIndex('content')),
          url: result.getString(result.getColumnIndex('url')),
          author: result.getString(result.getColumnIndex('author')),
          publishedAt: result.getLong(result.getColumnIndex('published_at')),
          isRead: result.getLong(result.getColumnIndex('is_read')),
          isStarred: result.getLong(result.getColumnIndex('is_starred')),
          coverImage: result.getString(result.getColumnIndex('cover_image')),
          cachedAt: result.getLong(result.getColumnIndex('cached_at'))
        });
      }
    } finally {
      result.close();
    }
    return articles;
  }

  // ==================== Tag CRUD ====================

  async insertTag(name: string): Promise<number> {
    if (!this.rdbStore) return -1;
    return await this.rdbStore.insert(Constants.TABLE_TAGS, { name });
  }

  async getAllTags(): Promise<Tag[]> {
    if (!this.rdbStore) return [];
    const pred = new relationalStore.RdbPredicates(Constants.TABLE_TAGS);
    const result = await this.rdbStore.query(pred, ['id', 'name']);
    const tags: Tag[] = [];
    while (result.goToNextRow()) {
      tags.push({
        id: result.getLong(result.getColumnIndex('id')),
        name: result.getString(result.getColumnIndex('name'))
      });
    }
    result.close();
    return tags;
  }

  async deleteTag(id: number): Promise<void> {
    if (!this.rdbStore) return;
    const atPred = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLE_TAGS);
    atPred.equalTo('tag_id', id);
    await this.rdbStore.delete(atPred);
    const pred = new relationalStore.RdbPredicates(Constants.TABLE_TAGS);
    pred.equalTo('id', id);
    await this.rdbStore.delete(pred);
  }

  async addTagToArticle(articleId: number, tagId: number): Promise<void> {
    if (!this.rdbStore) return;
    await this.rdbStore.insert(Constants.TABLE_ARTICLE_TAGS,
      { article_id: articleId, tag_id: tagId },
      relationalStore.ConflictResolution.ON_CONFLICT_IGNORE);
  }

  async removeTagFromArticle(articleId: number, tagId: number): Promise<void> {
    if (!this.rdbStore) return;
    const pred = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLE_TAGS);
    pred.equalTo('article_id', articleId).and().equalTo('tag_id', tagId);
    await this.rdbStore.delete(pred);
  }

  async getTagsForArticle(articleId: number): Promise<Tag[]> {
    if (!this.rdbStore) return [];
    const sql = `SELECT t.id, t.name FROM ${Constants.TABLE_TAGS} t
      INNER JOIN ${Constants.TABLE_ARTICLE_TAGS} at ON t.id = at.tag_id
      WHERE at.article_id = ?`;
    const result = await this.rdbStore.querySql(sql, [articleId]);
    const tags: Tag[] = [];
    while (result.goToNextRow()) {
      tags.push({
        id: result.getLong(result.getColumnIndex('id')),
        name: result.getString(result.getColumnIndex('name'))
      });
    }
    result.close();
    return tags;
  }

  private async deleteArticleTags(articleId: number): Promise<void> {
    if (!this.rdbStore) return;
    const pred = new relationalStore.RdbPredicates(Constants.TABLE_ARTICLE_TAGS);
    pred.equalTo('article_id', articleId);
    await this.rdbStore.delete(pred);
  }
}
