// 订阅源文章列表页
import { router } from '@kit.ArkUI';
import { Article, Feed } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { FeedRefreshService } from '../service/FeedRefreshService';
import { ArticleItemComponent } from '../components/ArticleItemComponent';

@Entry
@Component
struct FeedArticlesPage {
  @State feed: Feed | null = null;
  @State articles: Article[] = [];
  @State isRefreshing: boolean = false;
  @State onlyUnread: boolean = false;
  private feedId: number = -1;

  aboutToAppear() {
    const params = this.getUIContext().getRouter().getParams();
    if (params && typeof (params as Record<string, number>)['feedId'] === 'number') {
      this.feedId = (params as Record<string, number>)['feedId'];
    }
    this.loadData();
  }

  onPageShow(): void {
    // 从 ArticleDetailPage 返回时刷新已读状态
    if (this.feedId > 0) {
      this.loadData();
    }
  }

  async loadData() {
    const db = DatabaseHelper.getInstance();
    this.feed = await db.getFeedById(this.feedId);
    let arts = await db.getArticlesByFeedId(this.feedId, 100);
    if (this.onlyUnread) arts = arts.filter(a => a.isRead === 0);
    // 附加来源名称
    arts.forEach(a => a.feedTitle = this.feed?.title ?? '');
    this.articles = arts;
  }

  async doRefresh() {
    if (!this.feed) return;
    this.isRefreshing = true;
    try {
      await FeedRefreshService.getInstance().refreshSingleFeed(this.feed);
      await this.loadData();
    } finally {
      this.isRefreshing = false;
    }
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.arrow_left'))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(() => this.getUIContext().getRouter().back())

        Text(this.feed?.title ?? '加载中...')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ left: 8 })
          .layoutWeight(1)

        // 全部标记已读
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.checkmark'))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(() => {
          this.getUIContext().showAlertDialog({
            title: '标记全部已读',
            message: '将该订阅源所有文章标记为已读？',
            primaryButton: {
              value: '确认',
              action: async () => {
                await DatabaseHelper.getInstance().markAllReadByFeed(this.feedId);
                await this.loadData();
              }
            },
            secondaryButton: { value: '取消', action: () => {} }
          });
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      Refresh({ refreshing: $$this.isRefreshing }) {
        if (this.articles.length === 0) {
          Column({ space: 12 }) {
            Text('暂无文章').fontSize(16).fontColor($r('sys.color.ohos_id_color_text_secondary'))
            Button('立即刷新').onClick(() => this.doRefresh())
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
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
                  onStarToggle: async (): Promise<void> => {
                    const newStar = article.isStarred === 1 ? 0 : 1;
                    await DatabaseHelper.getInstance().toggleStar(article.id!, newStar);
                    article.isStarred = newStar;
                    this.articles = [...this.articles];
                  }
                })
              }
            }, (a: Article) => `${a.id}-${a.isStarred}-${a.isRead}`)
          }
          .divider({ strokeWidth: 0.5, color: $r('sys.color.ohos_id_color_list_separator') })
        }
      }
      .onRefreshing(() => this.doRefresh())
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
