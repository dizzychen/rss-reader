# 📐 技术设计文档

# RSS 阅读器 - 三层记忆系统

---

| 文档信息 | |
|---------|---|
| **版本** | v1.0 |
| **日期** | 2026-03-21 |
| **作者** | dizzy |
| **状态** | 待开发 |

---

## 一、技术概述

### 1.1 技术栈

| 层级 | 技术选型 |
|------|---------|
| **平台** | HarmonyOS NEXT (API 12+) |
| **语言** | ArkTS |
| **框架** | ArkUI 声明式 |
| **存储** | 文件系统（fileIo） |
| **AI** | 通义千问 API |

### 1.2 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                           UI 层                                  │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐           │
│  │ HomePage │ │ Detail   │ │ Settings │ │ SoulEdit │           │
│  │          │ │ Page     │ │ Page     │ │ Page     │           │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘           │
│       │            │            │            │                  │
├───────┼────────────┼────────────┼────────────┼──────────────────┤
│       ▼            ▼            ▼            ▼                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Service 层                            │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │   │
│  │  │ MemoryService│  │  AIService   │  │ProfileService│   │   │
│  │  │ (核心服务)    │  │ (AI 调用)    │  │ (画像计算)   │   │   │
│  │  └──────┬───────┘  └──────────────┘  └──────────────┘   │   │
│  │         │                                                │   │
│  │  ┌──────▼───────────────────────────────────────────┐   │   │
│  │  │              MemoryFileHelper                     │   │   │
│  │  │              (文件操作工具类)                      │   │   │
│  │  └──────────────────────────────────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
├──────────────────────────────┼──────────────────────────────────┤
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                     存储层                               │   │
│  │  ┌──────────┐  ┌──────────┐  ┌─────────────────────┐   │   │
│  │  │ SOUL.md  │  │PROFILE.md│  │ daily/YYYY-MM-DD.md │   │   │
│  │  │ (灵魂层) │  │ (画像层) │  │     (日志层)         │   │   │
│  │  └──────────┘  └──────────┘  └─────────────────────┘   │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 二、目录结构

### 2.1 新增文件

```
entry/src/main/ets/
│
├── service/
│   ├── MemoryService.ets        # [新增] 记忆服务核心
│   ├── MemoryFileHelper.ets     # [新增] 文件操作工具
│   ├── ProfileService.ets       # [新增] 画像计算服务
│   ├── AIService.ets            # [新增] AI 调用封装
│   └── ...
│
├── model/
│   └── Models.ets               # [修改] 新增行为模型
│
├── pages/
│   ├── SoulEditPage.ets         # [新增] 灵魂档案编辑页
│   ├── ProfileViewPage.ets      # [新增] 画像查看页
│   ├── ReadingStatsPage.ets     # [新增] 阅读统计页
│   ├── DailyBriefingPage.ets    # [新增] 每日简报页
│   └── ...
│
├── constants/
│   └── Constants.ets            # [修改] 新增记忆系统常量
│
└── utils/
    ├── DateUtil.ets             # [新增] 日期工具
    └── InterestCalculator.ets   # [新增] 兴趣权重计算
```

### 2.2 数据文件结构

```
{context.filesDir}/
└── memory/                          # 记忆根目录
    ├── SOUL.md                      # 灵魂层（~2KB）
    ├── PROFILE.md                   # 画像层（~3KB）
    └── daily/                       # 日志层目录
        ├── 2026-03-21.md            # 今日日志
        ├── 2026-03-20.md            # 昨日日志
        └── ...                      # 保留最近 30 天
```

---

## 三、数据模型设计

### 3.1 行为数据模型

```typescript
// entry/src/main/ets/model/Models.ets

/**
 * 用户行为类型
 */
export type BehaviorAction = 
  | 'READ'      // 开始阅读文章
  | 'READ_END'  // 结束阅读（离开页面）
  | 'STAR'      // 收藏文章
  | 'UNSTAR'    // 取消收藏
  | 'SKIP'      // 快速跳过（曝光<1秒）
  | 'SEARCH';   // 执行搜索

/**
 * 用户行为记录
 */
export interface UserBehavior {
  /** 时间戳（毫秒） */
  timestamp: number;
  /** 行为类型 */
  action: BehaviorAction;
  /** 文章 ID */
  articleId?: number;
  /** 文章标题 */
  articleTitle?: string;
  /** 来源名称 */
  feedTitle?: string;
  /** 阅读时长（秒），仅 READ_END 有值 */
  duration?: number;
  /** 滚动深度（0-100），仅 READ_END 有值 */
  scrollDepth?: number;
  /** 搜索关键词，仅 SEARCH 有值 */
  searchQuery?: string;
}
```

