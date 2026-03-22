## 1. 基础设施

- [x] 1.1 创建 `utils/DateUtil.ets` - 日期工具类（today, yesterday, daysAgo, formatTime, formatDuration）
- [x] 1.2 创建 `service/MemoryFileHelper.ets` - 文件操作工具类（readMarkdown, writeMarkdown, appendMarkdown, exists, ensureDir, listFiles, deleteFile）
- [x] 1.3 在 `model/Models.ets` 中添加行为数据模型（BehaviorAction, UserBehavior, DailyStats, InterestWeight, UserProfile）
- [x] 1.4 在 `constants/Constants.ets` 中添加记忆系统常量（MEMORY_DIR, MEMORY_DAILY_DIR, MEMORY_SOUL_FILE, MEMORY_PROFILE_FILE 等）
- [x] 1.5 创建 `service/MemoryService.ets` 骨架 - 单例模式、init 方法、目录初始化

## 2. 行为采集

- [x] 2.1 实现 MemoryService.recordBehavior() - 防抖队列机制
- [x] 2.2 实现 MemoryService.flushBehaviors() - 批量写入日志文件
- [x] 2.3 实现 MemoryService.createDailyLogHeader() - 创建日志文件头
- [x] 2.4 实现 MemoryService.formatBehaviorLine() - 格式化单条行为为表格行
- [x] 2.5 修改 ArticleDetailPage - 添加 READ/READ_END 行为埋点
- [x] 2.6 修改 ArticleDetailPage - 添加 STAR/UNSTAR 行为埋点
- [x] 2.7 修改 SearchPage - 添加 SEARCH 行为埋点

## 3. 灵魂档案

- [x] 3.1 实现 MemoryService 的 SOUL 操作（getSoul, hasSoul, updateSoul）
- [x] 3.2 创建 `pages/SoulEditPage.ets` - 灵魂档案查看和编辑页面
- [x] 3.3 在 `resources/base/profile/main_pages.json` 中注册 SoulEditPage 路由
- [x] 3.4 修改 SettingsPage - 添加「我的阅读档案」入口

## 4. 阅读画像

- [x] 4.1 创建 `utils/InterestCalculator.ets` - EMA 兴趣权重计算器
- [x] 4.2 创建 `service/ProfileService.ets` - 画像计算服务（parseDaily, aggregateStats, regenerate）
- [x] 4.3 实现 MemoryService 的 PROFILE 操作（getProfile, updateProfile）
- [x] 4.4 实现 MemoryService.dailyMaintenance() - 每日维护任务（画像更新、日志清理）
- [x] 4.5 实现 MemoryService.cleanOldLogs() - 清理 30 天前日志
- [x] 4.6 创建 `pages/ProfileViewPage.ets` - 画像查看页面
- [x] 4.7 创建 `pages/ReadingStatsPage.ets` - 阅读统计页面
- [x] 4.8 在 `resources/base/profile/main_pages.json` 中注册 ProfileViewPage 和 ReadingStatsPage 路由
- [x] 4.9 修改 SettingsPage - 添加「阅读画像」和「阅读统计」入口

## 5. AI 服务

- [x] 5.1 创建 `service/AIService.ets` - AI 服务骨架（单例、setApiKey、hasApiKey）
- [x] 5.2 实现 AIService.chat() - 通义千问 API 调用
- [x] 5.3 实现 MemoryService.buildAIContext() - 构建 AI 上下文（SOUL + PROFILE + 今日日志摘要）
- [x] 5.4 创建 `pages/AISettingsPage.ets` - AI 设置页面（API Key 配置）
- [x] 5.5 在 `resources/base/profile/main_pages.json` 中注册 AISettingsPage 路由
- [x] 5.6 修改 SettingsPage - 添加「AI 设置」入口

## 6. 智能排序

- [x] 6.1 实现 AIService.rankArticles() - 文章智能排序
- [x] 6.2 修改 HomePage - 添加排序模式切换（智能/最新）
- [x] 6.3 修改 HomePage - 集成 AI 排序逻辑
- [x] 6.4 实现排序结果缓存（1 小时有效期）
- [x] 6.5 实现 AI 排序失败降级逻辑

## 7. 每日简报

- [x] 7.1 实现 AIService.generateBriefing() - 每日简报生成
- [x] 7.2 创建 `pages/DailyBriefingPage.ets` - 每日简报页面
- [x] 7.3 在 `resources/base/profile/main_pages.json` 中注册 DailyBriefingPage 路由
- [x] 7.4 修改 HomePage - 添加每日简报卡片入口
- [x] 7.5 实现简报开关设置（SettingsService）

## 8. 精读辅助

- [x] 8.1 实现 AIService.analyzeArticle() - 精读辅助分析
- [x] 8.2 修改 ArticleDetailPage - 添加「AI 解读」按钮
- [x] 8.3 创建 AI 解读弹窗/面板组件
- [x] 8.4 实现加载状态和错误处理

## 9. 初始化与集成

- [x] 9.1 修改 EntryAbility - 添加 MemoryService.init() 调用
- [x] 9.2 修改 EntryAbility - 加载 AI API Key 到 AIService
- [x] 9.3 实现 SettingsService 的 AI API Key 存储方法（getAIApiKey, setAIApiKey）

## 10. 记忆管理

- [x] 10.1 修改 SettingsPage - 添加「数据管理」分组（导出、清除）
- [x] 10.2 实现记忆数据导出功能
- [x] 10.3 实现记忆数据清除功能（带确认对话框）
