// 搜索页
import { router } from '@kit.ArkUI';
import { Article, Feed } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { ArticleItemComponent } from '../components/ArticleItemComponent';

@Component
export struct SearchPage {
  @State keyword: string = '';
  @State results: Article[] = [];
  @State isSearching: boolean = false;
  @State feeds: Feed[] = [];
  @State selectedFeedId: number = -1;
  private debounceTimer: number = -1;

  aboutToAppear() {
    DatabaseHelper.getInstance().getAllFeeds().then(f => this.feeds = f);
  }

  doSearch(kw: string) {
    clearTimeout(this.debounceTimer);
    if (!kw.trim()) {
      this.results = [];
      return;
    }
    this.debounceTimer = setTimeout(async () => {
      this.isSearching = true;
      try {
        const res = await DatabaseHelper.getInstance().searchArticles(kw.trim(), this.selectedFeedId);
        // 附加 feedTitle
        for (const a of res) {
          const feed = this.feeds.find(f => f.id === a.feedId);
          a.feedTitle = feed?.title ?? '';
        }
        this.results = res;
      } finally {
        this.isSearching = false;
      }
    }, 400);
  }

  build() {
    Column() {
      // 搜索栏
      Row({ space: 8 }) {
        Search({ placeholder: '搜索文章标题、内容...', value: this.keyword })
          .layoutWeight(1)
          .onChange((val) => {
            this.keyword = val;
            this.doSearch(val);
          })
          .onSubmit((val) => this.doSearch(val))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      // 订阅源过滤
      if (this.feeds.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            Button('全部')
              .fontSize(13)
              .fontColor(this.selectedFeedId === -1 ? Color.White : $r('sys.color.ohos_id_color_text_secondary'))
              .backgroundColor(this.selectedFeedId === -1 ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.ohos_id_color_background'))
              .height(32)
              .borderRadius(16)
              .onClick(() => {
                this.selectedFeedId = -1;
                this.doSearch(this.keyword);
              })
            ForEach(this.feeds, (feed: Feed) => {
              Button(feed.title)
                .fontSize(13)
                .fontColor(this.selectedFeedId === feed.id! ? Color.White : $r('sys.color.ohos_id_color_text_secondary'))
                .backgroundColor(this.selectedFeedId === feed.id! ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.ohos_id_color_background'))
                .height(32)
                .borderRadius(16)
                .onClick(() => {
                  this.selectedFeedId = feed.id!;
                  this.doSearch(this.keyword);
                })
            }, (f: Feed) => `${f.id}`)
          }
          .padding({ left: 16, right: 16 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .width('100%')
        .height(48)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      }

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      if (!this.keyword) {
        Column({ space: 12 }) {
          Text('输入关键词搜索文章').fontSize(15).fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.isSearching) {
        Column() {
          LoadingProgress().width(40).height(40)
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.results.length === 0) {
        Column({ space: 12 }) {
          Text(`未找到「${this.keyword}」的相关文章`).fontSize(15).fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Column() {
          Text(`找到 ${this.results.length} 篇文章`)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .padding({ left: 16, top: 8, bottom: 4 })
          List() {
            ForEach(this.results, (article: Article) => {
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
                    this.results = [...this.results];
                  }
                })
              }
            }, (a: Article) => `${a.id}`)
          }
          .divider({ strokeWidth: 0.5, color: $r('sys.color.ohos_id_color_list_separator') })
          .layoutWeight(1)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
