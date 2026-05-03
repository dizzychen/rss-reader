// 订阅源文章列表页
import { Article, copyArticle, Feed } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { FeedRefreshService } from '../service/FeedRefreshService';
import { ArticleItemComponent } from '../components/ArticleItemComponent';

@Entry
@Component
struct FeedArticlesPage {
  @State feed: Feed | null = null;
  @State articles: Article[] = [];
  @State isRefreshing: boolean = false;
  @State onlyUnread: boolean = true;
  private feedId: number = -1;
  private syncTimerId: number = -1;

  aboutToAppear() {
    const params = this.getUIContext().getRouter().getParams();
    if (params && typeof (params as Record<string, number>)['feedId'] === 'number') {
      this.feedId = (params as Record<string, number>)['feedId'];
    }
    this.loadData();
  }

  onPageShow(): void {
    // 从 ArticleDetailPage 返回时，增量同步已读状态并平滑移除已读文章
    if (this.feedId > 0) {
      this.syncArticleStatus();
    }
  }

  aboutToDisappear(): void {
    clearTimeout(this.syncTimerId);
    this.syncTimerId = -1;
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

        Toggle({ type: ToggleType.Switch, isOn: this.onlyUnread })
          .onChange((isOn) => {
            this.onlyUnread = isOn;
            this.loadData();
          })

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
                if (this.onlyUnread) {
                  animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
                    this.articles = [];
                  });
                } else {
                  await this.loadData();
                }
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
          List() {
            ListItem() {
              Column({ space: 12 }) {
                Text('暂无文章').fontSize(16).fontColor($r('sys.color.ohos_id_color_text_secondary'))
                Button('立即刷新').onClick(() => this.doRefresh())
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
            ForEach(this.articles, (article: Article) => {
              ListItem() {
                ArticleItemComponent({
                  article: article,
                  onTap: async () => {
                    await this.preMarkArticleAsRead(article);
                    this.getUIContext().getRouter().pushUrl({
                      url: 'pages/ArticleDetailPage',
                      params: { articleId: article.id }
                    });
                  },
                  onStarToggle: async (): Promise<void> => {
                    const newStar = article.isStarred === 1 ? 0 : 1;
                    await DatabaseHelper.getInstance().toggleStar(article.id!, newStar);
                    const idx = this.articles.findIndex(a => a.id === article.id);
                    if (idx >= 0) {
                      const starOverrides = new Map<string, number | string>();
                      starOverrides.set('isStarred', newStar);
                      this.articles[idx] = copyArticle(article, starOverrides);
                      this.articles = [...this.articles];
                    }
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

  /**
   * 增量同步文章状态，当 onlyUnread=true 时平滑移除已读文章
   */
  private async syncArticleStatus() {
    if (this.articles.length === 0) return;
    try {
      const ids = this.articles.filter(a => a.id !== undefined).map(a => a.id!);
      const statusMap = await DatabaseHelper.getInstance().getArticlesStatus(ids);
      let changed = false;
      const newlyReadIds = new Set<number>();
      const updated: Article[] = this.articles.map(a => {
        const status = a.id !== undefined ? statusMap.get(a.id) : undefined;
        if (status) {
          const newRead = status['isRead'] ?? a.isRead;
          const newStarred = status['isStarred'] ?? a.isStarred;
          if (newRead !== a.isRead || newStarred !== a.isStarred) {
            changed = true;
            if (newRead === 1 && a.isRead === 0 && a.id !== undefined) {
              newlyReadIds.add(a.id);
            }
            const overrides = new Map<string, number | string>();
            overrides.set('isRead', newRead);
            overrides.set('isStarred', newStarred);
            return copyArticle(a, overrides);
          }
        }
        return a;
      });
      if (changed) {
        if (this.onlyUnread && newlyReadIds.size > 0) {
          this.articles = updated;
          this.syncTimerId = setTimeout(() => {
            animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
              this.articles = this.articles.filter(a => !newlyReadIds.has(a.id!));
            });
          }, 150);
        } else {
          this.articles = updated;
        }
      }
    } catch (e) {
      console.error('FeedArticlesPage', `syncArticleStatus failed: ${e}`);
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

  /**
   * 进入详情前先落库已读，并同步当前列表，避免仅未读模式下残留
   */
  private async preMarkArticleAsRead(article: Article): Promise<void> {
    if (article.id === undefined || article.isRead === 1) {
      return;
    }
    try {
      await DatabaseHelper.getInstance().markRead(article.id, 1);
    } catch (e) {
      console.error('FeedArticlesPage', `preMarkArticleAsRead DB update failed: ${e}`);
    }

    const idx = this.articles.findIndex(a => a.id === article.id);
    if (idx < 0) {
      return;
    }

    if (this.onlyUnread) {
      this.articles = this.articles.filter(a => a.id !== article.id);
      return;
    }

    const target = this.articles[idx];
    const readOverrides = new Map<string, number | string>();
    readOverrides.set('isRead', 1);
    this.articles[idx] = copyArticle(target, readOverrides);
    this.articles = [...this.articles];
  }
}
