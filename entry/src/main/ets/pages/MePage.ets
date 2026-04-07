// 我的页面：搜索、记忆与AI、设置
import { router } from '@kit.ArkUI';
import { Article, Feed } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { SettingsService } from '../service/SettingsService';
import { Constants } from '../constants/Constants';
import { WorkSchedulerManager } from '../service/WorkSchedulerManager';
import { ArticleItemComponent } from '../components/ArticleItemComponent';
import { DataOperationHelper } from '../service/DataOperationHelper';
import { common } from '@kit.AbilityKit';

interface SelectOption {
  value: ResourceStr;
}

@Component
export struct MePage {
  // 搜索相关
  @State keyword: string = '';
  @State searchResults: Article[] = [];
  @State isSearching: boolean = false;
  @State showSearchResults: boolean = false;
  @State feeds: Feed[] = [];
  @Prop @Watch('onRefreshTickChanged') refreshTick: number = 0;
  private debounceTimer: number = -1;

  // 设置相关
  @State refreshIntervalIndex: number = 2;
  @State bgRefreshEnabled: boolean = true;
  @State notificationEnabled: boolean = true;
  @State fontSizeIndex: number = 1;
  @State openOriginalInApp: boolean = true;
  @State cacheCountIndex: number = 1;
  @State loaded: boolean = false;
  @State isExporting: boolean = false;
  @State isImporting: boolean = false;
  @State isBackingUp: boolean = false;
  @State isRestoring: boolean = false;
  @State bgTaskStatus: string = '检查中...';

