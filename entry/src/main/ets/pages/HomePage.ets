// 首页：展示所有文章（聚合视图）
import { router } from '@kit.ArkUI';
import { Article, Feed } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { FeedRefreshService } from '../service/FeedRefreshService';
import { ArticleItemComponent } from '../components/ArticleItemComponent';

@Component
export struct HomePage {
  @State articles: Article[] = [];
  @State isLoading: boolean = false;
  @State onlyUnread: boolean = false;
  @State isRefreshing: boolean = false;
  @Prop @Watch('onRefreshTickChanged') refreshTick: number = 0;
  private pageOffset: number = 0;
  private pageSize: number = 30;
  private feedMap: Map<number, string> = new Map();

  aboutToAppear() {
    this.loadArticles();
  }

  onRefreshTickChanged() {
    this.loadArticles(true);
  }

  async loadArticles(reset: boolean = true) {
    if (reset) {
      this.pageOffset = 0;
      this.isLoading = true;
    }
    try {
      const db = DatabaseHelper.getInstance();
      // 构建 feedId → feedTitle 的映射
      const feeds: Feed[] = await db.getAllFeeds();
      this.feedMap.clear();
      for (const f of feeds) {
        this.feedMap.set(f.id!, f.title);
      }
      const items = await db.getAllArticles(this.onlyUnread, this.pageSize, this.pageOffset);
      // 给每篇文章附加来源名称
      for (const item of items) {
        item.feedTitle = this.feedMap.get(item.feedId) ?? '';
      }
      if (reset) {
        this.articles = items;
      } else {
        this.articles = [...this.articles, ...items];
      }
      this.pageOffset += items.length;
    } catch (e) {
      console.error('HomePage', `加载失败: ${e}`);
    } finally {
      this.isLoading = false;
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
          .margin({ left: 4, right: 8 })
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.gearshape'))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/SettingsPage' });
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      // 文章列表
      if (this.isLoading && this.articles.length === 0) {
        Column() {
          LoadingProgress().width(40).height(40)
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
                      this.articles[idx] = { ...article, isStarred: newStar };
                      this.articles = [...this.articles];
                    }
                  }
                })
              }
            }, (article: Article) => `${article.id}-${article.isStarred}-${article.isRead}`)

            // 加载更多
            ListItem() {
              Row() {
                Button('加载更多')
                  .fontSize(14)
                  .fontColor($r('sys.color.ohos_id_color_activated'))
                  .backgroundColor(Color.Transparent)
                  .onClick(() => this.loadArticles(false))
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
