# RSS Reader

一款基于 HarmonyOS 的智能 RSS 阅读器，使用 ArkTS/ArkUI 构建，支持 AI 辅助阅读与个性化内容推荐。

## 功能特性

### 核心阅读

- **RSS/Atom 订阅** — 支持添加、分组管理 RSS 和 Atom 格式的订阅源
- **文章阅读** — Markdown 渲染，支持字体大小调节
- **收藏与标签** — 文章收藏、自定义标签分类管理
- **全文搜索** — 快速检索已订阅的文章内容

### 订阅管理

- **OPML 导入/导出** — 兼容主流阅读器的订阅列表迁移
- **后台刷新** — 基于 WorkScheduler 的定时后台更新
- **分组管理** — 按主题或来源对订阅源进行分组

### AI 智能

- **每日简报** — AI 生成的每日阅读摘要
- **AI 服务集成** — 支持配置自定义 AI 服务提供商（兼容 DashScope 等）

### 记忆系统

应用内置三层记忆架构（参考 OpenClaw），实现从"了解用户"到"个性化推荐"的完整闭环：

```
灵魂层 (SOUL.md)        → 你的本性：价值观、长期目标、阅读哲学        [用户手动编辑，季度更新]
    ↓
画像层 (PROFILE.md)      → 你的近况：兴趣权重、阅读习惯、统计数据      [系统自动生成，每日更新]
    ↓
日志层 (daily/*.md)      → 你的今天：具体阅读行为、时间、时长          [实时记录，30天自动清理]
```

**灵魂档案 (SOUL.md)**
- 用户手动编辑的个人阅读画像，记录职业背景、兴趣领域、阅读目的、不感兴趣的内容等
- 首次安装从模板初始化，后续用户自由修改，系统不会覆盖
- 入口：设置 → 我的阅读档案

**阅读画像 (PROFILE.md)**
- 由 `ProfileService` 基于最近 30 天的行为数据自动生成
- 包含阅读概览（累计天数、文章数、日均阅读、平均时长）和订阅源兴趣权重（EMA 算法 + 阅读时长加权）
- **AI 综合分析**：每日维护时调用 AI 提取话题兴趣、阅读风格标签、兴趣漂移趋势和不感兴趣模式
- 完全自动化，用户无需手动维护

**行为日志 (daily/YYYY-MM-DD.md)**
- 实时采集用户行为：阅读(READ)、阅读结束(READ_END)、收藏(STAR)、取消收藏(UNSTAR)、跳过(SKIP)、搜索(SEARCH)、用户评分(RATE)、推荐命中(AI_REC_HIT)
- 以 Markdown 表格格式存储，每日一个文件，超过 30 天自动清理
- 采用防抖批量写入策略，减少 I/O 开销

**用户主动反馈**
- 文章详情页底部提供 "有价值 / 不感兴趣" 二元反馈按钮
- 首页列表左滑快速标记 "不感兴趣"，文章自动移除
- 反馈数据参与兴趣权重计算和 AI 画像综合

**AI 个性化推荐流程**
1. 系统读取 SOUL.md + PROFILE.md + 今日日志 + AI 洞察摘要，构建完整用户上下文
2. 调用 AI 服务为文章打分，按个性化分数排序展示
3. 追踪推荐命中率（用户是否点击了 AI 推荐的文章），反馈到画像综合
4. 支持 AI 排序缓存，避免重复请求

**数据安全**
- 所有记忆数据存储在应用沙箱目录，不上传云端
- 支持记忆数据导出与一键清除
- 支持重置为初始模板

### 阅读统计

- **阅读统计** — 阅读时长、文章数量、活跃天数、偏好阅读时段等多维度数据统计
- **兴趣分析** — 基于 EMA 算法 + 阅读深度加权自动计算订阅源偏好权重
- **话题提取** — AI 从已读文章标题中提取 5-8 个话题关键词及权重
- **搜索兴趣** — 聚合高频搜索关键词，纳入画像和 AI 上下文
- **每日简报** — AI 结合记忆上下文生成个性化阅读摘要

## 技术栈

