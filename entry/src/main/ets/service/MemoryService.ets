// 记忆服务核心 - 三层记忆架构（SOUL / PROFILE / DAILY）
import { common } from '@kit.AbilityKit';
import { Constants } from '../constants/Constants';
import { UserBehavior } from '../model/Models';
import { MemoryFileHelper } from './MemoryFileHelper';
import { util } from '@kit.ArkTS';
import { DateUtil } from '../utils/DateUtil';
import { MarkdownUtil } from '../utils/MarkdownUtil';

// 延迟导入 ProfileService 的回调，由 EntryAbility 注入，避免循环依赖
let profileRegenerateCallback: (() => Promise<void>) | null = null;
let profileQuickRefreshCallback: (() => Promise<void>) | null = null;

export function setProfileRegenerateCallback(cb: () => Promise<void>): void {
  profileRegenerateCallback = cb;
}

export function setProfileQuickRefreshCallback(cb: () => Promise<void>): void {
  profileQuickRefreshCallback = cb;
}

export class MemoryService {
  private static instance: MemoryService;
  private filesDir: string = '';
  private initialized: boolean = false;

  // 防抖队列
  private behaviorQueue: UserBehavior[] = [];
  private flushTimer: number = -1;

  // AI 排序缓存
  private aiRankCache: number[] = [];           // 排序后的 articleId 数组
  private aiRankCacheTime: number = 0;          // 缓存时间戳

  // 日内阅读计数器（内存变量，不持久化，用于触发 quickRefresh）
  private todayReadCount: number = 0;
  private todayReadDate: string = '';           // 当前计数对应的日期
  private quickRefreshTriggered: boolean = false; // 本日是否已触发过 quickRefresh

  static getInstance(): MemoryService {
    if (!MemoryService.instance) {
      MemoryService.instance = new MemoryService();
    }
    return MemoryService.instance;
  }

  /**
   * 初始化记忆系统，在 EntryAbility.onCreate 中调用
   * @param context 应用上下文
   * @param soulTemplate SOUL.md 模板内容（由 EntryAbility 从 rawfile 读取后传入）
   * @param profileTemplate PROFILE.md 模板内容（由 EntryAbility 从 rawfile 读取后传入）
   */
  async init(context: common.Context, soulTemplate: string = '', profileTemplate: string = '', lessonsTemplate: string = ''): Promise<void> {
    if (this.initialized) {
      return;
    }
    try {
      this.filesDir = context.filesDir;
      console.info('MemoryService', `init filesDir: ${this.filesDir}`);

      // 确保记忆目录结构存在
      try {
        await MemoryFileHelper.ensureDir(`${this.filesDir}/${Constants.MEMORY_DIR}`);
        console.info('MemoryService', `主目录已就绪: ${this.filesDir}/${Constants.MEMORY_DIR}`);
      } catch (dirErr) {
        const msg = dirErr instanceof Error ? dirErr.message : String(dirErr);
        console.warn('MemoryService', `主目录创建失败: ${msg}，继续尝试创建子目录`);
      }

      try {
        await MemoryFileHelper.ensureDir(`${this.filesDir}/${Constants.MEMORY_DAILY_DIR}`);
        console.info('MemoryService', `日志子目录已就绪: ${this.filesDir}/${Constants.MEMORY_DAILY_DIR}`);
      } catch (dirErr) {
        const msg = dirErr instanceof Error ? dirErr.message : String(dirErr);
        console.warn('MemoryService', `日志子目录创建失败: ${msg}`);
      }

      // 首次使用时写入模板（仅在文件不存在时）
      await this.initializeFromTemplates(soulTemplate, profileTemplate, lessonsTemplate);

      this.initialized = true;
      console.info('MemoryService', 'init success, filesDir=' + this.filesDir);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryService', `init failed: ${msg}`);
      // 标记为已初始化（部分初始化），避免反复重试
      this.initialized = true;
    }
  }

