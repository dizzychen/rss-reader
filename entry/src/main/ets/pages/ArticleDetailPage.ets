// 文章详情页（原生 ArkTS 渲染，无需 WebView/ArkWeb）
import { router } from '@kit.ArkUI';
import { Article } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { RssService } from '../service/RssService';
import { SettingsService } from '../service/SettingsService';
import { Constants } from '../constants/Constants';
import { common } from '@kit.AbilityKit';
import { Want } from '@kit.AbilityKit';

@Entry
@Component
struct ArticleDetailPage {
  @State article: Article | null = null;
  @State fontSizeIndex: number = 1;
  @State isStarred: boolean = false;
  @State bodyText: string = '';
  private articleId: number = -1;

  aboutToAppear() {
    const params = this.getUIContext().getRouter().getParams();
    if (params && typeof (params as Record<string, number>)['articleId'] === 'number') {
      this.articleId = (params as Record<string, number>)['articleId'];
    }
    this.loadArticle();
    this.loadFontSize();
  }

  async loadFontSize() {
    const settings = await SettingsService.getInstance().getSettings();
    const idx = Constants.FONT_SIZES.indexOf(settings.fontSize);
    this.fontSizeIndex = idx >= 0 ? idx : 1;
  }

  async loadArticle() {
    const db = DatabaseHelper.getInstance();
    this.article = await db.getArticleById(this.articleId);
    if (this.article) {
      this.isStarred = this.article.isStarred === 1;
      if (this.article.isRead === 0) {
        await db.markRead(this.articleId, 1);
      }
      // 将 HTML 内容转换为适合 ArkTS Text 渲染的纯文本
      const raw = this.article.content || this.article.summary || '';
      this.bodyText = this.htmlToReadableText(raw);
    }
  }

  /**
   * 将 HTML 转换为可读纯文本：
   * - 块级标签（p / div / h1-h6 / li / br）转换为换行
   * - 去除所有剩余 HTML 标签
   * - 解码常见 HTML 实体
   * - 合并多余空行
   */
  private htmlToReadableText(html: string): string {
    // 块级标签前后插入换行
    let text = html
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n\n')
      .replace(/<\/div>/gi, '\n')
      .replace(/<\/h[1-6]>/gi, '\n\n')
      .replace(/<h[1-6][^>]*>/gi, '\n')
      .replace(/<\/li>/gi, '\n')
      .replace(/<li[^>]*>/gi, '• ')
      .replace(/<\/tr>/gi, '\n')
      .replace(/<\/blockquote>/gi, '\n')
      // 去除所有剩余标签
      .replace(/<[^>]+>/g, '')
      // 解码 HTML 实体
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&apos;/g, "'")
      .replace(/&nbsp;/g, ' ')
      .replace(/&#(\d+);/g, (_m: string, code: string) => String.fromCharCode(parseInt(code, 10)))
      .replace(/&#x([0-9a-fA-F]+);/g, (_m: string, code: string) => String.fromCharCode(parseInt(code, 16)))
      // 合并超过两个连续换行
      .replace(/\n{3,}/g, '\n\n')
      .trim();
    return text;
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

        Text(this.article?.title ?? '加载中...')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 8, right: 8 })

        // 字体大小循环切换
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.textformat'))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(() => {
          this.fontSizeIndex = (this.fontSizeIndex + 1) % Constants.FONT_SIZES.length;
          SettingsService.getInstance()
            .setSetting(Constants.PREF_FONT_SIZE, Constants.FONT_SIZES[this.fontSizeIndex]);
        })

        // 收藏
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r(this.isStarred ? 'sys.symbol.star_fill' : 'sys.symbol.star'))
            .fontSize(20)
            .fontColor([this.isStarred ? Color.Orange : $r('sys.color.ohos_id_color_text_primary')])
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(async () => {
          const newVal = this.isStarred ? 0 : 1;
          await DatabaseHelper.getInstance().toggleStar(this.articleId, newVal);
          this.isStarred = !this.isStarred;
        })

        // 查看原文（在系统浏览器中打开）
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.link'))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(() => {
          if (this.article?.url) {
            const want: Want = {
              action: 'ohos.want.action.viewData',
              uri: this.article.url
            };
            const ctx = this.getUIContext().getHostContext();
            if (ctx) {
              (ctx as common.UIAbilityContext).startAbility(want).catch((e: Error) => {
                console.error('ArticleDetailPage', `打开原文失败: ${e.message}`);
              });
            }
          }
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      if (this.article === null) {
        // 加载中
        Column() {
          LoadingProgress().width(40).height(40)
          Text('加载中...').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary')).margin({ top: 8 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 0 }) {
            // 标题
            Text(this.article.title)
              .fontSize(Constants.FONT_SIZES[this.fontSizeIndex] + 4)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .lineHeight((Constants.FONT_SIZES[this.fontSizeIndex] + 4) * 1.4)
              .width('100%')

            // 元信息行
            Row({ space: 8 }) {
              if (this.article.author) {
                Text(this.article.author)
                  .fontSize(12)
                  .fontColor($r('sys.color.ohos_id_color_activated'))
                  .maxLines(1)
              }
              Text(RssService.getInstance().formatDate(this.article.publishedAt))
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
            }
            .width('100%')
            .margin({ top: 8, bottom: 16 })

            Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ bottom: 16 })

            // 正文
            Text(this.bodyText || this.article.summary || '（暂无内容）')
              .fontSize(Constants.FONT_SIZES[this.fontSizeIndex])
              .fontColor($r('sys.color.ohos_id_color_text_primary'))
              .lineHeight(Constants.FONT_SIZES[this.fontSizeIndex] * 1.8)
              .width('100%')
              .wordBreak(WordBreak.BREAK_WORD)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 32 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
