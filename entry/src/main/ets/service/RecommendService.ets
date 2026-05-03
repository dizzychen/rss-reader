// 本地推荐评分引擎
import { Article } from '../model/Models';
import { MemoryService } from './MemoryService';
import { InterestCalculator } from '../utils/InterestCalculator';
import { Constants } from '../constants/Constants';

const TAG = 'RecommendService';

/** 画像缓存数据 */
interface ProfileCache {
  feedWeights: Map<string, number>;       // 订阅源名 -> EMA 权重
  topicKeywords: Map<string, number>;     // 话题关键词 -> 权重（来自 AI 话题偏好）
  searchKeywords: string[];               // 搜索关键词列表（降级用，来自行为统计）
  loadedAt: number;                       // 缓存时间戳
}

/** 推荐评分结果 */
export interface RecommendResult {
  articles: Article[];    // 排序后的文章列表（已含 recommendScore 和 recommendReason）
  totalCount: number;     // 评分结果总数（供分页使用）
}

interface RecommendWeights {
  content: number;
  topic: number;
  freshness: number;
  feed: number;
}

export class RecommendService {
  private static instance: RecommendService;
  private profileCache: ProfileCache | null = null;
  private scoredCache: Article[] = [];   // 最近一次完整评分结果（供分页使用）

  static getInstance(): RecommendService {
    if (!RecommendService.instance) {
      RecommendService.instance = new RecommendService();
    }
    return RecommendService.instance;
  }

  /**
   * 对文章列表进行推荐评分排序
   * @param articles 待评分文章列表（通常是最近 7 天内未读文章）
   * @param feedMap  feedId -> feedTitle 映射
   * @param page     页码（从 0 开始），用于从缓存评分结果中分页取数据
   * @param pageSize 每页条数
   * @returns 排序后的文章列表 + 总数
   */
  async scoreAndSort(
    articles: Article[],
    feedMap: Map<number, string>,
    page: number = 0,
    pageSize: number = Constants.RECOMMEND_PAGE_SIZE
  ): Promise<RecommendResult> {
    // 首页（page=0）重新评分，后续页从缓存取
    if (page > 0 && this.scoredCache.length > 0) {
      const start = page * pageSize;
      const sliced = this.scoredCache.slice(start, start + pageSize);
      return { articles: sliced, totalCount: this.scoredCache.length };
    }

    // 【修复】重新评分前先清空旧缓存，防止并发读到脏数据
    if (page === 0) {
      this.scoredCache = [];
    }

    // 加载画像数据（带缓存）
    await this.ensureProfileCache();

    // 冷启动检测：无画像数据时退化为时间+多样性排序
    if (this.isColdStart()) {
      console.info(TAG, '冷启动：无画像数据，退化为时间+多样性排序');
      const sorted = this.coldStartSort(articles, feedMap);
      this.scoredCache = sorted;
      const sliced = sorted.slice(0, pageSize);
      return { articles: sliced, totalCount: sorted.length };
    }

    // 四维度加权评分（内容驱动）
    const weights = this.getEffectiveWeights();
    for (const article of articles) {
      const feedTitle = feedMap.get(article.feedId) ?? article.feedTitle ?? '';
      const feedScore = this.calcFeedScore(feedTitle);
      const freshnessScore = this.calcFreshnessScore(article.publishedAt);
      const topicScore = this.calcTopicScore(article.title);
      const contentScore = this.calcContentScore(article.summary);

      const totalScore =
        weights.topic * topicScore +
        weights.content * contentScore +
        weights.freshness * freshnessScore +
        weights.feed * feedScore;

      article.recommendScore = Math.round(totalScore * 1000) / 1000;

      // 确定推荐理由：取贡献最大的内容维度
      const topicContrib = weights.topic * topicScore;
      const contentContrib = weights.content * contentScore;
      const freshContrib = weights.freshness * freshnessScore;

      if (topicContrib >= contentContrib && topicContrib >= freshContrib && topicScore > 0.1) {
        article.recommendReason = Constants.BADGE_TOPIC_MATCH;
      } else if (contentContrib >= topicContrib && contentContrib >= freshContrib && contentScore > 0.1) {
        article.recommendReason = Constants.BADGE_CONTENT_MATCH;
      } else {
        article.recommendReason = Constants.BADGE_LATEST;
      }
    }

    // 按推荐分数降序排序
    articles.sort((a, b) => (b.recommendScore ?? 0) - (a.recommendScore ?? 0));

    // 来源多样性惩罚（两轮：惩罚→重排→再惩罚，处理重排后新出现的连续同源）
    this.applyDiversityPenalty(articles, feedMap);
    articles.sort((a, b) => (b.recommendScore ?? 0) - (a.recommendScore ?? 0));
    this.applyDiversityPenalty(articles, feedMap);

    // 最终重排
    articles.sort((a, b) => (b.recommendScore ?? 0) - (a.recommendScore ?? 0));

    // 确保所有文章都有推荐理由（兜底）
    for (const article of articles) {
      if (!article.recommendReason) {
        article.recommendReason = Constants.BADGE_RECOMMEND;
      }
    }

    // 缓存完整评分结果
    this.scoredCache = articles;

    const sliced = articles.slice(0, pageSize);
    return { articles: sliced, totalCount: articles.length };
  }

