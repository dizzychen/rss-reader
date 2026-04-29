// 画像计算服务 - 基于 30 天行为数据生成用户画像 + AI 综合分析
import { DailyStats, InterestWeight, UserProfile } from '../model/Models';
import { MemoryFileHelper } from './MemoryFileHelper';
import { MemoryService } from './MemoryService';
import { AIService } from './AIService';
import { InterestCalculator } from '../utils/InterestCalculator';
import { TopicExtractor } from '../utils/TopicExtractor';
import { RecommendService } from './RecommendService';
import { DateUtil } from '../utils/DateUtil';
import { MarkdownUtil } from '../utils/MarkdownUtil';
import { Constants } from '../constants/Constants';

/** aggregateStats 返回类型 */
interface AggregatedStats {
  totalReadDays: number;
  totalArticles: number;
  avgDailyRead: number;
  feedSignals: Map<string, number>;
  avgReadDuration: number;
  topKeywords: string[];
  feedAvgDuration: Map<string, number>;
}

/** 话题条目（名称 + 权重） */
interface TopicItem {
  name: string;
  weight: number;
}

/** AI 画像综合返回结构 */
interface AIProfileInsight {
  topics: TopicItem[];
  trend: string;
  style: string;
  dislikePatterns: string;
}

export class ProfileService {
  private static instance: ProfileService;

  static getInstance(): ProfileService {
    if (!ProfileService.instance) {
      ProfileService.instance = new ProfileService();
    }
    return ProfileService.instance;
  }

  /**
   * 解析单日日志文件，提取行为数据
   * 日志格式为 Markdown 表格：| 时间 | 行为 | 文章 | 来源 | 时长/关键词 |
   */
  parseDailyLog(content: string, date: string): DailyStats {
    const stats: DailyStats = {
      date,
      readCount: 0,
      starCount: 0,
      searchCount: 0,
      skipCount: 0,
      avgReadDuration: 0,
      topFeeds: [],
      starFeeds: [],
      topKeywords: [],
      readTitles: [],
      likedTitles: [],
      dislikedTitles: [],
      feedReadCounts: new Map<string, number>(),
      feedDurations: new Map<string, number[]>(),
      feedLikeCounts: new Map<string, number>(),
      readTimestamps: [],
      recExposureCount: 0,
      recHitCount: 0
    };

    const feedCount = new Map<string, number>();
    const feedStar = new Map<string, number>();
    const keywords: string[] = [];
    let totalDuration = 0;
    let durationCount = 0;
    let lastReadFeed = '';

    const lines = content.split('\n');
    for (const line of lines) {
      if (!line.startsWith('| ') || line.startsWith('| 时间') || line.startsWith('|---')) {
        continue;
      }
      const parts = line.split('|').map(s => s.trim()).filter(s => s.length > 0);
      if (parts.length < 4) {
        continue;
      }
      const time = parts[0];
      const action = parts[1];
      const title = parts[2];
      const feed = parts[3];
      const extra = parts.length >= 5 ? parts[4] : '-';

      if (action === 'READ') {
        stats.readCount++;
        if (title && title !== '-') {
          stats.readTitles.push(title);
        }
        if (feed && feed !== '-') {
          feedCount.set(feed, (feedCount.get(feed) ?? 0) + 1);
          lastReadFeed = feed;
        }
        if (time) {
          stats.readTimestamps.push(time);
        }
      } else if (action === 'READ_END') {
        const secs = this.parseDurationToSeconds(extra);
        if (secs > 0) {
          totalDuration += secs;
          durationCount++;
          if (lastReadFeed) {
            const durations = stats.feedDurations.get(lastReadFeed) ?? [];
            durations.push(secs);
            stats.feedDurations.set(lastReadFeed, durations);
          }
        }
      } else if (action === 'STAR') {
        stats.starCount++;
        if (feed && feed !== '-') {
          feedStar.set(feed, (feedStar.get(feed) ?? 0) + 1);
        }
      } else if (action === 'SEARCH') {
        stats.searchCount++;
        if (extra && extra !== '-') {
          keywords.push(extra);
        }
      } else if (action === 'SKIP') {
        stats.skipCount++;
      } else if (action === 'RATE') {
        if (extra === '👍' && title && title !== '-') {
          stats.likedTitles.push(title);
          if (feed && feed !== '-') {
            stats.feedLikeCounts.set(feed, (stats.feedLikeCounts.get(feed) ?? 0) + 1);
          }
        } else if (extra === '👎' && title && title !== '-') {
          // 点踩仅表示不喜欢该文章，不对订阅源建负反馈
          stats.dislikedTitles.push(title);
        }
      } else if (action === 'REC_EXPOSURE') {
        stats.recExposureCount++;
      } else if (action === 'AI_REC_HIT') {
        stats.recHitCount++;
      }
    }

    if (durationCount > 0) {
      stats.avgReadDuration = Math.round(totalDuration / durationCount);
    }

    const feedEntries: Array<[string, number]> = [];
    feedCount.forEach((cnt, name) => {
      feedEntries.push([name, cnt]);
    });
    feedEntries.sort((a, b) => b[1] - a[1]);
    stats.topFeeds = feedEntries.slice(0, 3).map(entry => entry[0]);

    // 保存完整的来源阅读计数（供 aggregateStats 使用）
    stats.feedReadCounts = feedCount;

    const seenKeywords = new Set<string>();
    const uniqueKeywords: string[] = [];
    for (const kw of keywords) {
      if (!seenKeywords.has(kw)) {
        seenKeywords.add(kw);
        uniqueKeywords.push(kw);
      }
    }
    stats.topKeywords = uniqueKeywords.slice(0, 5);

    const starFeedsArray: string[] = [];
    feedStar.forEach((_cnt, name) => {
      starFeedsArray.push(name);
    });
    stats.starFeeds = starFeedsArray;

    return stats;
  }