  /**
   * 首次安装时初始化记忆文件。
   * - SOUL.md：用户手动编辑，首次安装时从模板初始化，后续不覆盖
   * - PROFILE.md：系统自动生成，首次安装时创建空骨架，后续由 ProfileService 更新
   *
   * 参照 OpenClaw 三层记忆架构设计。
   */
  private async initializeFromTemplates(soulTemplate: string, _profileTemplate: string, lessonsTemplate: string = ''): Promise<void> {
    const soulPath = `${this.filesDir}/${Constants.MEMORY_SOUL_FILE}`;
    const profilePath = `${this.filesDir}/${Constants.MEMORY_PROFILE_FILE}`;
    const lessonsPath = `${this.filesDir}/${Constants.MEMORY_LESSONS_FILE}`;

    // ===== SOUL.md：用户手动编辑的灵魂档案 =====
    // 仅在文件不存在时从模板初始化，后续用户修改不会被覆盖
    const soulExists = await MemoryFileHelper.exists(soulPath);
    console.info('MemoryService', `SOUL.md exists=${soulExists}, path=${soulPath}`);
    if (!soulExists && soulTemplate.trim()) {
      try {
        await MemoryFileHelper.writeMarkdown(soulPath, soulTemplate);
        const bytes = new util.TextEncoder().encodeInto(soulTemplate).length;
        console.info('MemoryService', `SOUL.md 首次初始化成功 (${bytes} bytes)`);
      } catch (e) {
        console.error('MemoryService', `SOUL.md 写入失败: ${String(e)}`);
      }
    } else if (soulExists) {
      console.info('MemoryService', 'SOUL.md 已存在，保留用户数据');
    }

    // ===== PROFILE.md：系统自动生成的画像文件 =====
    // 仅在文件不存在时创建空骨架，后续由 ProfileService.regenerate() 自动更新
    const profileExists = await MemoryFileHelper.exists(profilePath);
    console.info('MemoryService', `PROFILE.md exists=${profileExists}, path=${profilePath}`);
    if (!profileExists) {
      try {
        // 创建最小骨架，等待系统自动填充
        const emptyProfile = `# 阅读画像\n\n> 系统将根据阅读行为自动生成画像，请先阅读几篇文章。\n`;
        await MemoryFileHelper.writeMarkdown(profilePath, emptyProfile);
        console.info('MemoryService', 'PROFILE.md 首次初始化（空骨架）');
      } catch (e) {
        console.error('MemoryService', `PROFILE.md 写入失败: ${String(e)}`);
      }
    } else {
      console.info('MemoryService', 'PROFILE.md 已存在，由 ProfileService 管理');
    }

    // ===== LESSONS.md：经验教训层 =====
    // 仅在文件不存在时从模板初始化
    const lessonsExists = await MemoryFileHelper.exists(lessonsPath);
    console.info('MemoryService', `LESSONS.md exists=${lessonsExists}, path=${lessonsPath}`);
    if (!lessonsExists) {
      try {
        const content = lessonsTemplate.trim()
          ? lessonsTemplate
          : `# 阅读经验\n\n> 系统将根据阅读行为自动沉淀经验教训。\n\n## 成功模式 🎯\n\n## 反模式 🚫\n\n## 推荐优化 ⚡\n\n## 推荐效果追踪\n\n| 日期 | 命中率 | 曝光数 | 点击数 |\n|------|--------|--------|--------|\n`;
        await MemoryFileHelper.writeMarkdown(lessonsPath, content);
        console.info('MemoryService', 'LESSONS.md 首次初始化');
      } catch (e) {
        console.error('MemoryService', `LESSONS.md 写入失败: ${String(e)}`);
      }
    } else {
      console.info('MemoryService', 'LESSONS.md 已存在');
    }
  }

  /**
   * 判断是否已初始化
   */
  isReady(): boolean {
    return this.initialized;
  }

  /**
   * 获取 filesDir（供其他方法使用）
   */
  getFilesDir(): string {
    return this.filesDir;
  }

  // ===== 行为采集 =====