### 3.2 日志统计模型

```typescript
/**
 * 每日统计数据
 */
export interface DailyStats {
  /** 日期 YYYY-MM-DD */
  date: string;
  /** 阅读数 */
  readCount: number;
  /** 收藏数 */
  starCount: number;
  /** 跳过数 */
  skipCount: number;
  /** 搜索数 */
  searchCount: number;
  /** 总阅读时长（秒） */
  totalDuration: number;
  /** 深度阅读数（>5分钟） */
  deepReadCount: number;
  /** 主题分布 Map<主题, 阅读数> */
  topicDistribution: Map<string, number>;
}
```

### 3.3 兴趣权重模型

```typescript
/**
 * 兴趣权重项
 */
export interface InterestWeight {
  /** 主题名称 */
  topic: string;
  /** 权重值 0-1 */
  weight: number;
  /** 阅读数 */
  readCount: number;
  /** 收藏数 */
  starCount: number;
  /** 趋势 ↑→↓ */
  trend: string;
}

/**
 * 用户画像数据
 */
export interface UserProfile {
  /** 兴趣权重列表 */
  interests: InterestWeight[];
  /** 活跃时段 */
  activeHours: string[];
  /** 日均阅读数 */
  avgDailyReads: number;
  /** 平均阅读时长（秒） */
  avgReadDuration: number;
  /** 深度阅读率 */
  deepReadRate: number;
  /** 收藏率 */
  starRate: number;
  /** 近期关注主题 */
  recentTopics: string[];
  /** 偏好文章长度 */
  preferredLength: string;
  /** 偏好来源 */
  preferredFeeds: string[];
  /** 更新时间 */
  updatedAt: string;
}
```

---

## 四、核心服务设计

### 4.1 MemoryService（记忆服务）

```typescript
// entry/src/main/ets/service/MemoryService.ets

import { common } from '@kit.AbilityKit';

/**
 * 记忆服务 - 核心服务
 * 负责记忆系统的初始化、读写、维护
 */
export class MemoryService {
  private static instance: MemoryService;
  private context: common.Context | null = null;
  private memoryDir: string = '';
  private dailyDir: string = '';
  
  // ===== 私有属性 =====
  private behaviorQueue: UserBehavior[] = [];
  private flushTimer: number | null = null;
  private readonly FLUSH_DELAY = 500; // 500ms 防抖
  
  // ===== 单例 =====
  static getInstance(): MemoryService {
    if (!MemoryService.instance) {
      MemoryService.instance = new MemoryService();
    }
    return MemoryService.instance;
  }
  
  // ===== 初始化 =====
  /**
   * 初始化记忆服务
   * @param context 应用上下文
   */
  async init(context: common.Context): Promise<void> {
    this.context = context;
    this.memoryDir = `${context.filesDir}/memory`;
    this.dailyDir = `${this.memoryDir}/daily`;
    
    // 创建目录结构
    await MemoryFileHelper.ensureDir(this.memoryDir);
    await MemoryFileHelper.ensureDir(this.dailyDir);
    
    // 执行每日维护任务
    await this.dailyMaintenance();
  }
  
  // ===== SOUL 操作 =====
  
  /** 获取灵魂档案路径 */
  private getSoulPath(): string {
    return `${this.memoryDir}/SOUL.md`;
  }
  
  /** 获取灵魂档案内容 */
  async getSoul(): Promise<string> {
    return await MemoryFileHelper.readMarkdown(this.getSoulPath());
  }
  
  /** 检查是否已初始化灵魂档案 */
  async hasSoul(): Promise<boolean> {
    return await MemoryFileHelper.exists(this.getSoulPath());
  }
  
  /** 更新灵魂档案（覆盖写入） */
  async updateSoul(content: string): Promise<void> {
    await MemoryFileHelper.writeMarkdown(this.getSoulPath(), content);
  }
  
  // ===== PROFILE 操作 =====
  
  /** 获取画像路径 */
  private getProfilePath(): string {
    return `${this.memoryDir}/PROFILE.md`;
  }
  
  /** 获取用户画像内容 */
  async getProfile(): Promise<string> {
    return await MemoryFileHelper.readMarkdown(this.getProfilePath());
  }
  
  /** 更新用户画像（覆盖写入） */
  async updateProfile(content: string): Promise<void> {
    await MemoryFileHelper.writeMarkdown(this.getProfilePath(), content);
  }
  
  // ===== DAILY 操作 =====
  
  /** 获取指定日期的日志路径 */
  private getDailyPath(date: string): string {
    return `${this.dailyDir}/${date}.md`;
  }
  
  /** 记录用户行为 */
  async recordBehavior(behavior: UserBehavior): Promise<void> {
    this.behaviorQueue.push(behavior);
    
    // 防抖：500ms 内的行为合并写入
    if (this.flushTimer !== null) {
      clearTimeout(this.flushTimer);
    }
    
    this.flushTimer = setTimeout(async () => {
      await this.flushBehaviors();
    }, this.FLUSH_DELAY);
  }
  
  /** 批量写入行为 */
  private async flushBehaviors(): Promise<void> {
    if (this.behaviorQueue.length === 0) return;
    
    const behaviors = [...this.behaviorQueue];
    this.behaviorQueue = [];
    this.flushTimer = null;
    
    const today = DateUtil.today();
    const todayPath = this.getDailyPath(today);
    
    // 检查今日日志是否存在，不存在则创建头部
    if (!(await MemoryFileHelper.exists(todayPath))) {
      await this.createDailyLogHeader(todayPath, today);
    }
    
    // 格式化行为并追加
    const lines = behaviors.map(b => this.formatBehaviorLine(b));
    await MemoryFileHelper.appendMarkdown(todayPath, lines.join('\n'));
  }
  
  /** 创建日志文件头 */
  private async createDailyLogHeader(path: string, date: string): Promise<void> {
    const header = `# ${date} 阅读日志

