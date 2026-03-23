import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { Article } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { RssService } from '../service/RssService';
import { SettingsService } from '../service/SettingsService';
import { MemoryService } from '../service/MemoryService';
import { AIService } from '../service/AIService';
import { Constants } from '../constants/Constants';
import { LvMarkdownIn } from '@luvi/lv-markdown-in';
import { common } from '@kit.AbilityKit';
import { Want } from '@kit.AbilityKit';

// 内容块类型：文本或图片
interface ContentBlock {
  type: 'text' | 'image';
  content: string;  // 文本内容或图片 URL
}

@Entry
@Component
struct ArticleDetailPage {
  @State article: Article | null = null;
  @State fontSizeIndex: number = 1;
  @State isStarred: boolean = false;
  @State bodyText: string = '';
  @State feedTitle: string = '';
  @State showAIPanel: boolean = false;
  @State aiAnalysis: string = '';
  @State isAILoading: boolean = false;
  @State contentBlocks: ContentBlock[] = [];
  @State userRating: number = 0;
  @State showWebView: boolean = false;
  @State webViewLoading: boolean = false;
  @State openOriginalInApp: boolean = true;
  private articleId: number = -1;
  private readStartTime: number = 0;
  private webController: webview.WebviewController = new webview.WebviewController();

  aboutToAppear() {
    const params = this.getUIContext().getRouter().getParams();
    if (params && typeof (params as Record<string, number>)['articleId'] === 'number') {
      this.articleId = (params as Record<string, number>)['articleId'];
    }
    this.loadArticle();
    this.loadFontSize();
    this.loadOpenOriginalSetting();
    this.readStartTime = Date.now();
  }

  aboutToDisappear() {
    // 记录 READ_END 行为（退出时）
    if (this.article && this.readStartTime > 0) {
      const duration = Math.floor((Date.now() - this.readStartTime) / 1000);
      if (duration >= 3) {  // 至少阅读 3 秒才记录
        MemoryService.getInstance().recordBehavior({
          timestamp: Date.now(),
          action: 'READ_END',
          articleId: this.article.id,
          articleTitle: this.article.title,
          feedTitle: this.feedTitle,
          duration: duration
        });
        // 立即刷写，防止数据丢失
        MemoryService.getInstance().flushBehaviors();
      }
    }
  }

  async loadFontSize() {
    const settings = await SettingsService.getInstance().getSettings();
    const idx = Constants.FONT_SIZES.indexOf(settings.fontSize);
    this.fontSizeIndex = idx >= 0 ? idx : 1;
  }

  async loadOpenOriginalSetting() {
    const settings = await SettingsService.getInstance().getSettings();
    this.openOriginalInApp = settings.openOriginalInApp;
  }

  async loadArticle() {
    const db = DatabaseHelper.getInstance();
    this.article = await db.getArticleById(this.articleId);
    if (this.article) {
      this.isStarred = this.article.isStarred === 1;
      if (this.article.isRead === 0) {
        await db.markRead(this.articleId, 1);
      }
      // 解析 HTML 为图文混排内容块
      const raw = this.article.content || this.article.summary || '';
      this.contentBlocks = this.parseHtmlToBlocks(raw);
      // 同时保留纯文本用于 AI 分析等场景
      this.bodyText = this.htmlToReadableText(raw);
      // 加载来源名称
      const feed = await db.getFeedById(this.article.feedId);
      this.feedTitle = feed?.title ?? '';

      // 记录 READ 行为
      MemoryService.getInstance().recordBehavior({
        timestamp: Date.now(),
        action: 'READ',
        articleId: this.article.id,
        articleTitle: this.article.title,
        feedTitle: this.feedTitle
      });
    }
  }

