// 自学习引擎 — Hermes 风格持续学习，越用越聪明
// 核心能力：自适应推荐权重 / 兴趣趋势检测 / 来源质量评分 / 记忆共识生成

import { MemoryService } from './MemoryService';
import { MemoryFileHelper } from './MemoryFileHelper';
import { Constants } from '../constants/Constants';
import { DateUtil } from '../utils/DateUtil';

const TAG = 'LearningService';

// ===== 数据结构 =====

/** 推荐维度贡献快照（单篇文章） */
interface DimensionSnapshot {
  content: number; // 摘要匹配贡献
  topic: number; // 话题匹配贡献
  freshness: number; // 时效性贡献
  feed: number; // 来源匹配贡献
}

/** 推荐维度效果追踪（累积统计） */
interface DimensionTracker {
  exposures: number; // 该维度主导的曝光次数
  hits: number; // 该维度主导的命中次数（用户点击）
  totalScore: number; // 该维度累计贡献分
  lastHitDate: string; // 最近命中日期
}

/** 自适应推荐权重 */
interface AdaptiveWeights {
  content: number;
  topic: number;
  freshness: number;
  feed: number;
  updatedAt: string;
  confidence: number; // 权重置信度 [0, 1]，数据越多越接近 1
}

/** 兴趣话题趋势 */
interface TopicTrend {
  keyword: string;
  currentWeight: number;
  trend: 'emerging' | 'stable' | 'fading' | 'core';
  consecutiveGrowth: number; // 连续增长天数
  consecutiveDecline: number; // 连续下降天数
  firstSeen: string;
  lastSeen: string;
  hitCount: number; // 该话题命中的推荐点击次数
}

/** 来源质量评分 */
interface FeedQuality {
  feedTitle: string;
  qualityScore: number; // 综合质量分 [0, 1]
  engagementRate: number; // 点击率（hits/exposures）
  avgReadDuration: number; // 平均阅读时长（秒）
  consistency: number; // 内容质量一致性 [0, 1]
  recencyBonus: number; // 近期活跃加分
  updatedAt: string;
}

/** 推荐策略记录 */
interface StrategyRecord {
  date: string;
  weights: AdaptiveWeights;
  hitRate: number;
  totalExposures: number;
  totalHits: number;
}

/** 持久化的完整学习状态 */
interface LearningState {
  version: number;
  adaptiveWeights: AdaptiveWeights;
  dimensionTrackers: Record<string, DimensionTracker>;
  topicTrends: Record<string, TopicTrend>;
  feedQualities: Record<string, FeedQuality>;
  strategyHistory: StrategyRecord[];
  lastConsolidationDate: string;
  totalSessions: number;
  totalLearnings: number;
}

// ===== 默认值 =====

const DEFAULT_ADAPTIVE_WEIGHTS: AdaptiveWeights = {
  content: Constants.W_CONTENT,
  topic: Constants.W_TOPIC,
  freshness: Constants.W_FRESHNESS,
  feed: Constants.W_FEED,
  updatedAt: '',
  confidence: 0
};

const DEFAULT_STATE: LearningState = {
  version: 1,
  adaptiveWeights: { ...DEFAULT_ADAPTIVE_WEIGHTS },
  dimensionTrackers: {},
  topicTrends: {},
  feedQualities: {},
  strategyHistory: [],
  lastConsolidationDate: '',
  totalSessions: 0,
  totalLearnings: 0
};

export class LearningService {
  private static instance: LearningService;
  private state: LearningState = DEFAULT_STATE;
  private initialized: boolean = false;
  private filesDir: string = '';

  static getInstance(): LearningService {
    if (!LearningService.instance) {
      LearningService.instance = new LearningService();
    }
    return LearningService.instance;
  }

  // ==================== 初始化 ====================

  async init(): Promise<void> {
    if (this.initialized) {
      return;
    }
    const memSvc = MemoryService.getInstance();
    if (!memSvc.isReady()) {
      console.warn(TAG, 'MemoryService 未就绪，延迟初始化');
      return;
    }
    this.filesDir = memSvc.getFilesDir();
    await this.loadState();
    this.initialized = true;
    console.info(TAG,
      `自学习引擎初始化完成，累计学习 ${this.state.totalLearnings} 次，权重置信度 ${this.state.adaptiveWeights.confidence.toFixed(2)}`);
  }

  isReady(): boolean {
    return this.initialized;
  }