  aboutToAppear() {
    this.loadFeeds();
    this.loadSettings();
    this.checkBgTaskStatus();
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

  async checkBgTaskStatus(): Promise<void> {
    try {
      const isRegistered = await WorkSchedulerManager.getInstance().isTaskRegistered();
      this.bgTaskStatus = isRegistered ? '运行中 ✓' : '未运行';
    } catch (e) {
      this.bgTaskStatus = '状态未知';
    }
  }

  async loadSettings() {
    const s = await SettingsService.getInstance().getSettings();
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

  doSearch(kw: string) {
    clearTimeout(this.debounceTimer);
    if (!kw.trim()) {
      this.searchResults = [];
      this.showSearchResults = false;
      return;
    }
    this.debounceTimer = setTimeout(async () => {
      this.isSearching = true;
      this.showSearchResults = true;
      try {
        const res = await DatabaseHelper.getInstance().searchArticles(kw.trim(), -1);
        for (const a of res) {
          const feed = this.feeds.find(f => f.id === a.feedId);
          a.feedTitle = feed?.title ?? '';
        }
        this.searchResults = res;
      } finally {
        this.isSearching = false;
      }
    }, 400);
  }

  build() {
    Column() {
      // 顶部栏
      Row() {
        Text('我')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .justifyContent(FlexAlign.Start)
      .alignItems(VerticalAlign.Center)

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

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

      // 搜索结果 或 设置列表
      if (this.showSearchResults) {
        // 搜索结果视图
        Column() {
          Row() {
            Text(`搜索结果 (${this.searchResults.length})`)
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            Blank()
            Text('关闭')
              .fontSize(14)
              .fontColor($r('sys.color.ohos_id_color_activated'))
              .onClick(() => {
                this.keyword = '';
                this.searchResults = [];
                this.showSearchResults = false;
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })

          if (this.isSearching) {
            Column() {
              LoadingProgress().width(40).height(40)
            }
            .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
          } else if (this.searchResults.length === 0) {
            Column() {
              Text('暂无搜索结果')
                .fontSize(16)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            }
            .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
          } else {
            List() {
              ForEach(this.searchResults, (article: Article) => {
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
                      const newVal = article.isStarred === 1 ? 0 : 1;
                      await DatabaseHelper.getInstance().toggleStar(article.id!, newVal);
                      article.isStarred = newVal;
                      this.searchResults = [...this.searchResults];
                    }
                  })
                }
              }, (a: Article) => `${a.id}`)
            }
            .layoutWeight(1)
            .divider({ strokeWidth: 0.5, color: $r('sys.color.ohos_id_color_list_separator'), startMargin: 16, endMargin: 16 })
          }
        }
        .layoutWeight(1)
        .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
      } else {
        // 设置列表
        if (!this.loaded) {
          Column() {
            LoadingProgress().width(40).height(40)
          }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            Column({ space: 16 }) {

              // ===== 记忆与 AI =====
              this.sectionHeader('记忆与 AI')
              Column() {
                Row() {
                  Text('我的阅读档案')
                    .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(16).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width('100%').height(52).padding({ left: 16, right: 16 })
                .onClick(() => router.pushUrl({ url: 'pages/SoulEditPage' }))

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                Row() {
                  Text('阅读画像')
                    .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(16).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width('100%').height(52).padding({ left: 16, right: 16 })
                .onClick(() => router.pushUrl({ url: 'pages/ProfileViewPage' }))

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                Row() {
                  Text('阅读统计')
                    .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(16).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width('100%').height(52).padding({ left: 16, right: 16 })
                .onClick(() => router.pushUrl({ url: 'pages/ReadingStatsPage' }))

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                Row() {
                  Text('AI 设置')
                    .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(16).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width('100%').height(52).padding({ left: 16, right: 16 })
                .onClick(() => router.pushUrl({ url: 'pages/AISettingsPage' }))
              }
              .backgroundColor($r('sys.color.ohos_id_color_background')).borderRadius(12)

              // ===== 通用设置 =====
              this.sectionHeader('通用设置')
              Column() {
                Row() {
                  Text('自动刷新间隔')
                    .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                  Select(Constants.REFRESH_INTERVAL_LABELS.map((l: string): SelectOption => ({ value: l })))
                    .selected(this.refreshIntervalIndex)
                    .value(Constants.REFRESH_INTERVAL_LABELS[this.refreshIntervalIndex])
                    .onSelect((index: number) => {
                      this.refreshIntervalIndex = index;
                      const interval = Constants.REFRESH_INTERVALS[index];
                      SettingsService.getInstance().setSetting(Constants.PREF_REFRESH_INTERVAL, interval);
                      if (this.bgRefreshEnabled && interval > 0) {
                        const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
                        WorkSchedulerManager.getInstance().registerFeedRefreshTask(ctx.abilityInfo.bundleName, interval).then(() => {
                          this.checkBgTaskStatus();
                        });
                      } else if (interval === 0) {
                        WorkSchedulerManager.getInstance().unregisterFeedRefreshTask().then(() => {
                          this.checkBgTaskStatus();
                        });
                      }
                    })
                    .font({ size: 14 })
                }
                .width('100%').height(52).padding({ left: 16, right: 16 })

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                Row() {
                  Column({ space: 2 }) {
                    Text('后台自动刷新')
                      .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary'))
                    Text(this.bgTaskStatus)
                      .fontSize(12)
                      .fontColor(this.bgTaskStatus.includes('运行中')
                        ? $r('sys.color.ohos_id_color_activated')
                        : $r('sys.color.ohos_id_color_text_secondary'))
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)
                  Toggle({ type: ToggleType.Switch, isOn: this.bgRefreshEnabled })
                    .onChange((val: boolean) => {
                      if (!this.loaded) return;
                      this.bgRefreshEnabled = val;
                      SettingsService.getInstance().setSetting(Constants.PREF_BG_REFRESH, val);
                      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
                      const interval = Constants.REFRESH_INTERVALS[this.refreshIntervalIndex];
                      if (val && interval > 0) {
                        WorkSchedulerManager.getInstance().registerFeedRefreshTask(ctx.abilityInfo.bundleName, interval).then(() => {
                          this.checkBgTaskStatus();
                        });
                      } else {
                        WorkSchedulerManager.getInstance().unregisterFeedRefreshTask().then(() => {
                          this.checkBgTaskStatus();
                        });
                      }
                    })
                }
                .width('100%').height(60).padding({ left: 16, right: 16 })

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

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                Row() {
                  Text('字体大小')
                    .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                  Select(Constants.FONT_SIZE_LABELS.map((l: string): SelectOption => ({ value: l })))
                    .selected(this.fontSizeIndex)
                    .value(Constants.FONT_SIZE_LABELS[this.fontSizeIndex])
                    .onSelect((index: number) => {
                      this.fontSizeIndex = index;
                      SettingsService.getInstance().setSetting(Constants.PREF_FONT_SIZE, Constants.FONT_SIZES[index]);
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

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                Row() {
                  Text('每源缓存文章数')
                    .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                  Select(Constants.CACHE_COUNT_OPTIONS.map((n: number): SelectOption => ({ value: `${n}篇` })))
                    .selected(this.cacheCountIndex)
                    .value(`${Constants.CACHE_COUNT_OPTIONS[this.cacheCountIndex]}篇`)
                    .onSelect((index: number) => {
                      this.cacheCountIndex = index;
                      SettingsService.getInstance().setSetting(Constants.PREF_CACHE_COUNT, Constants.CACHE_COUNT_OPTIONS[index]);
                    })
                    .font({ size: 14 })
                }
                .width('100%').height(52).padding({ left: 16, right: 16 })

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                Row() {
                  Text('清除缓存')
                    .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(16).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
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

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                Row() {
                  Text('标签管理')
                    .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                  SymbolGlyph($r('sys.symbol.chevron_right'))
                    .fontSize(16).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width('100%').height(52).padding({ left: 16, right: 16 })
                .onClick(() => router.pushUrl({ url: 'pages/TagsManagePage' }))
              }
              .backgroundColor($r('sys.color.ohos_id_color_background')).borderRadius(12)

              // ===== 备份与恢复 =====
              this.sectionHeader('备份与恢复')
              Column() {
                // 完整备份（订阅源 + 分组 + 配置）
                Row() {
                  Column({ space: 2 }) {
                    Text(this.isBackingUp ? '备份中...' : '完整备份')
                      .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary'))
                    Text('将订阅源、分组和所有配置保存为文件')
                      .fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)
                  if (this.isBackingUp) {
                    LoadingProgress().width(20).height(20)
                  } else {
                    SymbolGlyph($r('sys.symbol.arrow_up'))
                      .fontSize(18).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                  }
                }
                .width('100%').height(60).padding({ left: 16, right: 16 })
                .opacity(this.isBackingUp ? 0.5 : 1.0)
                .onClick(() => {
                  if (!this.isBackingUp) this.doFullBackup();
                })

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                // 恢复备份
                Row() {
                  Column({ space: 2 }) {
                    Text(this.isRestoring ? '恢复中...' : '恢复备份')
                      .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary'))
                    Text('从备份文件恢复订阅源和配置')
                      .fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)
                  if (this.isRestoring) {
                    LoadingProgress().width(20).height(20)
                  } else {
                    SymbolGlyph($r('sys.symbol.arrow_down'))
                      .fontSize(18).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                  }
                }
                .width('100%').height(60).padding({ left: 16, right: 16 })
                .opacity(this.isRestoring ? 0.5 : 1.0)
                .onClick(() => {
                  if (!this.isRestoring) this.doRestore();
                })

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                Row() {
                  Column({ space: 2 }) {
                    Text(this.isExporting ? '导出中...' : '导出订阅源（OPML）')
                      .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary'))
                    Text('兼容其他 RSS 阅读器的标准格式')
                      .fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)
                  if (this.isExporting) {
                    LoadingProgress().width(20).height(20)
                  } else {
                    SymbolGlyph($r('sys.symbol.arrow_up'))
                      .fontSize(18).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                  }
                }
                .width('100%').height(60).padding({ left: 16, right: 16 })
                .opacity(this.isExporting ? 0.5 : 1.0)
                .onClick(() => {
                  if (!this.isExporting) this.exportOPML();
                })

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                Row() {
                  Column({ space: 2 }) {
                    Text(this.isImporting ? '导入中...' : '导入订阅源（OPML）')
                      .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary'))
                    Text('从 OPML 文件批量添加订阅')
                      .fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)
                  if (this.isImporting) {
                    LoadingProgress().width(20).height(20)
                  } else {
                    SymbolGlyph($r('sys.symbol.arrow_down'))
                      .fontSize(18).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                  }
                }
                .width('100%').height(60).padding({ left: 16, right: 16 })
                .opacity(this.isImporting ? 0.5 : 1.0)
                .onClick(() => {
                  if (!this.isImporting) this.importOPML();
                })
              }
              .backgroundColor($r('sys.color.ohos_id_color_background')).borderRadius(12)

              // ===== 数据管理 =====
              this.sectionHeader('数据管理')
              Column() {
                Row() {
                  Column({ space: 2 }) {
                    Text('导出记忆数据')
                      .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary'))
                    Text('将灵魂档案、画像和近7天日志导出为文本')
                      .fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)
                  SymbolGlyph($r('sys.symbol.arrow_up'))
                    .fontSize(18).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width('100%').height(60).padding({ left: 16, right: 16 })
                .onClick(() => this.exportMemory())

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                Row() {
                  Column({ space: 2 }) {
                    Text('重置为默认模板')
                      .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary'))
                    Text('将灵魂档案恢复为初始模板内容')
                      .fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)
                  SymbolGlyph($r('sys.symbol.arrow_counterclockwise'))
                    .fontSize(18).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width('100%').height(60).padding({ left: 16, right: 16 })
                .onClick(() => this.confirmResetToTemplate())

                Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

                Row() {
                  Column({ space: 2 }) {
                    Text('清除记忆数据')
                      .fontSize(15).fontColor(Color.Red)
                    Text('删除所有行为日志、画像和灵魂档案')
                      .fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)
                  SymbolGlyph($r('sys.symbol.trash'))
                    .fontSize(18).fontColor([Color.Red])
                }
                .width('100%').height(60).padding({ left: 16, right: 16 })
                .onClick(() => this.confirmClearMemory())
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

  private async exportOPML() {
    this.isExporting = true;
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const r = await DataOperationHelper.getInstance().exportOPML(ctx);
      if (!r.cancelled && r.message) {
        this.getUIContext().getPromptAction().showToast({ message: r.message });
      }
    } finally {
      this.isExporting = false;
    }
  }

  private async doFullBackup() {
    this.isBackingUp = true;
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const r = await DataOperationHelper.getInstance().doFullBackup(ctx);
      if (!r.cancelled && r.message) {
        this.getUIContext().getPromptAction().showToast({ message: r.message });
      }
    } finally {
      this.isBackingUp = false;
    }
  }

  private async doRestore() {
    this.isRestoring = true;
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const r = await DataOperationHelper.getInstance().doRestore(ctx);
      if (!r.cancelled && r.message) {
        this.getUIContext().getPromptAction().showToast({ message: r.message });
      }
      if (r.success) await this.loadSettings();
    } finally {
      this.isRestoring = false;
    }
  }

  private async importOPML() {
    this.isImporting = true;
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const r = await DataOperationHelper.getInstance().importOPML(ctx);
      if (!r.cancelled && r.message) {
        this.getUIContext().getPromptAction().showToast({ message: r.message });
      }
    } finally {
      this.isImporting = false;
    }
  }

  private async exportMemory() {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
    const r = await DataOperationHelper.getInstance().exportMemory(ctx);
    if (!r.cancelled && r.message) {
      this.getUIContext().getPromptAction().showToast({ message: r.message });
    }
  }

  private confirmClearMemory() {
    this.getUIContext().showAlertDialog({
      title: '清除记忆数据',
      message: '将删除所有行为日志、阅读画像和灵魂档案。此操作不可撤销。',
      primaryButton: {
        value: '确认清除',
        fontColor: Color.Red,
        action: async () => {
          const r = await DataOperationHelper.getInstance().clearMemory();
          this.getUIContext().getPromptAction().showToast({ message: r.message });
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }

  private confirmResetToTemplate() {
    this.getUIContext().showAlertDialog({
      title: '重置为默认模板',
      message: '将覆盖当前灵魂档案和画像为初始模板内容。已有的个人设置将丢失。',
      primaryButton: {
        value: '确认重置',
        fontColor: $r('sys.color.ohos_id_color_warning'),
        action: async () => {
          const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
          const r = await DataOperationHelper.getInstance().resetToTemplate(ctx);
          this.getUIContext().getPromptAction().showToast({ message: r.message });
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }
}