  /**
   * 记录用户行为（防抖批量写入）
   */
  recordBehavior(behavior: UserBehavior): void {
    if (!this.initialized) {
      return;
    }
    this.behaviorQueue.push(behavior);

    // 日内阅读计数 + quickRefresh 触发
    if (behavior.action === 'READ') {
      const today = DateUtil.today();
      if (this.todayReadDate !== today) {
        this.todayReadCount = 0;
        this.todayReadDate = today;
        this.quickRefreshTriggered = false;
      }
      this.todayReadCount++;
      if (!this.quickRefreshTriggered && this.todayReadCount >= Constants.QUICK_REFRESH_THRESHOLD) {
        this.quickRefreshTriggered = true;
        // 异步触发，不阻塞当前行为记录
        if (profileQuickRefreshCallback) {
          profileQuickRefreshCallback().then(() => {
            // quickRefresh 后清除推荐缓存，下次加载首页使用最新画像
            this.clearAIRankCache();
            console.info('MemoryService', 'quickRefresh triggered and caches cleared');
          }).catch((e: Error) => {
            console.warn('MemoryService', `quickRefresh callback failed: ${e.message}`);
          });
        }
      }
    }

    // 清除已有定时器，重置防抖
    if (this.flushTimer !== -1) {
      clearTimeout(this.flushTimer);
    }
    this.flushTimer = setTimeout(() => {
      this.flushBehaviors();
      this.flushTimer = -1;
    }, Constants.BEHAVIOR_FLUSH_DELAY);
  }

  /**
   * 立即将队列中的行为刷写到日志文件
   */
  async flushBehaviors(): Promise<void> {
    if (this.behaviorQueue.length === 0) {
      return;
    }
    const toFlush: UserBehavior[] = [];
    for (const item of this.behaviorQueue) {
      toFlush.push(item);
    }
    this.behaviorQueue = [];

    try {
      const today = DateUtil.today();
      const logPath = `${this.filesDir}/${Constants.MEMORY_DAILY_DIR}/${today}.md`;

      // 如果日志文件不存在，写入表头
      const exists = await MemoryFileHelper.exists(logPath);
      if (!exists) {
        const header = this.createDailyLogHeader(today);
        await MemoryFileHelper.writeMarkdown(logPath, header);
      }

      // 追加行为记录
      let lines = '';
      for (const b of toFlush) {
        lines += this.formatBehaviorLine(b) + '\n';
      }
      await MemoryFileHelper.appendMarkdown(logPath, lines);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryService', `flushBehaviors failed: ${msg}`);
      // 回滚：将未写入的行为放回队列头部
      const combined: UserBehavior[] = [];
      for (const item of toFlush) {
        combined.push(item);
      }
      for (const item of this.behaviorQueue) {
        combined.push(item);
      }
      this.behaviorQueue = combined;
    }
  }

  /**
   * 创建每日日志文件头（Markdown 表格格式）
   */
  createDailyLogHeader(date: string): string {
    return `# 阅读日志 ${date}\n\n| 时间 | 行为 | 文章 | 来源 | 时长/关键词 |\n|------|------|------|------|----------|\n`;
  }

  /**
   * 格式化单条行为为表格行
   */
  formatBehaviorLine(b: UserBehavior): string {
    const d = new Date(b.timestamp);
    const time = DateUtil.formatTime(d);
    const action = b.action;
    const title = b.articleTitle ? b.articleTitle.substring(0, 80).replace(/\|/g, '\\|') : '-';
    const feed = b.feedTitle ? b.feedTitle.replace(/\|/g, '\\|') : '-';
    let extra = '-';
    if (b.action === 'READ_END' && b.duration !== undefined) {
      extra = DateUtil.formatDuration(b.duration);
    } else if (b.action === 'SEARCH' && b.keyword) {
      extra = b.keyword.replace(/\|/g, '\\|');
    } else if (b.action === 'RATE' && b.score !== undefined) {
      extra = b.score > 0 ? '👍' : '👎';
    }
    return `| ${time} | ${action} | ${title} | ${feed} | ${extra} |`;
  }

