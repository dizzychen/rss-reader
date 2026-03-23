// 首页：展示所有文章（聚合视图）
import { router } from '@kit.ArkUI';
import { Article, Feed } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { FeedRefreshService } from '../service/FeedRefreshService';
import { MemoryService } from '../service/MemoryService';
import { SettingsService } from '../service/SettingsService';
import { ArticleItemComponent } from '../components/ArticleItemComponent';

@Component
export struct HomePage {
  @State articles: Article[] = [];
  @State isLoading: boolean = false;
  @State isLoadingMore: boolean = false;
  @State hasMore: boolean = true;
  @State onlyUnread: boolean = true;
  @State isRefreshing: boolean = false;
  @State briefingEnabled: boolean = true;
  @Prop @Watch('onRefreshTickChanged') refreshTick: number = 0;
  private pageOffset: number = 0;
  private pageSize: number = 30;
  private feedMap: Map<number, string> = new Map();
  private exposedArticleIds: Map<number, string> = new Map();

  aboutToAppear() {
    this.loadAISettings();
    this.loadArticles();
  }

  async loadAISettings() {
    try {
      this.briefingEnabled = await SettingsService.getInstance().getBriefingEnabled();
    } catch (e) {
      // 忽略错误
    }
  }

  onRefreshTickChanged() {
    this.loadArticles(true);
  }

  async loadArticles(reset: boolean = true) {
    if (reset) {
      this.flushSkipBehaviors();
      this.pageOffset = 0;
      this.hasMore = true;
      this.isLoading = true;
    } else {
      if (!this.hasMore || this.isLoadingMore) return;
      this.isLoadingMore = true;
    }
    try {
      const db = DatabaseHelper.getInstance();
      // reset 时重建 feedMap；追加时仅补充新增 feed
      if (reset) {
        const feeds: Feed[] = await db.getAllFeeds();
        this.feedMap.clear();
        for (const f of feeds) {
          this.feedMap.set(f.id!, f.title);
        }
      }
      const items = await db.getAllArticles(this.onlyUnread, this.pageSize, this.pageOffset);
      // 给每篇文章附加来源名称
      for (const item of items) {
        item.feedTitle = this.feedMap.get(item.feedId) ?? '';
      }
      if (reset) {
        this.articles = items;
        this.exposedArticleIds.clear();
      } else {
        this.articles = this.articles.concat(items);
      }
      // 记录曝光的文章 ID
      for (const item of items) {
        if (item.id !== undefined) {
          this.exposedArticleIds.set(item.id, item.feedTitle ?? '');
        }
      }
      this.pageOffset += items.length;
      this.hasMore = items.length >= this.pageSize;
    } catch (e) {
      console.error('HomePage', `加载失败: ${e}`);
    } finally {
      this.isLoading = false;
      this.isLoadingMore = false;
    }
  }

  async doRefresh() {
    this.isRefreshing = true;
    try {
      await FeedRefreshService.getInstance().refreshAll(this.getUIContext().getHostContext()!);
      await this.loadArticles(true);
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
      feedTitle: article.feedTitle,
      score: -1
    });
    const idx = this.articles.findIndex(a => a.id === article.id);
    if (idx >= 0) {
      this.articles.splice(idx, 1);
      this.articles = [...this.articles];
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
    .backgroundColor('#F44336')
    .onClick(() => this.markDislike(article))
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Text('RSS阅读器')
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
        // 每日简报按钮（若开启）
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

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      // 文章列表
      if (this.isLoading && this.articles.length === 0) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .backgroundColor(Color.Transparent)
          Text('加载中...').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary')).margin({ top: 8 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.articles.length === 0) {
        Column({ space: 16 }) {
          Text('暂无文章').fontSize(16).fontColor($r('sys.color.ohos_id_color_text_secondary'))
          Text('请先在「订阅」页添加RSS源').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          List() {
            ForEach(this.articles, (article: Article) => {
              ListItem() {
                ArticleItemComponent({
                  article: article,
                  onTap: () => {
                    // 从曝光集合中移除（不算 SKIP）
                    if (article.id !== undefined) {
                      this.exposedArticleIds.delete(article.id);
                    }
                    this.getUIContext().getRouter().pushUrl({
                      url: 'pages/ArticleDetailPage',
                      params: { articleId: article.id }
                    });
                  },
                  onStarToggle: async () => {
                    const newStar = article.isStarred === 1 ? 0 : 1;
                    await DatabaseHelper.getInstance().toggleStar(article.id!, newStar);
                    const idx = this.articles.findIndex(a => a.id === article.id);
                    if (idx >= 0) {
                      const updated: Article = {
                        id: article.id, feedId: article.feedId, feedTitle: article.feedTitle,
                        guid: article.guid, title: article.title, summary: article.summary,
                        content: article.content, url: article.url, author: article.author,
                        publishedAt: article.publishedAt, isRead: article.isRead,
                        isStarred: newStar, coverImage: article.coverImage, cachedAt: article.cachedAt
                      };
                      this.articles[idx] = updated;
                      this.articles = [...this.articles];
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
            }, (article: Article) => `${article.id}-${article.isStarred}-${article.isRead}`)

            // 加载更多
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
          .layoutWeight(1)
          .divider({ strokeWidth: 0.5, color: $r('sys.color.ohos_id_color_list_separator') })
        }
        .onRefreshing(() => this.doRefresh())
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
