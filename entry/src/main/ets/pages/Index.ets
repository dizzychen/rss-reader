// 主页：底部Tab导航 + 内容区域
import { HomePage } from './HomePage';
import { FeedsPage } from './FeedsPage';
import { StarredPage } from './StarredPage';
import { MePage } from './MePage';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { SettingsService } from '../service/SettingsService';
import { FeedRefreshService } from '../service/FeedRefreshService';
import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State dbReady: boolean = false;  // 数据库就绪标志
  // 刷新触发器：每次自增时通知子组件重新加载数据
  @State homeRefreshTick: number = 0;
  @State feedsRefreshTick: number = 0;
  @State starredRefreshTick: number = 0;
  @State meRefreshTick: number = 0;
  // 完整重载触发器：后台刷新完成后需要重新加载文章列表（区别于状态同步）
  @State homeFullReloadTick: number = 0;
  // 追踪通知点击是否已发生（用于抑制 autoRefreshOnLaunch 的冗余吐司）
  private notificationTapHandlerTriggered: boolean = false;
  // 追踪是否是从通知冷启动进来的
  private isStartedFromNotification: boolean = false;
  // 通知点击事件回调引用，用于注销时保持引用一致
  private notificationTapHandler: () => void = () => this.handleNotificationTap();

  aboutToAppear() {
    // 获取 UIAbilityContext（用于 EventHub 注册和数据库初始化）
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    
    // 检查是否是从通知冷启动（通过 EntryAbility 设置的 AppStorage）
    this.isStartedFromNotification = AppStorage.get<boolean>('notification_cold_start') ?? false;
    // 读取后立即清理，避免影响后续普通启动
    AppStorage.setOrCreate('notification_cold_start', false);
    if (this.isStartedFromNotification) {
      console.info('Index', '检测到通知冷启动');
    }
    
    // 注册 EventHub 监听：通知点击后触发首页刷新
    if (ctx) {
      ctx.eventHub.on('notification_tap', this.notificationTapHandler);
      console.info('Index', 'EventHub: notification_tap 监听已注册');
    }

    // 确保数据库和设置服务已初始化完毕再渲染页面
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
      // 后台自动刷新订阅源，完成后刷新首页
      this.autoRefreshOnLaunch();
    }).catch((e: Error) => {
      console.error('Index', `DB init failed: ${e?.message}`);
      // 即便失败也显示页面，避免白屏
      this.dbReady = true;
    });
  }

  aboutToDisappear(): void {
    // 注销 EventHub 监听，避免内存泄漏
    const ctx = this.getUIContext().getHostContext();
    if (ctx) {
      (ctx as common.UIAbilityContext).eventHub.off('notification_tap', this.notificationTapHandler);
      console.info('Index', 'EventHub: notification_tap 监听已注销');
    }
  }

  /**
   * 通知点击事件处理：切到首页 Tab + 触发完整重载
   */
  private handleNotificationTap(): void {
    console.info('Index', '收到通知点击事件，清空路由栈并切换到首页刷新数据');
    this.notificationTapHandlerTriggered = true;
    // 如果当前在详情页或其他子页面，直接清空返回 Index
    if (Number(router.getLength()) > 1) {
      router.back({ url: 'pages/Index' });
    }
    // 切到首页 Tab
    this.currentIndex = 0;
    // 触发首页完整重载（拉取最新文章列表）
    this.homeFullReloadTick++;
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
        this.meRefreshTick++;
        break;
      default:
        break;
    }
  }

  /**
   * 启动时自动在后台刷新所有订阅源，完成后触发当前 Tab 刷新
   */
  private autoRefreshOnLaunch(): void {
    const ctx = this.getUIContext().getHostContext();
    if (!ctx) return;
    FeedRefreshService.getInstance().refreshAll(ctx).then((newCount: number) => {
      console.info('Index', `启动自动刷新完成，新增 ${newCount} 篇文章`);
      // 无论是否有新文章，都触发完整重载（已有文章内容可能也已更新）
      this.homeFullReloadTick++;
      this.feedsRefreshTick++;
      
      if (newCount > 0) {
        this.getUIContext().getPromptAction().showToast({ message: `已更新 ${newCount} 篇新文章` });
      } else if (!this.notificationTapHandlerTriggered && !this.isStartedFromNotification) {
        this.getUIContext().getPromptAction().showToast({ message: '订阅内容已是最新' });
      }
    }).catch((e: Error) => {
      console.error('Index', `启动自动刷新失败: ${e?.message}`);
      this.getUIContext().getPromptAction().showToast({ message: `刷新失败: ${e?.message ?? '未知错误'}` });
    });
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
            HomePage({ refreshTick: this.homeRefreshTick, fullReloadTick: this.homeFullReloadTick })
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
            MePage({ refreshTick: this.meRefreshTick })
          }
          .tabBar(this.tabBarBuilder(3, 'person', 'person_fill', '我'))
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
          LoadingProgress()
            .width(48)
            .height(48)
            .backgroundColor(Color.Transparent)
          Text('加载中...').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary')).margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(Color.Transparent)
      }
    }
    .width('100%')
    .height('100%')
  }
}