## 行为记录

| 时间 | 动作 | 文章ID | 标题 | 来源 | 时长 | 备注 |
|------|------|--------|------|------|------|------|
`;
    await MemoryFileHelper.writeMarkdown(path, header);
  }
  
  /** 格式化单条行为为表格行 */
  private formatBehaviorLine(b: UserBehavior): string {
    const time = DateUtil.formatTime(b.timestamp);
    const id = b.articleId?.toString() ?? '-';
    const title = b.articleTitle ?? '-';
    const feed = b.feedTitle ?? '-';
    const duration = b.duration ? DateUtil.formatDuration(b.duration) : '-';
    
    let note = '-';
    if (b.action === 'READ_END') {
      if (b.duration && b.duration >= 300) {
        note = '完读';
      } else if (b.duration && b.duration < 60) {
        note = '跳过';
      }
    } else if (b.action === 'SEARCH') {
      note = `关键词: ${b.searchQuery}`;
    }
    
    return `| ${time} | ${b.action} | ${id} | ${title} | ${feed} | ${duration} | ${note} |`;
  }
  
  /** 获取今日日志 */
  async getTodayLog(): Promise<string> {
    return await MemoryFileHelper.readMarkdown(
      this.getDailyPath(DateUtil.today())
    );
  }
  
  /** 获取昨日日志 */
  async getYesterdayLog(): Promise<string> {
    return await MemoryFileHelper.readMarkdown(
      this.getDailyPath(DateUtil.yesterday())
    );
  }
  
  /** 获取指定日期范围的日志 */
  async getLogs(startDate: string, endDate: string): Promise<Map<string, string>> {
    const result = new Map<string, string>();
    const start = new Date(startDate);
    const end = new Date(endDate);
    
    for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
      const dateStr = d.toISOString().split('T')[0];
      const content = await MemoryFileHelper.readMarkdown(
        this.getDailyPath(dateStr)
      );
      if (content) {
        result.set(dateStr, content);
      }
    }
    
    return result;
  }
  
  // ===== AI 上下文 =====
  
  /** 构建 AI 调用上下文（SOUL + PROFILE + 今日摘要） */
  async buildAIContext(): Promise<string> {
    const soul = await this.getSoul();
    const profile = await this.getProfile();
    const todayLog = await this.getTodayLog();
    
    return `## 用户灵魂档案
${soul || '（未设置）'}

## 用户阅读画像
${profile || '（数据不足）'}

