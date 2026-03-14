// 文章详情页（内置阅读器）
import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { Article } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { RssService } from '../service/RssService';
import { SettingsService } from '../service/SettingsService';
import { Constants } from '../constants/Constants';

@Entry
@Component
struct ArticleDetailPage {
  @State article: Article | null = null;
  @State fontSizeIndex: number = 1; // 默认「中」
  @State isStarred: boolean = false;
  controller: webview.WebviewController = new webview.WebviewController();
  private articleId: number = -1;

  aboutToAppear() {
    const params = router.getParams() as Record<string, number>;
    this.articleId = params['articleId'] ?? -1;
    this.loadArticle();
    this.loadSettings();
  }

  async loadSettings() {
    const settings = await SettingsService.getInstance().getSettings();
    const idx = Constants.FONT_SIZES.indexOf(settings.fontSize);
    this.fontSizeIndex = idx >= 0 ? idx : 1;
  }

  async loadArticle() {
    const db = DatabaseHelper.getInstance();
    this.article = await db.getArticleById(this.articleId);
    if (this.article) {
      this.isStarred = this.article.isStarred === 1;
      // 标记已读
      if (this.article.isRead === 0) {
        await db.markRead(this.articleId, 1);
      }
    }
  }

  buildHtml(): string {
    if (!this.article) return '';
    const fontSize = Constants.FONT_SIZES[this.fontSizeIndex];
    const content = this.article.content || `<p>${this.article.summary}</p>`;
    return `<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=3.0">
<style>
  * { box-sizing: border-box; }
  body {
    font-family: -apple-system, 'PingFang SC', sans-serif;
    font-size: ${fontSize}px;
    line-height: 1.8;
    color: #1a1a1a;
    background: #ffffff;
    margin: 0;
    padding: 16px;
    word-break: break-word;
  }
  h1,h2,h3,h4 { font-weight: 600; line-height: 1.4; }
  a { color: #007AFF; }
  img { max-width: 100%; height: auto; border-radius: 8px; margin: 8px 0; }
  pre { background: #f5f5f5; padding: 12px; border-radius: 8px; overflow-x: auto; font-size: 13px; }
  code { background: #f0f0f0; padding: 2px 4px; border-radius: 4px; font-size: 0.9em; }
  blockquote { border-left: 4px solid #007AFF; margin: 0; padding-left: 16px; color: #555; }
  figure { margin: 0; }
  .meta { color: #888; font-size: 13px; margin-bottom: 16px; border-bottom: 1px solid #eee; padding-bottom: 12px; }
</style>
</head>
<body>
  <div class="meta">
    ${this.article.author ? `<span>${this.article.author}</span> · ` : ''}
    <span>${RssService.getInstance().formatDate(this.article.publishedAt)}</span>
  </div>
  ${content}
</body>
</html>`;
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

        Text(this.article?.title ?? '')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .margin({ left: 8, right: 8 })

        // 字体大小
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_font')).width(20).height(20).fillColor($r('sys.color.ohos_id_color_text_primary'))
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(() => {
          this.fontSizeIndex = (this.fontSizeIndex + 1) % Constants.FONT_SIZES.length;
          SettingsService.getInstance().setSetting(Constants.PREF_FONT_SIZE, Constants.FONT_SIZES[this.fontSizeIndex]);
          this.controller.loadData(this.buildHtml(), 'text/html', 'UTF-8');
        })

        // 收藏
        Button({ type: ButtonType.Circle }) {
          Image(this.isStarred ? $r('app.media.ic_star_filled') : $r('app.media.ic_star'))
            .width(20).height(20)
            .fillColor(this.isStarred ? Color.Orange : $r('sys.color.ohos_id_color_text_primary'))
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(async () => {
          const newVal = this.isStarred ? 0 : 1;
          await DatabaseHelper.getInstance().toggleStar(this.articleId, newVal);
          this.isStarred = !this.isStarred;
        })

        // 查看原文
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_open_link')).width(20).height(20).fillColor($r('sys.color.ohos_id_color_text_primary'))
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(() => {
          if (this.article?.url) {
            this.controller.loadUrl(this.article.url);
          }
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      // 标题区
      if (this.article) {
        Column({ space: 8 }) {
          Text(this.article.title)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .lineHeight(28)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16, bottom: 8 })
        .backgroundColor($r('sys.color.ohos_id_color_background'))
      }

      // WebView 正文
      Web({
        src: '',
        controller: this.controller
      })
        .layoutWeight(1)
        .onPageBegin(() => {})
        .onControllerAttached(() => {
          if (this.article) {
            this.controller.loadData(this.buildHtml(), 'text/html', 'UTF-8');
          }
        })
        .javaScriptAccess(false)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