  /**
   * 将 HTML 解析为图文混排内容块
   */
  private parseHtmlToBlocks(html: string): ContentBlock[] {
    const blocks: ContentBlock[] = [];

    // 匹配图片标签，提取 src
    const imgRegex = /<img[^>]+src\s*=\s*["']([^"']+)["'][^>]*>/gi;

    let lastIndex = 0;
    let match: RegExpExecArray | null;

    while ((match = imgRegex.exec(html)) !== null) {
      // 图片前的文本
      if (match.index > lastIndex) {
        const textHtml = html.substring(lastIndex, match.index);
        const text = this.htmlToReadableText(textHtml).trim();
        if (text) {
          blocks.push({ type: 'text', content: text });
        }
      }

      // 图片
      const imgSrc = match[1];
      if (imgSrc && (imgSrc.startsWith('http://') || imgSrc.startsWith('https://'))) {
        blocks.push({ type: 'image', content: imgSrc });
      }

      lastIndex = imgRegex.lastIndex;
    }

    // 剩余文本
    if (lastIndex < html.length) {
      const textHtml = html.substring(lastIndex);
      const text = this.htmlToReadableText(textHtml).trim();
      if (text) {
        blocks.push({ type: 'text', content: text });
      }
    }

    // 如果没有解析到任何内容，返回整个文本
    if (blocks.length === 0) {
      const text = this.htmlToReadableText(html).trim();
      if (text) {
        blocks.push({ type: 'text', content: text });
      }
    }

    return blocks;
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

  private submitRating(score: number) {
    if (!this.article || this.userRating !== 0) return;
    this.userRating = score;
    MemoryService.getInstance().recordBehavior({
      timestamp: Date.now(),
      action: 'RATE',
      articleId: this.article.id,
      articleTitle: this.article.title,
      feedTitle: this.feedTitle,
      score: score
    });
    this.getUIContext().getPromptAction().showToast({
      message: score > 0 ? '已标记为有价值' : '已标记为不感兴趣'
    });
  }

  /**
   * 触发 AI 解读分析
   */
  private async analyzeWithAI() {
    if (this.isAILoading || !this.article) return;

    if (!AIService.getInstance().hasApiKey()) {
      this.getUIContext().getPromptAction().showToast({
        message: '请先在「设置 → AI 设置」中配置 API Key'
      });
      return;
    }

    this.isAILoading = true;
    this.showAIPanel = true;
    this.aiAnalysis = '正在分析中...';

    try {
      // Article 接口含 feedTitle? 字段，直接赋值后传入，无需展开
      const art = this.article;
      art.feedTitle = this.feedTitle;
      const analysis = await AIService.getInstance().analyzeArticle(art);
      this.aiAnalysis = analysis ?? '分析失败，请稍后重试。';
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.aiAnalysis = `分析失败：${msg}`;
    } finally {
      this.isAILoading = false;
    }
  }

  private openInExternalBrowser() {
    if (!this.article?.url) return;
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
          const action = newVal === 1 ? 'STAR' : 'UNSTAR';
          MemoryService.getInstance().recordBehavior({
            timestamp: Date.now(),
            action: action,
            articleId: this.article?.id,
            articleTitle: this.article?.title,
            feedTitle: this.feedTitle
          });
          this.isStarred = !this.isStarred;
        })

