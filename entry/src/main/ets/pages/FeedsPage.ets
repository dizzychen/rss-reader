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

  aboutToAppear() {
    this.loadData();
  }

  async loadData() {
    const db = DatabaseHelper.getInstance();
    this.groups = await db.getAllGroups();
    this.feeds = await db.getAllFeeds();
    // 加载未读数
    const map = new Map<number, number>();
    for (const feed of this.feeds) {
      map.set(feed.id!, await db.getUnreadCountByFeed(feed.id!));
    }
    this.unreadMap = map;
  }

  getFeedsInGroup(groupId: number): Feed[] {
    return this.feeds.filter(f => f.groupId === groupId);
  }

  async deleteFeed(feed: Feed) {
    await DatabaseHelper.getInstance().deleteFeed(feed.id!);
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
            Image($r('app.media.ic_refresh'))
              .width(20)
              .height(20)
              .fillColor($r('sys.color.ohos_id_color_text_primary'))
          }
          .width(36)
          .height(36)
          .backgroundColor(Color.Transparent)
          .onClick(async () => {
            this.isRefreshing = true;
            try {
              await FeedRefreshService.getInstance().refreshAll(getContext(this));
              await this.loadData();
            } finally {
              this.isRefreshing = false;
            }
          })
        }
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_add'))
            .width(20)
            .height(20)
            .fillColor($r('sys.color.ohos_id_color_text_primary'))
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .margin({ left: 4 })
        .onClick(() => {
          router.pushUrl({ url: 'pages/AddFeedPage' })
            .then(() => this.loadData());
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
              router.pushUrl({ url: 'pages/AddFeedPage' })
                .then(() => this.loadData());
            })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.groups, (group: FeedGroup) => {
            // 组标题
            ListItemGroup({
              header: this.groupHeader(group)
            }) {
              ForEach(this.getFeedsInGroup(group.id!), (feed: Feed) => {
                ListItem() {
                  this.feedItem(feed)
                }
                .swipeAction({
                  end: this.swipeDeleteBuilder(feed)
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
  groupHeader(group: FeedGroup) {
    Row() {
      Text(group.name)
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
  feedItem(feed: Feed) {
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
          .minWidth(20)
          .textAlign(TextAlign.Center)
      }
    }
    .width('100%')
    .height(64)
    .padding({ left: 16, right: 16 })
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .onClick(() => {
      router.pushUrl({
        url: 'pages/FeedArticlesPage',
        params: { feedId: feed.id }
      }).then(() => this.loadData());
    })
  }

  @Builder
  swipeDeleteBuilder(feed: Feed) {
    Button('删除')
      .fontSize(14)
      .fontColor(Color.White)
      .backgroundColor(Color.Red)
      .height(64)
      .padding({ left: 16, right: 16 })
      .onClick(() => {
        AlertDialog.show({
          title: '删除订阅源',
          message: `确定删除「${feed.title}」？相关文章也会被删除。`,
          primaryButton: {
            value: '删除',
            fontColor: Color.Red,
            action: () => this.deleteFeed(feed)
          },
          secondaryButton: {
            value: '取消',
            action: () => {}
          }
        });
      })
  }
}