  // ===== SOUL 操作 =====

  /**
   * 读取灵魂档案内容
   */
  async getSoul(): Promise<string> {
    if (!this.initialized) {
      return '';
    }
    return MemoryFileHelper.readMarkdown(`${this.filesDir}/${Constants.MEMORY_SOUL_FILE}`);
  }

  /**
   * 判断灵魂档案是否存在
   */
  async hasSoul(): Promise<boolean> {
    if (!this.initialized) {
      return false;
    }
    const content = await this.getSoul();
    return content.trim().length > 0;
  }

  /**
   * 更新灵魂档案内容
   */
  async updateSoul(content: string): Promise<void> {
    if (!this.initialized) {
      return;
    }
    await MemoryFileHelper.writeMarkdown(`${this.filesDir}/${Constants.MEMORY_SOUL_FILE}`, content);
  }

  // ===== PROFILE 操作 =====

  /**
   * 读取用户画像 Markdown 内容
   */
  async getProfile(): Promise<string> {
    if (!this.initialized) {
      return '';
    }
    return MemoryFileHelper.readMarkdown(`${this.filesDir}/${Constants.MEMORY_PROFILE_FILE}`);
  }

  /**
   * 更新用户画像（写入 Markdown）
   */
  async updateProfile(content: string): Promise<void> {
    if (!this.initialized) {
      return;
    }
    await MemoryFileHelper.writeMarkdown(`${this.filesDir}/${Constants.MEMORY_PROFILE_FILE}`, content);
  }

  // ===== LESSONS 操作 =====

  /**
   * 读取经验教训 Markdown 内容
   */
  async getLessons(): Promise<string> {
    if (!this.initialized) {
      return '';
    }
    return MemoryFileHelper.readMarkdown(`${this.filesDir}/${Constants.MEMORY_LESSONS_FILE}`);
  }

  /**
   * 更新经验教训（写入 Markdown）
   */
  async updateLessons(content: string): Promise<void> {
    if (!this.initialized) {
      return;
    }
    await MemoryFileHelper.writeMarkdown(`${this.filesDir}/${Constants.MEMORY_LESSONS_FILE}`, content);
  }

  // ===== 每日维护 =====

  /**
   * 每日维护任务：画像更新 + 日志清理
   * 应在每日首次启动时调用
   */
  async dailyMaintenance(): Promise<void> {
    if (!this.initialized) {
      return;
    }
    try {
      console.info('MemoryService', 'dailyMaintenance start');

      // 1. 清理 30 天前的旧日志
      await this.cleanOldLogs();

      // 2. 自动更新用户画像（基于最近 30 天行为数据）
      if (profileRegenerateCallback) {
        await profileRegenerateCallback();
        console.info('MemoryService', 'dailyMaintenance: profile regenerated');
      } else {
        console.warn('MemoryService', 'dailyMaintenance: profileRegenerateCallback not set, skip profile update');
      }

      console.info('MemoryService', 'dailyMaintenance done');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryService', `dailyMaintenance failed: ${msg}`);
    }
  }