  // ==================== 持久化 ====================

  /**
   * 获取当前自适应推荐权重
   * 置信度低时向默认权重回归，避免冷启动偏差
   */
  getAdaptiveWeights(): AdaptiveWeights {
    const w = this.state.adaptiveWeights;
    const c = w.confidence;
    // 低保真度时向默认值回归
    if (c < Constants.LEARNING_MIN_CONFIDENCE) {
      const ratio = c / Constants.LEARNING_MIN_CONFIDENCE;
      return {
        content: this.lerp(Constants.W_CONTENT, w.content, ratio),
        topic: this.lerp(Constants.W_TOPIC, w.topic, ratio),
        freshness: this.lerp(Constants.W_FRESHNESS, w.freshness, ratio),
        feed: this.lerp(Constants.W_FEED, w.feed, ratio),
        updatedAt: w.updatedAt,
        confidence: w.confidence
      };
    }
    return w;
  }

  /**
   * 记录一次推荐结果：用户是否点击 + 阅读时长
   * 这是自学习的核心反馈信号
   */
  recordOutcome(dims: DimensionSnapshot, wasClicked: boolean, readDurationSec: number = 0): void {
    this.state.totalLearnings++;

    const dominant = this.getDominantDimension(dims);
    if (dominant === null) {
      return;
    }

    const tracker = this.ensureTracker(dominant);
    if (wasClicked) {
      tracker.hits++;
      tracker.lastHitDate = DateUtil.today();
    }

    // 每个维度都根据结果微调
    this.adjustWeightsFromOutcome(dims, wasClicked, readDurationSec);
  }

  /**
   * 检测所有话题的兴趣趋势
   * 每次 profile 更新后调用，对比当前权重与历史趋势
   */
  detectTopicTrends(topicWeights: Map<string, number>): Map<string, TopicTrend> {
    const today = DateUtil.today();
    const result = new Map<string, TopicTrend>();

    topicWeights.forEach((weight, keyword) => {
      const existing = this.state.topicTrends[keyword];
      if (existing) {
        // 更新已有话题
        const prevWeight = existing.currentWeight;
        existing.currentWeight = weight;
        existing.lastSeen = today;
        existing.hitCount++;

        // 趋势判断：双向阈值检测
        if (weight >= prevWeight * Constants.LEARNING_TOPIC_GROWTH_THRESHOLD) {
          existing.consecutiveGrowth++;
          existing.consecutiveDecline = 0;
        } else if (weight <= prevWeight * Constants.LEARNING_TOPIC_DECLINE_THRESHOLD) {
          existing.consecutiveDecline++;
          existing.consecutiveGrowth = 0;
        } else {
          // 持平：两个方向都重置
          existing.consecutiveGrowth = 0;
          existing.consecutiveDecline = 0;
        }

        existing.trend = this.classifyTrend(existing);
      } else {
        // 新话题
        const trend: TopicTrend = {
          keyword: keyword,
          currentWeight: weight,
          trend: 'emerging',
          consecutiveGrowth: 1,
          consecutiveDecline: 0,
          firstSeen: today,
          lastSeen: today,
          hitCount: 1
        };
        this.state.topicTrends[keyword] = trend;
        result.set(keyword, trend);
        return;
      }

      result.set(keyword, existing);
    });

    // 清理超过 30 天未出现的话题
    const thirtyDaysAgo = DateUtil.daysAgo(30);
    const keysToRemove: string[] = [];
    Object.keys(this.state.topicTrends).forEach(k => {
      if (this.state.topicTrends[k].lastSeen < thirtyDaysAgo) {
        keysToRemove.push(k);
      }
    });
    for (const k of keysToRemove) {
      delete this.state.topicTrends[k];
    }

    return result;
  }

  // ==================== 自适应权重核心 ====================

  /**
   * 获取新兴兴趣（用于推荐多样性）
   */
  getEmergingTopics(): TopicTrend[] {
    const result: TopicTrend[] = [];
    Object.values(this.state.topicTrends).forEach(t => {
      if (t.trend === 'emerging') {
        result.push(t);
      }
    });
    result.sort((a, b) => b.currentWeight - a.currentWeight);
    return result.slice(0, 5);
  }

