// 设置页
import router from '@ohos.router';
import { AppSettings } from '../model/Models';
import { SettingsService } from '../service/SettingsService';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { Constants } from '../constants/Constants';

@Entry
@Component
struct SettingsPage {
  @State settings: AppSettings = {
    refreshInterval: 30,
    bgRefreshEnabled: true,
    notificationEnabled: true,
    fontSize: 16,
    openOriginalInApp: true,
    cacheCountPerFeed: 50
  };
  @State fontSizeIndex: number = 1;

  aboutToAppear() {
    this.loadSettings();
  }

  async loadSettings() {
    this.settings = await SettingsService.getInstance().getSettings();
    const idx = Constants.FONT_SIZES.indexOf(this.settings.fontSize);
    this.fontSizeIndex = idx >= 0 ? idx : 1;
  }

  async setSetting(key: string, value: number | boolean | string) {
    await SettingsService.getInstance().setSetting(key, value);
    await this.loadSettings();
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_back')).width(20).height(20).fillColor($r('sys.color.ohos_id_color_text_primary'))
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(() => router.back())

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

      Scroll() {
        Column({ space: 16 }) {

          // ===== 刷新设置 =====
          this.sectionHeader('刷新与通知')
          Column() {
            // 刷新间隔
            this.settingItem('自动刷新间隔', () => {
              Select(Constants.REFRESH_INTERVAL_LABELS.map(l => ({ value: l })))
                .selected(Constants.REFRESH_INTERVALS.indexOf(this.settings.refreshInterval))
                .onSelect((index) => {
                  this.setSetting(Constants.PREF_REFRESH_INTERVAL, Constants.REFRESH_INTERVALS[index]);
                })
                .font({ size: 14 })
            })

            Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

            // 后台刷新
            this.settingToggleItem('后台自动刷新', this.settings.bgRefreshEnabled, (val) => {
              this.setSetting(Constants.PREF_BG_REFRESH, val);
            })

            Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

            // 通知推送
            this.settingToggleItem('新文章通知', this.settings.notificationEnabled, (val) => {
              this.setSetting(Constants.PREF_NOTIFICATION, val);
            })
          }
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(12)

          // ===== 阅读设置 =====
          this.sectionHeader('阅读')
          Column() {
            // 字体大小
            this.settingItem('字体大小', () => {
              Select(Constants.FONT_SIZE_LABELS.map(l => ({ value: l })))
                .selected(this.fontSizeIndex)
                .onSelect((index) => {
                  this.fontSizeIndex = index;
                  this.setSetting(Constants.PREF_FONT_SIZE, Constants.FONT_SIZES[index]);
                })
                .font({ size: 14 })
            })

            Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

            // 原文打开方式
            this.settingToggleItem('在应用内打开原文', this.settings.openOriginalInApp, (val) => {
              this.setSetting(Constants.PREF_OPEN_ORIGINAL, val);
            })
          }
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(12)

          // ===== 缓存设置 =====
          this.sectionHeader('缓存与数据')
          Column() {
            // 每源缓存数量
            this.settingItem('每源缓存文章数', () => {
              Select(Constants.CACHE_COUNT_OPTIONS.map(n => ({ value: `${n}篇` })))
                .selected(Constants.CACHE_COUNT_OPTIONS.indexOf(this.settings.cacheCountPerFeed))
                .onSelect((index) => {
                  this.setSetting(Constants.PREF_CACHE_COUNT, Constants.CACHE_COUNT_OPTIONS[index]);
                })
                .font({ size: 14 })
            })

            Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

            // 清除缓存
            Row() {
              Text('清除缓存').fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
              Image($r('app.media.ic_arrow_right')).width(16).height(16).fillColor($r('sys.color.ohos_id_color_text_tertiary'))
            }
            .width('100%')
            .height(52)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              AlertDialog.show({
                title: '清除缓存',
                message: '将删除所有未收藏的本地缓存内容，已收藏文章不受影响。',
                primaryButton: {
                  value: '清除',
                  fontColor: Color.Red,
                  action: async () => {
                    // 清除操作：遍历所有feed，保留 0 篇缓存（仅保留收藏）
                    const feeds = await DatabaseHelper.getInstance().getAllFeeds();
                    for (const f of feeds) {
                      await DatabaseHelper.getInstance().cleanOldCache(f.id!, 0);
                    }
                    promptAction.showToast({ message: '缓存已清除' });
                  }
                },
                secondaryButton: { value: '取消', action: () => {} }
              });
            })
          }
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(12)

          // ===== 订阅源管理 =====
          this.sectionHeader('订阅源')
          Column() {
            Row() {
              Text('标签管理').fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
              Image($r('app.media.ic_arrow_right')).width(16).height(16).fillColor($r('sys.color.ohos_id_color_text_tertiary'))
            }
            .width('100%').height(52).padding({ left: 16, right: 16 })
            .onClick(() => router.pushUrl({ url: 'pages/TagsManagePage' }))
          }
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(12)

          // ===== 关于 =====
          this.sectionHeader('关于')
          Column() {
            Row() {
              Text('版本').fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
              Text('1.0.0').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary'))
            }
            .width('100%').height(52).padding({ left: 16, right: 16 })
          }
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(12)

        }
        .padding(16)
      }
      .layoutWeight(1)
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

  @Builder
  settingItem(label: string, content: () => void) {
    Row() {
      Text(label).fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
      content()
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
  }

  @Builder
  settingToggleItem(label: string, isOn: boolean, onChange: (val: boolean) => void) {
    Row() {
      Text(label).fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .onChange(onChange)
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
  }
}