  /**
   * 对包含已读和未读文章的混合列表进行分区排序
   * 未读文章按推荐分排前面，已读文章按时间排后面
   */
  async scoreAndSortWithPartition(
    unreadArticles: Article[],
    readArticles: Article[],
    feedMap: Map<number, string>,
    page: number = 0,
    pageSize: number = Constants.RECOMMEND_PAGE_SIZE
  ): Promise<RecommendResult> {
    // 首页重新评分
    if (page > 0 && this.scoredCache.length > 0) {
      const start = page * pageSize;
      const sliced = this.scoredCache.slice(start, start + pageSize);
      return { articles: sliced, totalCount: this.scoredCache.length };
    }

    // 未读文章评分排序
    const unreadResult = await this.scoreAndSort(unreadArticles, feedMap, 0, unreadArticles.length);

    // 已读文章按时间倒序排列
    readArticles.sort((a, b) => b.publishedAt - a.publishedAt);
    for (const a of readArticles) {
      a.recommendReason = '';
    }

    // 分区合并：未读在前 + 已读在后
    const combined = unreadResult.articles.concat(readArticles);
    this.scoredCache = combined;

    const sliced = combined.slice(0, pageSize);
    return { articles: sliced, totalCount: combined.length };
  }

  /**
   * 清除评分缓存（切换排序模式、刷新文章后调用）
   */
  clearScoredCache(): void {
    this.scoredCache = [];
  }

  /**
   * 外部注入评分缓存（AI 排序路径分页用）
   * AI 排序后调用，后续分页从缓存切片，避免重新评分导致角标跳变
   */
  setScoredCache(articles: Article[]): void {
    this.scoredCache = articles;
  }

  /**
   * 清除画像缓存（画像更新后调用）
   */
  clearProfileCache(): void {
    this.profileCache = null;
  }

  // ==================== 私有方法 ====================

  /**
   * 获取生效权重：若配置异常则回退默认值，保障排序稳定性
   */
  private getEffectiveWeights(): RecommendWeights {
    const configured: RecommendWeights = {
      content: Constants.W_CONTENT,
      topic: Constants.W_TOPIC,
      freshness: Constants.W_FRESHNESS,
      feed: Constants.W_FEED
    };

    const isEachValid = configured.content >= 0 && configured.content <= 1 &&
      configured.topic >= 0 && configured.topic <= 1 &&
      configured.freshness >= 0 && configured.freshness <= 1 &&
      configured.feed >= 0 && configured.feed <= 1;

    const sum = configured.content + configured.topic + configured.freshness + configured.feed;
    if (isEachValid && Math.abs(sum - 1.0) <= Constants.W_SUM_EPSILON) {
      return configured;
    }

    const fallback: RecommendWeights = {
      content: Constants.W_DEFAULT_CONTENT,
      topic: Constants.W_DEFAULT_TOPIC,
      freshness: Constants.W_DEFAULT_FRESHNESS,
      feed: Constants.W_DEFAULT_FEED
    };
    console.warn(TAG, `推荐权重配置异常，使用默认值。configuredSum=${sum.toFixed(3)}`);
    return fallback;
  }

