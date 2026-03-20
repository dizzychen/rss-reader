// 设置页
import { router } from '@kit.ArkUI';
import { SettingsService } from '../service/SettingsService';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { Constants } from '../constants/Constants';

interface SelectOption {
  value: ResourceStr;
}

@Entry
@Component
struct SettingsPage {
  // 每个设置项独立 @State，Toggle 只绑定自身，不被 loadSettings 反复覆盖
  @State refreshIntervalIndex: number = 2;   // 默认 30 分钟
  @State bgRefreshEnabled: boolean = true;
  @State notificationEnabled: boolean = true;
  @State fontSizeIndex: number = 1;          // 默认「中」
  @State openOriginalInApp: boolean = true;
  @State cacheCountIndex: number = 1;        // 默认 50 篇
  @State loaded: boolean = false;

  aboutToAppear() {
    this.loadSettings();
  }

  async loadSettings() {
    const s = await SettingsService.getInstance().getSettings();
    // 只在首次加载时赋值（loaded 为 false），避免用户操作后被覆盖
    const riIdx = Constants.REFRESH_INTERVALS.indexOf(s.refreshInterval);
    this.refreshIntervalIndex = riIdx >= 0 ? riIdx : 2;
    this.bgRefreshEnabled = s.bgRefreshEnabled;
    this.notificationEnabled = s.notificationEnabled;
    const fsIdx = Constants.FONT_SIZES.indexOf(s.fontSize);
    this.fontSizeIndex = fsIdx >= 0 ? fsIdx : 1;
    this.openOriginalInApp = s.openOriginalInApp;
    const ccIdx = Constants.CACHE_COUNT_OPTIONS.indexOf(s.cacheCountPerFeed);
    this.cacheCountIndex = ccIdx >= 0 ? ccIdx : 1;
    this.loaded = true;
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

        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 8 })
        Blank()
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      if (!this.loaded) {
        Column() {
          LoadingProgress().width(40).height(40)
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 16 }) {

            // ===== 刷新与通知 =====
            this.sectionHeader('刷新与通知')
            Column() {
              Row() {
                Text('自动刷新间隔')
                  .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                Select(Constants.REFRESH_INTERVAL_LABELS.map((l: string): SelectOption => ({ value: l })))
                  .selected(this.refreshIntervalIndex)
                  .value(Constants.REFRESH_INTERVAL_LABELS[this.refreshIntervalIndex])
                  .onSelect((index: number) => {
                    this.refreshIntervalIndex = index;
                    SettingsService.getInstance()
                      .setSetting(Constants.PREF_REFRESH_INTERVAL, Constants.REFRESH_INTERVALS[index]);
                  })
                  .font({ size: 14 })
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              Row() {
                Text('后台自动刷新')
                  .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.bgRefreshEnabled })
                  .onChange((val: boolean) => {
                    if (!this.loaded) return;
                    this.bgRefreshEnabled = val;
                    SettingsService.getInstance().setSetting(Constants.PREF_BG_REFRESH, val);
                  })
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              Row() {
                Text('新文章通知')
                  .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.notificationEnabled })
                  .onChange((val: boolean) => {
                    if (!this.loaded) return;
                    this.notificationEnabled = val;
                    SettingsService.getInstance().setSetting(Constants.PREF_NOTIFICATION, val);
                  })
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })
            }
            .backgroundColor($r('sys.color.ohos_id_color_background')).borderRadius(12)

            // ===== 阅读 =====
            this.sectionHeader('阅读')
            Column() {
              Row() {
                Text('字体大小')
                  .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                Select(Constants.FONT_SIZE_LABELS.map((l: string): SelectOption => ({ value: l })))
                  .selected(this.fontSizeIndex)
                  .value(Constants.FONT_SIZE_LABELS[this.fontSizeIndex])
                  .onSelect((index: number) => {
                    this.fontSizeIndex = index;
                    SettingsService.getInstance()
                      .setSetting(Constants.PREF_FONT_SIZE, Constants.FONT_SIZES[index]);
                  })
                  .font({ size: 14 })
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              Row() {
                Text('在应用内打开原文')
                  .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                Toggle({ type: ToggleType.Switch, isOn: this.openOriginalInApp })
                  .onChange((val: boolean) => {
                    if (!this.loaded) return;
                    this.openOriginalInApp = val;
                    SettingsService.getInstance().setSetting(Constants.PREF_OPEN_ORIGINAL, val);
                  })
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })
            }
            .backgroundColor($r('sys.color.ohos_id_color_background')).borderRadius(12)

            // ===== 缓存与数据 =====
            this.sectionHeader('缓存与数据')
            Column() {
              Row() {
                Text('每源缓存文章数')
                  .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                Select(Constants.CACHE_COUNT_OPTIONS.map((n: number): SelectOption => ({ value: `${n}篇` })))
                  .selected(this.cacheCountIndex)
                  .value(`${Constants.CACHE_COUNT_OPTIONS[this.cacheCountIndex]}篇`)
                  .onSelect((index: number) => {
                    this.cacheCountIndex = index;
                    SettingsService.getInstance()
                      .setSetting(Constants.PREF_CACHE_COUNT, Constants.CACHE_COUNT_OPTIONS[index]);
                  })
                  .font({ size: 14 })
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              Row() {
                Text('清除缓存')
                  .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(16)
                  .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })
              .onClick(() => {
                this.getUIContext().showAlertDialog({
                  title: '清除缓存',
                  message: '将删除所有未收藏的本地缓存内容，已收藏文章不受影响。',
                  primaryButton: {
                    value: '清除',
                    fontColor: Color.Red,
                    action: async () => {
                      const feeds = await DatabaseHelper.getInstance().getAllFeeds();
                      for (const f of feeds) {
                        await DatabaseHelper.getInstance().cleanOldCache(f.id!, 0);
                      }
                      this.getUIContext().getPromptAction().showToast({ message: '缓存已清除' });
                    }
                  },
                  secondaryButton: { value: '取消', action: () => {} }
                });
              })
            }
            .backgroundColor($r('sys.color.ohos_id_color_background')).borderRadius(12)

            // ===== 订阅源 =====
            this.sectionHeader('订阅源')
            Column() {
              Row() {
                Text('标签管理')
                  .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(16)
                  .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })
              .onClick(() => this.getUIContext().getRouter().pushUrl({ url: 'pages/TagsManagePage' }))
            }
            .backgroundColor($r('sys.color.ohos_id_color_background')).borderRadius(12)

            // ===== 关于 =====
            this.sectionHeader('关于')
            Column() {
              Row() {
                Text('版本')
                  .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                Text('1.0.0').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary'))
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })
            }
            .backgroundColor($r('sys.color.ohos_id_color_background')).borderRadius(12)

          }
          .padding(16)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  sectionHeader(title: string) {
    Text(title)
      .fontSize(13)
      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      .width('100%')
      .padding({ left: 4, bottom: 4 })
  }
}
