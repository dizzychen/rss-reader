// 每日简报页面 — 结构化卡片式展示
import { BriefingData, BriefingItem, BriefingSkipItem, TimelineEntry } from '../model/Models';
import { BriefingService } from '../service/BriefingService';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { Constants } from '../constants/Constants';

@Entry
@Component
struct DailyBriefingPage {
  @State briefing: BriefingData | null = null;
  @State isGenerating: boolean = false;
  @State errorMsg: string = '';
  @State showSkippable: boolean = false;
  // 数据洞察
  @State unreadCount: number = 0;
  @State readCount: number = 0;
  @State starCount: number = 0;

  aboutToAppear() {
    this.loadBriefing();
    this.loadInsights();
  }

  async loadBriefing() {
    if (this.isGenerating) return;
    this.isGenerating = true;
    this.errorMsg = '';

    try {
      const data = await BriefingService.getInstance().generate();
      this.briefing = data;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.errorMsg = msg;
    } finally {
      this.isGenerating = false;
    }
  }

  async loadInsights() {
    try {
      const db = DatabaseHelper.getInstance();
      this.unreadCount = await db.getUnreadCount();
      this.readCount = await db.getTodayReadCount();
      this.starCount = await db.getTodayStarCount();
    } catch {
      // 数据洞察获取失败不影响主流程
    }
  }

  private getLevelColor(level: string): ResourceColor {
    if (level === 'high') return Constants.COLOR_RECOMMEND_HIGH;
    if (level === 'medium') return Constants.COLOR_RECOMMEND_MEDIUM;
    return Constants.COLOR_RECOMMEND_LOW;
  }