  /**
   * 解析时长字符串为秒数
   */
  private parseDurationToSeconds(durationStr: string): number {
    if (!durationStr || durationStr === '-') {
      return 0;
    }
    if (durationStr.endsWith('秒') && !durationStr.includes('分')) {
      return parseInt(durationStr.replace('秒', ''), 10) || 0;
    }
    if (durationStr.includes('分') && durationStr.includes('秒')) {
      const parts = durationStr.split('分');
      const minutes = parseInt(parts[0], 10) || 0;
      const secs = parseInt(parts[1].replace('秒', ''), 10) || 0;
      return minutes * 60 + secs;
    }
    if (durationStr.includes('小时')) {
      const parts = durationStr.split('小时');
      const hours = parseInt(parts[0], 10) || 0;
      const mins = parseInt(parts[1].replace('分', ''), 10) || 0;
      return hours * 3600 + mins * 60;
    }
    return 0;
  }

  /**
   * 聚合 30 天的 DailyStats，计算总体统计
   */
  aggregateStats(dailyStatsList: DailyStats[]): AggregatedStats {
    const activeDays = dailyStatsList.filter(d => d.readCount > 0 || d.starCount > 0);
    const totalArticles = dailyStatsList.reduce((sum, d) => sum + d.readCount, 0);
    const avgDailyRead = activeDays.length > 0 ? Math.round(totalArticles / activeDays.length) : 0;

    const feedCount = new Map<string, number>();
    const feedStar = new Map<string, number>();
    const feedDurationAll = new Map<string, number[]>();
    const feedLike = new Map<string, number>();
    let totalDuration = 0;
    let durationCount = 0;

    const keywordCount = new Map<string, number>();

    for (const d of dailyStatsList) {
      // 使用完整的来源阅读计数（而非仅 Top3 名称）
      d.feedReadCounts.forEach((cnt, feed) => {
        feedCount.set(feed, (feedCount.get(feed) ?? 0) + cnt);
      });
      for (const feed of d.starFeeds) {
        feedStar.set(feed, (feedStar.get(feed) ?? 0) + 1);
      }
      if (d.avgReadDuration > 0) {
        totalDuration += d.avgReadDuration;
        durationCount++;
      }
      // 聚合每个订阅源的阅读时长
      d.feedDurations.forEach((durations, feed) => {
        const existing = feedDurationAll.get(feed) ?? [];
        for (const dur of durations) {
          existing.push(dur);
        }
        feedDurationAll.set(feed, existing);
      });
      // 聚合搜索关键词
      for (const kw of d.topKeywords) {
        keywordCount.set(kw, (keywordCount.get(kw) ?? 0) + 1);
      }
      // 聚合 RATE 👍 次数
      d.feedLikeCounts.forEach((cnt, feed) => {
        feedLike.set(feed, (feedLike.get(feed) ?? 0) + cnt);
      });
    }

    // 计算每个源的平均阅读时长
    const feedAvgDuration = new Map<string, number>();
    feedDurationAll.forEach((durations, feed) => {
      if (durations.length > 0) {
        const sum = durations.reduce((a, b) => a + b, 0);
        feedAvgDuration.set(feed, Math.round(sum / durations.length));
      }
    });

    // 计算信号强度（含阅读时长加权、正负反馈）
    const feedSignals = new Map<string, number>();
    feedCount.forEach((count, feed) => {
      const starCount = feedStar.get(feed) ?? 0;
      const avgDur = feedAvgDuration.get(feed) ?? 0;
      const like = feedLike.get(feed) ?? 0;
      const signal = InterestCalculator.calcSignal(count, starCount, dailyStatsList.length, avgDur, like);
      feedSignals.set(feed, signal);
    });
    feedStar.forEach((starCount, feed) => {
      if (!feedCount.has(feed)) {
        const avgDur = feedAvgDuration.get(feed) ?? 0;
        const like = feedLike.get(feed) ?? 0;
        const signal = InterestCalculator.calcSignal(0, starCount, dailyStatsList.length, avgDur, like);
        feedSignals.set(feed, signal);
      }
    });

    const avgDuration = durationCount > 0 ? Math.round(totalDuration / durationCount) : 0;

    // 关键词按频次排序取 Top 10
    const kwEntries: Array<[string, number]> = [];
    keywordCount.forEach((cnt, kw) => {
      kwEntries.push([kw, cnt]);
    });
    kwEntries.sort((a, b) => b[1] - a[1]);
    const topKeywords = kwEntries.slice(0, 10).map(entry => entry[0]);

    const result: AggregatedStats = {
      totalReadDays: activeDays.length,
      totalArticles: totalArticles,
      avgDailyRead: avgDailyRead,
      feedSignals: feedSignals,
      avgReadDuration: avgDuration,
      topKeywords: topKeywords,
      feedAvgDuration: feedAvgDuration
    };
    return result;
  }

