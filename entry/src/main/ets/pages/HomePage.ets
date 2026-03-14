// 首页：展示所有文章（聚合视图）
import router from '@ohos.router';
import { Article } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { FeedRefreshService } from '../service/FeedRefreshService';
import { RssService } from '../service/RssService';
import { ArticleItemComponent } from '../components/ArticleItemComponent';

@Component
export struct HomePage {
  @State articles: Article[] = [];
  @State isLoading: boolean = false;
  @State onlyUnread: boolean = false;
  @State isRefreshing: boolean = false;
  private pageOffset: number = 0;
  private pageSize: number = 30;

  aboutToAppear() {
    this.loadArticles();
  }

  async loadArticles(reset: boolean = true) {
    if (reset) {
      this.pageOffset = 0;
      this.isLoading = true;
    }
    try {
      const db = DatabaseHelper.getInstance();
      const items = await db.getAllArticles(this.onlyUnread, this.pageSize, this.pageOffset);
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
      await FeedRefreshService.getInstance().refreshAll(getContext(this));
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
          Image($r('app.media.ic_settings'))
            .width(20)
            .height(20)
            .fillColor($r('sys.color.ohos_id_color_text_primary'))
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => {
          router.pushUrl({ url: 'pages/SettingsPage' });
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
                    router.pushUrl({
                      url: 'pages/ArticleDetailPage',
                      params: { articleId: article.id }
                    });
                  },
                  onStarToggle: async () => {
                    const newStar = article.isStarred === 1 ? 0 : 1;
                    await DatabaseHelper.getInstance().toggleStar(article.id!, newStar);
                    article.isStarred = newStar;
                    this.articles = [...this.articles];
                  }
                })
              }
            }, (article: Article) => `${article.id}`)

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
