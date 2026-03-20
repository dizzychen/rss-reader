# CODEBUDDY.md This file provides guidance to CodeBuddy when working with code in this repository.

## Project Overview

RssReader 是一个 HarmonyOS NEXT (API 6.0) RSS 阅读器应用，使用 ArkTS + ArkUI 声明式框架，采用 Stage 模型。包名 `com.dizzy.myapplication`，目标设备为 phone。

- **SDK**: compatibleSdkVersion 6.0.0(20), targetSdkVersion 6.0.2(22)
- **唯一运行时依赖**: 无三方运行时依赖（XML 解析使用纯正则引擎，无需任何 XML 库）
- **测试框架**: `@ohos/hypium 1.0.25` + `@ohos/hamock 1.0.0`
- **权限**: `ohos.permission.INTERNET`

## Build & Development Commands

### 构建项目
通过 DevEco Studio 构建，或使用 hvigor CLI：
```bash
hvigorw assembleHap --mode module -p module=entry@default
```
根级 `hvigorfile.ts` 使用 `appTasks` 插件，entry 模块使用 `hapTasks` 插件。构建配置分 debug/release 两种模式，release 可选开启混淆（`entry/build-profile.json5` 中 `artifactType: "obfuscation"`）。

### 代码检查
```bash
hvigorw lint
```
启用了 `@performance/recommended` 和 `@typescript-eslint/recommended` 规则集，详见 `code-linter.json5`。

### 运行设备端测试
```bash
hvigorw assembleHap --mode module -p module=entry@ohosTest
```
设备端测试位于 `entry/src/ohosTest/`，使用 `@ohos/hypium` 框架。测试通过提取纯函数逻辑来避免直接依赖系统 API（RDB、HTTP）。

### 运行本地单元测试
本地测试位于 `entry/src/test/`，当前仅含模板测试。

## Architecture

### 整体分层

应用采用**页面 → 服务 → 数据库**三层架构，服务层均为单例模式：

```
EntryAbility (应用入口，初始化 DB + Settings)
    │
    ▼
Index.ets (底部 Tabs: 首页 | 订阅 | 收藏 | 搜索)
    │
    ├─ HomePage ──→ SettingsPage ──→ TagsManagePage
    ├─ FeedsPage ──→ AddFeedPage
    │              └→ FeedArticlesPage ──→ ArticleDetailPage
    ├─ StarredPage ──→ ArticleDetailPage
    └─ SearchPage ──→ ArticleDetailPage

服务层 (单例):
  DatabaseHelper  ── relationalStore (RDB)
  RssService      ── HTTP 抓取 + 纯正则 XML 解析
  FeedRefreshService ── 批量刷新 + 通知
  SettingsService ── preferences 键值存储
```

### 导航模式

采用**两级导航**：

1. **Tab 导航** — `Index.ets` 内嵌 4 个 `@Component` 子页面（HomePage、FeedsPage、StarredPage、SearchPage），不注册为独立路由。
2. **页面栈导航** — 通过 `router.pushUrl` 跳转到 `@Entry` 页面（ArticleDetailPage、FeedArticlesPage、AddFeedPage、SettingsPage、TagsManagePage）。

路由注册在 `entry/src/main/resources/base/profile/main_pages.json`。

### 数据模型 (`model/Models.ets`)

6 个 interface 定义了核心数据结构：

| 模型 | 关键字段 | 说明 |
|------|---------|------|
| `FeedGroup` | id, name, sortOrder | 订阅源分组，默认分组 id=1 |
| `Feed` | id, title, url(唯一), groupId, unreadCount? | 订阅源 |
| `Article` | id, feedId, guid, isRead(0/1), isStarred(0/1), coverImage | 文章，(feedId, guid) 联合唯一 |
| `Tag` | id, name(唯一) | 标签 |
| `ArticleTag` | articleId, tagId | 多对多关联 |
| `AppSettings` | refreshInterval, fontSize, cacheCountPerFeed, ... | 应用设置 |

### 数据库 (`database/DatabaseHelper.ets`)

