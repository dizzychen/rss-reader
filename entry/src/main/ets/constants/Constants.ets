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
  static readonly MEMORY_LESSONS_FILE: string = 'memory/LESSONS.md';

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

  // 推荐评分权重（内容驱动：摘要为主，标题为辅）
  static readonly W_CONTENT: number = 0.45;      // 摘要内容关键词匹配权重（主导）
  static readonly W_TOPIC: number = 0.30;        // 话题/标题匹配权重（辅助）
  static readonly W_FRESHNESS: number = 0.20;    // 时效性权重
  static readonly W_FEED: number = 0.05;         // 订阅源匹配权重（微调）

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

  // ===== 简报系统 =====

  // 简报缓存文件前缀（存于 memory/ 目录下，格式 briefing_YYYY-MM-DD.json）
  static readonly BRIEFING_CACHE_PREFIX: string = 'memory/briefing_';

  // 简报偏好
  static readonly PREF_BRIEFING_COUNT: string = 'briefing_count';
  static readonly DEFAULT_BRIEFING_COUNT: number = 5;
  static readonly BRIEFING_COUNT_OPTIONS: number[] = [3, 5, 8];
  static readonly BRIEFING_COUNT_LABELS: string[] = ['3 篇', '5 篇', '8 篇'];

  // 自动生成简报
  static readonly PREF_AUTO_BRIEFING: string = 'auto_briefing_enabled';
  static readonly DEFAULT_AUTO_BRIEFING: boolean = true;

  // 简报 AI 参数
  static readonly BRIEFING_MAX_TOKENS: number = 1800;

  // 日内画像刷新
  static readonly QUICK_REFRESH_THRESHOLD: number = 5;  // 阅读篇数达到此阈值触发日内刷新

  // 本地话题提取停用词
  static readonly STOP_WORDS: string[] = [
    // 中文停用词
    '的', '了', '在', '是', '我', '有', '和', '就', '不', '人', '都', '一', '一个',
    '上', '也', '很', '到', '说', '要', '去', '你', '会', '着', '没有', '看', '好',
    '自己', '这', '他', '她', '它', '们', '那', '些', '什么', '之', '与', '为',
    '中', '大', '年', '对', '以', '及', '等', '可以', '被', '从', '而', '但',
    '如何', '使用', '通过', '进行', '关于', '更多', '什么',
    // 英文停用词
    'a', 'an', 'the', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'can', 'shall', 'to', 'of', 'in', 'for',
    'on', 'with', 'at', 'by', 'from', 'as', 'into', 'through', 'during',
    'before', 'after', 'above', 'below', 'between', 'and', 'but', 'or',
    'not', 'no', 'so', 'if', 'then', 'than', 'too', 'very', 'just',
    'about', 'up', 'out', 'how', 'what', 'which', 'who', 'when', 'where',
    'why', 'all', 'each', 'every', 'both', 'few', 'more', 'most', 'other',
    'some', 'such', 'only', 'own', 'same', 'that', 'this', 'these', 'those',
    'it', 'its', 'i', 'me', 'my', 'we', 'our', 'you', 'your', 'he', 'him',
    'his', 'she', 'her', 'they', 'them', 'their', 'new', 'one', 'two'
  ];

  // 离散时间衰减分档（OpenClaw V2 对齐）
  static readonly DECAY_BRACKETS: Array<[number, number]> = [
    [1, 1.0],    // 0-1 天：不衰减
    [3, 0.9],    // 1-3 天
    [7, 0.7],    // 3-7 天
    [14, 0.4],   // 7-14 天
    [Infinity, 0.1]  // 14 天以上
  ];
  static readonly DECAY_CAP_7D: number = 0.3;    // 7 天以上权重上限
  static readonly DECAY_CAP_14D: number = 0.05;  // 14 天以上强制归档权重
}
