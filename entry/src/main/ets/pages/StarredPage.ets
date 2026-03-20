// 收藏页
import { router } from '@kit.ArkUI';
import { Article, Feed } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { ArticleItemComponent } from '../components/ArticleItemComponent';

@Component
export struct StarredPage {
  @State articles: Article[] = [];
  @State isLoading: boolean = true;
  @Prop @Watch('onRefreshTickChanged') refreshTick: number = 0;

  aboutToAppear() {
    this.loadData();
  }

  onRefreshTickChanged() {
    this.loadData();
  }

  async loadData() {
    // 只有列表当前为空时才显示 loading spinner，避免刷新时页面抖动
    const showSpinner = this.articles.length === 0;
    if (showSpinner) {
      this.isLoading = true;
    }
    try {
      const db = DatabaseHelper.getInstance();
      const articles = await db.getStarredArticles(200);
      // 附加 feedTitle
      const feeds: Feed[] = await db.getAllFeeds();
      const feedMap = new Map<number, string>();
      for (const f of feeds) {
        feedMap.set(f.id!, f.title);
      }
      for (const a of articles) {
        a.feedTitle = feedMap.get(a.feedId) ?? '';
      }
      this.articles = articles;
    } finally {
      if (showSpinner) {
        this.isLoading = false;
      }
    }
  }

  build() {
    Column() {
      Row() {
        Text('收藏')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(40).height(40)
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.articles.length === 0) {
        Column({ space: 12 }) {
          Text('暂无收藏').fontSize(16).fontColor($r('sys.color.ohos_id_color_text_secondary'))
          Text('在文章详情页点击星标即可收藏').fontSize(13).fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
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
                  // 直接从本地列表移除，无需重新查询数据库，避免抖动
                  await DatabaseHelper.getInstance().toggleStar(article.id!, 0);
                  this.articles = this.articles.filter(a => a.id !== article.id);
                }
              })
            }
          }, (a: Article) => `${a.id}-${a.isStarred}-${a.isRead}`)
        }
        .width('100%')
        .layoutWeight(1)
        .divider({ strokeWidth: 0.5, color: $r('sys.color.ohos_id_color_list_separator') })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