  /**
   * 获取核心兴趣（最稳定的话题）
   */
  getCoreTopics(): TopicTrend[] {
    const result: TopicTrend[] = [];
    Object.values(this.state.topicTrends).forEach(t => {
      if (t.trend === 'core') {
        result.push(t);
      }
    });
    result.sort((a, b) => b.currentWeight - a.currentWeight);
    return result;
  }

  /**
   * 更新来源质量评分
   * 综合考量：点击率 + 阅读深度 + 内容一致性 + 近期活跃度
   */
  updateFeedQuality(
    feedTitle: string,
    wasClicked: boolean,
    readDurationSec: number
  ): void {
    if (!feedTitle) {
      return;
    }

    const existing = this.state.feedQualities[feedTitle];
    const today = DateUtil.today();
    const lr = Constants.LEARNING_RATE;

    if (existing) {
      // EMA 更新
      existing.engagementRate = this.lerp(
        existing.engagementRate,
        wasClicked ? 1.0 : 0.0,
        lr * 3
      );

      if (wasClicked && readDurationSec > 0) {
        existing.avgReadDuration = this.lerp(
          existing.avgReadDuration,
          Math.min(readDurationSec, 600), // cap at 10min
          lr
        );
      }

      // 近期活跃加分：最近 7 天内有互动的加分
      const daysSinceUpdate = DateUtil.daysBetween(existing.updatedAt, today);
      existing.recencyBonus = Math.max(0, 1.0 - daysSinceUpdate * 0.05);

      existing.updatedAt = today;
    } else {
      this.state.feedQualities[feedTitle] = {
        feedTitle: feedTitle,
        qualityScore: 0.5, // 中性初始值
        engagementRate: wasClicked ? 0.5 : 0.0,
        avgReadDuration: Math.min(readDurationSec, 600),
        consistency: 0.5,
        recencyBonus: 1.0,
        updatedAt: today
      };
    }

    // 重新计算综合质量分
    this.recalcFeedQuality(feedTitle);
  }

  /**
   * 获取来源质量分（供推荐引擎使用）
   * 返回 [0, 1]，分数越高来源越优质
   */
  getFeedQualityScore(feedTitle: string): number {
    const fq = this.state.feedQualities[feedTitle];
    return fq ? fq.qualityScore : 0.5; // 未知来源中性分
  }

  /**
   * 获取高质量来源 Top N
   */
  getTopQualityFeeds(n: number = 5): FeedQuality[] {
    const result: FeedQuality[] = [];
    Object.values(this.state.feedQualities).forEach(fq => {
      if (fq.engagementRate > Constants.LEARNING_FEED_ENGAGEMENT_MIN) {
        result.push(fq);
      }
    });
    result.sort((a, b) => b.qualityScore - a.qualityScore);
    return result.slice(0, n);
  }

  /**
   * 记录每日推荐策略效果
   */
  recordStrategyDay(hitRate: number, exposures: number, hits: number): void {
    const today = DateUtil.today();
    // 替换当天已有记录，避免重复
    const existingIdx = this.state.strategyHistory.findIndex(s => s.date === today);
    const record: StrategyRecord = {
      date: today,
      weights: { ...this.state.adaptiveWeights },
      hitRate: hitRate,
      totalExposures: exposures,
      totalHits: hits
    };
    if (existingIdx >= 0) {
      this.state.strategyHistory[existingIdx] = record;
    } else {
      this.state.strategyHistory.push(record);
    }
    // 保留最近 60 天
    if (this.state.strategyHistory.length > 60) {
      this.state.strategyHistory = this.state.strategyHistory.slice(-60);
    }
  }

  /**
   * 获取策略效果趋势（用于 MEMORY.md）
   */
  getStrategyTrend(): { improving: boolean; avgHitRate: number; recentRates: number[] } {
    const recent = this.state.strategyHistory.slice(-14);
    if (recent.length < 3) {
      return { improving: false, avgHitRate: 0, recentRates: [] };
    }
    const rates = recent.map(s => s.hitRate).filter(r => r >= 0);
    const avgHitRate = rates.reduce((a, b) => a + b, 0) / Math.max(1, rates.length);
    // 简单趋势：最近 3 天 vs 前 3 天
    const recent3 = rates.slice(-3);
    const prev3 = rates.slice(-6, -3);
    const recent3Avg = recent3.length > 0 ? recent3.reduce((a, b) => a + b, 0) / recent3.length : 0;
    const prev3Avg = prev3.length > 0 ? prev3.reduce((a, b) => a + b, 0) / prev3.length : 0;
    return {
      improving: recent3Avg > prev3Avg,
      avgHitRate: Math.round(avgHitRate * 1000) / 1000,
      recentRates: rates.map(r => Math.round(r * 1000) / 1000)
    };
  }