  /**
   * 确保画像缓存已加载且未过期
   */
  private async ensureProfileCache(): Promise<void> {
    if (this.profileCache && (Date.now() - this.profileCache.loadedAt) < Constants.RECOMMEND_CACHE_TTL) {
      return;
    }

    const memSvc = MemoryService.getInstance();
    if (!memSvc.isReady()) {
      console.warn(TAG, 'MemoryService 未初始化，无法加载画像');
      this.profileCache = {
        feedWeights: new Map(),
        topicKeywords: new Map(),
        searchKeywords: [],
        loadedAt: Date.now()
      };
      return;
    }

    try {
      const profileContent = await memSvc.getProfile();
      if (!profileContent || profileContent.trim().length === 0) {
        this.profileCache = {
          feedWeights: new Map(),
          topicKeywords: new Map(),
          searchKeywords: [],
          loadedAt: Date.now()
        };
        return;
      }

      // 解析订阅源权重
      const feedSection = this.extractSection(profileContent, '## 订阅源偏好');
      const feedWeightsList = InterestCalculator.parseFromMarkdown(feedSection);
      const feedWeights = new Map<string, number>();
      for (const iw of feedWeightsList) {
        feedWeights.set(iw.key, iw.weight);
      }

      // 解析话题权重
      const topicSection = this.extractSection(profileContent, '## 话题偏好');
      const topicWeightsList = InterestCalculator.parseFromMarkdown(topicSection);
      const topicKeywords = new Map<string, number>();
      for (const iw of topicWeightsList) {
        topicKeywords.set(iw.key, iw.weight);
      }

      // 解析搜索关键词（降级用）
      const searchSection = this.extractSection(profileContent, '## 搜索兴趣');
      const searchKeywords = this.parseSearchKeywords(searchSection);

      this.profileCache = {
        feedWeights,
        topicKeywords,
        searchKeywords,
        loadedAt: Date.now()
      };

      console.info(TAG,
        `画像已加载: ${feedWeights.size} 个订阅源权重, ${topicKeywords.size} 个话题关键词, ${searchKeywords.length} 个搜索词`);
    } catch (e) {
      console.error(TAG, `画像加载失败: ${e}`);
      this.profileCache = {
        feedWeights: new Map(),
        topicKeywords: new Map(),
        searchKeywords: [],
        loadedAt: Date.now()
      };
    }
  }

  /**
   * 判断是否为冷启动（无有效画像数据）
   */
  private isColdStart(): boolean {
    if (!this.profileCache) {
      return true;
    }
    // 内容驱动：只要有话题或搜索关键词就不算冷启动
    return this.profileCache.topicKeywords.size === 0 &&
           this.profileCache.searchKeywords.length === 0;
  }

  /**
   * 冷启动排序：按时间倒序 + 来源多样性
   */
  private coldStartSort(articles: Article[], feedMap: Map<number, string>): Article[] {
    // 按时间倒序
    articles.sort((a, b) => b.publishedAt - a.publishedAt);
    for (const a of articles) {
      a.recommendScore = 0;
      a.recommendReason = Constants.BADGE_LATEST;
    }
    // 应用多样性惩罚（虽然分数为 0，但能打散同源文章的连续排列）
    this.applyDiversityPenalty(articles, feedMap);
    return articles;
  }

  /**
   * 计算订阅源匹配分
   */
  private calcFeedScore(feedTitle: string): number {
    if (!this.profileCache || !feedTitle) {
      return 0;
    }
    return this.profileCache.feedWeights.get(feedTitle) ?? 0;
  }

  /**
   * 计算时效性分数
   * 24 小时内为 1.0，每过 24 小时衰减 0.1，最低 0.1
   */
  private calcFreshnessScore(publishedAt: number): number {
    if (publishedAt <= 0) {
      return 0.1;
    }
    const daysOld = (Date.now() - publishedAt) / (24 * 60 * 60 * 1000);
    return Math.min(1.0, Math.max(0.1, 1.0 - daysOld * 0.1));
  }

  /**
   * 计算话题匹配分
   * 有 AI 话题时用话题关键词，无 AI 时降级用搜索关键词
   * 返回命中关键词中的最大权重值
   */
  private calcTopicScore(title: string): number {
    if (!this.profileCache || !title) {
      return 0;
    }

    let maxScore = 0;

    // 优先使用 AI 话题关键词
    if (this.profileCache.topicKeywords.size > 0) {
      this.profileCache.topicKeywords.forEach((weight, keyword) => {
        if (this.matchKeyword(title, keyword)) {
          maxScore = Math.max(maxScore, weight);
        }
      });
      return maxScore;
    }

    // 降级使用搜索关键词（统一权重 0.5）
    if (this.profileCache.searchKeywords.length > 0) {
      for (const keyword of this.profileCache.searchKeywords) {
        if (this.matchKeyword(title, keyword)) {
          maxScore = 0.5;
          break;  // 搜索词权重统一，命中一个即可
        }
      }
    }

    return maxScore;
  }

  /**
   * 计算摘要内容匹配分
   * 对文章摘要（而非标题）进行关键词匹配，扩大内容覆盖面
   * 使用话题关键词 + 搜索关键词，匹配命中数越多分越高
   */
  private calcContentScore(summary: string): number {
    if (!this.profileCache || !summary) {
      return 0;
    }

    const text = summary.substring(0, 200); // 取前 200 字避免过长
    let hitCount = 0;
    let totalKeywords = 0;

    // 话题关键词匹配
    if (this.profileCache.topicKeywords.size > 0) {
      totalKeywords = this.profileCache.topicKeywords.size;
      this.profileCache.topicKeywords.forEach((_weight, keyword) => {
        if (this.matchKeyword(text, keyword)) {
          hitCount++;
        }
      });
    }

    // 搜索关键词补充匹配
    if (this.profileCache.searchKeywords.length > 0) {
      for (const keyword of this.profileCache.searchKeywords) {
        totalKeywords++;
        if (this.matchKeyword(text, keyword)) {
          hitCount++;
        }
      }
    }

    if (totalKeywords === 0 || hitCount === 0) {
      return 0;
    }

    // 命中率 × 0.8 + 至少命中 1 个关键词给 0.2 基础分
    return Math.min(1.0, (hitCount / totalKeywords) * 0.8 + 0.2);
  }

