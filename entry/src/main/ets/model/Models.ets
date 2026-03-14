// 数据模型定义

export interface FeedGroup {
  id?: number;
  name: string;
  sortOrder: number;
}

export interface Feed {
  id?: number;
  title: string;
  url: string;
  siteUrl: string;
  iconUrl: string;
  description: string;
  groupId: number;
  lastUpdated: number;
  unreadCount?: number;
}

export interface Article {
  id?: number;
  feedId: number;
  feedTitle?: string;
  guid: string;
  title: string;
  summary: string;
  content: string;
  url: string;
  author: string;
  publishedAt: number;
  isRead: number;    // 0=未读, 1=已读
  isStarred: number; // 0=普通, 1=收藏
  coverImage: string;
  cachedAt?: number;
}

export interface Tag {
  id?: number;
  name: string;
}

export interface ArticleTag {
  articleId: number;
  tagId: number;
}

// 设置数据结构
export interface AppSettings {
  refreshInterval: number;
  bgRefreshEnabled: boolean;
  notificationEnabled: boolean;
  fontSize: number;
  openOriginalInApp: boolean;
  cacheCountPerFeed: number;
}
