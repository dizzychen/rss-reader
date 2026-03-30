// 简报生命周期管理服务（生成、解析）
import { Article, BriefingData, BriefingItem, BriefingLevel, BriefingSkipItem, TimelineEntry } from '../model/Models';
import { AIService } from './AIService';
import { SettingsService } from './SettingsService';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { Constants } from '../constants/Constants';
import { DateUtil } from '../utils/DateUtil';

/** AI 返回的 JSON 中单条推荐的原始结构 */
interface RawRecommended {
  index: number;
  title: string;
  source: string;
  reason: string;
  level: string;
}

/** AI 返回的 JSON 中单条可跳过的原始结构 */
interface RawSkippable {
  index: number;
  title: string;
  reason: string;
}

/** AI 返回的 JSON 中单条时间轴的原始结构 */
interface RawTimeline {
  time: string;
  headline: string;
  brief: string;
  index: number;
}

/** AI 返回的完整 JSON 结构 */
interface RawBriefingJSON {
  summary: string;
  recommended: RawRecommended[];
  skippable: RawSkippable[];
  timeline: RawTimeline[];
}

export class BriefingService {
  private static instance: BriefingService;

  static getInstance(): BriefingService {
    if (!BriefingService.instance) {
      BriefingService.instance = new BriefingService();
    }
    return BriefingService.instance;
  }

  /**
   * 生成简报（调 AI + 解析 JSON + 映射 articleId）
   */
  async generate(): Promise<BriefingData> {
    const today = DateUtil.today();

    // 获取未读文章
    const articles: Article[] = await DatabaseHelper.getInstance().getAllArticles(true, 50, 0);
    if (articles.length === 0) {
      const empty: BriefingData = {
        summary: '暂无未读文章',
        recommended: [],
        skippable: [],
        timeline: [],
        generatedAt: `${today} ${DateUtil.formatTime(new Date())}`,
        articleCount: 0
      };
      return empty;
    }

    // 给文章附上 feedTitle
    const feeds = await DatabaseHelper.getInstance().getAllFeeds();
    const feedMap = new Map<number, string>();
    for (const f of feeds) {
      feedMap.set(f.id!, f.title);
    }
    for (const a of articles) {
      if (!a.feedTitle) {
        a.feedTitle = feedMap.get(a.feedId) ?? '';
      }
    }

    // 获取用户偏好的推荐数量
    const briefingCount = await SettingsService.getInstance().getBriefingCount();

    // 检查 AI Key
    if (!AIService.getInstance().hasApiKey()) {
      const noKey: BriefingData = {
        summary: '请先配置 AI API Key',
        recommended: [],
        skippable: [],
        timeline: [],
        generatedAt: `${today} ${DateUtil.formatTime(new Date())}`,
        articleCount: articles.length
      };
      return noKey;
    }

    // 调用 AI 生成
    const rawJson = await AIService.getInstance().generateBriefing(articles, briefingCount);

    // 解析 JSON 并映射 articleId
    const briefing = this.parseAIResponse(rawJson, articles);
    briefing.generatedAt = `${today} ${DateUtil.formatTime(new Date())}`;
    briefing.articleCount = articles.length;

    return briefing;
  }

  /**
   * 解析 AI 返回的 JSON，映射 index → articleId
   */
  private parseAIResponse(rawResponse: string, articles: Article[]): BriefingData {
    const defaultData: BriefingData = {
      summary: '',
      recommended: [],
      skippable: [],
      timeline: [],
      generatedAt: '',
      articleCount: articles.length
    };

    try {
      // 提取 JSON 部分（AI 可能在 JSON 前后加文字）
      const jsonMatch = rawResponse.match(/\{[\s\S]*\}/);
      if (!jsonMatch) {
        console.warn('BriefingService', 'no JSON found in AI response, using raw text');
        defaultData.summary = rawResponse.substring(0, 200);
        return defaultData;
      }

      const parsed = JSON.parse(jsonMatch[0]) as RawBriefingJSON;

      defaultData.summary = parsed.summary ?? '';

      // 映射推荐文章
      if (Array.isArray(parsed.recommended)) {
        for (const r of parsed.recommended) {
          const idx = (r.index ?? 0) - 1; // 转为 0-based
          if (idx >= 0 && idx < articles.length) {
            const a = articles[idx];
            const level = this.normalizeLevel(r.level);
            const item: BriefingItem = {
              articleId: a.id ?? -1,
              title: r.title ?? a.title,
              source: r.source ?? a.feedTitle ?? '',
              reason: r.reason ?? '',
              level: level
            };
            defaultData.recommended.push(item);
          }
        }
      }

      // 映射可跳过文章
      if (Array.isArray(parsed.skippable)) {
        for (const s of parsed.skippable) {
          const idx = (s.index ?? 0) - 1;
          if (idx >= 0 && idx < articles.length) {
            const a = articles[idx];
            const skip: BriefingSkipItem = {
              articleId: a.id ?? -1,
              title: s.title ?? a.title,
              reason: s.reason ?? ''
            };
            defaultData.skippable.push(skip);
          }
        }
      }

      // 映射时间轴
      if (Array.isArray(parsed.timeline)) {
        for (const t of parsed.timeline) {
          const idx = (t.index ?? 0) - 1;
          let articleId = -1;
          if (idx >= 0 && idx < articles.length) {
            articleId = articles[idx].id ?? -1;
          }
          const entry: TimelineEntry = {
            time: t.time ?? '',
            headline: t.headline ?? '',
            brief: t.brief ?? '',
            articleId: articleId
          };
          defaultData.timeline.push(entry);
        }
      }

      return defaultData;
    } catch (e) {
      console.warn('BriefingService', `parseAIResponse failed: ${e}, using raw text`);
      defaultData.summary = rawResponse.substring(0, 200);
      return defaultData;
    }
  }

  /**
   * 规范化推荐等级
   */
  private normalizeLevel(level: string): BriefingLevel {
    const l = (level ?? '').toLowerCase();
    if (l === 'high') return 'high';
    if (l === 'medium') return 'medium';
    if (l === 'low') return 'low';
    return 'medium';
  }
}
