# HarmonyOS RSS 阅读器

一款运行在鸿蒙操作系统上的本地 RSS 阅读器，支持聚合订阅多个 RSS/Atom 信息源，纯本地存储，无需注册账号。

## 功能特性

- **订阅源管理** — 手动添加/删除、分组分类、OPML 导入导出
- **内容刷新** — 手动刷新、定时自动刷新、后台刷新 + 新文章通知推送
- **文章阅读** — 内置 WebView 阅读器，支持字体大小调节，可一键跳转原始页面
- **个人内容库** — 已读/未读管理、收藏、离线缓存、全文搜索、标签系统
- **鸿蒙原生 UI** — 遵循 HarmonyOS 设计规范，支持系统深色/浅色模式
- **纯本地存储** — 所有数据存储在设备本地，不收集任何用户数据

## 技术栈

| 层次 | 技术 |
|---|---|
| 开发语言 | ArkTS |
| UI 框架 | ArkUI（声明式） |
| 本地数据库 | RelationalStore（RDB） |
| 轻量配置 | Preferences |
| 网络请求 | @ohos.net.http |
| XML 解析 | @ohos.xml |
| 后台任务 | Background Tasks Kit |
| 通知 | Notification Kit |

## 系统要求

- HarmonyOS API Level 14+（HarmonyOS 5.x / 6.x）
- 支持机型：手机（竖屏为主）

## 项目结构

```
rss-reader/
├── AppScope/
│   └── app.json5                    # 应用元信息
├── entry/src/main/
│   ├── module.json5                 # 权限、Ability、后台任务声明
│   ├── resources/                   # 字符串、颜色、页面路由配置
│   └── ets/
│       ├── constants/Constants.ets  # 全局常量
│       ├── model/Models.ets         # 数据模型
│       ├── database/
│       │   └── DatabaseHelper.ets  # RDB 数据库操作
│       ├── service/
│       │   ├── RssService.ets       # HTTP 请求 + RSS/Atom 解析
│       │   ├── FeedRefreshService.ets # 刷新调度 + 通知
│       │   └── SettingsService.ets  # 设置读写
│       ├── pages/
│       │   ├── Index.ets            # 底部 Tab 导航入口
│       │   ├── HomePage.ets         # 聚合首页
│       │   ├── FeedsPage.ets        # 订阅源管理
│       │   ├── FeedArticlesPage.ets # 单源文章列表
│       │   ├── ArticleDetailPage.ets# 文章详情（内置阅读器）
│       │   ├── StarredPage.ets      # 收藏页
│       │   ├── SearchPage.ets       # 全文搜索
│       │   ├── AddFeedPage.ets      # 添加订阅源
│       │   ├── SettingsPage.ets     # 设置页
│       │   └── TagsManagePage.ets   # 标签管理
│       ├── components/
│       │   └── ArticleItemComponent.ets # 文章列表项组件
│       └── workers/
│           └── RssRefreshWorker.ets # 后台刷新 Worker
└── README.md
```

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/dizzychen/rss-reader.git
```

### 2. 用 DevEco Studio 打开

打开 DevEco Studio → **File → Open** → 选择项目根目录。

### 3. 补充图标资源

在 `entry/src/main/resources/base/media/` 下放置以下图标文件（SVG 或 PNG）：

| 文件名 | 用途 |
|---|---|
| `app_icon` | 应用图标 |
| `startIcon` | 启动页图标 |
| `ic_home` / `ic_home_filled` | 首页 Tab |
| `ic_feeds` / `ic_feeds_filled` | 订阅 Tab |
| `ic_star` / `ic_star_filled` | 收藏 Tab / 收藏按钮 |
| `ic_search` / `ic_search_filled` | 搜索 Tab |
| `ic_back` | 返回按钮 |
| `ic_add` | 添加按钮 |
| `ic_refresh` | 刷新按钮 |
| `ic_settings` | 设置按钮 |
| `ic_mark_read` | 标记已读按钮 |
| `ic_font` | 字体调节按钮 |
| `ic_open_link` | 查看原文按钮 |
| `ic_check` | 验证成功图标 |
| `ic_delete` | 删除图标 |
| `ic_arrow_right` | 列表右箭头 |

> 推荐使用 [HarmonyOS 官方图标库](https://developer.huawei.com/consumer/cn/design/harmonyos-symbol/)。

### 4. 编译运行

连接手机或启动模拟器，点击 **Run** 即可安装。

## 权限说明

| 权限 | 用途 |
|---|---|
| `ohos.permission.INTERNET` | 拉取 RSS 订阅源内容 |
| `ohos.permission.SEND_MESSAGES` | 发送新文章通知 |

## 数据库设计

| 表名 | 说明 |
|---|---|
| `feeds` | 订阅源信息 |
| `articles` | 文章内容与状态 |
| `groups` | 订阅源分组 |
| `tags` | 标签 |
| `article_tags` | 文章与标签关联 |

## License

MIT
