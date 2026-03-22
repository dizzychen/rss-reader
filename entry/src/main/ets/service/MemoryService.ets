// 记忆服务核心 - 三层记忆架构（SOUL / PROFILE / DAILY）
import { common } from '@kit.AbilityKit';
import { Constants } from '../constants/Constants';
import { UserBehavior } from '../model/Models';
import { MemoryFileHelper } from './MemoryFileHelper';
import { util } from '@kit.ArkTS';
import { DateUtil } from '../utils/DateUtil';

// 延迟导入 ProfileService 的回调，由 EntryAbility 注入，避免循环依赖
let profileRegenerateCallback: (() => Promise<void>) | null = null;

export function setProfileRegenerateCallback(cb: () => Promise<void>): void {
  profileRegenerateCallback = cb;
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
  async init(context: common.Context, soulTemplate: string = '', profileTemplate: string = ''): Promise<void> {
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
      await this.initializeFromTemplates(soulTemplate, profileTemplate);

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
  private async initializeFromTemplates(soulTemplate: string, _profileTemplate: string): Promise<void> {
    const soulPath = `${this.filesDir}/${Constants.MEMORY_SOUL_FILE}`;
    const profilePath = `${this.filesDir}/${Constants.MEMORY_PROFILE_FILE}`;

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
    const title = b.articleTitle ? b.articleTitle.substring(0, 30).replace(/\|/g, '\\|') : '-';
    const feed = b.feedTitle ? b.feedTitle.replace(/\|/g, '\\|') : '-';
    let extra = '-';
    if (b.action === 'READ_END' && b.duration !== undefined) {
      extra = DateUtil.formatDuration(b.duration);
    } else if (b.action === 'SEARCH' && b.keyword) {
      extra = b.keyword.replace(/\|/g, '\\|');
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

  // ===== AI 上下文构建 =====

  /**
   * 构建 AI 上下文（SOUL + PROFILE + 今日日志摘要）
   */
  async buildAIContext(): Promise<string> {
    if (!this.initialized) {
      return '';
    }
    try {
      const soul = await this.getSoul();
      const profile = await this.getProfile();
      const today = DateUtil.today();
      const todayLog = await MemoryFileHelper.readMarkdown(
        `${this.filesDir}/${Constants.MEMORY_DAILY_DIR}/${today}.md`
      );

      const parts: string[] = [];

      if (soul.trim()) {
        parts.push(`## 我的阅读偏好\n${soul.trim()}`);
      }

      if (profile.trim()) {
        parts.push(`## 我的阅读画像\n${profile.trim()}`);
      }

      if (todayLog.trim()) {
        // 仅取前 50 行日志作为摘要，避免上下文过长
        const logLines = todayLog.split('\n').slice(0, 50).join('\n');
        parts.push(`## 今日阅读行为\n${logLines}`);
      }

      return parts.join('\n\n');
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryService', `buildAIContext failed: ${msg}`);
      return '';
    }
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
      // 删除 SOUL 和 PROFILE
      await MemoryFileHelper.deleteFile(`${this.filesDir}/${Constants.MEMORY_SOUL_FILE}`);
      await MemoryFileHelper.deleteFile(`${this.filesDir}/${Constants.MEMORY_PROFILE_FILE}`);

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