| 项目 | 说明 |
|------|------|
| 平台 | HarmonyOS |
| 语言 | ArkTS |
| UI 框架 | ArkUI（声明式） |
| 应用模型 | Stage 模型 |
| 构建工具 | Hvigor |
| 包管理 | OHPM |
| 数据库 | RDB（relationalStore） |
| SDK | 6.0.0 ~ 6.0.2 |

## 项目结构

```
rss-reader/
├── AppScope/                  # 应用级配置与共享资源
│   ├── app.json5              # 应用包名、版本号等
│   └── resources/             # 全局资源（图标、字符串）
├── entry/                     # 主模块
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/  # 应用入口 Ability
│       │   ├── extension/     # WorkScheduler 后台刷新扩展
│       │   ├── pages/         # 页面
│       │   │   ├── Index.ets            # 主页（Tab 容器）
│       │   │   ├── HomePage.ets         # 首页 Tab
│       │   │   ├── FeedsPage.ets        # 订阅 Tab
│       │   │   ├── StarredPage.ets      # 收藏 Tab
│       │   │   ├── MePage.ets           # 我的 Tab
│       │   │   ├── ArticleDetailPage.ets # 文章详情
│       │   │   ├── AddFeedPage.ets      # 添加订阅
│       │   │   ├── SettingsPage.ets     # 设置
│       │   │   ├── AISettingsPage.ets   # AI 设置
│       │   │   ├── DailyBriefingPage.ets # 每日简报
│       │   │   ├── ReadingStatsPage.ets # 阅读统计
│       │   │   └── ...
│       │   ├── service/       # 业务服务层
│       │   │   ├── RssService.ets       # RSS 解析与获取
│       │   │   ├── FeedRefreshService.ets # 订阅刷新
│       │   │   ├── AIService.ets        # AI 服务
│       │   │   ├── MemoryService.ets    # 记忆系统
│       │   │   ├── ProfileService.ets   # 用户画像
│       │   │   ├── SettingsService.ets  # 设置管理
│       │   │   ├── OPMLService.ets      # OPML 导入导出
│       │   │   └── WorkSchedulerManager.ets # 后台任务调度
│       │   ├── database/      # 数据库
│       │   │   └── DatabaseHelper.ets   # RDB 操作封装
│       │   ├── model/         # 数据模型
│       │   │   └── Models.ets           # Feed, Article, Tag 等
│       │   ├── components/    # 公共组件
│       │   ├── utils/         # 工具类
│       │   └── constants/     # 常量定义
│       └── resources/         # 模块资源（颜色、字符串、rawfile）
│           └── rawfile/memory/  # 记忆系统模板（SOUL.md, PROFILE.md）
├── hvigor/                    # Hvigor 构建配置
├── oh-package.json5           # OHPM 依赖
└── build-profile.json5        # 构建配置
```

## 依赖

| 包名 | 版本 | 用途 |
|------|------|------|
| `@luvi/lv-markdown-in` | ^2.0.0 | Markdown 内容渲染 |
| `@ohos/hypium` | 1.0.25 | 测试框架（dev） |
| `@ohos/hamock` | 1.0.0 | Mock 工具（dev） |

## 权限

| 权限 | 用途 |
|------|------|
| `ohos.permission.INTERNET` | 获取 RSS 订阅源内容 |

## 开发环境

- **IDE**: DevEco Studio
- **SDK**: HarmonyOS SDK 6.0.0+
- **设备**: phone

## 快速开始

1. 克隆项目

```bash
git clone <repository-url>
```

2. 使用 DevEco Studio 打开项目根目录

3. 安装依赖

```bash
ohpm install
```

4. 连接 HarmonyOS 设备或启动模拟器

5. 点击 **Run** 编译并部署到设备

## 记忆系统存储结构

运行时记忆数据存储在应用沙箱目录：

```
{context.filesDir}/memory/
├── SOUL.md              # 灵魂档案（用户编辑）
├── PROFILE.md           # 阅读画像（系统自动生成）
└── daily/
    ├── 2026-03-23.md    # 今日行为日志
    ├── 2026-03-22.md
    └── ...              # 保留最近 30 天
```

## 应用权限说明

本应用仅申请网络权限（`ohos.permission.INTERNET`），用于从互联网获取 RSS 订阅源内容。不涉及用户隐私数据的采集或上传。

## 许可证

MIT
