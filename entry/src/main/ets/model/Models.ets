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
  recommendScore?: number;   // 推荐评分（0~1）
  recommendReason?: string;  // 推荐理由标签文本
  aiSummary?: string;        // AI 总结缓存
}

export interface Tag {
  id?: number;
  name: string;
}

export interface ArticleTag {
  articleId: number;
  tagId: number;
}

// OPML 导入结果
export interface ImportResult {
  success: number;   // 成功导入数量
  failed: number;    // 失败数量
  skipped: number;   // 跳过数量（网络故障但已存在的 Feed）
  errors: string[];  // 错误详情列表
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

// ===== 记忆系统数据模型 =====

/** 用户行为动作枚举 */
export type BehaviorAction = 'READ' | 'READ_END' | 'STAR' | 'UNSTAR' | 'SKIP' | 'SEARCH' | 'RATE' | 'AI_REC_HIT';

/** 单条用户行为记录 */
export interface UserBehavior {
  timestamp: number;        // 行为发生时间（ms）
  action: BehaviorAction;   // 行为类型
  articleId?: number;       // 相关文章 ID
  articleTitle?: string;    // 文章标题
  feedTitle?: string;       // 来源订阅名
  tags?: string[];          // 文章标签
  duration?: number;        // 阅读时长（秒，READ_END 时使用）
  keyword?: string;         // 搜索关键词（SEARCH 时使用）
  score?: number;           // 用户评分（RATE: 1=正面, -1=负面）
}

/** 某天的聚合统计数据 */
export interface DailyStats {
  date: string;             // YYYY-MM-DD
  readCount: number;        // 阅读文章数
  starCount: number;        // 收藏文章数
  searchCount: number;      // 搜索次数
  skipCount: number;        // 跳过文章数
  avgReadDuration: number;  // 平均阅读时长（秒）
  topFeeds: string[];       // 阅读最多的订阅源（最多3个）
  starFeeds: string[];      // 收藏文章的订阅源（用于计算兴趣权重）
  topKeywords: string[];    // 搜索关键词（最多5个）
  readTitles: string[];     // 已读文章标题（供 AI 话题提取）
  likedTitles: string[];    // 用户标记正面的文章标题
  dislikedTitles: string[]; // 用户标记负面的文章标题
  feedDurations: Map<string, number[]>; // 每个订阅源的阅读时长列表（秒）
  feedDislikeCounts: Map<string, number>; // 每个订阅源被标记"不感兴趣"的次数
  readTimestamps: string[]; // READ 行为时间戳（HH:MM 格式，用于时段分析）
}

/** 兴趣权重条目 */
export interface InterestWeight {
  key: string;              // 兴趣标签/来源名
  weight: number;           // 权重 [0, 1]
  updatedAt: string;        // 最后更新日期 YYYY-MM-DD
}

/** 用户画像 */
export interface UserProfile {
  generatedAt: string;          // 生成时间 YYYY-MM-DD
  totalReadDays: number;        // 累计阅读天数
  totalArticles: number;        // 累计阅读文章数
  avgDailyRead: number;         // 日均阅读文章数
  feedInterests: InterestWeight[];   // 订阅源兴趣权重
  topicInterests: InterestWeight[];  // 话题/标签兴趣权重
  preferredReadTime: string;    // 偏好阅读时段（如 "早晨 07-09"）
  avgReadDuration: number;      // 平均阅读时长（秒）
  aiInsight: string;            // AI 生成的自然语言理解
  readingStyle: string;         // 阅读风格标签
  dislikePatterns: string;      // 不感兴趣的内容模式
  searchKeywords: string[];     // 高频搜索关键词
}
