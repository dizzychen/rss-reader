// 画像计算服务 - 基于 30 天行为数据生成用户画像
import { DailyStats, InterestWeight, UserProfile } from '../model/Models';
import { MemoryFileHelper } from './MemoryFileHelper';
import { MemoryService } from './MemoryService';
import { InterestCalculator } from '../utils/InterestCalculator';
import { DateUtil } from '../utils/DateUtil';
import { Constants } from '../constants/Constants';

/** aggregateStats 返回类型 */
interface AggregatedStats {
  totalReadDays: number;
  totalArticles: number;
  avgDailyRead: number;
  feedSignals: Map<string, number>;
  avgReadDuration: number;
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
      avgReadDuration: 0,
      topFeeds: [],
      starFeeds: [],
      topKeywords: []
    };

    const feedCount = new Map<string, number>();
    const feedStar = new Map<string, number>();
    const keywords: string[] = [];
    let totalDuration = 0;
    let durationCount = 0;

    const lines = content.split('\n');
    for (const line of lines) {
      if (!line.startsWith('| ') || line.startsWith('| 时间') || line.startsWith('|---')) {
        continue;
      }
      const parts = line.split('|').map(s => s.trim()).filter(s => s.length > 0);
      if (parts.length < 4) {
        continue;
      }
      const action = parts[1];
      const feed = parts[3];
      const extra = parts.length >= 5 ? parts[4] : '-';

      if (action === 'READ') {
        stats.readCount++;
        if (feed && feed !== '-') {
          feedCount.set(feed, (feedCount.get(feed) ?? 0) + 1);
        }
      } else if (action === 'READ_END') {
        // 解析时长
        const secs = this.parseDurationToSeconds(extra);
        if (secs > 0) {
          totalDuration += secs;
          durationCount++;
        }
      } else if (action === 'STAR') {
        stats.starCount++;
        // 收藏行为也计入订阅源统计（权重更高，在 calcSignal 中 ×3）
        if (feed && feed !== '-') {
          feedStar.set(feed, (feedStar.get(feed) ?? 0) + 1);
        }
      } else if (action === 'SEARCH') {
        stats.searchCount++;
        if (extra && extra !== '-') {
          keywords.push(extra);
        }
      }
    }

    if (durationCount > 0) {
      stats.avgReadDuration = Math.round(totalDuration / durationCount);
    }

    // 取阅读最多的前3个订阅源
    const feedEntries: Array<[string, number]> = [];
    feedCount.forEach((cnt, name) => {
      feedEntries.push([name, cnt]);
    });
    feedEntries.sort((a, b) => b[1] - a[1]);
    stats.topFeeds = feedEntries.slice(0, 3).map(entry => entry[0]);

    // 去重关键词，保留最多5个
    const seenKeywords = new Set<string>();
    const uniqueKeywords: string[] = [];
    for (const kw of keywords) {
      if (!seenKeywords.has(kw)) {
        seenKeywords.add(kw);
        uniqueKeywords.push(kw);
      }
    }
    stats.topKeywords = uniqueKeywords.slice(0, 5);

    // 收集收藏文章的订阅源
    const starFeedsArray: string[] = [];
    feedStar.forEach((_cnt, name) => {
      starFeedsArray.push(name);
    });
    stats.starFeeds = starFeedsArray;

    return stats;
  }

  /**
   * 解析时长字符串为秒数
   * 支持格式：Xs, Xm Ys, Xh Ym
   */
  private parseDurationToSeconds(durationStr: string): number {
    if (!durationStr || durationStr === '-') {
      return 0;
    }
    // 格式：X秒
    if (durationStr.endsWith('秒') && !durationStr.includes('分')) {
      return parseInt(durationStr.replace('秒', ''), 10) || 0;
    }
    // 格式：X分YY秒
    if (durationStr.includes('分') && durationStr.includes('秒')) {
      const parts = durationStr.split('分');
      const minutes = parseInt(parts[0], 10) || 0;
      const secs = parseInt(parts[1].replace('秒', ''), 10) || 0;
      return minutes * 60 + secs;
    }
    // 格式：X小时YY分
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
    let totalDuration = 0;
    let durationCount = 0;

    for (const d of dailyStatsList) {
      // 统计阅读的订阅源
      for (const feed of d.topFeeds) {
        feedCount.set(feed, (feedCount.get(feed) ?? 0) + 1);
      }
      // 统计收藏的订阅源
      for (const feed of d.starFeeds) {
        feedStar.set(feed, (feedStar.get(feed) ?? 0) + 1);
      }
      if (d.avgReadDuration > 0) {
        totalDuration += d.avgReadDuration;
        durationCount++;
      }
    }

    // 计算每个订阅源的信号强度（阅读 + 收藏）
    const feedSignals = new Map<string, number>();
    // 首先处理有阅读记录的订阅源
    feedCount.forEach((count, feed) => {
      const starCount = feedStar.get(feed) ?? 0;
      const signal = InterestCalculator.calcSignal(count, starCount, dailyStatsList.length);
      feedSignals.set(feed, signal);
    });
    // 然后处理只有收藏但没有阅读记录的订阅源
    feedStar.forEach((starCount, feed) => {
      if (!feedCount.has(feed)) {
        const signal = InterestCalculator.calcSignal(0, starCount, dailyStatsList.length);
        feedSignals.set(feed, signal);
      }
    });

    const avgDuration = durationCount > 0 ? Math.round(totalDuration / durationCount) : 0;

    const result: AggregatedStats = {
      totalReadDays: activeDays.length,
      totalArticles: totalArticles,
      avgDailyRead: avgDailyRead,
      feedSignals: feedSignals,
      avgReadDuration: avgDuration
    };
    return result;
  }

  /**
   * 重新生成用户画像并保存
   */
  async regenerate(): Promise<void> {
    const memSvc = MemoryService.getInstance();
    if (!memSvc.isReady()) {
      return;
    }

    try {
      const filesDir = memSvc.getFilesDir();
      const dailyDir = `${filesDir}/${Constants.MEMORY_DAILY_DIR}`;
      const files = await MemoryFileHelper.listFiles(dailyDir);

      // 读取最近 30 天的日志
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

      // 生成新的画像 Markdown
      const profileContent = this.buildProfileMarkdown({
        generatedAt: today,
        totalReadDays: aggregated.totalReadDays,
        totalArticles: aggregated.totalArticles,
        avgDailyRead: aggregated.avgDailyRead,
        feedInterests: updatedFeedWeights,
        topicInterests: [],
        preferredReadTime: this.calcPreferredReadTime(dailyStatsList),
        avgReadDuration: aggregated.avgReadDuration
      });

      await memSvc.updateProfile(profileContent);
      console.info('ProfileService', 'regenerate done');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('ProfileService', `regenerate failed: ${msg}`);
    }
  }

  /**
   * 从已有画像内容中解析兴趣权重
   */
  private parseExistingWeights(content: string): InterestWeight[] {
    const feedSection = this.extractSection(content, '## 订阅源偏好');
    if (!feedSection) {
      return [];
    }
    return InterestCalculator.parseFromMarkdown(feedSection);
  }

  /**
   * 提取 Markdown 中某个 ## 章节的内容
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
   * 计算偏好阅读时段（基于日志时间统计，简化版：使用固定偏好）
   */
  private calcPreferredReadTime(_dailyStatsList: DailyStats[]): string {
    // TODO: 实现时段统计（需要从行为时间戳分析），当前返回占位文本
    return '待分析';
  }

  /**
   * 构建用户画像 Markdown 内容
   */
  buildProfileMarkdown(profile: UserProfile): string {
    const lines: string[] = [
      `# 阅读画像`,
      ``,
      `> 生成时间：${profile.generatedAt}`,
      ``,
      `## 阅读概览`,
      ``,
      `| 指标 | 数值 |`,
      `|------|------|`,
      `| 累计阅读天数 | ${profile.totalReadDays} 天 |`,
      `| 累计阅读文章 | ${profile.totalArticles} 篇 |`,
      `| 日均阅读 | ${profile.avgDailyRead} 篇 |`,
      `| 平均阅读时长 | ${DateUtil.formatDuration(profile.avgReadDuration)} |`,
      `| 偏好阅读时段 | ${profile.preferredReadTime} |`,
      ``,
      `## 订阅源偏好`,
      ``,
      InterestCalculator.serializeToMarkdown(profile.feedInterests),
    ];

    if (profile.topicInterests.length > 0) {
      lines.push(`## 话题偏好`, ``, InterestCalculator.serializeToMarkdown(profile.topicInterests));
    }

    return lines.join('\n');
  }
}
