// 首页：展示所有文章（聚合视图）
import { Article, Feed, copyArticle } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { FeedRefreshService } from '../service/FeedRefreshService';
import { MemoryService } from '../service/MemoryService';
import { SettingsService } from '../service/SettingsService';
import { RecommendService } from '../service/RecommendService';
import { AIService } from '../service/AIService';
import { BriefingService } from '../service/BriefingService';
import { Constants } from '../constants/Constants';
import { ArticleItemComponent } from '../components/ArticleItemComponent';
import { BackupService } from '../service/BackupService';
import { common } from '@kit.AbilityKit';

@Component
export struct HomePage {
  @State latestArticles: Article[] = [];
  @State recommendArticles: Article[] = [];
  @State isLoading: boolean = false;
  @State isLoadingMore: boolean = false;
  @State hasMore: boolean = true;
  @State onlyUnread: boolean = true;
  @State isRefreshing: boolean = false;
  @State briefingEnabled: boolean = true;
  @State sortMode: string = Constants.SORT_MODE_LATEST;
  @State currentTabIndex: number = 0; // 0: 最新, 1: 推荐
  @Prop @Watch('onRefreshTickChanged') refreshTick: number = 0;
  @Prop @Watch('onFullReloadTickChanged') fullReloadTick: number = 0;
  @State private listVersion: number = 0; // 每次 loadArticles(true) 后递增，强制 ForEach 重新渲染
  private pageOffset: number = 0;
  private recommendPage: number = 0;
  private pageSize: number = 30;
  private feedMap: Map<number, string> = new Map();
  private exposedArticleIds: Map<number, string> = new Map();
  private recExposureDedup: Set<number> = new Set(); // 日级曝光去重，防止同一篇文章重复计 REC_EXPOSURE
  private recExposureDedupDate: string = '';          // 去重集合对应的日期
  private tabController: TabsController = new TabsController();
  private isFullReloading: boolean = false; // 防止并发 loadArticles(true)
  private sortModeReady: boolean = false; // sortMode 是否已从持久化恢复完毕
  private syncTimerId: number = -1; // syncArticleStatus 中 setTimeout 的 ID

  /** 获取当前 Tab 对应的文章列表 */
  private getCurrentArticles(): Article[] {
    return this.sortMode === Constants.SORT_MODE_RECOMMEND ? this.recommendArticles : this.latestArticles;
  }

  /** 设置当前 Tab 对应的文章列表 */
  private setCurrentArticles(items: Article[]) {
    if (this.sortMode === Constants.SORT_MODE_RECOMMEND) {
      this.recommendArticles = items;
    } else {
      this.latestArticles = items;
    }
  }

  aboutToAppear() {
    this.loadAISettings();
    this.initLoad();
    // 监听恢复提示事件
    const hostContext = this.getUIContext()?.getHostContext();
    if (hostContext) {
      hostContext.eventHub.on('need_restore', () => {
        this.showRestoreDialog();
      });
    }
  }

  aboutToDisappear() {
    super.aboutToDisappear?.();
    // 移除事件监听
    const hostContext = this.getUIContext()?.getHostContext();
    if (hostContext) {
      hostContext.eventHub.off('need_restore');
    }
    // 清理定时器
    if (this.syncTimerId !== -1) {
      clearTimeout(this.syncTimerId);
      this.syncTimerId = -1;
    }
  }

