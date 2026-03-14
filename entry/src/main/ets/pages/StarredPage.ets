// 收藏页
import { router } from '@kit.ArkUI';
import { Article } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { ArticleItemComponent } from '../components/ArticleItemComponent';

@Component
export struct StarredPage {
  @State articles: Article[] = [];
  @State isLoading: boolean = true;

  aboutToAppear() {
    this.loadData();
  }

  async loadData() {
    this.isLoading = true;
    try {
      this.articles = await DatabaseHelper.getInstance().getStarredArticles(200);
    } finally {
      this.isLoading = false;
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
                  router.pushUrl({
                    url: 'pages/ArticleDetailPage',
                    params: { articleId: article.id }
                  }).then(() => this.loadData());
                },
                onStarToggle: async () => {
                  await DatabaseHelper.getInstance().toggleStar(article.id!, 0);
                  await this.loadData();
                }
              })
            }
          }, (a: Article) => `${a.id}`)
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