## 今日阅读记录
${this.summarizeDailyLog(todayLog)}`;
  }
  
  /** 构建完整 AI 上下文（含近 7 天日志） */
  async buildFullAIContext(): Promise<string> {
    const baseContext = await this.buildAIContext();
    const logs = await this.getLogs(
      DateUtil.daysAgo(7),
      DateUtil.today()
    );
    
    let weekSummary = '\n## 近 7 天阅读趋势\n';
    logs.forEach((content, date) => {
      weekSummary += `\n### ${date}\n${this.summarizeDailyLog(content)}`;
    });
    
    return baseContext + weekSummary;
  }
  
  /** 日志摘要 */
  private summarizeDailyLog(log: string): string {
    if (!log) return '（无记录）';
    
    // 简单统计：READ、STAR 数量
    const readCount = (log.match(/\| READ \|/g) || []).length;
    const starCount = (log.match(/\| STAR \|/g) || []).length;
    
    return `已阅读 ${readCount} 篇，收藏 ${starCount} 篇`;
  }
  
  // ===== 维护 =====
  
  /** 每日维护任务 */
  async dailyMaintenance(): Promise<void> {
    // 清理 30 天前的日志
    await this.cleanOldLogs(30);
    
    // 更新画像（如果有足够数据）
    // await ProfileService.getInstance().regenerate();
  }
  
  /** 清理旧日志 */
  async cleanOldLogs(keepDays: number = 30): Promise<void> {
    const files = await MemoryFileHelper.listFiles(this.dailyDir);
    const cutoffDate = DateUtil.daysAgo(keepDays);
    
    for (const file of files) {
      // 文件名格式: YYYY-MM-DD.md
      const dateStr = file.replace('.md', '');
      if (dateStr < cutoffDate) {
        await MemoryFileHelper.deleteFile(`${this.dailyDir}/${file}`);
      }
    }
  }
}
```

### 4.2 MemoryFileHelper（文件操作工具）

```typescript
// entry/src/main/ets/service/MemoryFileHelper.ets

import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

/**
 * 记忆文件操作工具类
 */
export class MemoryFileHelper {
  
  /**
   * 读取 Markdown 文件
   * @param filePath 文件路径
   * @returns 文件内容，不存在返回空字符串
   */
  static async readMarkdown(filePath: string): Promise<string> {
    try {
      // 检查文件是否存在
      await fileIo.access(filePath);
      
      const file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
      const stat = await fileIo.stat(file.fd);
      
      if (stat.size === 0) {
        await fileIo.close(file.fd);
        return '';
      }
      
      const buf = new ArrayBuffer(stat.size);
      const bytesRead = await fileIo.read(file.fd, buf);
      await fileIo.close(file.fd);
      
      const decoder = util.TextDecoder.create('utf-8');
      return decoder.decodeToString(new Uint8Array(buf, 0, bytesRead));
    } catch (e) {
      // 文件不存在或读取失败，返回空字符串
      return '';
    }
  }
  
  /**
   * 覆盖写入 Markdown 文件
   * @param filePath 文件路径
   * @param content 文件内容
   */
  static async writeMarkdown(filePath: string, content: string): Promise<void> {
    const file = await fileIo.open(
      filePath,
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
    );
    
    const encoder = new util.TextEncoder();
    const buffer = encoder.encodeInto(content);
    await fileIo.write(file.fd, buffer.buffer);
    await fileIo.close(file.fd);
  }
  
  /**
   * 追加写入 Markdown 文件
   * @param filePath 文件路径
   * @param content 追加内容
   */
  static async appendMarkdown(filePath: string, content: string): Promise<void> {
    const file = await fileIo.open(
      filePath,
      fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND
    );
    
    const encoder = new util.TextEncoder();
    const buffer = encoder.encodeInto(content + '\n');
    await fileIo.write(file.fd, buffer.buffer);
    await fileIo.close(file.fd);
  }
  
  /**
   * 检查文件是否存在
   * @param filePath 文件路径
   */
  static async exists(filePath: string): Promise<boolean> {
    try {
      await fileIo.access(filePath);
      return true;
    } catch {
      return false;
    }
  }
  
  /**
   * 创建目录（递归）
   * @param dirPath 目录路径
   */
  static async ensureDir(dirPath: string): Promise<void> {
    try {
      await fileIo.mkdir(dirPath, true);
    } catch {
      // 目录已存在，忽略
    }
  }
  
  /**
   * 列出目录下的文件
   * @param dirPath 目录路径
   */
  static async listFiles(dirPath: string): Promise<string[]> {
    try {
      return await fileIo.listFile(dirPath);
    } catch {
      return [];
    }
  }
  
  /**
   * 删除文件
   * @param filePath 文件路径
   */
  static async deleteFile(filePath: string): Promise<void> {
    try {
      await fileIo.unlink(filePath);
    } catch {
      // 文件不存在，忽略
    }
  }
}
```

### 4.3 DateUtil（日期工具）

```typescript
// entry/src/main/ets/utils/DateUtil.ets