  // ==================== 兴趣趋势检测 ====================

  /**
   * 生成 Hermes 风格的记忆共识文件
   * 从所有记忆层中蒸馏出最关键的洞察
   */
  async generateConsolidatedMemory(soul: string, profile: string): Promise<string> {
    const lines: string[] = [];
    const today = DateUtil.today();

    lines.push('# 记忆共识 (Memory Consensus)');
    lines.push(`> 自动生成于 ${today}，蒸馏自所有记忆层的高阶洞察`);
    lines.push('');

    // ---- 自适应权重 ----
    const w = this.state.adaptiveWeights;
    lines.push('## 推荐策略');
    lines.push('');
    lines.push(`- **内容匹配权重**: ${w.content.toFixed(2)} ${this.describeWeightChange('content')}`);
    lines.push(`- **话题匹配权重**: ${w.topic.toFixed(2)} ${this.describeWeightChange('topic')}`);
    lines.push(`- **时效性权重**: ${w.freshness.toFixed(2)} ${this.describeWeightChange('freshness')}`);
    lines.push(`- **来源偏好权重**: ${w.feed.toFixed(2)} ${this.describeWeightChange('feed')}`);
    lines.push(`- **权重置信度**: ${(w.confidence * 100).toFixed(0)}%（${this.state.totalLearnings} 次学习）`);
    lines.push('');

    // ---- 策略效果 ----
    const strategy = this.getStrategyTrend();
    if (strategy.avgHitRate > 0) {
      const trend = strategy.improving ? '📈 提升中' : '📉 待优化';
      lines.push(`- **近期推荐命中率**: ${(strategy.avgHitRate * 100).toFixed(1)}% ${trend}`);
      lines.push('');
    }

    // ---- 兴趣趋势 ----
    const coreTopics = this.getCoreTopics();
    const emergingTopics = this.getEmergingTopics();
    lines.push('## 兴趣地图');
    lines.push('');

    if (coreTopics.length > 0) {
      lines.push('### 核心兴趣 🔒');
      for (const t of coreTopics.slice(0, 5)) {
        lines.push(`- **${t.keyword}** (weight: ${t.currentWeight.toFixed(2)}, hits: ${t.hitCount})`);
      }
      lines.push('');
    }

    if (emergingTopics.length > 0) {
      lines.push('### 新兴兴趣 🌱');
      for (const t of emergingTopics) {
        lines.push(`- **${t.keyword}** (weight: ${t.currentWeight.toFixed(2)}, 连续 ${t.consecutiveGrowth} 天增长)`);
      }
      lines.push('');
    }

    // 衰减兴趣
    const fadingTopics = Object.values(this.state.topicTrends).filter(t => t.trend === 'fading');
    if (fadingTopics.length > 0) {
      lines.push('### 衰减兴趣 🍂');
      for (const t of fadingTopics.slice(0, 3)) {
        lines.push(`- **${t.keyword}** (连续 ${t.consecutiveDecline} 天下降)`);
      }
      lines.push('');
    }

    // ---- 来源质量 ----
    const topFeeds = this.getTopQualityFeeds(5);
    if (topFeeds.length > 0) {
      lines.push('## 优质来源');
      lines.push('');
      lines.push('| 来源 | 质量分 | 点击率 | 平均阅读 |');
      lines.push('|------|--------|--------|----------|');
      for (const fq of topFeeds) {
        const rate = (fq.engagementRate * 100).toFixed(0);
        const dur = fq.avgReadDuration > 60
          ? `${(fq.avgReadDuration / 60).toFixed(1)}分`
          : `${Math.round(fq.avgReadDuration)}秒`;
        lines.push(`| ${fq.feedTitle} | ${fq.qualityScore.toFixed(2)} | ${rate}% | ${dur} |`);
      }
      lines.push('');
    }

    // ---- 维度效果 ----
    lines.push('## 推荐维度效果');
    lines.push('');
    lines.push('| 维度 | 曝光 | 命中 | 命中率 |');
    lines.push('|------|------|------|--------|');
    const dimKeys: (keyof DimensionSnapshot)[] = ['content', 'topic', 'freshness', 'feed'];
    const dimLabels: Record<string, string> = {
      'content': '内容匹配',
      'topic': '话题匹配',
      'freshness': '时效性',
      'feed': '来源偏好'
    };
    for (const k of dimKeys) {
      const t = this.state.dimensionTrackers[k as string];
      if (t && t.exposures > 0) {
        const hitRate = (t.hits / t.exposures * 100).toFixed(1);
        lines.push(`| ${dimLabels[k as string]} | ${t.exposures} | ${t.hits} | ${hitRate}% |`);
      }
    }

    return lines.join('\n');
  }