  /**
   * 重新生成用户画像并保存（统计 + AI 综合）
   */
  async regenerate(): Promise<void> {
    const memSvc = MemoryService.getInstance();
    if (!memSvc.isReady()) {
      return;
    }

    try {
      // 先落盘行为队列，确保推荐曝光/命中统计是最新值
      await memSvc.flushBehaviors();

      const filesDir = memSvc.getFilesDir();
      const dailyDir = `${filesDir}/${Constants.MEMORY_DAILY_DIR}`;
      const files = await MemoryFileHelper.listFiles(dailyDir);

      const today = DateUtil.today();
      const cutoff = DateUtil.daysAgo(Constants.MEMORY_KEEP_DAYS);
      const dailyStatsList: DailyStats[] = [];

      for (const file of files) {
        if (!file.endsWith('.md')) {
          continue;
        }
        const dateStr = file.replace('.md', '');
        if (dateStr < cutoff || dateStr > today) {
          continue;
        }
        const content = await MemoryFileHelper.readMarkdown(`${dailyDir}/${file}`);
        if (content.trim()) {
          dailyStatsList.push(this.parseDailyLog(content, dateStr));
        }
      }

      if (dailyStatsList.length === 0) {
        return;
      }

      // 按日期升序排序，确保 slice(-7) 取到的是最近 7 天
      dailyStatsList.sort((a, b) => a.date.localeCompare(b.date));

      // 聚合统计
      const aggregated = this.aggregateStats(dailyStatsList);

      // 读取已有画像中的兴趣权重
      const existingProfileContent = await memSvc.getProfile();
      const existingWeights = this.parseExistingWeights(existingProfileContent);

      // 更新兴趣权重（EMA）
      const updatedFeedWeights = InterestCalculator.update(
        existingWeights,
        aggregated.feedSignals,
        today
      );

      // 收集最近 7 天的已读/点赞/点踩标题（供 AI 分析）
      const recentStats = dailyStatsList.slice(-7);
      const allReadTitles: string[] = [];
      const allLikedTitles: string[] = [];
      const allDislikedTitles: string[] = [];
      for (const d of recentStats) {
        for (const t of d.readTitles) {
          allReadTitles.push(t);
        }
        for (const t of d.likedTitles) {
          allLikedTitles.push(t);
        }
        for (const t of d.dislikedTitles) {
          allDislikedTitles.push(t);
        }
      }

      // 计算推荐命中率（最近 7 天）
      const recHitRate = this.calcRecommendationHitRate(recentStats);

      // AI 综合分析（有 API Key 时）
      let aiInsight: AIProfileInsight | null = null;
      let topicWeights: InterestWeight[] = [];
      if (AIService.getInstance().hasApiKey() && allReadTitles.length >= 3) {
        try {
          aiInsight = await this.runAIProfileSynthesis(
            await memSvc.getSoul(),
            existingProfileContent,
            aggregated,
            allReadTitles.slice(0, 100),
            allLikedTitles,
            allDislikedTitles,
            recHitRate
          );
          if (aiInsight && aiInsight.topics.length > 0) {
            topicWeights = aiInsight.topics.map((t): InterestWeight => {
              const iw: InterestWeight = {
                key: t.name,
                weight: Math.round(Math.min(1, Math.max(0, t.weight)) * 1000) / 1000,
                updatedAt: today
              };
              return iw;
            });
          }
        } catch (e) {
          const msg = e instanceof Error ? e.message : String(e);
          console.warn('ProfileService', `AI synthesis skipped: ${msg}`);
        }
      }

      // 本地话题提取降级：无 AI 或 AI 未返回话题时，用本地频次统计
      if (topicWeights.length === 0 && allReadTitles.length >= 3) {
        const localTopics = TopicExtractor.extractFromTitles(allReadTitles, 12);
        const merged = TopicExtractor.mergeWithSearchKeywords(localTopics, aggregated.topKeywords);
        topicWeights = merged.map((t): InterestWeight => {
          const iw: InterestWeight = {
            key: t.name,
            weight: Math.round(t.weight * 1000) / 1000,
            updatedAt: today
          };
          return iw;
        });
      }

      // LESSONS 经验沉淀：将推荐命中率追踪写入 LESSONS.md
      await this.updateLessonsTracking(memSvc, today, recHitRate, recentStats);

      const profileContent = this.buildProfileMarkdown({
        generatedAt: today,
        totalReadDays: aggregated.totalReadDays,
        totalArticles: aggregated.totalArticles,
        avgDailyRead: aggregated.avgDailyRead,
        feedInterests: updatedFeedWeights,
        topicInterests: topicWeights,
        preferredReadTime: this.calcPreferredReadTime(dailyStatsList),
        avgReadDuration: aggregated.avgReadDuration,
        aiInsight: aiInsight?.trend ?? '',
        readingStyle: aiInsight?.style ?? '',
        dislikePatterns: aiInsight?.dislikePatterns ?? '',
        searchKeywords: aggregated.topKeywords
      });

      await memSvc.updateProfile(profileContent);
      console.info('ProfileService', 'regenerate done');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('ProfileService', `regenerate failed: ${msg}`);
    }
  }