  private getLevelLabel(level: string): string {
    if (level === 'high') return '强烈推荐';
    if (level === 'medium') return '值得一看';
    return '可选阅读';
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

        Text('今日简报')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 8 })
          .layoutWeight(1)

        if (this.isGenerating) {
          LoadingProgress().width(24).height(24).margin({ right: 8 })
        } else {
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(20)
              .fontColor([$r('sys.color.ohos_id_color_text_primary')])
          }
          .width(36).height(36).backgroundColor(Color.Transparent)
          .onClick(() => this.loadBriefing())
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      if (this.isGenerating && !this.briefing) {
        // 首次加载态
        Column({ space: 16 }) {
          LoadingProgress().width(48).height(48)
          Text('AI 正在为你生成今日简报...')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.errorMsg && !this.briefing) {
        // 错误态
        Column({ space: 16 }) {
          Text(this.errorMsg)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .textAlign(TextAlign.Center)
            .padding({ left: 32, right: 32 })
          Button('重试')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_activated'))
            .backgroundColor(Color.Transparent)
            .onClick(() => this.loadBriefing())
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.briefing) {
        Scroll() {
          Column({ space: 16 }) {
            // 今日概览卡片
            this.overviewCard()

            // 推荐文章列表
            if (this.briefing!.recommended.length > 0) {
              this.sectionHeader('推荐阅读')
              this.recommendedList()
            }

            // 时间轴
            if (this.briefing!.timeline && this.briefing!.timeline.length > 0) {
              this.sectionHeader('今日新闻时间轴')
              this.timelineSection()
            }

            // 可跳过区域（折叠）
            if (this.briefing!.skippable.length > 0) {
              this.skippableSection()
            }

            // 数据洞察面板
            this.insightsPanel()
          }
          .padding({ left: 16, right: 16, top: 12, bottom: 40 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
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

  @Builder
  overviewCard() {
    Column({ space: 8 }) {
      // 摘要
      Text(this.briefing!.summary || '今日简报')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
        .width('100%')

      Row({ space: 16 }) {
        Text(`${this.briefing!.generatedAt}`)
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        Text(`分析 ${this.briefing!.articleCount} 篇文章`)
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        Text(`推荐 ${this.briefing!.recommended.length} 篇`)
          .fontSize(12)
          .fontColor($r('sys.color.ohos_id_color_activated'))
      }
      .width('100%')
    }
    .width('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .borderRadius(12)
    .padding(16)
  }

  @Builder
  recommendedList() {
    Column() {
      ForEach(this.briefing!.recommended, (item: BriefingItem, index: number) => {
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            // 推荐等级标签
            Text(this.getLevelLabel(item.level))
              .fontSize(10)
              .fontColor(Color.White)
              .backgroundColor(this.getLevelColor(item.level))
              .borderRadius(4)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })

            Text(item.source)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          }
          .width('100%')

          Text(item.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Text(item.reason)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .lineHeight(18)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .onClick(() => {
          if (item.articleId > 0) {
            this.getUIContext().getRouter().pushUrl({
              url: 'pages/ArticleDetailPage',
              params: { articleId: item.articleId }
            });
          }
        })

        if (index < this.briefing!.recommended.length - 1) {
          Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })
        }
      }, (item: BriefingItem, index: number) => `rec_${index}`)
    }
    .width('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .borderRadius(12)
  }

  @Builder
  timelineSection() {
    Column() {
      ForEach(this.briefing!.timeline, (entry: TimelineEntry, index: number) => {
        Row({ space: 12 }) {
          // 时间轴线 + 节点
          Column() {
            // 圆点
            Circle({ width: 10, height: 10 })
              .fill($r('sys.color.ohos_id_color_activated'))

            // 连接线（最后一个不显示）
            if (index < this.briefing!.timeline.length - 1) {
              Line()
                .width(2)
                .height(40)
                .backgroundColor($r('sys.color.ohos_id_color_list_separator'))
            }
          }
          .width(20)
          .alignItems(HorizontalAlign.Center)

          // 内容
          Column({ space: 4 }) {
            Text(entry.time)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.ohos_id_color_activated'))

            Text(entry.headline)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(entry.brief)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .alignItems(VerticalAlign.Top)
        .onClick(() => {
          if (entry.articleId > 0) {
            this.getUIContext().getRouter().pushUrl({
              url: 'pages/ArticleDetailPage',
              params: { articleId: entry.articleId }
            });
          }
        })
      }, (entry: TimelineEntry, index: number) => `tl_${index}`)
    }
    .width('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .borderRadius(12)
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  skippableSection() {
    Column({ space: 0 }) {
      // 折叠标题
      Row() {
        Text(`可以跳过（${this.briefing!.skippable.length}篇）`)
          .fontSize(13)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .layoutWeight(1)
        SymbolGlyph(this.showSkippable ? $r('sys.symbol.chevron_up') : $r('sys.symbol.chevron_down'))
          .fontSize(14)
          .fontColor([$r('sys.color.ohos_id_color_text_tertiary')])
      }
      .width('100%')
      .height(40)
      .padding({ left: 4, right: 4 })
      .onClick(() => {
        this.showSkippable = !this.showSkippable;
      })

      if (this.showSkippable) {
        Column() {
          ForEach(this.briefing!.skippable, (item: BriefingSkipItem, index: number) => {
            Row({ space: 8 }) {
              Column({ space: 2 }) {
                Text(item.title)
                  .fontSize(14)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Text(item.reason)
                  .fontSize(12)
                  .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                  .width('100%')
              }
              .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 10, bottom: 10 })

            if (index < this.briefing!.skippable.length - 1) {
              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })
            }
          }, (item: BriefingSkipItem, index: number) => `skip_${index}`)
        }
        .width('100%')
        .backgroundColor($r('sys.color.ohos_id_color_background'))
        .borderRadius(12)
      }
    }
    .width('100%')
  }

  @Builder
  insightsPanel() {
    Column({ space: 0 }) {
      Text('今日概况')
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
        .padding({ left: 4, bottom: 8 })

      Row({ space: 0 }) {
        this.insightItem('待阅读', `${this.unreadCount}`)
        this.insightItem('今日已读', `${this.readCount}`)
        this.insightItem('今日收藏', `${this.starCount}`)
      }
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .borderRadius(12)
    }
    .width('100%')
  }

  @Builder
  insightItem(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
      Text(label)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .layoutWeight(1)
    .padding({ top: 14, bottom: 14 })
    .alignItems(HorizontalAlign.Center)
  }
}
