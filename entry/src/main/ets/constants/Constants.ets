// 应用全局常量

export class Constants {
  // 数据库
  static readonly DB_NAME: string = 'rss_reader.db';
  static readonly DB_VERSION: number = 1;

  // 表名
  static readonly TABLE_FEEDS: string = 'feeds';
  static readonly TABLE_ARTICLES: string = 'articles';
  static readonly TABLE_GROUPS: string = 'groups';
  static readonly TABLE_TAGS: string = 'tags';
  static readonly TABLE_ARTICLE_TAGS: string = 'article_tags';

  // Preferences
  static readonly PREF_NAME: string = 'rss_settings';
  static readonly PREF_REFRESH_INTERVAL: string = 'refresh_interval';
  static readonly PREF_BG_REFRESH: string = 'bg_refresh_enabled';
  static readonly PREF_NOTIFICATION: string = 'notification_enabled';
  static readonly PREF_FONT_SIZE: string = 'font_size';
  static readonly PREF_OPEN_ORIGINAL: string = 'open_original_in_app';
  static readonly PREF_CACHE_COUNT: string = 'cache_count_per_feed';

  // 默认值
  static readonly DEFAULT_REFRESH_INTERVAL: number = 30; // 分钟
  static readonly DEFAULT_CACHE_COUNT: number = 50;
  static readonly DEFAULT_FONT_SIZE: number = 16;

  // 字体大小档位
  static readonly FONT_SIZES: number[] = [13, 16, 19, 22];
  static readonly FONT_SIZE_LABELS: string[] = ['小', '中', '大', '超大'];

  // 刷新间隔选项（分钟），0 表示不自动刷新
  static readonly REFRESH_INTERVALS: number[] = [0, 15, 30, 60, 120];
  static readonly REFRESH_INTERVAL_LABELS: string[] = ['关闭', '15分钟', '30分钟', '1小时', '2小时'];

  // 每源缓存数量选项
  static readonly CACHE_COUNT_OPTIONS: number[] = [20, 50, 100];
}