  private async showRestoreDialog() {
    const ctx = this.getUIContext();
    ctx.showAlertDialog({
      title: '发现备份数据',
      message: '检测到您可能是重装了应用，是否从公共目录的备份恢复数据？',
      primaryButton: {
        value: '立即恢复',
        action: async () => {
          try {
            const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
            const backupService = BackupService.getInstance();
            const json = await backupService.loadBackupFromPublic(context);
            const result = await backupService.restoreBackup(json);
            let msg = `恢复完成：${result.feedCount} 个订阅源`;
            if (result.groupCount > 0) msg += `、${result.groupCount} 个分组`;
            if (result.skippedFeeds > 0) msg += `（${result.skippedFeeds} 个已存在跳过）`;
            if (result.settingsRestored) msg += '，配置已恢复';
            ctx.getPromptAction().showToast({ message: msg });
            // 重新加载数据
            this.initLoad();
          } catch (e) {
            ctx.getPromptAction().showToast({ message: `恢复失败：${e instanceof Error ? e.message : String(e)}` });
          }
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }

  /**
   * 初始化加载：先恢复排序模式，再加载文章列表
   * 解决 loadSortMode 和 loadArticles 并行导致推荐角标缺失的竞态问题
   */
  private async initLoad() {
    await this.loadSortMode();
    this.sortModeReady = true;
    // fullReloadTick > 0 说明在等待 sortMode 期间后台刷新已完成，
    // 直接用 reset=true 加载最新数据即可
    this.loadArticles(true);
  }

  async loadAISettings() {
    try {
      this.briefingEnabled = await SettingsService.getInstance().getBriefingEnabled();
    } catch (e) {
      // 忽略错误
    }
  }

  async loadSortMode() {
    try {
      const saved = await SettingsService.getInstance().getSortMode();
      if (saved === Constants.SORT_MODE_RECOMMEND) {
        this.sortMode = Constants.SORT_MODE_RECOMMEND;
        this.currentTabIndex = 1;
      } else {
        this.currentTabIndex = 0;
      }
    } catch (e) {
      // 使用默认值
    }
  }

  async saveSortMode(mode: string) {
    try {
      await SettingsService.getInstance().setSortMode(mode);
    } catch (e) {
      // 忽略保存错误
    }
  }

  onRefreshTickChanged() {
    // 从详情页返回时，仅增量同步文章状态（已读/收藏），不重新加载列表
    // 避免"仅未读"模式下已读文章突然消失造成界面抖动
    this.syncArticleStatus();
  }

  onFullReloadTickChanged() {
    // 后台刷新完成后，完整重新加载文章列表
    // 必须等 sortMode 恢复完毕，否则推荐模式下会错误地以"最新"模式加载（无角标）
    if (!this.sortModeReady) {
      console.info('HomePage', 'onFullReloadTickChanged: sortMode 未就绪，延迟到 initLoad 完成后自动加载');
      return;
    }
    if (this.isFullReloading) {
      console.info('HomePage', 'onFullReloadTickChanged: 已在刷新中，当前加载将包含最新数据');
      return;
    }
    this.loadArticles(true);
  }

  /**
   * 增量同步：更新当前列表中文章的已读/收藏状态
   * 当 onlyUnread=true 时，已读文章通过动画平滑移除，避免界面抖动
   */
  private async syncArticleStatus() {
    const articles = this.getCurrentArticles();
    if (articles.length === 0) return;
    try {
      const ids = articles.filter(a => a.id !== undefined).map(a => a.id!);
      const statusMap = await DatabaseHelper.getInstance().getArticlesStatus(ids);
      let changed = false;
      // 收集新变为已读的文章 ID
      const newlyReadIds = new Set<number>();
      const updated: Article[] = articles.map(a => {
        const status = a.id !== undefined ? statusMap.get(a.id) : undefined;
        if (status) {
          const newRead = status['isRead'] ?? a.isRead;
          const newStarred = status['isStarred'] ?? a.isStarred;
          if (newRead !== a.isRead || newStarred !== a.isStarred) {
            changed = true;
            if (newRead === 1 && a.isRead === 0 && a.id !== undefined) {
              newlyReadIds.add(a.id);
            }
            const copy: Article = {
              id: a.id, feedId: a.feedId, feedTitle: a.feedTitle,
              guid: a.guid, title: a.title, summary: a.summary,
              content: a.content, url: a.url, author: a.author,
              publishedAt: a.publishedAt, isRead: newRead,
              isStarred: newStarred, coverImage: a.coverImage, cachedAt: a.cachedAt,
              recommendScore: a.recommendScore, recommendReason: a.recommendReason
            };
            return copy;
          }
        }
        return a;
      });
      if (changed) {
        if (this.onlyUnread && newlyReadIds.size > 0) {
          // 先更新状态（让文章样式变灰），再用动画移除
          this.setCurrentArticles(updated);
          // 短暂延迟后平滑移除已读文章
          this.syncTimerId = setTimeout(() => {
            this.syncTimerId = -1;
            animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
              const current = this.getCurrentArticles();
              this.setCurrentArticles(current.filter(a => !newlyReadIds.has(a.id!)));
            });
          }, 150);
        } else {
          this.setCurrentArticles(updated);
        }
      }
    } catch (e) {
      console.error('HomePage', `syncArticleStatus failed: ${e}`);
    }
  }

  /**
   * 进入详情前先落库已读，并同步当前列表，避免已读文章仍停留在仅未读列表
   */
  private async preMarkArticleAsRead(article: Article): Promise<void> {
    if (article.id === undefined || article.isRead === 1) {
      return;
    }
    try {
      await DatabaseHelper.getInstance().markRead(article.id, 1);
    } catch (e) {
      console.error('HomePage', `preMarkArticleAsRead DB update failed: ${e}`);
    }

    const current = this.getCurrentArticles();
    const idx = current.findIndex(a => a.id === article.id);
    if (idx < 0) {
      return;
    }

    if (this.onlyUnread) {
      this.setCurrentArticles(current.filter(a => a.id !== article.id));
      return;
    }

    const target = current[idx];
    const updated: Article = {
      id: target.id, feedId: target.feedId, feedTitle: target.feedTitle,
      guid: target.guid, title: target.title, summary: target.summary,
      content: target.content, url: target.url, author: target.author,
      publishedAt: target.publishedAt, isRead: 1,
      isStarred: target.isStarred, coverImage: target.coverImage, cachedAt: target.cachedAt,
      recommendScore: target.recommendScore, recommendReason: target.recommendReason
    };
    const copy = [...current];
    copy[idx] = updated;
    this.setCurrentArticles(copy);
  }

  async loadArticles(reset: boolean = true) {
    // 防止多个 loadArticles(true) 并发执行（如下拉刷新和自动刷新同时触发）
    if (reset && this.isFullReloading) {
      console.info('HomePage', 'loadArticles(true) 已在进行中，跳过重复调用');
      return;
    }
    if (reset) {
      this.isFullReloading = true;
    }
    const articles = this.getCurrentArticles();
    if (reset) {
      this.flushSkipBehaviors();
      this.pageOffset = 0;
      this.recommendPage = 0;
      this.hasMore = true;
      // 仅在列表为空时显示全屏 Loading，否则保持当前列表不动
      if (articles.length === 0) {
        this.isLoading = true;
      }
      RecommendService.getInstance().clearScoredCache();
    } else {
      if (!this.hasMore || this.isLoadingMore) return;
      this.isLoadingMore = true;
    }
    try {
      const db = DatabaseHelper.getInstance();
      // reset 时重建 feedMap
      if (reset) {
        const feeds: Feed[] = await db.getAllFeeds();
        this.feedMap.clear();
        for (const f of feeds) {
          this.feedMap.set(f.id!, f.title);
        }
      }

      let items: Article[];

      if (this.sortMode === Constants.SORT_MODE_RECOMMEND) {
        items = await this.loadRecommendArticles(reset);
      } else {
        items = await this.loadLatestArticles(reset);
      }

      // 给每篇文章附加来源名称
      for (const item of items) {
        if (!item.feedTitle) {
          item.feedTitle = this.feedMap.get(item.feedId) ?? '';
        }
      }
      if (reset) {
        this.setCurrentArticles(items);
        this.exposedArticleIds.clear();
        this.listVersion++;
      } else {
        this.setCurrentArticles(this.getCurrentArticles().concat(items));
      }
      // 记录曝光的文章 ID
      for (const item of items) {
        if (item.id !== undefined) {
          this.exposedArticleIds.set(item.id, item.feedTitle ?? '');
        }
      }
      // 推荐模式下记录 REC_EXPOSURE（同一篇文章同一天只计一次曝光）
      if (this.sortMode === Constants.SORT_MODE_RECOMMEND) {
        const today = new Date().toISOString().slice(0, 10);
        if (this.recExposureDedupDate !== today) {
          this.recExposureDedup.clear();
          this.recExposureDedupDate = today;
        }
        const now = Date.now();
        for (let i = 0; i < items.length; i++) {
          const item = items[i];
          if (item.id !== undefined && !this.recExposureDedup.has(item.id)) {
            this.recExposureDedup.add(item.id);
            MemoryService.getInstance().recordBehavior({
              timestamp: now,
              action: 'REC_EXPOSURE',
              articleId: item.id,
              articleTitle: item.title,
              feedTitle: item.feedTitle
            });
          }
        }
      }
      if (this.sortMode === Constants.SORT_MODE_LATEST) {
        this.pageOffset += items.length;
        this.hasMore = items.length >= this.pageSize;
      }
    } catch (e) {
      console.error('HomePage', `加载失败: ${e}`);
    } finally {
      this.isLoading = false;
      this.isLoadingMore = false;
      if (reset) {
        this.isFullReloading = false;
      }
    }
  }

  /**
   * 最新模式：时间倒序分页
   */
  private async loadLatestArticles(reset: boolean): Promise<Article[]> {
    const db = DatabaseHelper.getInstance();
    return await db.getAllArticles(this.onlyUnread, this.pageSize, this.pageOffset);
  }

  /**
   * 推荐模式：优先使用 AI 排序，无 AI Key 时降级为本地评分
   */
  private async loadRecommendArticles(reset: boolean): Promise<Article[]> {
    const db = DatabaseHelper.getInstance();
    const recommendSvc = RecommendService.getInstance();
    const memSvc = MemoryService.getInstance();
    const aiSvc = AIService.getInstance();

    // 获取待推荐的文章列表（跟随仅未读开关）
    const allArticles = await db.getRecentArticles(
      Constants.RECOMMEND_RECENT_DAYS, Constants.RECOMMEND_MAX_ARTICLES, this.onlyUnread);
    for (const a of allArticles) {
      a.feedTitle = this.feedMap.get(a.feedId) ?? '';
    }

    // 如果有 AI Key，尝试使用 AI 排序
    if (aiSvc.hasApiKey() && reset && allArticles.length > 0) {
      try {
        // 调用 AI 排序（内部会先检查缓存，若无缓存则请求 AI）
        const rankedIds = await aiSvc.rankArticles(allArticles);

        if (rankedIds.length > 0) {
          // AI 排序成功，按返回的 ID 顺序排列
          const articleMap = new Map<number, Article>();
          for (const a of allArticles) {
            if (a.id !== undefined) {
              articleMap.set(a.id, a);
            }
          }
          const sorted: Article[] = [];
          for (const id of rankedIds) {
            const a = articleMap.get(id);
            if (a) {
              a.recommendReason = 'AI 推荐';
              sorted.push(a);
              articleMap.delete(id);
            }
          }
          // 未在 AI 结果中的文章追加到末尾
          articleMap.forEach((a) => sorted.push(a));
          this.hasMore = sorted.length > this.pageSize;
          return sorted.slice(0, this.pageSize);
        }
      } catch (e) {
        console.warn('HomePage', `AI 排序失败，降级到本地评分: ${e}`);
        // AI 排序失败，继续使用本地评分
      }
    }

    // 无 AI Key 或 AI 排序失败：使用本地评分
    const page = reset ? 0 : this.recommendPage;
    if (reset) {
      const result = await recommendSvc.scoreAndSort(allArticles, this.feedMap, page, this.pageSize);
      this.recommendPage = 1;
      this.hasMore = result.totalCount > this.pageSize;
      // 【修复】本地评分 also 设置推荐理由，确保角标显示
      for (const a of result.articles) {
        if (!a.recommendReason) {
          a.recommendReason = '推荐';
        }
      }
      return result.articles;
    } else {
      // 分页取（从缓存评分结果切片）
      const result = await recommendSvc.scoreAndSort([], this.feedMap, this.recommendPage, this.pageSize);
      this.recommendPage++;
      this.hasMore = result.articles.length >= this.pageSize;
      // 【修复】本地评分 also 设置推荐理由，确保角标显示
      for (const a of result.articles) {
        if (!a.recommendReason) {
          a.recommendReason = '推荐';
        }
      }
      return result.articles;
    }
  }

  async doRefresh() {
    this.isRefreshing = true;
    try {
      const newCount = await FeedRefreshService.getInstance().refreshAll(this.getUIContext().getHostContext()!);
      // 手动刷新后清除画像缓存，确保推荐评分使用最新画像（角标及时生成）
      RecommendService.getInstance().clearProfileCache();
      await this.loadArticles(true);
      const msg = newCount > 0 ? `已更新 ${newCount} 篇新文章` : '暂无新内容';
      this.getUIContext().getPromptAction().showToast({ message: msg });
    } catch (e) {
      console.error('HomePage', `刷新失败: ${e}`);
    } finally {
      this.isRefreshing = false;
    }
  }

  /**
   * 将当前曝光但未点击的文章批量记录为 SKIP
   */
  private flushSkipBehaviors() {
    if (this.exposedArticleIds.size <= 3) {
      return;
    }
    const now = Date.now();
    this.exposedArticleIds.forEach((feedTitle, articleId) => {
      MemoryService.getInstance().recordBehavior({
        timestamp: now,
        action: 'SKIP',
        articleId: articleId,
        feedTitle: feedTitle
      });
    });
    this.exposedArticleIds.clear();
  }

  /**
   * 标记文章为不感兴趣（列表左滑操作）
   */
  private markDislike(article: Article) {
    MemoryService.getInstance().recordBehavior({
      timestamp: Date.now(),
      action: 'RATE',
      articleId: article.id,
      articleTitle: article.title,
      score: -1
    });
    const articles = this.getCurrentArticles();
    const idx = articles.findIndex(a => a.id === article.id);
    if (idx >= 0) {
      const copy = [...articles];
      copy.splice(idx, 1);
      this.setCurrentArticles(copy);
    }
    this.exposedArticleIds.delete(article.id!);
  }

  @Builder
  swipeDislikeBuilder(article: Article) {
    Row() {
      Text('不感兴趣')
        .fontSize(13)
        .fontColor(Color.White)
    }
    .width(80)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Constants.COLOR_DISLIKE)
    .onClick(() => this.markDislike(article))
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('AIRSS')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.onlyUnread })
          .onChange((isOn) => {
            this.onlyUnread = isOn;
            this.loadArticles(true);
          })
        Text('仅未读')
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .margin({ left: 4, right: 4 })
        // 每日简报入口按钮（若开启）
        if (this.briefingEnabled) {
          Button('简报')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_activated'))
            .backgroundColor(Color.Transparent)
            .height(28)
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/DailyBriefingPage' });
            })
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 8 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      // Tabs: 最新 / 推荐
      Tabs({ barPosition: BarPosition.Start, controller: this.tabController, index: this.currentTabIndex }) {
        TabContent() {
          this.latestListBuilder()
        }
        .tabBar(this.tabBarBuilder('最新', 0))

        TabContent() {
          this.recommendListBuilder()
        }
        .tabBar(this.tabBarBuilder('推荐', 1))
      }
      .layoutWeight(1)
      .barMode(BarMode.Fixed)
      .barWidth('100%')
      .barHeight(44)
      .animationDuration(200)
      .onChange((index: number) => {
        if (this.currentTabIndex !== index) {
          this.currentTabIndex = index;
          this.sortMode = index === 0 ? Constants.SORT_MODE_LATEST : Constants.SORT_MODE_RECOMMEND;
          this.saveSortMode(this.sortMode);
          this.loadArticles(true);
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  tabBarBuilder(title: string, index: number) {
    Column() {
      Text(title)
        .fontSize(16)
        .fontWeight(this.currentTabIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.currentTabIndex === index ?
          $r('sys.color.ohos_id_color_text_primary') :
          $r('sys.color.ohos_id_color_text_secondary'))
        .margin({ top: 8, bottom: 6 })
      Divider()
        .width(24)
        .strokeWidth(2)
        .color(this.currentTabIndex === index ?
          $r('sys.color.ohos_id_color_activated') :
          Color.Transparent)
        .borderRadius(1)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  latestListBuilder() {
    Column() {
      Refresh({ refreshing: $$this.isRefreshing }) {
        if (this.isLoading && this.latestArticles.length === 0) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .backgroundColor(Color.Transparent)
            Text('加载中...').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary')).margin({ top: 8 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.latestArticles.length === 0) {
          List() {
            ListItem() {
              Column({ space: 16 }) {
                Text('暂无文章').fontSize(16).fontColor($r('sys.color.ohos_id_color_text_secondary'))
                Text('请先在「订阅」页添加RSS源').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_tertiary'))
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
            }
          }
          .width('100%')
          .height('100%')
          .edgeEffect(EdgeEffect.Spring)
        } else {
          List() {
            ForEach(this.latestArticles, (article: Article) => {
              ListItem() {
                ArticleItemComponent({
                  article: article,
                  recommendReason: '',
                  onTap: async () => {
                    if (article.id !== undefined) {
                      this.exposedArticleIds.delete(article.id);
                    }
                    await this.preMarkArticleAsRead(article);
                    this.getUIContext().getRouter().pushUrl({
                      url: 'pages/ArticleDetailPage',
                      params: { articleId: article.id }
                    });
                  },
                  onStarToggle: async () => {
                    const newStar = article.isStarred === 1 ? 0 : 1;
                    await DatabaseHelper.getInstance().toggleStar(article.id!, newStar);
                    const idx = this.latestArticles.findIndex(a => a.id === article.id);
                    if (idx >= 0) {
                      const updated: Article = {
                        id: article.id, feedId: article.feedId, feedTitle: article.feedTitle,
                        guid: article.guid, title: article.title, summary: article.summary,
                        content: article.content, url: article.url, author: article.author,
                        publishedAt: article.publishedAt, isRead: article.isRead,
                        isStarred: newStar, coverImage: article.coverImage, cachedAt: article.cachedAt,
                        recommendScore: article.recommendScore, recommendReason: article.recommendReason
                      };
                      this.latestArticles[idx] = updated;
                      this.latestArticles = [...this.latestArticles];
                    }
                  }
                })
              }
              .swipeAction({
                end: {
                  builder: () => {
                    this.swipeDislikeBuilder(article)
                  }
                }
              })
            }, (article: Article) => `${this.listVersion}-${article.id}-${article.isStarred}-${article.isRead}`)

            ListItem() {
              Row() {
                if (this.isLoadingMore) {
                  LoadingProgress()
                    .width(24)
                    .height(24)
                    .backgroundColor(Color.Transparent)
                } else if (this.hasMore) {
                  Button('加载更多')
                    .fontSize(14)
                    .fontColor($r('sys.color.ohos_id_color_activated'))
                    .backgroundColor(Color.Transparent)
                    .onClick(() => this.loadArticles(false))
                } else {
                  Text('已加载全部文章')
                    .fontSize(13)
                    .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding(16)
            }
          }
          .width('100%')
          .height('100%')
          .divider({ strokeWidth: 0.5, color: $r('sys.color.ohos_id_color_list_separator') })
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .onRefreshing(() => this.doRefresh())
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  recommendListBuilder() {
    Column() {
      Refresh({ refreshing: $$this.isRefreshing }) {
        if (this.isLoading && this.recommendArticles.length === 0) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
              .backgroundColor(Color.Transparent)
            Text('加载中...').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary')).margin({ top: 8 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
        } else if (this.recommendArticles.length === 0) {
          List() {
            ListItem() {
              Column({ space: 16 }) {
                Text('暂无文章').fontSize(16).fontColor($r('sys.color.ohos_id_color_text_secondary'))
                Text('请先在「订阅」页添加RSS源').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_tertiary'))
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
            }
          }
          .width('100%')
          .height('100%')
          .edgeEffect(EdgeEffect.Spring)
        } else {
          List() {
            ForEach(this.recommendArticles, (article: Article) => {
              ListItem() {
                ArticleItemComponent({
                  article: article,
                  recommendReason: article.recommendReason ?? '',
                  onTap: async () => {
                    if (article.id !== undefined) {
                      this.exposedArticleIds.delete(article.id);
                      // 记录推荐命中
                      MemoryService.getInstance().recordBehavior({
                        timestamp: Date.now(),
                        action: 'AI_REC_HIT',
                        articleId: article.id,
                        articleTitle: article.title,
                        feedTitle: article.feedTitle
                      });
                    }
                    await this.preMarkArticleAsRead(article);
                    this.getUIContext().getRouter().pushUrl({
                      url: 'pages/ArticleDetailPage',
                      params: { articleId: article.id }
                    });
                  },
                  onStarToggle: async () => {
                    const newStar = article.isStarred === 1 ? 0 : 1;
                    await DatabaseHelper.getInstance().toggleStar(article.id!, newStar);
                    const idx = this.recommendArticles.findIndex(a => a.id === article.id);
                    if (idx >= 0) {
                      const starOverrides = new Map<string, number | string | undefined>();
                      starOverrides.set('isStarred', newStar);
                      this.recommendArticles[idx] = copyArticle(article, starOverrides);
                      this.recommendArticles = [...this.recommendArticles];
                    }
                  }
                })
              }
              .swipeAction({
                end: {
                  builder: () => {
                    this.swipeDislikeBuilder(article)
                  }
                }
              })
            }, (article: Article) => `${this.listVersion}-${article.id}-${article.isStarred}-${article.isRead}`)

            ListItem() {
              Row() {
                if (this.isLoadingMore) {
                  LoadingProgress()
                    .width(24)
                    .height(24)
                    .backgroundColor(Color.Transparent)
                } else if (this.hasMore) {
                  Button('加载更多')
                    .fontSize(14)
                    .fontColor($r('sys.color.ohos_id_color_activated'))
                    .backgroundColor(Color.Transparent)
                    .onClick(() => this.loadArticles(false))
                } else {
                  Text('已加载全部文章')
                    .fontSize(13)
                    .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                }
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .padding(16)
            }
          }
          .width('100%')
          .height('100%')
          .divider({ strokeWidth: 0.5, color: $r('sys.color.ohos_id_color_list_separator') })
          .edgeEffect(EdgeEffect.Spring)
        }
      }
      .onRefreshing(() => this.doRefresh())
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
