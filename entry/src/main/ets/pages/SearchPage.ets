// 搜索页
import { router } from '@kit.ArkUI';
import { Article, Feed, copyArticle } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { ArticleItemComponent } from '../components/ArticleItemComponent';
import { MemoryService } from '../service/MemoryService';

@Component
export struct SearchPage {
  @State keyword: string = '';
  @State results: Article[] = [];
  @State isSearching: boolean = false;
  @State feeds: Feed[] = [];
  @Prop @Watch('onRefreshTickChanged') refreshTick: number = 0;
  private debounceTimer: number = -1;

  aboutToAppear() {
    this.loadFeeds();
  }

  aboutToDisappear() {
    if (this.debounceTimer !== -1) {
      clearTimeout(this.debounceTimer);
      this.debounceTimer = -1;
    }
  }

  onRefreshTickChanged() {
    this.loadFeeds();
  }

  async loadFeeds() {
    this.feeds = await DatabaseHelper.getInstance().getAllFeeds();
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
        const res = await DatabaseHelper.getInstance().searchArticles(kw.trim(), -1);
        // 附加 feedTitle
        for (const a of res) {
          const feed = this.feeds.find(f => f.id === a.feedId);
          a.feedTitle = feed?.title ?? '';
        }
        this.results = res;
        // 记录 SEARCH 行为
        MemoryService.getInstance().recordBehavior({
          timestamp: Date.now(),
          action: 'SEARCH',
          keyword: kw.trim()
        });
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
                    this.getUIContext().getRouter().pushUrl({
                      url: 'pages/ArticleDetailPage',
                      params: { articleId: article.id }
                    });
                  },
                  onStarToggle: async () => {
                    const newStar = article.isStarred === 1 ? 0 : 1;
                    await DatabaseHelper.getInstance().toggleStar(article.id!, newStar);
                    const idx = this.results.findIndex(a => a.id === article.id);
                    if (idx >= 0) {
                      const starOverrides = new Map<string, number | string | undefined>();
                      starOverrides.set('isStarred', newStar);
                      this.results[idx] = copyArticle(article, starOverrides);
                      this.results = [...this.results];
                    }
                  }
                })
              }
            }, (a: Article) => `${a.id}-${a.isStarred}-${a.isRead}`)
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
