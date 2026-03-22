// 每日简报页面
import { AIService } from '../service/AIService';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { Article } from '../model/Models';
import { DateUtil } from '../utils/DateUtil';

@Entry
@Component
struct DailyBriefingPage {
  @State briefingContent: string = '';
  @State isGenerating: boolean = false;
  @State generatedDate: string = '';
  @State articleCount: number = 0;

  aboutToAppear() {
    this.generateBriefing();
  }

  async generateBriefing() {
    if (this.isGenerating) return;
    this.isGenerating = true;
    this.briefingContent = '';

    try {
      if (!AIService.getInstance().hasApiKey()) {
        this.briefingContent = '请先在「设置 → AI 设置」中配置通义千问 API Key。';
        return;
      }

      // 获取今日未读文章
      const articles: Article[] = await DatabaseHelper.getInstance().getAllArticles(true, 50, 0);
      this.articleCount = articles.length;

      if (articles.length === 0) {
        this.briefingContent = '今日暂无未读文章，去「订阅」页添加更多 RSS 源吧！';
        return;
      }

      const content = await AIService.getInstance().generateBriefing(articles);
      this.briefingContent = content ?? '简报生成失败，请稍后重试。';
      this.generatedDate = DateUtil.today();
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.briefingContent = `生成失败：${msg}\n\n请检查网络连接和 API Key 是否有效。`;
    } finally {
      this.isGenerating = false;
    }
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
          .onClick(() => this.generateBriefing())
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      if (this.isGenerating) {
        Column({ space: 16 }) {
          LoadingProgress().width(48).height(48)
          Text('AI 正在为你生成今日简报...')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          if (this.articleCount > 0) {
            Text(`分析 ${this.articleCount} 篇文章中`)
              .fontSize(13)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          }
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 0 }) {
            if (this.generatedDate) {
              Text(`${this.generatedDate} · 共分析 ${this.articleCount} 篇文章`)
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                .width('100%')
                .padding({ left: 16, top: 12, bottom: 8 })
            }

            Text(this.briefingContent || '正在加载...')
              .fontSize(16)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .lineHeight(28)
              .width('100%')
              .padding({ left: 16, right: 16, top: 8, bottom: 40 })
          }
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .align(Alignment.TopStart)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
