// 订阅源管理页
import { router } from '@kit.ArkUI';
import { Feed, FeedGroup } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { FeedRefreshService } from '../service/FeedRefreshService';

@Component
export struct FeedsPage {
  @State groups: FeedGroup[] = [];
  @State feeds: Feed[] = [];
  @State unreadMap: Map<number, number> = new Map();
  @State isRefreshing: boolean = false;
  @Prop @Watch('onRefreshTickChanged') refreshTick: number = 0;

  aboutToAppear() {
    this.loadData();
  }

  aboutToDisappear() {
    // 嵌入式组件在 Tab 切换时不会被销毁，此处可以不做任何处理
  }

  private onFeedAdded(): void {
    this.loadData();
  }

  onRefreshTickChanged() {
    console.info('FeedsPage', `onRefreshTickChanged triggered, refreshTick: ${this.refreshTick}`);
    this.loadData();
  }

  async loadData() {
    const db = DatabaseHelper.getInstance();
    this.feeds = await db.getAllFeeds();
    let groups = await db.getAllGroups();
    // 确保所有 feed 都能找到对应的分组，避免因 groupId 不匹配而消失
    const groupIds = new Set(groups.map(g => g.id!));
    const hasOrphanFeeds = this.feeds.some(f => !groupIds.has(f.groupId));
    if (hasOrphanFeeds) {
      // 将孤立 feed 的 groupId 修正为第一个分组 id，并持久化到数据库
      const firstGroupId = groups.length > 0 ? groups[0].id! : 1;
      for (const feed of this.feeds) {
        if (!groupIds.has(feed.groupId)) {
          feed.groupId = firstGroupId;
          db.updateFeed(feed).catch((e: Error) => {
            console.error('FeedsPage', `failed to persist orphan feed fix: ${feed.title}: ${e.message}`);
          });
        }
      }
    }
    this.groups = groups;
    this.unreadMap = await db.getUnreadCountAllFeeds();
  }

  getFeedsInGroup(groupId: number): Feed[] {
    return this.feeds.filter(f => f.groupId === groupId);
  }

  async deleteFeedById(feedId: number) {
    await DatabaseHelper.getInstance().deleteFeed(feedId);
    await this.loadData();
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('我的订阅')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
        Blank()
        if (this.isRefreshing) {
          LoadingProgress().width(24).height(24)
        } else {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(20)
              .fontColor([$r('sys.color.ohos_id_color_text_primary')])
          }
          .width(36)
          .height(36)
          .backgroundColor(Color.Transparent)
          .onClick(async () => {
            this.isRefreshing = true;
            try {
              await FeedRefreshService.getInstance().refreshAll(this.getUIContext().getHostContext()!);
              await this.loadData();
            } finally {
              this.isRefreshing = false;
            }
          })
        }
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .margin({ left: 4 })
        .onClick(() => {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/AddFeedPage' });
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      if (this.feeds.length === 0) {
        Column({ space: 16 }) {
          Text('还没有订阅源').fontSize(16).fontColor($r('sys.color.ohos_id_color_text_secondary'))
          Button('添加第一个RSS源')
            .fontSize(14)
            .onClick(() => {
              this.getUIContext().getRouter().pushUrl({ url: 'pages/AddFeedPage' });
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.groups.length === 0) {
        // 数据库异常：groups 表为空，无法显示分组下的 feed
        Column({ space: 16 }) {
          Text('数据加载异常').fontSize(16).fontColor($r('sys.color.ohos_id_color_text_secondary'))
          Text('分组数据缺失，请重启应用').fontSize(12).fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          Button('重新加载').fontSize(14).onClick(() => this.loadData())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.groups, (group: FeedGroup) => {
            ListItemGroup({
              header: this.groupHeaderBuilder(group.name)
            }) {
              ForEach(this.getFeedsInGroup(group.id!), (feed: Feed) => {
                ListItem() {
                  this.feedItemBuilder(feed)
                }
                .swipeAction({
                  end: this.swipeDeleteBuilder(feed.id!, feed.title)
                })
              }, (feed: Feed) => `${feed.id}`)
            }
          }, (group: FeedGroup) => `${group.id}`)
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
        .divider({ strokeWidth: 0.5, color: $r('sys.color.ohos_id_color_list_separator'), startMargin: 56 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  groupHeaderBuilder(name: string): void {
    Row() {
      Text(name)
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .height(36)
    .padding({ left: 16 })
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  feedItemBuilder(feed: Feed): void {
    Row({ space: 12 }) {
      // 图标
      if (feed.iconUrl) {
        Image(feed.iconUrl)
          .width(36)
          .height(36)
          .borderRadius(8)
          .backgroundColor($r('sys.color.ohos_id_color_foreground_contrary'))
      } else {
        Column() {
          Text(feed.title.charAt(0))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width(36)
        .height(36)
        .borderRadius(8)
        .backgroundColor($r('sys.color.ohos_id_color_activated'))
        .justifyContent(FlexAlign.Center)
      }

      Column({ space: 4 }) {
        Text(feed.title)
          .fontSize(15)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (feed.description) {
          Text(feed.description)
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 未读数角标
      if ((this.unreadMap.get(feed.id!) ?? 0) > 0) {
        Text(`${this.unreadMap.get(feed.id!)}`)
          .fontSize(11)
          .fontColor(Color.White)
          .backgroundColor($r('sys.color.ohos_id_color_activated'))
          .borderRadius(10)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .constraintSize({ minWidth: 20 })
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .onClick(() => {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/FeedArticlesPage',
        params: { feedId: feed.id }
      });
    })
  }

  @Builder
  swipeDeleteBuilder(feedId: number, feedTitle: string): void {
    Button('删除')
      .fontSize(14)
      .fontColor(Color.White)
      .backgroundColor(Color.Red)
      .height(64)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        this.getUIContext().showAlertDialog({
          title: '删除订阅源',
          message: `确定删除「${feedTitle}」？相关文章也会被删除。`,
          primaryButton: {
            value: '删除',
            fontColor: Color.Red,
            action: () => this.deleteFeedById(feedId)
          },
          secondaryButton: {
            value: '取消',
            action: () => {}
          }
        });
      })
  }
}
