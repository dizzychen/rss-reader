## Why

当前 RSS 阅读器已具备完整的订阅、阅读、收藏功能，但缺乏「记忆」能力——每次打开都是全新开始，无法基于历史行为提供个性化体验。作为开发者的个人工具，需要一个能「越来越懂自己」的阅读器，实现个性化推荐、智能简报、精读辅助等功能。

## What Changes

- **新增三层记忆架构**：SOUL（灵魂层）+ PROFILE（画像层）+ DAILY（日志层），采用 Markdown 格式存储，人类可读可编辑
- **新增行为自动采集**：自动记录 READ、READ_END、STAR、UNSTAR、SKIP、SEARCH 六种行为
- **新增 AI 能力集成**：接入通义千问 API，实现智能排序、每日简报、精读辅助
- **新增 5 个设置页面**：灵魂档案编辑、画像查看、阅读统计、每日简报、AI 设置
- **修改首页排序逻辑**：从时间排序升级为 AI 智能排序（可切换）

## Capabilities

### New Capabilities

- `behavior-tracking`: 用户阅读行为自动采集与存储，包括阅读、收藏、跳过、搜索等行为的实时记录
- `soul-profile`: 灵魂档案（SOUL）管理，用户手动编辑个人特质、阅读哲学、兴趣偏好
- `user-profile`: 阅读画像（PROFILE）自动生成，基于 30 天行为数据计算兴趣权重和阅读习惯
- `ai-ranking`: AI 智能排序，基于记忆上下文为文章打分排序
- `daily-briefing`: 每日智能简报，AI 筛选值得阅读的内容并生成摘要
- `reading-assist`: 精读辅助，在文章详情页提供 AI 个性化解读
- `memory-management`: 记忆系统管理，包括查看、编辑、导出、清除记忆数据

### Modified Capabilities

（无现有能力需要修改规范）

## Impact

**新增文件**：
- 4 个服务类：MemoryService、MemoryFileHelper、ProfileService、AIService
- 2 个工具类：DateUtil、InterestCalculator
- 5 个新页面：SoulEditPage、ProfileViewPage、ReadingStatsPage、DailyBriefingPage、AISettingsPage

**修改文件**：
- Models.ets：新增行为、画像等数据模型
- Constants.ets：新增记忆系统相关常量
- EntryAbility.ets：新增 MemoryService 初始化
- ArticleDetailPage.ets：新增阅读行为埋点 + AI 解读入口
- SearchPage.ets：新增搜索行为埋点
- HomePage.ets：新增智能排序逻辑
- SettingsPage.ets：新增记忆管理入口

**存储影响**：
- 新增 `{filesDir}/memory/` 目录
- 预计占用 ~155KB（30 天数据）

**依赖**：
- 通义千问 API（需用户配置 API Key）
- 网络权限（已有）
