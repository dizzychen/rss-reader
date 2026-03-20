// 主页：底部Tab导航 + 内容区域
import { HomePage } from './HomePage';
import { FeedsPage } from './FeedsPage';
import { StarredPage } from './StarredPage';
import { SearchPage } from './SearchPage';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { SettingsService } from '../service/SettingsService';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State dbReady: boolean = false;  // 数据库就绪标志
  // 刷新触发器：每次自增时通知子组件重新加载数据
  @State homeRefreshTick: number = 0;
  @State feedsRefreshTick: number = 0;
  @State starredRefreshTick: number = 0;
  @State searchRefreshTick: number = 0;

  aboutToAppear() {
    // 确保数据库和设置服务已初始化完毕再渲染页面
    const ctx = this.getUIContext().getHostContext();
    if (!ctx) {
      this.dbReady = true;
      return;
    }
    Promise.all([
      DatabaseHelper.getInstance().init(ctx),
      SettingsService.getInstance().init(ctx)
    ]).then(() => {
      this.dbReady = true;
      // DB 就绪后立即触发当前 Tab 加载数据
      this.triggerCurrentTabRefresh();
    }).catch((e: Error) => {
      console.error('Index', `DB init failed: ${e?.message}`);
      // 即便失败也显示页面，避免白屏
      this.dbReady = true;
    });
  }

  onPageShow(): void {
    // 从其他 @Entry 页面返回时触发，通知当前活动的 Tab 刷新
    // 使用 Promise.resolve() 确保状态已同步
    Promise.resolve().then(() => {
      this.triggerCurrentTabRefresh();
    });
  }

  private triggerCurrentTabRefresh(): void {
    switch (this.currentIndex) {
      case 0:
        this.homeRefreshTick++;
        break;
      case 1:
        this.feedsRefreshTick++;
        break;
      case 2:
        this.starredRefreshTick++;
        break;
      case 3:
        this.searchRefreshTick++;
        break;
      default:
        break;
    }
  }

  @Builder
  tabBarBuilder(index: number, iconName: string, selectedIconName: string, label: string) {
    Column({ space: 4 }) {
      SymbolGlyph($r(`sys.symbol.${this.currentIndex === index ? selectedIconName : iconName}`))
        .fontSize(24)
        .fontColor([this.currentIndex === index ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.ohos_id_color_text_secondary')])
      Text(label)
        .fontSize(10)
        .fontColor(this.currentIndex === index ? $r('sys.color.ohos_id_color_activated') : $r('sys.color.ohos_id_color_text_secondary'))
    }
    .width('100%')
    .height(56)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack() {
      // 数据库就绪后显示主界面
      if (this.dbReady) {
        Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
          TabContent() {
            HomePage({ refreshTick: this.homeRefreshTick })
          }
          .tabBar(this.tabBarBuilder(0, 'house', 'house_fill', '首页'))

          TabContent() {
            FeedsPage({ refreshTick: this.feedsRefreshTick })
          }
          .tabBar(this.tabBarBuilder(1, 'discover', 'discover_fill', '订阅'))

          TabContent() {
            StarredPage({ refreshTick: this.starredRefreshTick })
          }
          .tabBar(this.tabBarBuilder(2, 'star', 'star_fill', '收藏'))

          TabContent() {
            SearchPage({ refreshTick: this.searchRefreshTick })
          }
          .tabBar(this.tabBarBuilder(3, 'magnifyingglass', 'magnifyingglass', '搜索'))
        }
        .onChange((index) => {
          this.currentIndex = index;
          // 切换 Tab 时触发目标 Tab 刷新
          this.triggerCurrentTabRefresh();
        })
        .barHeight(56)
        .animationDuration(200)
      } else {
        // 数据库初始化中，显示加载界面
        Column() {
          LoadingProgress().width(48).height(48)
          Text('加载中...').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary')).margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