  /**
   * 清理 30 天前的日志文件
   */
  async cleanOldLogs(): Promise<void> {
    if (!this.initialized) {
      return;
    }
    try {
      const dailyDir = `${this.filesDir}/${Constants.MEMORY_DAILY_DIR}`;
      const files = await MemoryFileHelper.listFiles(dailyDir);
      const cutoff = DateUtil.daysAgo(Constants.MEMORY_KEEP_DAYS);

      for (const file of files) {
        // 文件名格式 YYYY-MM-DD.md
        if (!file.endsWith('.md')) {
          continue;
        }
        const dateStr = file.replace('.md', '');
        if (dateStr < cutoff) {
          await MemoryFileHelper.deleteFile(`${dailyDir}/${file}`);
          console.info('MemoryService', `cleanOldLogs: deleted ${file}`);
        }
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryService', `cleanOldLogs failed: ${msg}`);
    }
  }

  // ===== AI 上下文构建（分层加载，借鉴 MemPalace L0-L3 思想） =====

  /**
   * 分层上下文级别：
   * - L0: SOUL 核心段（身份+兴趣，~100 token）— 始终加载
   * - L1: PROFILE 压缩摘要（权重+话题+洞察，~200 token）— level >= 1 时加载
   * - L2: 近日行为摘要（今日+昨日结构化摘要）— level >= 2 时加载
   * - L3: LESSONS 经验教训（完整追踪数据）— level >= 3 时加载
   */

  /**
   * 构建分层 AI 上下文（按需加载，降低 token 消耗）
   * @param level 最高加载层级，取值会被归一化到 [0, 3]，默认 1（轻量模式）
   */
  async buildLayeredContext(level: number = 1): Promise<string> {
    if (!this.initialized) {
      return '';
    }
    try {
      const normalizedLevel = Math.max(0, Math.min(3, Math.floor(level)));
      const parts: string[] = [];

      // === L0: SOUL 核心段（始终加载）===
      const soul = await this.getSoul();
      if (soul.trim()) {
        const compactSoul = this.extractSoulCore(soul);
        parts.push(`## 用户偏好\n${compactSoul}`);
      }

      // === L1: PROFILE 压缩摘要（level>=1 加载）===
      if (normalizedLevel >= 1) {
        const profile = await this.getProfile();
        if (profile.trim()) {
          const compactProfile = this.extractCompactProfile(profile);
          if (compactProfile) {
            parts.push(`## 阅读画像摘要\n${compactProfile}`);
          }
        }
      }

      // === L2: 近日行为摘要（level>=2 加载）===
      if (normalizedLevel >= 2) {
        const today = DateUtil.today();
        const yesterday = DateUtil.daysAgo(1);
        const todayLog = await MemoryFileHelper.readMarkdown(
          `${this.filesDir}/${Constants.MEMORY_DAILY_DIR}/${today}.md`
        );
        const yesterdayLog = await MemoryFileHelper.readMarkdown(
          `${this.filesDir}/${Constants.MEMORY_DAILY_DIR}/${yesterday}.md`
        );
        const todaySummary = this.buildDaySummary(todayLog, today);
        const yesterdaySummary = this.buildDaySummary(yesterdayLog, yesterday);
        if (todaySummary || yesterdaySummary) {
          let summaryText = '## 近日阅读行为\n';
          if (todaySummary) {
            summaryText += `### 今日 (${today})\n${todaySummary}\n`;
          }
          if (yesterdaySummary) {
            summaryText += `### 昨日 (${yesterday})\n${yesterdaySummary}\n`;
          }
          parts.push(summaryText.trimEnd());
        }
      }

      // === L3: LESSONS 经验教训（level>=3 加载）===
      if (normalizedLevel >= 3) {
        const lessons = await this.getLessons();
        const lessonsTrimmed = lessons.trim();
        if (lessonsTrimmed && lessonsTrimmed !== '# 阅读经验') {
          const lessonsSnippet = lessons.substring(0, 2000);
          parts.push(`## 阅读经验教训\n${lessonsSnippet}`);
        }
      }

      return parts.join('\n\n');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryService', `buildLayeredContext failed: ${msg}`);
      return '';
    }
  }

  /**
   * 兼容旧接口：全量加载（L0-L3）
   */
  async buildAIContext(): Promise<string> {
    return this.buildLayeredContext(3);
  }

  /**
   * L0: 从 SOUL.md 提取核心身份信息（压缩到 ~100 token）
   * 只保留"关于我"、"兴趣领域"、"不感兴趣的内容"三个关键段
   */
  private extractSoulCore(soul: string): string {
    const sections = soul.split(/\n##\s+/);
    const coreParts: string[] = [];
    const coreKeywords = ['关于我', '自我介绍', '兴趣领域', '兴趣', '不感兴趣', '不喜欢'];
    for (const section of sections) {
      const lower = section.toLowerCase();
      const firstLine = section.split('\n')[0] ?? '';
      if (coreKeywords.some(kw => lower.startsWith(kw) || firstLine.includes(kw))) {
        const lines = section.split('\n')
          .filter(l => l.trim() && !l.trim().startsWith('<!--'));
        const heading = lines[0] ?? '';
        const body = lines.slice(1, 6).join('\n');
        coreParts.push(`### ${heading}\n${body}`);
      }
    }
    return coreParts.length > 0 ? coreParts.join('\n') : soul.substring(0, 500);
  }

  /**
   * L1: 从 PROFILE.md 提取压缩摘要区块
   * 优先读取 ## 压缩摘要 区块（由 ProfileService 生成）
   * 降级：提取订阅源偏好 Top5 + 话题偏好 + AI 洞察关键句
   */
  private extractCompactProfile(profile: string): string {
    // 优先使用预生成的压缩摘要
    const compactSection = MarkdownUtil.extractSection(profile, '## 压缩摘要');
    if (compactSection && compactSection.trim()) {
      return compactSection.trim();
    }

    // 降级：手动提取关键段
    const parts: string[] = [];

    // 提取订阅源偏好 Top5
    const feedSection = MarkdownUtil.extractSection(profile, '## 订阅源偏好');
    if (feedSection) {
      const feedLines = feedSection.split('\n')
        .filter(l => l.startsWith('|') && !l.startsWith('| 名称') && !l.startsWith('|---'));
      if (feedLines.length > 0) {
        const top5 = feedLines.slice(0, 5).map(line => {
          const cols = line.split('|').map(s => s.trim()).filter(s => s.length > 0);
          return cols.length >= 2 ? `${cols[0]}:${cols[1].replace(/█/g, '').trim()}` : '';
        }).filter(s => s).join(', ');
        parts.push(`订阅源偏好: ${top5}`);
      }
    }

    // 提取话题偏好
    const topicSection = MarkdownUtil.extractSection(profile, '## 话题偏好');
    if (topicSection) {
      const topicLines = topicSection.split('\n')
        .filter(l => l.startsWith('|') && !l.startsWith('| 名称') && !l.startsWith('|---'));
      if (topicLines.length > 0) {
        const topics = topicLines.slice(0, 8).map(line => {
          const cols = line.split('|').map(s => s.trim()).filter(s => s.length > 0);
          return cols.length >= 1 ? cols[0] : '';
        }).filter(s => s).join(', ');
        parts.push(`话题偏好: ${topics}`);
      }
    }

    // 提取 AI 洞察关键句
    const insightSection = MarkdownUtil.extractSection(profile, '## AI 洞察');
    if (insightSection) {
      const insightLines = insightSection.split('\n')
        .filter(l => l.trim() && !l.startsWith('#'));
      parts.push(insightLines.slice(0, 3).join('\n'));
    }

    return parts.join('\n');
  }

  /**
   * 构建单日结构化行为摘要
   */
  private buildDaySummary(logContent: string, date: string): string {
    if (!logContent.trim()) {
      return '';
    }
    let readCount = 0;
    let starCount = 0;
    let searchCount = 0;
    const feedCounts = new Map<string, number>();
    const keywords: string[] = [];
    const timestamps: string[] = [];

    const lines = logContent.split('\n');
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
      const feed = parts[3];
      const extra = parts.length >= 5 ? parts[4] : '-';

      if (action === 'READ') {
        readCount++;
        if (feed && feed !== '-') {
          feedCounts.set(feed, (feedCounts.get(feed) ?? 0) + 1);
        }
        if (time) {
          timestamps.push(time);
        }
      } else if (action === 'STAR') {
        starCount++;
      } else if (action === 'SEARCH') {
        searchCount++;
        if (extra && extra !== '-') {
          keywords.push(extra);
        }
      }
    }

    if (readCount === 0 && starCount === 0) {
      return '';
    }

    const summaryParts: string[] = [];
    summaryParts.push(`- 阅读 ${readCount} 篇，收藏 ${starCount} 篇`);

    // Top3 来源
    const feedEntries: Array<[string, number]> = [];
    feedCounts.forEach((cnt, name) => feedEntries.push([name, cnt]));
    feedEntries.sort((a, b) => b[1] - a[1]);
    if (feedEntries.length > 0) {
      const top3 = feedEntries.slice(0, 3).map(e => `${e[0]}(${e[1]}篇)`).join('、');
      summaryParts.push(`- 高频来源：${top3}`);
    }

    if (keywords.length > 0) {
      const kwSet = new Set<string>(keywords);
      const uniqueKws: string[] = [];
      kwSet.forEach((kw) => {
        if (uniqueKws.length < 5) {
          uniqueKws.push(kw);
        }
      });
      summaryParts.push(`- 搜索关键词：${uniqueKws.join('、')}`);
    }

    // 阅读时段分布
    if (timestamps.length > 0) {
      const periods: Record<string, number> = { '早(6-12)': 0, '午(12-18)': 0, '晚(18-24)': 0, '凌晨(0-6)': 0 };
      for (const ts of timestamps) {
        const h = parseInt(ts.split(':')[0], 10);
        if (isNaN(h)) continue;
        if (h < 6) periods['凌晨(0-6)']++;
        else if (h < 12) periods['早(6-12)']++;
        else if (h < 18) periods['午(12-18)']++;
        else periods['晚(18-24)']++;
      }
      const activePeriods = Object.entries(periods).filter(e => e[1] > 0).map(e => `${e[0]}${e[1]}篇`);
      if (activePeriods.length > 0) {
        summaryParts.push(`- 时段：${activePeriods.join('、')}`);
      }
    }

    return summaryParts.join('\n');
  }

  // ===== AI 排序缓存 =====

  /**
   * 获取 AI 排序缓存（若未过期）
   */
  getAIRankCache(): number[] | null {
    const now = DateUtil.now();
    if (this.aiRankCache.length > 0 && (now - this.aiRankCacheTime) < Constants.AI_SORT_CACHE_TTL) {
      return this.aiRankCache;
    }
    return null;
  }

  /**
   * 设置 AI 排序缓存
   */
  setAIRankCache(articleIds: number[]): void {
    this.aiRankCache = articleIds;
    this.aiRankCacheTime = DateUtil.now();
  }

  /**
   * 清除 AI 排序缓存
   */
  clearAIRankCache(): void {
    this.aiRankCache = [];
    this.aiRankCacheTime = 0;
  }

  // ===== 简报缓存 =====

  /**
   * 读取当日简报缓存
   * @param date YYYY-MM-DD
   */
  async readBriefingCache(date: string): Promise<string> {
    if (!this.initialized) return '';
    const path = `${this.filesDir}/${Constants.BRIEFING_CACHE_PREFIX}${date}.json`;
    try {
      return await MemoryFileHelper.readMarkdown(path);
    } catch {
      return '';
    }
  }

  /**
   * 写入简报缓存
   * @param date YYYY-MM-DD
   * @param json 序列化后的 JSON 字符串
   */
  async writeBriefingCache(date: string, json: string): Promise<void> {
    if (!this.initialized) return;
    const path = `${this.filesDir}/${Constants.BRIEFING_CACHE_PREFIX}${date}.json`;
    await MemoryFileHelper.writeMarkdown(path, json);
  }

  /**
   * 检查当日简报缓存是否存在
   * @param date YYYY-MM-DD
   */
  async briefingCacheExists(date: string): Promise<boolean> {
    if (!this.initialized) return false;
    const path = `${this.filesDir}/${Constants.BRIEFING_CACHE_PREFIX}${date}.json`;
    return MemoryFileHelper.exists(path);
  }

  // ===== 数据管理 =====

  /**
   * 导出记忆数据（返回所有记忆文件内容的合并字符串）
   */
  async exportMemoryData(): Promise<string> {
    if (!this.initialized) {
      return '';
    }
    try {
      const parts: string[] = [];
      parts.push('# 记忆数据导出\n');
      parts.push(`导出时间：${DateUtil.today()}\n`);

      const soul = await this.getSoul();
      if (soul.trim()) {
        parts.push('\n---\n\n## 灵魂档案 (SOUL.md)\n\n' + soul);
      }

      const profile = await this.getProfile();
      if (profile.trim()) {
        parts.push('\n---\n\n## 阅读画像 (PROFILE.md)\n\n' + profile);
      }

      const dailyDir = `${this.filesDir}/${Constants.MEMORY_DAILY_DIR}`;
      const logFiles = await MemoryFileHelper.listFiles(dailyDir);
      if (logFiles.length > 0) {
        parts.push('\n---\n\n## 阅读日志\n');
        for (const file of logFiles.slice(-7)) {  // 仅导出最近 7 天
          const content = await MemoryFileHelper.readMarkdown(`${dailyDir}/${file}`);
          if (content.trim()) {
            parts.push(`\n### ${file}\n\n${content}`);
          }
        }
      }

      return parts.join('');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryService', `exportMemoryData failed: ${msg}`);
      return '';
    }
  }

  /**
   * 清除所有记忆数据
   */
  async clearAllMemory(): Promise<void> {
    if (!this.initialized) {
      return;
    }
    try {
      // 删除 SOUL、PROFILE 和 LESSONS
      await MemoryFileHelper.deleteFile(`${this.filesDir}/${Constants.MEMORY_SOUL_FILE}`);
      await MemoryFileHelper.deleteFile(`${this.filesDir}/${Constants.MEMORY_PROFILE_FILE}`);
      await MemoryFileHelper.deleteFile(`${this.filesDir}/${Constants.MEMORY_LESSONS_FILE}`);

      // 删除所有日志文件
      const dailyDir = `${this.filesDir}/${Constants.MEMORY_DAILY_DIR}`;
      const files = await MemoryFileHelper.listFiles(dailyDir);
      for (const file of files) {
        await MemoryFileHelper.deleteFile(`${dailyDir}/${file}`);
      }

      // 清除内存缓存
      this.behaviorQueue = [];
      this.clearAIRankCache();

      console.info('MemoryService', 'clearAllMemory done');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryService', `clearAllMemory failed: ${msg}`);
      throw new Error(`clearAllMemory failed: ${msg}`);
    }
  }

  /**
   * 重置记忆文件为原始模板（强制覆盖现有文件）
   * @param soulTemplate SOUL.md 模板内容
   * @param profileTemplate PROFILE.md 模板内容（可选，为空则使用默认骨架）
   */
  async resetToTemplate(soulTemplate: string, profileTemplate: string = ''): Promise<void> {
    if (!this.initialized) {
      throw new Error('MemoryService 未初始化');
    }
    try {
      const soulPath = `${this.filesDir}/${Constants.MEMORY_SOUL_FILE}`;
      const profilePath = `${this.filesDir}/${Constants.MEMORY_PROFILE_FILE}`;

      // 强制写入 SOUL.md（无论是否存在）
      if (soulTemplate.trim()) {
        await MemoryFileHelper.writeMarkdown(soulPath, soulTemplate);
        console.info('MemoryService', 'SOUL.md 已重置为模板');
      }

      // 强制写入 PROFILE.md（空骨架或传入的模板）
      const profileContent = profileTemplate.trim()
        ? profileTemplate
        : `# 阅读画像\n\n> 系统将根据阅读行为自动生成画像，请先阅读几篇文章。\n`;
      await MemoryFileHelper.writeMarkdown(profilePath, profileContent);
      console.info('MemoryService', 'PROFILE.md 已重置为模板');

      // 清除 AI 排序缓存
      this.clearAIRankCache();

      console.info('MemoryService', 'resetToTemplate done');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryService', `resetToTemplate failed: ${msg}`);
      throw new Error(`resetToTemplate failed: ${msg}`);
    }
  }
}