/**
 * 日期工具类
 */
export class DateUtil {
  
  /**
   * 获取今天的日期字符串
   * @returns YYYY-MM-DD
   */
  static today(): string {
    return new Date().toISOString().split('T')[0];
  }
  
  /**
   * 获取昨天的日期字符串
   * @returns YYYY-MM-DD
   */
  static yesterday(): string {
    const d = new Date();
    d.setDate(d.getDate() - 1);
    return d.toISOString().split('T')[0];
  }
  
  /**
   * 获取 N 天前的日期字符串
   * @param n 天数
   * @returns YYYY-MM-DD
   */
  static daysAgo(n: number): string {
    const d = new Date();
    d.setDate(d.getDate() - n);
    return d.toISOString().split('T')[0];
  }
  
  /**
   * 格式化时间戳为 HH:mm
   * @param timestamp 时间戳（毫秒）
   */
  static formatTime(timestamp: number): string {
    const d = new Date(timestamp);
    const hours = d.getHours().toString().padStart(2, '0');
    const minutes = d.getMinutes().toString().padStart(2, '0');
    return `${hours}:${minutes}`;
  }
  
  /**
   * 格式化秒数为可读时长
   * @param seconds 秒数
   * @returns 如 "5m" 或 "30s"
   */
  static formatDuration(seconds: number): string {
    if (seconds >= 60) {
      return `${Math.floor(seconds / 60)}m`;
    }
    return `${seconds}s`;
  }
  
  /**
   * 获取当前时间的 ISO 字符串
   */
  static nowISO(): string {
    return new Date().toISOString();
  }
}
```

### 4.4 InterestCalculator（兴趣权重计算）

```typescript
// entry/src/main/ets/utils/InterestCalculator.ets

/**
 * 兴趣权重计算器
 * 使用指数移动平均（EMA）算法
 */
export class InterestCalculator {
  /** 衰减因子 */
  private readonly ALPHA = 0.3;
  
  /**
   * 更新单个主题的兴趣权重
   * 公式: 新权重 = α × 新信号 + (1 - α) × 旧权重
   * 
   * @param oldWeight 旧权重
   * @param newSignal 新信号（0-1）
   * @returns 新权重
   */
  updateWeight(oldWeight: number, newSignal: number): number {
    return this.ALPHA * newSignal + (1 - this.ALPHA) * oldWeight;
  }
  
  /**
   * 计算新信号值
   * 公式: (阅读数 × 1 + 收藏数 × 3) / 总阅读数
   * 
   * @param readCount 该主题阅读数
   * @param starCount 该主题收藏数
   * @param totalReads 总阅读数
   * @returns 信号值（0-1）
   */
  calculateSignal(readCount: number, starCount: number, totalReads: number): number {
    if (totalReads === 0) return 0;
    const raw = (readCount + starCount * 3) / totalReads;
    return Math.min(1, raw); // 归一化到 0-1
  }
  
  /**
   * 判断趋势方向
   * @param oldWeight 旧权重
   * @param newWeight 新权重
   * @returns ↑ → ↓
   */
  getTrend(oldWeight: number, newWeight: number): string {
    const diff = newWeight - oldWeight;
    if (diff > 0.05) return '↑';
    if (diff < -0.05) return '↓';
    return '→';
  }
  
  /**
   * 批量更新兴趣权重
   */
  updateInterests(
    oldInterests: Map<string, number>,
    newStats: Map<string, { reads: number; stars: number }>,
    totalReads: number
  ): InterestWeight[] {
    const result: InterestWeight[] = [];
    
    // 收集所有主题
    const allTopics = new Set([
      ...oldInterests.keys(),
      ...newStats.keys()
    ]);
    
    for (const topic of allTopics) {
      const oldWeight = oldInterests.get(topic) ?? 0;
      const stats = newStats.get(topic) ?? { reads: 0, stars: 0 };
      
      const signal = this.calculateSignal(stats.reads, stats.stars, totalReads);
      const newWeight = this.updateWeight(oldWeight, signal);
      const trend = this.getTrend(oldWeight, newWeight);
      
      result.push({
        topic,
        weight: Math.round(newWeight * 100) / 100,
        readCount: stats.reads,
        starCount: stats.stars,
        trend
      });
    }
    
    // 按权重降序排列
    return result.sort((a, b) => b.weight - a.weight);
  }
}
```

### 4.5 AIService（AI 服务）

```typescript
// entry/src/main/ets/service/AIService.ets