  /**
   * AI 画像综合分析
   */
  private async runAIProfileSynthesis(
    soul: string,
    existingProfile: string,
    aggregated: AggregatedStats,
    readTitles: string[],
    likedTitles: string[],
    dislikedTitles: string[],
    recHitRate: number
  ): Promise<AIProfileInsight> {
    const titleList = readTitles.map((t, i) => `${i + 1}. ${t}`).join('\n');
    const likedList = likedTitles.length > 0
      ? likedTitles.map(t => `- ${t}`).join('\n') : '（无）';
    const dislikedList = dislikedTitles.length > 0
      ? dislikedTitles.map(t => `- ${t}`).join('\n') : '（无）';

    let feedRanking = '';
    const feedEntries: Array<[string, number]> = [];
    aggregated.feedSignals.forEach((signal, feed) => {
      feedEntries.push([feed, signal]);
    });
    feedEntries.sort((a, b) => b[1] - a[1]);
    feedRanking = feedEntries.slice(0, 10).map(e => `${e[0]}: ${e[1].toFixed(3)}`).join(', ');

    const userPrompt = `请分析以下用户阅读数据，重点从文章内容和标题中提取用户的兴趣话题。

## 用户灵魂档案
${soul.trim() || '（未设置）'}

## 统计概览
- 活跃天数: ${aggregated.totalReadDays}
- 总阅读量: ${aggregated.totalArticles} 篇
- 日均阅读: ${aggregated.avgDailyRead} 篇
- 平均时长: ${aggregated.avgReadDuration} 秒
- 推荐命中率: ${recHitRate >= 0 ? (recHitRate * 100).toFixed(0) + '%' : '暂无数据'}
- 搜索关键词: ${aggregated.topKeywords.join('、') || '暂无'}

## 最近 7 天已读文章标题
${titleList}

## 用户主动标记"有价值"的文章
${likedList}

## 用户主动标记"不感兴趣"的文章
${dislikedList}

请输出以下 JSON（不要输出其他内容）：
{
  "topics": [{"name": "话题关键词", "weight": 0.8}],
  "trend": "与之前相比兴趣变化的一句话描述",
  "style": "阅读风格标签（如深度技术阅读者、快速信息扫描者等）",
  "dislikePatterns": "用户不感兴趣的内容模式描述"
}

重要：topics 是推荐系统的核心数据，请从文章标题和内容中深入提取 8-12 个具体话题关键词（如"大模型"、"量化交易"、"Rust"），不要提取来源/网站名称。weight 范围 0-1，反映用户的兴趣程度。`;

    const response = await AIService.getInstance().chat(
      Constants.AI_PROFILE_SYSTEM_PROMPT,
      userPrompt,
      Constants.AI_PROFILE_MAX_TOKENS
    );

    return this.parseAIInsightResponse(response);
  }