- 数据库名 `rss_reader.db`，安全级别 S1，5 张表（groups, feeds, articles, tags, article_tags）
- 通过 `getInstance()` 获取单例，`init(context)` 在 EntryAbility.onCreate 中调用
- 文章插入使用 `ON_CONFLICT_IGNORE` 策略（基于 feedId+guid 去重）
- 删除 Feed 时级联删除其文章和标签关联
- 删除 FeedGroup 时将其下 Feed 移至默认分组（id=1）而非删除
- `cleanOldCache(feedId, keepCount)` 保留收藏文章不被清理

### 服务层

**RssService** (`service/RssService.ets`):
- 支持 RSS 2.0、Atom、RDF 三种格式自动检测与解析
- 输出统一的 `ParsedFeedInfo { title, siteUrl, description, iconUrl, articles[] }`
- 工具函数：`stripHtml()`（HTML 去标签+实体解码）、`parseDate()`（RFC 822 + ISO 8601）、`extractFirstImage()`（从 HTML 提取首图）、`formatDate()`（相对时间格式化）
- 封面图优先级：RSS enclosure 图片 > 内容中首个 `<img>` 标签

**FeedRefreshService** (`service/FeedRefreshService.ets`):
- `refreshAll(context)` 遍历所有 Feed 刷新，返回新增文章总数，有新文章且通知启用时发送系统通知
- `refreshSingleFeed(feed)` 抓取→解析→插入文章→更新 Feed 元信息

**SettingsService** (`service/SettingsService.ets`):
- 使用 `@kit.ArkData` preferences 做键值持久化
- 设置键名和默认值定义在 `constants/Constants.ets`

### 状态管理

项目使用**组件级状态**，无全局状态管理（不使用 AppStorage）：

- `@State` — 页面本地状态（articles、feeds、isLoading 等）
- `@Prop` — ArticleItemComponent 接收父组件数据（单向数据流）
- 回调函数（`onTap`、`onStarToggle`）实现父子组件通信
- 数据变更后通过重新调用 `loadData()` 刷新列表
- `$$` 双向绑定仅用于 Refresh 组件的 `refreshing` 属性

### 可复用组件

**ArticleItemComponent** (`components/ArticleItemComponent.ets`):
- 唯一的抽取组件，被 HomePage、FeedArticlesPage、SearchPage、StarredPage 四处复用
- 接收 `@Prop article: Article` + `onTap`/`onStarToggle` 回调
- 展示封面图（80x80，可选）、标题、摘要、来源、时间、收藏按钮
- 已读文章标题颜色变浅

### 文章详情渲染

`ArticleDetailPage` 使用 WebView 加载自定义 HTML 模板渲染文章内容，支持：
- 4 档字体大小切换（循环切换，持久化到 SettingsService）
- 收藏切换
- 「查看原文」模式（加载原始 URL）
- 进入时自动标记已读

### 搜索实现

`SearchPage` 实现了 400ms 防抖的实时搜索，数据库层使用 `contains` 匹配标题+摘要+内容，支持按订阅源过滤（横向滚动 Chip 选择器）。

### 测试结构

设备端测试 (`entry/src/ohosTest/ets/tests/`) 覆盖：
- `ConstantsTest` — 常量、键名、默认值
- `DatabaseHelperTest` — 数据映射、查询逻辑、级联删除、未读数
- `FeedRefreshServiceTest` — 刷新计数、通知逻辑、元信息更新
- `ModelsTest` — 全部数据模型完整性
- `RssServiceTest` — 单例、日期格式化、HTML 处理、RSS/Atom 解析
- `RssUtilsTest` — 纯函数单元测试（stripHtml、parseDate、extractFirstImage 等）

测试入口在 `entry/src/ohosTest/ets/test/List.test.ets`，通过 import 聚合各测试文件。

## Key Configuration Files

| 文件 | 作用 |
|------|------|
| `build-profile.json5` | 全局构建配置（SDK 版本、构建模式） |
| `entry/build-profile.json5` | 模块构建配置（target、混淆） |
| `entry/src/main/module.json5` | 模块声明（abilities、权限、设备类型） |
| `entry/src/main/resources/base/profile/main_pages.json` | 路由页面注册 |
| `constants/Constants.ets` | 所有数据库表名、Preferences 键名、默认值、选项配置 |
| `code-linter.json5` | Lint 规则配置 |