  /**
   * 每次首页加载时调用，递增会话计数
   */
  recordSession(): void {
    this.state.totalSessions++;
  }

  /**
   * 每日简报/画像更新后保存学习状态
   */
  async persist(): Promise<void> {
    await this.saveState();
  }

  /**
   * 运行每日学习维护：清理旧数据 + 保存状态
   */
  async dailyLearningMaintenance(): Promise<void> {
    if (!this.initialized) {
      return;
    }
    const today = DateUtil.today();
    if (this.state.lastConsolidationDate === today) {
      return;
    }

    // 清理过期策略记录
    const cutoff = DateUtil.daysAgo(60);
    this.state.strategyHistory = this.state.strategyHistory.filter(s => s.date >= cutoff);

    this.state.lastConsolidationDate = today;
    await this.saveState();
    console.info(TAG, `每日学习维护完成，累计 ${this.state.totalLearnings} 次学习`);
  }

  // ==================== 来源质量评分 ====================

  /**
   * 导出学习数据（供备份）
   */
  exportLearningData(): string {
    return JSON.stringify(this.state, null, 2);
  }

  /**
   * 重置学习数据
   */
  async resetLearning(): Promise<void> {
    this.state = { ...DEFAULT_STATE };
    this.state.totalSessions = 0;
    this.state.totalLearnings = 0;
    await this.saveState();
    console.info(TAG, '学习数据已重置');
  }

  private statePath(): string {
    return `${this.filesDir}/${Constants.LEARNING_STATE_FILE}`;
  }

  private async loadState(): Promise<void> {
    try {
      const exists = await MemoryFileHelper.exists(this.statePath());
      if (!exists) {
        return;
      }
      const raw = await MemoryFileHelper.readMarkdown(this.statePath());
      if (!raw.trim()) {
        return;
      }
      const parsed = JSON.parse(raw) as LearningState;
      if (parsed.version === 1) {
        this.state = parsed;
        console.info(TAG, `学习状态已加载 (${raw.length} bytes)`);
      }
    } catch (e) {
      console.warn(TAG, `加载学习状态失败: ${e}`);
    }
  }

  // ==================== 策略历史记录 ====================

  private async saveState(): Promise<void> {
    if (!this.initialized) {
      return;
    }
    try {
      const json = JSON.stringify(this.state);
      await MemoryFileHelper.writeMarkdown(this.statePath(), json);
    } catch (e) {
      console.warn(TAG, `保存学习状态失败: ${e}`);
    }
  }

  private lerp(defaultVal: number, learnedVal: number, ratio: number): number {
    return Math.round((defaultVal + (learnedVal - defaultVal) * ratio) * 1000) / 1000;
  }

  // ==================== 记忆共识生成 (MEMORY.md) ====================

  private getDominantDimension(dims: DimensionSnapshot): keyof DimensionSnapshot | null {
    let maxKey: keyof DimensionSnapshot | null = null;
    let maxVal = 0;
    const keys: (keyof DimensionSnapshot)[] = ['content', 'topic', 'freshness', 'feed'];
    for (const k of keys) {
      if (dims[k] > maxVal) {
        maxVal = dims[k];
        maxKey = k;
      }
    }
    return maxKey;
  }

  private ensureTracker(dim: keyof DimensionSnapshot): DimensionTracker {
    const key = dim as string;
    if (!this.state.dimensionTrackers[key]) {
      this.state.dimensionTrackers[key] = {
        exposures: 0,
        hits: 0,
        totalScore: 0,
        lastHitDate: ''
      };
    }
    return this.state.dimensionTrackers[key];
  }

  // ==================== 会话与持久化 ====================