  /**
   * 解析 AI 返回的 JSON 洞察
   */
  private parseAIInsightResponse(response: string): AIProfileInsight {
    const defaultResult: AIProfileInsight = {
      topics: [], trend: '', style: '', dislikePatterns: ''
    };
    try {
      // 提取 JSON 部分（AI 可能在 JSON 前后加文字）
      const jsonMatch = response.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        return defaultResult;
      }
      const parsed = JSON.parse(jsonMatch[0]) as Record<string, Object>;
      const topics: TopicItem[] = [];
      if (Array.isArray(parsed['topics'])) {
        for (const t of parsed['topics'] as Array<Record<string, Object>>) {
          const name = String(t['name'] ?? '');
          const weight = Number(t['weight'] ?? 0);
          if (name && weight > 0) {
            const item: TopicItem = { name, weight };
            topics.push(item);
          }
        }
      }
      return {
        topics: topics.slice(0, 12),
        trend: String(parsed['trend'] ?? ''),
        style: String(parsed['style'] ?? ''),
        dislikePatterns: String(parsed['dislikePatterns'] ?? '')
      };
    } catch (e) {
      console.warn('ProfileService', `parseAIInsightResponse failed: ${String(e)}`);
      return defaultResult;
    }
  }

  /**
   * 计算推荐命中率（最近 N 天 AI_REC_HIT / 总推荐曝光）
   * 返回 -1 表示无数据
   */
  private calcRecommendationHitRate(recentStats: DailyStats[]): number {
    let totalExposure = 0;
    let totalHit = 0;
    for (const d of recentStats) {
      totalExposure += d.recExposureCount;
      totalHit += d.recHitCount;
    }
    if (totalExposure <= 0) {
      return -1;
    }
    return totalHit / totalExposure;
  }

  /**
   * 从已有画像内容中解析兴趣权重
   */
  private parseExistingWeights(content: string): InterestWeight[] {
    const feedSection = MarkdownUtil.extractSection(content, '## 订阅源偏好');
    if (!feedSection) {
      return [];
    }
    return InterestCalculator.parseFromMarkdown(feedSection);
  }

  /**
   * 计算偏好阅读时段
   */
  private calcPreferredReadTime(dailyStatsList: DailyStats[]): string {
    const slots: Record<string, number> = {
      '凌晨 (0-6点)': 0,
      '早晨 (6-9点)': 0,
      '上午 (9-12点)': 0,
      '下午 (12-18点)': 0,
      '傍晚 (18-21点)': 0,
      '深夜 (21-24点)': 0
    };
    const slotKeys = Object.keys(slots);

    for (const d of dailyStatsList) {
      for (const ts of d.readTimestamps) {
        const hourStr = ts.split(':')[0];
        const hour = parseInt(hourStr, 10);
        if (isNaN(hour)) continue;
        if (hour < 6) slots[slotKeys[0]]++;
        else if (hour < 9) slots[slotKeys[1]]++;
        else if (hour < 12) slots[slotKeys[2]]++;
        else if (hour < 18) slots[slotKeys[3]]++;
        else if (hour < 21) slots[slotKeys[4]]++;
        else slots[slotKeys[5]]++;
      }
    }

    let maxSlot = '待分析';
    let maxCount = 0;
    for (const key of slotKeys) {
      if (slots[key] > maxCount) {
        maxCount = slots[key];
        maxSlot = key;
      }
    }
    return maxCount > 0 ? maxSlot : '待分析';
  }

  /**
   * 构建用户画像 Markdown 内容
   */
  buildProfileMarkdown(profile: UserProfile): string {
    const parts: string[] = [];

    parts.push(`# 阅读画像`);
    parts.push(``);
    parts.push(`> 生成时间：${profile.generatedAt}`);
    parts.push(``);
    parts.push(`## 阅读概览`);
    parts.push(``);
    parts.push(`| 指标 | 数值 |`);
    parts.push(`|------|------|`);
    parts.push(`| 累计阅读天数 | ${profile.totalReadDays} 天 |`);
    parts.push(`| 累计阅读文章 | ${profile.totalArticles} 篇 |`);
    parts.push(`| 日均阅读 | ${profile.avgDailyRead} 篇 |`);
    parts.push(`| 平均阅读时长 | ${DateUtil.formatDuration(profile.avgReadDuration)} |`);
    parts.push(`| 偏好阅读时段 | ${profile.preferredReadTime} |`);
    parts.push(``);
    parts.push(`## 订阅源偏好`);
    parts.push(``);
    parts.push(InterestCalculator.serializeToMarkdown(profile.feedInterests).trimEnd());
    parts.push(``);

    if (profile.topicInterests.length > 0) {
      parts.push(`## 话题偏好`);
      parts.push(``);
      parts.push(InterestCalculator.serializeToMarkdown(profile.topicInterests).trimEnd());
      parts.push(``);
    }

    if (profile.searchKeywords && profile.searchKeywords.length > 0) {
      parts.push(`## 搜索兴趣`);
      parts.push(``);
      parts.push(`近期高频搜索：${profile.searchKeywords.join('、')}`);
      parts.push(``);
    }

    // AI 洞察章节
    if (profile.aiInsight || profile.readingStyle || profile.dislikePatterns) {
      parts.push(`## AI 洞察`);
      parts.push(``);
      if (profile.readingStyle) {
        parts.push(`阅读风格：${profile.readingStyle}`);
        parts.push(``);
      }
      if (profile.aiInsight) {
        parts.push(`兴趣变化：${profile.aiInsight}`);
        parts.push(``);
      }
      if (profile.dislikePatterns) {
        parts.push(`不感兴趣的内容：${profile.dislikePatterns}`);
        parts.push(``);
      }
    }

    // === 压缩摘要区块（供分层上下文 L1 快速加载，~150 token）===
    parts.push(`## 压缩摘要`);
    parts.push(``);
    const compactLines: string[] = [];
    // 订阅源 Top5 压缩格式
    if (profile.feedInterests.length > 0) {
      const feedCompact = profile.feedInterests.slice(0, 5)
        .map(w => `${w.key}:${w.weight.toFixed(2)}`).join(', ');
      compactLines.push(`源偏好: ${feedCompact}`);
    }
    // 话题压缩格式
    if (profile.topicInterests.length > 0) {
      const topicCompact = profile.topicInterests.slice(0, 8)
        .map(w => `${w.key}:${w.weight.toFixed(2)}`).join(', ');
      compactLines.push(`话题: ${topicCompact}`);
    }
    // 搜索关键词
    if (profile.searchKeywords && profile.searchKeywords.length > 0) {
      compactLines.push(`搜索: ${profile.searchKeywords.join(', ')}`);
    }
    // AI 洞察一行
    if (profile.readingStyle) {
      compactLines.push(`风格: ${profile.readingStyle}`);
    }
    if (profile.dislikePatterns) {
      compactLines.push(`排除: ${profile.dislikePatterns}`);
    }
    // 统计概要
    compactLines.push(`统计: ${profile.totalArticles}篇/${profile.totalReadDays}天, 日均${profile.avgDailyRead}篇, 时段${profile.preferredReadTime}`);
    parts.push(compactLines.join('\n'));
    parts.push(``);

    return parts.join('\n');
  }

  /**
   * 日内轻量刷新：仅更新订阅源偏好章节（patch 模式），不触发 AI
   * 若 patch 失败则降级为 regenerate()
   */
  async quickRefresh(): Promise<void> {
    const memSvc = MemoryService.getInstance();
    if (!memSvc.isReady()) {
      return;
    }
    try {
      const today = DateUtil.today();
      const logPath = `${memSvc.getFilesDir()}/${Constants.MEMORY_DAILY_DIR}/${today}.md`;
      const todayLog = await MemoryFileHelper.readMarkdown(logPath);
      if (!todayLog.trim()) {
        return;
      }

      const todayStats = this.parseDailyLog(todayLog, today);
      if (todayStats.readCount === 0) {
        return;
      }

      // 仅用今日数据构建 feedSignals
      const feedSignals = new Map<string, number>();
      todayStats.feedReadCounts.forEach((count, feed) => {
        const starCount = todayStats.starFeeds.includes(feed) ? 1 : 0;
        const like = todayStats.feedLikeCounts.get(feed) ?? 0;
        const signal = InterestCalculator.calcSignal(count, starCount, 1, 0, like);
        feedSignals.set(feed, signal);
      });

      // 读取现有画像
      const existingProfile = await memSvc.getProfile();
      const existingWeights = this.parseExistingWeights(existingProfile);
      const updatedWeights = InterestCalculator.update(existingWeights, feedSignals, today);

      // 尝试 patch 订阅源偏好章节
      const feedSectionNew = InterestCalculator.serializeToMarkdown(updatedWeights).trimEnd();
      const sectionHeader = '## 订阅源偏好';
      const headerIdx = existingProfile.indexOf(sectionHeader);

      if (headerIdx >= 0) {
        // 找到下一个 ## 章节的起始位置
        const afterHeader = existingProfile.indexOf('\n', headerIdx);
        let nextSectionIdx = existingProfile.indexOf('\n## ', afterHeader);
        if (nextSectionIdx < 0) {
          nextSectionIdx = existingProfile.length;
        }
        const before = existingProfile.substring(0, afterHeader + 1);
        const after = existingProfile.substring(nextSectionIdx);
        const patchedFeed = `${before}\n${feedSectionNew}\n${after}`;
        const patched = this.patchCompactFeedSummaryLine(patchedFeed, updatedWeights);
        await memSvc.updateProfile(patched);
        RecommendService.getInstance().clearProfileCache();
        console.info('ProfileService', 'quickRefresh patch done (feed + compact summary)');
      } else {
        // 章节不存在，降级为全量重建
        console.warn('ProfileService', 'quickRefresh: section not found, falling back to regenerate');
        await this.regenerate();
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.warn('ProfileService', `quickRefresh failed, falling back: ${msg}`);
      try {
        await this.regenerate();
      } catch (regen) {
        console.error('ProfileService', `quickRefresh fallback regenerate failed: ${String(regen)}`);
      }
    }
  }

  /**
   * 同步更新 PROFILE.md 的压缩摘要区块中的“源偏好”行
   */
  private patchCompactFeedSummaryLine(profileContent: string, feedWeights: InterestWeight[]): string {
    if (feedWeights.length === 0) {
      return profileContent;
    }

    const compactHeader = '## 压缩摘要';
    const compactIdx = profileContent.indexOf(compactHeader);
    if (compactIdx < 0) {
      return profileContent;
    }

    const afterHeader = profileContent.indexOf('\n', compactIdx);
    if (afterHeader < 0) {
      return profileContent;
    }

    let nextSectionIdx = profileContent.indexOf('\n## ', afterHeader);
    if (nextSectionIdx < 0) {
      nextSectionIdx = profileContent.length;
    }

    const before = profileContent.substring(0, afterHeader + 1);
    const sectionContent = profileContent.substring(afterHeader + 1, nextSectionIdx);
    const after = profileContent.substring(nextSectionIdx);

    const feedCompact = feedWeights.slice(0, 5)
      .map(w => `${w.key}:${w.weight.toFixed(2)}`).join(', ');
    const newLine = `源偏好: ${feedCompact}`;

    const lines = sectionContent.split('\n');
    let replaced = false;
    for (let i = 0; i < lines.length; i++) {
      // 【修复】使用更宽泛的匹配条件，识别各种格式的"源偏好"行
      if (/^(源偏好|Feed Preference|feed)[:：]/.test(lines[i])) {
        lines[i] = newLine;
        replaced = true;
        break;
      }
    }

    if (!replaced) {
      let insertIndex = 0;
      while (insertIndex < lines.length && lines[insertIndex].trim().length === 0) {
        insertIndex++;
      }
      lines.splice(insertIndex, 0, newLine);
    }

    return `${before}${lines.join('\n')}${after}`;
  }

  /**
   * 更新 LESSONS.md 的推荐效果追踪表
   */
  private async updateLessonsTracking(
    memSvc: MemoryService,
    today: string,
    hitRate: number,
    recentStats: DailyStats[]
  ): Promise<void> {
    try {
      let totalExposure = 0;
      let totalHit = 0;
      for (const d of recentStats) {
        totalExposure += d.recExposureCount;
        totalHit += d.recHitCount;
      }

      const lessonsContent = await memSvc.getLessons();
      const hitRateStr = hitRate >= 0 ? `${(hitRate * 100).toFixed(1)}%` : '-';
      const newRow = `| ${today} | ${hitRateStr} | ${totalExposure} | ${totalHit} |`;

      // 同一天数据使用最新统计覆盖，避免命中率卡在旧值（如 0.0%）
      const lines = lessonsContent.split('\n');
      let inTrackingSection = false;
      let separatorIndex = -1;
      let sectionEndIndex = lines.length;
      const dataRowIndexes: number[] = [];

      for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.includes('推荐效果追踪')) {
          inTrackingSection = true;
          continue;
        }
        if (!inTrackingSection) {
          continue;
        }
        if (line.startsWith('## ') && !line.includes('推荐效果追踪')) {
          sectionEndIndex = i;
          break;
        }
        if (line.startsWith('|------|')) {
          separatorIndex = i;
          continue;
        }
        if (line.startsWith('| ') && !line.startsWith('| 日期')) {
          dataRowIndexes.push(i);
        }
      }

      if (separatorIndex < 0) {
        return;
      }

      let replaced = false;
      for (const rowIndex of dataRowIndexes) {
        if (lines[rowIndex].includes(`| ${today} |`)) {
          lines[rowIndex] = newRow;
          replaced = true;
          break;
        }
      }

      if (!replaced) {
        // 新日期插入到表头后（最新在前）
        lines.splice(separatorIndex + 1, 0, newRow);
      }

      // 仅保留推荐效果追踪区间内的行排序（日期倒序）
      const currentDataRows: string[] = [];
      let start = separatorIndex + 1;
      let end = sectionEndIndex;
      if (end < start) {
        end = lines.length;
      }
      for (let i = start; i < end; i++) {
        const line = lines[i];
        if (line.startsWith('| ') && !line.startsWith('| 日期') && !line.startsWith('|------|')) {
          currentDataRows.push(line);
        }
      }
      currentDataRows.sort((a, b) => {
        const aParts = a.split('|').map(s => s.trim()).filter(s => s.length > 0);
        const bParts = b.split('|').map(s => s.trim()).filter(s => s.length > 0);
        const aDate = aParts.length > 0 ? aParts[0] : '';
        const bDate = bParts.length > 0 ? bParts[0] : '';
        return bDate.localeCompare(aDate);
      });

      // 重建 tracking 表数据区，避免重复行
      const rebuilt: string[] = [];
      for (let i = 0; i < lines.length; i++) {
        if (i <= separatorIndex || i >= sectionEndIndex) {
          rebuilt.push(lines[i]);
          continue;
        }
        if (i === separatorIndex + 1) {
          for (const row of currentDataRows) {
            rebuilt.push(row);
          }
        }
      }

      await memSvc.updateLessons(rebuilt.join('\n'));
    } catch (e) {
      console.warn('ProfileService', `updateLessonsTracking failed: ${String(e)}`);
    }
  }
}
