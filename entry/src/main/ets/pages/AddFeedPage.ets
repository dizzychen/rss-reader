// 添加订阅源页面
import { router } from '@kit.ArkUI';
import { UIContext } from '@kit.ArkUI';
import { RssService } from '../service/RssService';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { FeedGroup } from '../model/Models';

@Entry
@Component
struct AddFeedPage {
  @State url: string = '';
  @State isProcessing: boolean = false;
  @State errorMsg: string = '';
  @State previewTitle: string = '';
  @State previewDesc: string = '';
  @State previewArticleCount: number = 0;
  @State groups: FeedGroup[] = [];
  @State selectedGroupId: number = 1;
  private uiCtx: UIContext | null = null;

  aboutToAppear() {
    this.uiCtx = this.getUIContext();
    this.loadGroups();
  }

  async loadGroups() {
    this.groups = await DatabaseHelper.getInstance().getAllGroups();
    if (this.groups.length > 0) {
      this.selectedGroupId = this.groups[0].id!;
    }
  }

  // 合并验证和添加为一个流程
  async addFeed() {
    const trimUrl = this.url.trim();
    if (!trimUrl) {
      this.errorMsg = '请输入RSS链接';
      return;
    }
    if (!trimUrl.startsWith('http://') && !trimUrl.startsWith('https://')) {
      this.errorMsg = '请输入有效的HTTP/HTTPS链接';
      return;
    }

    this.isProcessing = true;
    this.errorMsg = '';

    try {
      // 获取并解析订阅源
      const info = await RssService.getInstance().fetchFeedInfo(trimUrl);
      console.info('AddFeedPage', `Fetched feed: ${info.title}, articles: ${info.articles.length}`);
      
      if (!info.title && info.articles.length === 0) {
        this.errorMsg = '解析成功但未获取到内容，请检查订阅源格式';
        this.isProcessing = false;
        return;
      }

      // 显示预览
      this.previewTitle = info.title || '（无标题）';
      this.previewDesc = info.description || '';
      this.previewArticleCount = info.articles.length;

      // 保存到数据库
      const db = DatabaseHelper.getInstance();
      const feedId = await db.insertFeed({
        title: info.title || trimUrl,
        url: trimUrl,
        siteUrl: info.siteUrl,
        iconUrl: info.iconUrl,
        description: info.description,
        groupId: this.selectedGroupId,
        lastUpdated: 0
      });
      console.info('AddFeedPage', `Feed inserted with id: ${feedId}`);

      // 插入文章
      for (const pa of info.articles) {
        const coverImage = pa.coverImage || RssService.getInstance().extractFirstImage(pa.content);
        await db.insertOrUpdateArticle({
          feedId: feedId,
          guid: pa.guid,
          title: pa.title,
          summary: pa.summary,
          content: pa.content,
          url: pa.url,
          author: pa.author,
          publishedAt: pa.publishedAt,
          isRead: 0,
          isStarred: 0,
          coverImage: coverImage
        });
      }
      console.info('AddFeedPage', `Inserted ${info.articles.length} articles`);

      // 返回上一页
      this.uiCtx?.runScopedTask(() => {
        router.back();
      });
    } catch (e) {
      const err = e as Error;
      console.error('AddFeedPage', `Error: ${err?.message || String(e)}`);
      this.errorMsg = `添加失败：${err?.message || String(e)}`;
    } finally {
      this.isProcessing = false;
    }
  }

  build() {
    Column() {
      // 导航栏
      Row() {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_back'))
            .width(20).height(20)
            .fillColor($r('sys.color.ohos_id_color_text_primary'))
        }
        .width(36).height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => router.back())

        Text('添加订阅源')
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
          // URL 输入
          Column({ space: 8 }) {
            Text('RSS链接').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary')).alignSelf(ItemAlign.Start)
            TextInput({ placeholder: 'https://example.com/feed.xml', text: this.url })
              .fontSize(15)
              .onChange((val) => {
                this.url = val;
                this.errorMsg = '';
                this.previewTitle = '';
              })
              .onSubmit(() => this.addFeed())
              .borderRadius(8)
              .backgroundColor($r('sys.color.ohos_id_color_background'))
            if (this.errorMsg) {
              Text(this.errorMsg)
                .fontSize(13)
                .fontColor(Color.Red)
                .alignSelf(ItemAlign.Start)
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(12)

          // 分组选择
          Column({ space: 8 }) {
            Text('添加到分组').fontSize(14).fontColor($r('sys.color.ohos_id_color_text_secondary')).alignSelf(ItemAlign.Start)
            ForEach(this.groups, (group: FeedGroup) => {
              Row() {
                Radio({ value: `${group.id}`, group: 'groupSelect' })
                  .checked(this.selectedGroupId === group.id!)
                  .onChange((checked) => {
                    if (checked) this.selectedGroupId = group.id!;
                  })
                Text(group.name).fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).margin({ left: 8 })
              }
              .width('100%')
              .height(44)
              .onClick(() => { this.selectedGroupId = group.id!; })
            }, (g: FeedGroup) => `${g.id}`)
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.ohos_id_color_background'))
          .borderRadius(12)

          // 添加按钮（合并验证和添加）
          Button(this.isProcessing ? '添加中...' : '添加订阅源')
            .width('100%')
            .fontSize(16)
            .fontColor(Color.White)
            .enabled(!this.isProcessing && this.url.trim().length > 0)
            .opacity((!this.isProcessing && this.url.trim().length > 0) ? 1.0 : 0.5)
            .onClick(() => this.addFeed())
        }
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