  /**
   * 根据单次反馈微调权重（在线学习）
   */
  private adjustWeightsFromOutcome(
    dims: DimensionSnapshot,
    wasClicked: boolean,
    readDurationSec: number
  ): void {
    const w = this.state.adaptiveWeights;
    const lr = Constants.LEARNING_RATE; // 学习率

    // 深度阅读（>60s）给予更强正反馈
    const depthBonus = readDurationSec > 60 ? 1.5 : 1.0;
    // 快速跳过（<10s 但点击了）给予弱负反馈
    const skimPenalty = (wasClicked && readDurationSec > 0 && readDurationSec < 10) ? 0.5 : 1.0;

    const totalDims = dims.content + dims.topic + dims.freshness + dims.feed;
    if (totalDims < 0.001) {
      return;
    }

    if (wasClicked) {
      // 点击：按各维度贡献比例正向调整
      w.content += lr * (dims.content / totalDims) * depthBonus * skimPenalty;
      w.topic += lr * (dims.topic / totalDims) * depthBonus * skimPenalty;
      w.freshness += lr * (dims.freshness / totalDims) * depthBonus * skimPenalty;
      w.feed += lr * (dims.feed / totalDims) * depthBonus * skimPenalty;
    } else {
      // 未点击：主导维度轻微负向调整
      const dominant = this.getDominantDimension(dims);
      if (dominant) {
        w[dominant] -= lr * 0.3;
      }
    }

    // 归一化权重总和为 1
    this.normalizeWeights(w);
    w.updatedAt = DateUtil.today();

    // 更新置信度（随学习次数逐步接近 1）
    w.confidence = Math.min(0.95, this.state.totalLearnings / Constants.LEARNING_MATURE_THRESHOLD);
  }

  private normalizeWeights(w: AdaptiveWeights): void {
    const sum = w.content + w.topic + w.freshness + w.feed;
    if (sum < 0.01) {
      // 退化到默认值
      w.content = Constants.W_CONTENT;
      w.topic = Constants.W_TOPIC;
      w.freshness = Constants.W_FRESHNESS;
      w.feed = Constants.W_FEED;
      return;
    }
    w.content = Math.round((w.content / sum) * 1000) / 1000;
    w.topic = Math.round((w.topic / sum) * 1000) / 1000;
    w.freshness = Math.round((w.freshness / sum) * 1000) / 1000;
    w.feed = Math.round((w.feed / sum) * 1000) / 1000;
  }

  private classifyTrend(t: TopicTrend): 'emerging' | 'stable' | 'fading' | 'core' {
    if (t.hitCount >= 10 && t.currentWeight >= 0.3) {
      return 'core'; // 长期高频话题
    }
    if (t.consecutiveGrowth >= Constants.LEARNING_CONSECUTIVE_DAYS) {
      return 'emerging';
    }
    if (t.consecutiveDecline >= Constants.LEARNING_CONSECUTIVE_DAYS) {
      return 'fading';
    }
    return 'stable';
  }

  private recalcFeedQuality(feedTitle: string): void {
    const fq = this.state.feedQualities[feedTitle];
    if (!fq) {
      return;
    }

    // 综合质量分 = 点击率*0.4 + 阅读深度*0.3 + 一致性*0.2 + 近期活跃*0.1
    const depthScore = Math.min(1.0, fq.avgReadDuration / 180); // 3分钟为满分
    fq.qualityScore = Math.round((
      fq.engagementRate * 0.4 +
        depthScore * 0.3 +
        fq.consistency * 0.2 +
        fq.recencyBonus * 0.1
    ) * 1000) / 1000;
  }

  private describeWeightChange(dim: keyof DimensionSnapshot): string {
    const d = Constants as Record<string, number>;
    const defaultMap: Record<string, number> = {
      'content': Constants.W_CONTENT,
      'topic': Constants.W_TOPIC,
      'freshness': Constants.W_FRESHNESS,
      'feed': Constants.W_FEED
    };
    const def = defaultMap[dim];
    const cur = this.state.adaptiveWeights[dim];
    const diff = cur - def;
    if (Math.abs(diff) < 0.02) {
      return '(与默认持平)';
    }
    return diff > 0 ? `↑ 高于默认 ${diff.toFixed(2)}` : `↓ 低于默认 ${Math.abs(diff).toFixed(2)}`;
  }
}

// 单例引用缓存
let instance: LearningService | null = null;

export function getLearningService(): LearningService {
  if (!instance) {
    instance = LearningService.getInstance();
  }
  return instance;
}
