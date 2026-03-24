// 应用全局常量

export class Constants {
  // ===== 主题颜色 =====
  // 主色调（用于高亮、强调）
  static readonly COLOR_PRIMARY: string = '#FF6D00';           // 橙色主色
  static readonly COLOR_PRIMARY_LIGHT: string = '#FF9E40';     // 橙色浅色
  static readonly COLOR_PRIMARY_DARK: string = '#C43E00';      // 橙色深色

  // 语义颜色
  static readonly COLOR_SUCCESS: string = '#4CAF50';           // 成功/完成
  static readonly COLOR_WARNING: string = '#FFA726';           // 警告
  static readonly COLOR_ERROR: string = '#F44336';             // 错误
  static readonly COLOR_INFO: string = '#2196F3';              // 信息

  // 推荐/评分相关
  static readonly COLOR_RECOMMEND_HIGH: string = '#4CAF50';    // 高推荐度
  static readonly COLOR_RECOMMEND_MEDIUM: string = '#FF9800';  // 中推荐度
  static readonly COLOR_RECOMMEND_LOW: string = '#9E9E9E';     // 低推荐度

  // 反馈颜色
  static readonly COLOR_LIKE: string = '#4CAF50';              // 点赞/喜欢
  static readonly COLOR_DISLIKE: string = '#F44336';           // 踩/不喜欢

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
  // 注：HarmonyOS WorkScheduler 要求 repeatCycleTime >= 20 分钟
  static readonly REFRESH_INTERVALS: number[] = [0, 20, 30, 60, 120];
  static readonly REFRESH_INTERVAL_LABELS: string[] = ['关闭', '20分钟', '30分钟', '1小时', '2小时'];

  // 每源缓存数量选项
  static readonly CACHE_COUNT_OPTIONS: number[] = [20, 50, 100];

  // ===== 记忆系统 =====

  // 记忆目录结构（相对于 context.filesDir）
  static readonly MEMORY_DIR: string = 'memory';
  static readonly MEMORY_DAILY_DIR: string = 'memory/daily';
  static readonly MEMORY_SOUL_FILE: string = 'memory/SOUL.md';
  static readonly MEMORY_PROFILE_FILE: string = 'memory/PROFILE.md';

  // 记忆系统 Preferences 键名
  static readonly PREF_AI_API_KEY: string = 'ai_api_key';
  static readonly PREF_DAILY_BRIEFING_ENABLED: string = 'daily_briefing_enabled';
  static readonly PREF_AI_SORT_ENABLED: string = 'ai_sort_enabled';
  static readonly PREF_LAST_MAINTENANCE_DATE: string = 'last_maintenance_date';

  // AI 提供商配置键名
  static readonly PREF_AI_PROVIDER: string = 'ai_provider';
  static readonly PREF_AI_BASE_URL: string = 'ai_base_url';
  static readonly PREF_AI_MODEL_NAME: string = 'ai_model_name';

  // AI 提供商列表
  static readonly AI_PROVIDER_LABELS: string[] = ['通义千问', 'OpenAI', 'DeepSeek', 'Groq', '自定义'];
  static readonly AI_PROVIDER_KEYS: string[] = ['qwen', 'openai', 'deepseek', 'groq', 'custom'];
  // 各提供商的 Base URL（统一为 OpenAI 兼容协议 Base URL，最终追加 /chat/completions）
  static readonly AI_PROVIDER_URLS: string[] = [
    'https://dashscope.aliyuncs.com/compatible-mode/v1',
    'https://api.openai.com',
    'https://api.deepseek.com',
    'https://api.groq.com/openai',
    ''
  ];
  static readonly AI_PROVIDER_DEFAULT_MODELS: string[] = [
    'qwen-plus', 'gpt-4o-mini', 'deepseek-chat', 'llama3-8b-8192', ''
  ];

  // 记忆系统参数
  static readonly MEMORY_KEEP_DAYS: number = 30;           // 日志保留天数
  static readonly BEHAVIOR_FLUSH_DELAY: number = 500;      // 防抖延迟（ms）
  static readonly AI_SORT_CACHE_TTL: number = 3600000;     // AI 排序缓存有效期（1小时，ms）
  static readonly EMA_ALPHA: number = 0.3;                 // EMA 衰减系数

  // 通义千问 API
  static readonly QWEN_API_URL: string = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  static readonly QWEN_MODEL: string = 'qwen-plus';

  // ===== 推荐排序 =====

  // 排序模式 Preferences 键名
  static readonly PREF_SORT_MODE: string = 'sort_mode';

  // 排序模式值
  static readonly SORT_MODE_LATEST: string = 'latest';
  static readonly SORT_MODE_RECOMMEND: string = 'recommend';

  // 推荐评分权重
  static readonly W_FEED: number = 0.45;         // 订阅源匹配权重
  static readonly W_FRESHNESS: number = 0.25;    // 时效性权重
  static readonly W_TOPIC: number = 0.15;        // 话题匹配权重

  // 推荐参数
  static readonly RECOMMEND_CACHE_TTL: number = 1800000;   // 画像缓存过期时间（30分钟，ms）
  static readonly RECOMMEND_RECENT_DAYS: number = 7;       // 推荐取文天数
  static readonly RECOMMEND_MAX_ARTICLES: number = 200;    // 推荐最大取文数
  static readonly RECOMMEND_PAGE_SIZE: number = 30;        // 推荐每页条数

  // 来源多样性惩罚系数
  static readonly DIVERSITY_PENALTY_2ND: number = 0.8;     // 连续同源第 2 篇
  static readonly DIVERSITY_PENALTY_3RD: number = 0.6;     // 连续同源第 3 篇及之后

  // AI 画像综合
  static readonly AI_PROFILE_MAX_TOKENS: number = 800;
  static readonly AI_PROFILE_SYSTEM_PROMPT: string =
    '你是一个阅读行为分析专家，负责根据用户的阅读数据生成画像洞察。' +
    '你的输出必须是严格的 JSON 格式，不要包含任何其他文字。';
}