  /**
   * 关键词匹配（含短词边界检查）
   * 关键词长度 <= 2 时，要求前后为标点/空格/字符串边界
   */
  private matchKeyword(title: string, keyword: string): boolean {
    if (!keyword || keyword.length === 0) {
      return false;
    }

    const lowerTitle = title.toLowerCase();
    const lowerKeyword = keyword.toLowerCase();
    const index = lowerTitle.indexOf(lowerKeyword);

    if (index < 0) {
      return false;
    }

    // 长关键词（> 2 字符）直接命中
    if (keyword.length > 2) {
      return true;
    }

    // 短关键词需检查边界
    return this.checkWordBoundary(lowerTitle, index, lowerKeyword.length);
  }

  /**
   * 检查短词匹配位置的前后边界
   * 前后字符应为标点、空格、字符串边界或 CJK 字符边界
   */
  private checkWordBoundary(text: string, matchStart: number, matchLen: number): boolean {
    const matchEnd = matchStart + matchLen;

    // 检查前边界
    if (matchStart > 0) {
      const charBefore = text.charAt(matchStart - 1);
      if (!this.isBoundaryChar(charBefore)) {
        return false;
      }
    }

    // 检查后边界
    if (matchEnd < text.length) {
      const charAfter = text.charAt(matchEnd);
      if (!this.isBoundaryChar(charAfter)) {
        return false;
      }
    }

    return true;
  }

  /**
   * 判断字符是否为单词边界字符
   */
  private isBoundaryChar(ch: string): boolean {
    // 空格、标点符号
    const boundaryChars = ' \t\n\r,.;:!?/\\()[]{}「」《》【】、。，！？；：""' + "''·—…";
    if (boundaryChars.includes(ch)) {
      return true;
    }
    // CJK 字符视为天然边界（中文字之间不需要空格分隔）
    const code = ch.charCodeAt(0);
    return code >= 0x4E00 && code <= 0x9FFF;
  }

  /**
   * 来源多样性惩罚
   * 遍历排序后列表，连续同源文章递减打折
   */
  private applyDiversityPenalty(articles: Article[], feedMap: Map<number, string>): void {
    if (articles.length <= 1) {
      return;
    }

    let lastFeedId = -1;
    let consecutiveCount = 0;

    for (const article of articles) {
      if (article.feedId === lastFeedId) {
        consecutiveCount++;
        if (consecutiveCount === 2) {
          article.recommendScore = (article.recommendScore ?? 0) * Constants.DIVERSITY_PENALTY_2ND;
        } else if (consecutiveCount >= 3) {
          article.recommendScore = (article.recommendScore ?? 0) * Constants.DIVERSITY_PENALTY_3RD;
        }
      } else {
        lastFeedId = article.feedId;
        consecutiveCount = 1;
      }
    }
  }

  /**
   * 从 Markdown 中提取指定 ## 章节的内容
   * （与 ProfileService.extractSection 逻辑一致）
   */
  private extractSection(content: string, header: string): string {
    const lines = content.split('\n');
    let inSection = false;
    const sectionLines: string[] = [];
    for (const line of lines) {
      if (line.startsWith('## ')) {
        if (inSection) {
          break;
        }
        if (line.startsWith(header)) {
          inSection = true;
          continue;
        }
      }
      if (inSection) {
        sectionLines.push(line);
      }
    }
    return sectionLines.join('\n');
  }

  /**
   * 从 "## 搜索兴趣" 章节解析搜索关键词
   * 格式：近期高频搜索：关键词1、关键词2、关键词3
   */
  private parseSearchKeywords(section: string): string[] {
    if (!section || section.trim().length === 0) {
      return [];
    }
    const lines = section.split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      if (trimmed.startsWith('近期高频搜索：') || trimmed.startsWith('近期高频搜索:')) {
        const colonIdx = trimmed.indexOf('：');
        const colonIdx2 = trimmed.indexOf(':');
        const idx = colonIdx >= 0 ? colonIdx : colonIdx2;
        if (idx >= 0) {
          const keywordsStr = trimmed.substring(idx + 1).trim();
          return keywordsStr.split('、').map(k => k.trim()).filter(k => k.length > 0);
        }
      }
    }
    return [];
  }
}