import { http } from '@kit.NetworkKit';

/**
 * AI 服务 - 封装通义千问 API 调用
 */
export class AIService {
  private static instance: AIService;
  private apiKey: string = '';
  private readonly API_URL = 'https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation';
  
  static getInstance(): AIService {
    if (!AIService.instance) {
      AIService.instance = new AIService();
    }
    return AIService.instance;
  }
  
  /**
   * 设置 API Key
   */
  setApiKey(key: string): void {
    this.apiKey = key;
  }
  
  /**
   * 检查是否已配置 API Key
   */
  hasApiKey(): boolean {
    return this.apiKey.length > 0;
  }
  
  /**
   * 调用通义千问 API
   * @param prompt 提示词
   * @param systemPrompt 系统提示词（可选）
   * @returns AI 响应文本
   */
  async chat(prompt: string, systemPrompt?: string): Promise<string> {
    if (!this.hasApiKey()) {
      throw new Error('API Key 未配置');
    }
    
    const messages: Array<{ role: string; content: string }> = [];
    
    if (systemPrompt) {
      messages.push({ role: 'system', content: systemPrompt });
    }
    messages.push({ role: 'user', content: prompt });
    
    const httpRequest = http.createHttp();
    
    try {
      const response = await httpRequest.request(this.API_URL, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${this.apiKey}`
        },
        extraData: JSON.stringify({
          model: 'qwen-turbo',
          input: { messages },
          parameters: {
            result_format: 'message'
          }
        })
      });
      
      if (response.responseCode !== 200) {
        throw new Error(`API 请求失败: ${response.responseCode}`);
      }
      
      const result = JSON.parse(response.result as string);
      return result.output?.choices?.[0]?.message?.content ?? '';
      
    } finally {
      httpRequest.destroy();
    }
  }
  
  /**
   * 文章智能排序
   * @param articles 待排序文章列表
   * @param context AI 上下文
   * @returns 文章ID到分数的映射
   */
  async rankArticles(
    articles: Array<{ id: number; title: string; feed: string }>,
    context: string
  ): Promise<Map<number, number>> {
    const articleList = articles
      .map((a, i) => `${i + 1}. [ID:${a.id}] 《${a.title}》 - ${a.feed}`)
      .join('\n');
    
    const prompt = `你是一个 RSS 阅读助手。请为以下文章打分（1-10），分数越高表示越值得阅读。

${context}

## 待排序文章
${articleList}

## 输出格式
仅返回 JSON，格式: {"scores": {"文章ID": 分数, ...}}`;

    const response = await this.chat(prompt);
    
    // 解析 JSON 响应
    try {
      const match = response.match(/\{[\s\S]*\}/);
      if (match) {
        const data = JSON.parse(match[0]);
        const result = new Map<number, number>();
        for (const [id, score] of Object.entries(data.scores || {})) {
          result.set(parseInt(id), score as number);
        }
        return result;
      }
    } catch {
      // 解析失败，返回空结果
    }
    
    return new Map();
  }
  
  /**
   * 生成每日简报
   */
  async generateBriefing(
    articles: Array<{ id: number; title: string; feed: string; summary: string }>,
    context: string
  ): Promise<string> {
    const articleList = articles
      .map((a, i) => `${i + 1}. 《${a.title}》 - ${a.feed}\n   ${a.summary}`)
      .join('\n\n');
    
    const prompt = `你是一个个人阅读助手。请为用户生成今日简报。

${context}

## 今日新文章（共 ${articles.length} 篇）
${articleList}

## 任务
1. 筛选出最值得阅读的 5-8 篇，说明推荐理由
2. 用 2-3 句话概括今日资讯亮点
3. 标出可以跳过的文章类型

## 输出格式
🌅 早安！今日资讯简报

【今日亮点】
...

【推荐阅读】
1. ⭐ 文章名 - 推荐理由
2. ...

【可以跳过】
- ...`;

    return await this.chat(prompt);
  }
  
  /**
   * 精读辅助
   */
  async analyzeArticle(
    article: { title: string; feed: string; content: string },
    context: string
  ): Promise<string> {
    const prompt = `用户正在阅读这篇文章，请提供个性化解读。

${context}

## 文章信息
- 标题: ${article.title}
- 来源: ${article.feed}
- 内容:
${article.content.substring(0, 3000)}

## 任务
1. 提炼 3 个关键要点（每个不超过 50 字）
2. 联系用户背景，指出与其工作/学习的关联
3. 建议 1-2 个延伸阅读方向

## 输出格式
📖 **关键要点**
1. ...
2. ...
3. ...

🔗 **与你的关联**
...

💡 **延伸建议**
...`;

    return await this.chat(prompt);
  }
}
```

---

## 五、埋点设计

### 5.1 埋点位置

| 页面/组件 | 行为 | 触发时机 | 采集数据 |
|----------|------|---------|---------|
| **ArticleDetailPage** | READ | `aboutToAppear` | articleId, title, feedTitle |
| **ArticleDetailPage** | READ_END | `aboutToDisappear` | duration, scrollDepth |
| **ArticleDetailPage** | STAR | 点击收藏按钮 | articleId |
| **ArticleDetailPage** | UNSTAR | 取消收藏 | articleId |
| **ArticleItemComponent** | SKIP | 曝光后 1 秒内滑走 | articleId |
| **SearchPage** | SEARCH | 执行搜索 | searchQuery |

### 5.2 ArticleDetailPage 埋点示例

```typescript
// entry/src/main/ets/pages/ArticleDetailPage.ets

@Entry
@Component
struct ArticleDetailPage {
  @State article: Article = {} as Article;
  
  // 埋点相关状态
  private enterTime: number = 0;
  private maxScrollDepth: number = 0;
  
  aboutToAppear() {
    // 记录进入时间
    this.enterTime = Date.now();
    
    // 记录阅读行为
    MemoryService.getInstance().recordBehavior({
      timestamp: this.enterTime,
      action: 'READ',
      articleId: this.article.id,
      articleTitle: this.article.title,
      feedTitle: this.article.feedTitle
    });
  }
  
  aboutToDisappear() {
    // 计算阅读时长
    const duration = Math.floor((Date.now() - this.enterTime) / 1000);
    
    // 记录离开行为
    MemoryService.getInstance().recordBehavior({
      timestamp: Date.now(),
      action: 'READ_END',
      articleId: this.article.id,
      duration: duration,
      scrollDepth: this.maxScrollDepth
    });
  }
  
  // 收藏按钮点击
  private async toggleStar() {
    const newStarred = !this.article.isStarred;
    
    // 记录收藏/取消收藏行为
    MemoryService.getInstance().recordBehavior({
      timestamp: Date.now(),
      action: newStarred ? 'STAR' : 'UNSTAR',
      articleId: this.article.id
    });
    
    // 更新数据库...
  }
  
  build() {
    Scroll() {
      // 内容...
    }
    .onScroll((xOffset: number, yOffset: number) => {
      // 更新滚动深度（简化版本）
      // 实际需要获取总高度计算百分比
      this.maxScrollDepth = Math.max(this.maxScrollDepth, Math.min(100, yOffset));
    })
  }
}
```

### 5.3 SearchPage 埋点示例

```typescript
// entry/src/main/ets/pages/SearchPage.ets

@Component
export struct SearchPage {
  @State searchQuery: string = '';
  
  private async doSearch() {
    if (!this.searchQuery.trim()) return;
    
    // 记录搜索行为
    MemoryService.getInstance().recordBehavior({
      timestamp: Date.now(),
      action: 'SEARCH',
      searchQuery: this.searchQuery.trim()
    });
    
    // 执行搜索...
  }
}
```

---

## 六、初始化流程

### 6.1 EntryAbility 初始化

```typescript
// entry/src/main/ets/entryability/EntryAbility.ets

import { MemoryService } from '../service/MemoryService';
import { AIService } from '../service/AIService';
import { SettingsService } from '../service/SettingsService';

export default class EntryAbility extends UIAbility {
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    // 初始化数据库
    await DatabaseHelper.getInstance().init(this.context);
    
    // 初始化设置服务
    await SettingsService.getInstance().init(this.context);
    
    // [新增] 初始化记忆服务
    await MemoryService.getInstance().init(this.context);
    
    // [新增] 加载 AI API Key
    const apiKey = await SettingsService.getInstance().getAIApiKey();
    if (apiKey) {
      AIService.getInstance().setApiKey(apiKey);
    }
  }
}
```

---

## 七、常量定义

```typescript
// entry/src/main/ets/constants/Constants.ets

// ===== 记忆系统常量 =====

/** 记忆目录名 */
export const MEMORY_DIR = 'memory';

/** 日志子目录名 */
export const MEMORY_DAILY_DIR = 'daily';

/** 灵魂档案文件名 */
export const MEMORY_SOUL_FILE = 'SOUL.md';

/** 画像文件名 */
export const MEMORY_PROFILE_FILE = 'PROFILE.md';

/** 日志保留天数 */
export const MEMORY_LOG_KEEP_DAYS = 30;

/** 行为防抖延迟（毫秒） */
export const MEMORY_FLUSH_DELAY = 500;

/** 深度阅读阈值（秒） */
export const DEEP_READ_THRESHOLD = 300;

/** 画像更新触发阅读数 */
export const PROFILE_UPDATE_READS = 20;

// ===== AI 相关常量 =====

/** AI API Key 存储键 */
export const AI_API_KEY = 'ai_api_key';

/** 排序结果缓存时长（毫秒） */
export const AI_RANK_CACHE_TTL = 3600000; // 1 小时
```

---

## 八、新增页面路由

```json
// entry/src/main/resources/base/profile/main_pages.json

{
  "src": [
    "pages/Index",
    "pages/ArticleDetailPage",
    "pages/FeedArticlesPage",
    "pages/AddFeedPage",
    "pages/SettingsPage",
    "pages/TagsManagePage",
    "pages/SoulEditPage",        // [新增] 灵魂档案编辑
    "pages/ProfileViewPage",     // [新增] 画像查看
    "pages/ReadingStatsPage",    // [新增] 阅读统计
    "pages/DailyBriefingPage",   // [新增] 每日简报
    "pages/AISettingsPage"       // [新增] AI 设置
  ]
}
```

---

## 九、实现计划

### Phase 1：基础设施（3 天）

| 任务 | 产出文件 | 状态 |
|------|---------|------|
| 创建 MemoryFileHelper | `service/MemoryFileHelper.ets` | ⬜ |
| 创建 DateUtil | `utils/DateUtil.ets` | ⬜ |
| 创建 MemoryService 骨架 | `service/MemoryService.ets` | ⬜ |
| 定义数据模型 | `model/Models.ets` | ⬜ |
| 定义常量 | `constants/Constants.ets` | ⬜ |
| EntryAbility 初始化 | `entryability/EntryAbility.ets` | ⬜ |

### Phase 2：行为采集（3 天）

| 任务 | 修改文件 | 状态 |
|------|---------|------|
| ArticleDetailPage 埋点 | `pages/ArticleDetailPage.ets` | ⬜ |
| SearchPage 埋点 | `pages/SearchPage.ets` | ⬜ |
| 实现防抖写入 | `service/MemoryService.ets` | ⬜ |
| 日志格式化 | `service/MemoryService.ets` | ⬜ |

### Phase 3：灵魂档案（2 天）

| 任务 | 产出文件 | 状态 |
|------|---------|------|
| SoulEditPage | `pages/SoulEditPage.ets` | ⬜ |
| 设置页入口 | `pages/SettingsPage.ets` | ⬜ |

### Phase 4：画像更新（3 天）

| 任务 | 产出文件 | 状态 |
|------|---------|------|
| InterestCalculator | `utils/InterestCalculator.ets` | ⬜ |
| ProfileService | `service/ProfileService.ets` | ⬜ |
| ProfileViewPage | `pages/ProfileViewPage.ets` | ⬜ |
| ReadingStatsPage | `pages/ReadingStatsPage.ets` | ⬜ |

### Phase 5：AI 集成（5 天）

| 任务 | 产出文件 | 状态 |
|------|---------|------|
| AIService | `service/AIService.ets` | ⬜ |
| AISettingsPage | `pages/AISettingsPage.ets` | ⬜ |
| 首页智能排序 | `pages/HomePage.ets` | ⬜ |
| DailyBriefingPage | `pages/DailyBriefingPage.ets` | ⬜ |
| 精读辅助 | `pages/ArticleDetailPage.ets` | ⬜ |

---

## 十、测试计划

### 10.1 单元测试

| 模块 | 测试点 |
|------|--------|
| DateUtil | today(), yesterday(), daysAgo(), formatTime(), formatDuration() |
| InterestCalculator | updateWeight(), calculateSignal(), getTrend() |
| MemoryFileHelper | 读/写/追加/删除/列表 |

### 10.2 集成测试

| 场景 | 测试点 |
|------|--------|
| 行为记录 | 进入文章→记录 READ→离开→记录 READ_END |
| 防抖写入 | 快速操作多次，验证合并写入 |
| 日志清理 | 创建 35 天前的日志，验证自动清理 |
| AI 排序 | Mock API 响应，验证排序逻辑 |

---

**文档结束**
