// 主页：底部Tab导航 + 内容区域
import { HomePage } from './HomePage';
import { FeedsPage } from './FeedsPage';
import { StarredPage } from './StarredPage';
import { SearchPage } from './SearchPage';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;

  @Builder
  tabBarBuilder(index: number, icon: Resource, selectedIcon: Resource, label: string) {
    Column({ space: 4 }) {
      Image(this.currentIndex === index ? selectedIcon : icon)
        .width(24)
        .height(24)
        .fillColor(this.currentIndex === index ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.ohos_id_color_text_secondary'))
      Text(label)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.ohos_id_color_text_secondary'))
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
      TabContent() {
        HomePage()
      }
      .tabBar(this.tabBarBuilder(0, $r('app.media.ic_home'), $r('app.media.ic_home_filled'), '首页'))

      TabContent() {
        FeedsPage()
      }
      .tabBar(this.tabBarBuilder(1, $r('app.media.ic_feeds'), $r('app.media.ic_feeds_filled'), '订阅'))

      TabContent() {
        StarredPage()
      }
      .tabBar(this.tabBarBuilder(2, $r('app.media.ic_star'), $r('app.media.ic_star_filled'), '收藏'))

      TabContent() {
        SearchPage()
      }
      .tabBar(this.tabBarBuilder(3, $r('app.media.ic_search'), $r('app.media.ic_search_filled'), '搜索'))
    }
    .onChange((index) => {
      this.currentIndex = index;
    })
    .barHeight(56)
    .animationDuration(200)
  }
}