        // AI 解读按钮
        Button({ type: ButtonType.Circle }) {
          if (this.isAILoading) {
            LoadingProgress().width(18).height(18)
          } else {
            Text('AI')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.showAIPanel
                ? $r('sys.color.ohos_id_color_activated')
                : $r('sys.color.ohos_id_color_text_primary'))
          }
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(() => {
          if (this.showAIPanel && !this.isAILoading) {
            this.showAIPanel = false;
          } else {
            this.analyzeWithAI();
          }
        })
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      if (this.article === null) {
        Column() {
          LoadingProgress().width(40).height(40)
          Text('加载中...').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary')).margin({ top: 8 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Column() {
          // 视图切换 Tab（有 URL 时显示）
          if (this.article.url) {
            Row() {
              // RSS 内容 Tab
              Text('RSS 内容')
                .fontSize(14)
                .fontWeight(!this.showWebView ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(!this.showWebView ? Color.White : $r('sys.color.ohos_id_color_text_secondary'))
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .backgroundColor(!this.showWebView ? $r('sys.color.ohos_id_color_activated') : Color.Transparent)
                .borderRadius(18)
                .border({
                  width: !this.showWebView ? 0 : 1,
                  color: $r('sys.color.ohos_id_color_component_normal')
                })
                .onClick(() => { this.showWebView = false; })
                .margin({ right: 8 })

              // 查看原文 Tab
              Text('查看原文')
                .fontSize(14)
                .fontWeight(this.showWebView ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(this.showWebView ? Color.White : $r('sys.color.ohos_id_color_text_secondary'))
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .backgroundColor(this.showWebView ? $r('sys.color.ohos_id_color_activated') : Color.Transparent)
                .borderRadius(18)
                .border({
                  width: this.showWebView ? 0 : 1,
                  color: $r('sys.color.ohos_id_color_component_normal')
                })
                .onClick(() => {
                  this.showWebView = true;
                  if (!this.openOriginalInApp) {
                    this.openInExternalBrowser();
                  }
                })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 8 })
            .backgroundColor($r('sys.color.ohos_id_color_background'))
          }

          if (this.showWebView && this.article.url) {
            // WebView 原文模式
            Stack() {
              Web({ src: this.article.url, controller: this.webController })
                .javaScriptAccess(true)
                .domStorageAccess(true)
                .mixedMode(MixedMode.Compatible)
                .onPageBegin(() => {
                  this.webViewLoading = true;
                })
                .onPageEnd(() => {
                  this.webViewLoading = false;
                })
                .onErrorReceive((event) => {
                  console.error('ArticleDetailPage', `WebView error: ${event?.error?.getErrorInfo()}`);
                  this.webViewLoading = false;
                })
                .width('100%')
                .height('100%')

              if (this.webViewLoading) {
                Column() {
                  LoadingProgress().width(36).height(36)
                  Text('正在加载原文...')
                    .fontSize(13)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                    .margin({ top: 8 })
                }
                .width('100%')
                .height('100%')
                .justifyContent(FlexAlign.Center)
                .backgroundColor('#80FFFFFF')
              }
            }
            .width('100%')
            .layoutWeight(1)
          } else {
            // RSS 内容模式（原有逻辑）
            Scroll() {
              Column({ space: 0 }) {
                Text(this.article.title)
                  .fontSize(Constants.FONT_SIZES[this.fontSizeIndex] + 4)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .lineHeight((Constants.FONT_SIZES[this.fontSizeIndex] + 4) * 1.5)
                  .width('100%')

                Row({ space: 8 }) {
                  if (this.feedTitle) {
                    SymbolGlyph($r('sys.symbol.discover'))
                      .fontSize(11)
                      .fontColor([$r('sys.color.ohos_id_color_activated')])
                    Text(this.feedTitle)
                      .fontSize(12)
                      .fontColor($r('sys.color.ohos_id_color_activated'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .constraintSize({ maxWidth: '50%' })
                  }
                  if (this.article.author) {
                    Text(this.article.author)
                      .fontSize(12)
                      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .constraintSize({ maxWidth: '30%' })
                  }
                  Blank()
                  Text(RssService.getInstance().formatDate(this.article.publishedAt))
                    .fontSize(12)
                    .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                }
                .width('100%')
                .margin({ top: 8 })
                .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
                .borderRadius(8)
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })

                Divider()
                  .color($r('sys.color.ohos_id_color_list_separator'))
                  .margin({ top: 16, bottom: 16 })

                if (this.contentBlocks.length > 0) {
                  ForEach(this.contentBlocks, (block: ContentBlock, index: number) => {
                    if (block.type === 'text') {
                      Text(block.content)
                        .fontSize(Constants.FONT_SIZES[this.fontSizeIndex])
                        .fontColor($r('sys.color.ohos_id_color_text_primary'))
                        .lineHeight(Constants.FONT_SIZES[this.fontSizeIndex] * 1.8)
                        .width('100%')
                        .wordBreak(WordBreak.BREAK_WORD)
                        .margin({ bottom: 16 })
                    } else if (block.type === 'image') {
                      Image(block.content)
                        .width('100%')
                        .objectFit(ImageFit.Contain)
                        .borderRadius(8)
                        .margin({ top: 8, bottom: 16 })
                    }
                  }, (block: ContentBlock, index: number) => `${index}-${block.type}`)
                } else {
                  Text(this.article.summary || '（暂无内容）')
                    .fontSize(Constants.FONT_SIZES[this.fontSizeIndex])
                    .fontColor($r('sys.color.ohos_id_color_text_primary'))
                    .lineHeight(Constants.FONT_SIZES[this.fontSizeIndex] * 1.8)
                    .width('100%')
                    .wordBreak(WordBreak.BREAK_WORD)
                }

                // 文章反馈区
                Divider()
                  .color($r('sys.color.ohos_id_color_list_separator'))
                  .margin({ top: 24, bottom: 16 })

                Column({ space: 12 }) {
                  Text('这篇文章对你有帮助吗？')
                    .fontSize(14)
                    .fontColor($r('sys.color.ohos_id_color_text_tertiary'))

                  Row({ space: 12 }) {
                    // 有价值按钮
                    Row({ space: 6 }) {
                      SymbolGlyph(this.userRating === 1
                        ? $r('sys.symbol.hand_thumbsup_fill')
                        : $r('sys.symbol.hand_thumbsup'))
                        .fontSize(18)
                        .fontColor([this.userRating === 1
                          ? $r('sys.color.ohos_id_color_activated')
                          : $r('sys.color.ohos_id_color_text_secondary')])
                      Text('有价值')
                        .fontSize(14)
                        .fontColor(this.userRating === 1
                          ? $r('sys.color.ohos_id_color_activated')
                          : $r('sys.color.ohos_id_color_text_secondary'))
                    }
                    .height(40)
                    .padding({ left: 16, right: 16 })
                    .borderRadius(20)
                    .backgroundColor(this.userRating === 1
                      ? '#1A0A59F7'  // 激活状态的浅蓝色背景
                      : $r('sys.color.ohos_id_color_sub_background'))
                    .border({
                      width: 1,
                      color: this.userRating === 1
                        ? $r('sys.color.ohos_id_color_activated')
                        : $r('sys.color.ohos_id_color_component_normal'),
                      style: BorderStyle.Solid
                    })
                    .enabled(this.userRating === 0)
                    .opacity(this.userRating === -1 ? 0.4 : 1.0)
                    .onClick(() => this.submitRating(1))

                    // 不感兴趣按钮
                    Row({ space: 6 }) {
                      SymbolGlyph(this.userRating === -1
                        ? $r('sys.symbol.hand_thumbsdown_fill')
                        : $r('sys.symbol.hand_thumbsdown'))
                        .fontSize(18)
                        .fontColor([this.userRating === -1
                          ? $r('sys.color.ohos_id_color_warning')
                          : $r('sys.color.ohos_id_color_text_secondary')])
                      Text('不感兴趣')
                        .fontSize(14)
                        .fontColor(this.userRating === -1
                          ? $r('sys.color.ohos_id_color_warning')
                          : $r('sys.color.ohos_id_color_text_secondary'))
                    }
                    .height(40)
                    .padding({ left: 16, right: 16 })
                    .borderRadius(20)
                    .backgroundColor(this.userRating === -1
                      ? '#1AE84026'  // 警告状态的浅红色背景
                      : $r('sys.color.ohos_id_color_sub_background'))
                    .border({
                      width: 1,
                      color: this.userRating === -1
                        ? $r('sys.color.ohos_id_color_warning')
                        : $r('sys.color.ohos_id_color_component_normal'),
                      style: BorderStyle.Solid
                    })
                    .enabled(this.userRating === 0)
                    .opacity(this.userRating === 1 ? 0.4 : 1.0)
                    .onClick(() => this.submitRating(-1))
                  }
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)

              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 20, bottom: 40 })
              .alignItems(HorizontalAlign.Start)
            }
            .align(Alignment.TopStart)
            .layoutWeight(1)
            .scrollBar(BarState.Auto)
          }

          // AI 解读面板（底部浮层）
          if (this.showAIPanel) {
            Column() {
              Row() {
                Text('AI 解读')
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .layoutWeight(1)
                Button({ type: ButtonType.Circle }) {
                  SymbolGlyph($r('sys.symbol.xmark'))
                    .fontSize(16)
                    .fontColor([$r('sys.color.ohos_id_color_text_secondary')])
                }
                .width(28).height(28).backgroundColor(Color.Transparent)
                .onClick(() => { this.showAIPanel = false; })
              }
              .width('100%')
              .padding({ left: 16, right: 12, top: 12, bottom: 8 })

              Divider().color($r('sys.color.ohos_id_color_list_separator'))

              if (this.isAILoading) {
                Row({ space: 8 }) {
                  LoadingProgress().width(20).height(20)
                  Text('AI 正在分析...').fontSize(13)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                }
                .width('100%').padding(16).justifyContent(FlexAlign.Center)
              } else {
                Scroll() {
                  LvMarkdownIn({
                    text: this.aiAnalysis
                  })
                }
                .constraintSize({ maxHeight: 300 })
                .scrollBar(BarState.Auto)
              }
            }
            .width('100%')
            .backgroundColor($r('sys.color.ohos_id_color_background'))
            .shadow({ radius: 8, color: '#20000000', offsetY: -4 })
          }
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
