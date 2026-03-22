// 设置页
import { router } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { SettingsService } from '../service/SettingsService';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { MemoryService } from '../service/MemoryService';
import { Constants } from '../constants/Constants';
import { OPMLService } from '../service/OPMLService';
import { OPMLFileHelper } from '../service/OPMLFileHelper';
import { WorkSchedulerManager } from '../service/WorkSchedulerManager';
import { common } from '@kit.AbilityKit';

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
  @State isExporting: boolean = false;
  @State isImporting: boolean = false;
  @State bgTaskStatus: string = '检查中...';

  aboutToAppear() {
    this.loadSettings();
    this.checkBgTaskStatus();
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
                    const interval = Constants.REFRESH_INTERVALS[index];
                    SettingsService.getInstance()
                      .setSetting(Constants.PREF_REFRESH_INTERVAL, interval);
                    // 若后台刷新已开启，同步更新任务周期
                    if (this.bgRefreshEnabled && interval > 0) {
                      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
                      WorkSchedulerManager.getInstance().registerFeedRefreshTask(ctx.abilityInfo.bundleName, interval).then(() => {
                        this.checkBgTaskStatus();
                      });
                    } else if (interval === 0) {
                      // 间隔设为「关闭」时停止后台任务
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
                    // 启动或停止后台任务
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

            // ===== 备份与恢复 =====
            this.sectionHeader('备份与恢复')
            Column() {
              Row() {
                Column({ space: 2 }) {
                  Text(this.isExporting ? '导出中...' : '导出订阅源')
                    .fontSize(15)
                    .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  Text('将订阅源保存为 OPML 文件')
                    .fontSize(12)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                if (this.isExporting) {
                  LoadingProgress().width(20).height(20)
                } else {
                  SymbolGlyph($r('sys.symbol.arrow_up'))
                    .fontSize(18)
                    .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
              }
              .width('100%').height(60).padding({ left: 16, right: 16 })
              .opacity(this.isExporting ? 0.5 : 1.0)
              .onClick(() => {
                if (!this.isExporting) {
                  this.exportOPML();
                }
              })

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              Row() {
                Column({ space: 2 }) {
                  Text(this.isImporting ? '导入中...' : '导入订阅源')
                    .fontSize(15)
                    .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  Text('从 OPML 文件批量添加订阅')
                    .fontSize(12)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                if (this.isImporting) {
                  LoadingProgress().width(20).height(20)
                } else {
                  SymbolGlyph($r('sys.symbol.arrow_down'))
                    .fontSize(18)
                    .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
              }
              .width('100%').height(60).padding({ left: 16, right: 16 })
              .opacity(this.isImporting ? 0.5 : 1.0)
              .onClick(() => {
                if (!this.isImporting) {
                  this.importOPML();
                }
              })
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
              .onClick(() => this.getUIContext().getRouter().pushUrl({ url: 'pages/SoulEditPage' }))

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              Row() {
                Text('阅读画像')
                  .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(16).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })
              .onClick(() => this.getUIContext().getRouter().pushUrl({ url: 'pages/ProfileViewPage' }))

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              Row() {
                Text('阅读统计')
                  .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(16).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })
              .onClick(() => this.getUIContext().getRouter().pushUrl({ url: 'pages/ReadingStatsPage' }))

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              Row() {
                Text('AI 设置')
                  .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(16).fontColor([$r('sys.color.ohos_id_color_text_secondary')])
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })
              .onClick(() => this.getUIContext().getRouter().pushUrl({ url: 'pages/AISettingsPage' }))
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

  private async exportOPML() {
    this.isExporting = true;
    try {
      const feeds = await DatabaseHelper.getInstance().getAllFeeds();
      if (feeds.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '没有订阅源可导出' });
        return;
      }

      const opmlContent = OPMLService.getInstance().generateOPML(feeds);
      const filename = OPMLService.getInstance().generateOPMLFilename();

      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const filePath = await OPMLFileHelper.saveOPMLFile(ctx, opmlContent, filename);

      console.info('SettingsPage', `OPML exported to: ${filePath}`);
      this.getUIContext().getPromptAction().showToast({
        message: `导出成功，共 ${feeds.length} 个订阅源`
      });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg === '用户取消保存') {
        return;
      }
      console.error('SettingsPage', `Export OPML failed: ${msg}`);
      this.getUIContext().getPromptAction().showToast({ message: `导出失败：${msg}` });
    } finally {
      this.isExporting = false;
    }
  }

  private async importOPML() {
    this.isImporting = true;
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;

      // 1. 打开文件选择器
      const fileUri = await OPMLFileHelper.selectOPMLFile(ctx);

      // 2. 读取文件内容
      const opmlContent = await OPMLFileHelper.readOPMLFile(fileUri);

      // 3. 解析 OPML
      const items = OPMLService.getInstance().parseOPML(opmlContent);
      if (items.length === 0) {
        this.getUIContext().getPromptAction().showToast({ message: '文件中未找到有效的 RSS 订阅' });
        return;
      }

      // 4. 批量导入（使用默认分组 id=1）
      const result = await OPMLService.getInstance().importFeeds(items, 1);

      // 5. 显示导入结果
      const total = items.length;
      let msg = `解析 ${total} 个订阅，成功 ${result.success} 个`;
      if (result.skipped > 0) {
        msg += `，跳过 ${result.skipped} 个`;
      }
      if (result.failed > 0) {
        msg += `，失败 ${result.failed} 个`;
      }
      this.getUIContext().getPromptAction().showToast({ message: msg });

      if (result.errors.length > 0) {
        console.warn('SettingsPage', 'OPML import errors:', result.errors.join('\n'));
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg === '未选择文件') {
        // 用户取消选择，不显示错误
        return;
      }
      console.error('SettingsPage', `Import OPML failed: ${msg}`);
      this.getUIContext().getPromptAction().showToast({ message: `导入失败：${msg}` });
    } finally {
      this.isImporting = false;
    }
  }

  private async exportMemory() {
    try {
      const content = await MemoryService.getInstance().exportMemoryData();
      if (!content.trim()) {
        this.getUIContext().getPromptAction().showToast({ message: '暂无记忆数据可导出' });
        return;
      }

      // 使用 OPMLFileHelper 保存文件（复用文件保存逻辑）
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const filename = `memory_export_${new Date().toISOString().slice(0, 10)}.md`;
      await OPMLFileHelper.saveOPMLFile(ctx, content, filename);
      this.getUIContext().getPromptAction().showToast({ message: '记忆数据导出成功' });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg === '用户取消保存') return;
      this.getUIContext().getPromptAction().showToast({ message: `导出失败：${msg}` });
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
          try {
            await MemoryService.getInstance().clearAllMemory();
            this.getUIContext().getPromptAction().showToast({ message: '记忆数据已清除' });
          } catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            this.getUIContext().getPromptAction().showToast({ message: `清除失败：${msg}` });
          }
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
          try {
            // 从 rawfile 读取模板
            const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
            const soulRaw = await ctx.resourceManager.getRawFileContent('memory/SOUL.md');
            const profileRaw = await ctx.resourceManager.getRawFileContent('memory/PROFILE.md');
            const decoder = new util.TextDecoder('utf-8');
            const soulTemplate = decoder.decodeToString(soulRaw);
            const profileTemplate = decoder.decodeToString(profileRaw);

            // 执行重置
            await MemoryService.getInstance().resetToTemplate(soulTemplate, profileTemplate);
            this.getUIContext().getPromptAction().showToast({ message: '已重置为默认模板' });
          } catch (e) {
            const msg = e instanceof Error ? e.message : String(e);
            this.getUIContext().getPromptAction().showToast({ message: `重置失败：${msg}` });
          }
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }
}

