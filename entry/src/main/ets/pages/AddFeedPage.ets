// 添加订阅源页面
import { router } from '@kit.ArkUI';
import { RssService } from '../service/RssService';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { FeedGroup } from '../model/Models';

@Entry
@Component
struct AddFeedPage {
  @State url: string = '';
  @State isProcessing: boolean = false;
  @State errorMsg: string = '';
  @State groups: FeedGroup[] = [];
  @State selectedGroupId: number = 1;
  @State @Watch('onShouldGoBack') shouldGoBack: boolean = false;

  onShouldGoBack() {
    if (this.shouldGoBack) {
      this.getUIContext().getRouter().back();
    }
  }

  aboutToAppear() {
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

      // 保存 Feed 元信息到数据库
      const db = DatabaseHelper.getInstance();
      let feedId = await db.insertFeed({
        title: info.title || trimUrl,
        url: trimUrl,
        siteUrl: info.siteUrl,
        iconUrl: info.iconUrl,
        description: info.description,
        groupId: this.selectedGroupId,
        lastUpdated: 0
      });
      console.info('AddFeedPage', `Feed inserted with id: ${feedId}`);

      // 实机：insert 成功返回新行 id（>= 1），ON_CONFLICT_IGNORE 冲突时返回 -1
      // Previewer mock：insert 始终返回 0（模拟实现限制）
      if (feedId === -1) {
        // URL 已存在，查出已有 Feed 的 id
        const existingFeed = await db.getFeedByUrl(trimUrl);
        if (existingFeed && existingFeed.id) {
          feedId = existingFeed.id;
          console.info('AddFeedPage', `Feed already exists with id: ${feedId}`);
        } else {
          // 理论上不会走到这里，保险起见报错
          this.errorMsg = '添加失败：数据库写入异常，请重试';
          this.isProcessing = false;
          return;
        }
      } else if (feedId === 0) {
        // Previewer mock 环境：无法获取真实 id，直接继续（文章插入也会走 mock）
        console.info('AddFeedPage', 'Running in Previewer mock, skipping real id lookup');
      }

      // Feed 已保存，通过状态标志触发返回（避免在 async 中直接调用 router.back() 丢失 UI 上下文）
      this.isProcessing = false;
      this.shouldGoBack = true;

      // 文章插入在后台异步执行，不阻塞页面跳转
      const articles = info.articles;
      const savedFeedId = feedId;
      Promise.resolve().then(async () => {
        for (const pa of articles) {
          const coverImage = pa.coverImage || RssService.getInstance().extractFirstImage(pa.content);
          const rowId = await db.insertOrUpdateArticle({
            feedId: savedFeedId,
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
          // 文章已存在但有新封面图：尝试回填
          if (rowId === -1 && coverImage) {
            await db.updateCoverImage(savedFeedId, pa.guid, coverImage);
          }
        }
        console.info('AddFeedPage', `Background: inserted ${articles.length} articles for feed ${savedFeedId}`);
      }).catch((e: Error) => {
        console.error('AddFeedPage', `Background article insert error: ${e?.message || String(e)}`);
      });

    } catch (e) {
      let msg: string;
      if (e instanceof Error) {
        msg = e.message;
      } else if (typeof e === 'object' && e !== null) {
        // 处理 BusinessError 等对象类型
        const errObj = e as object;
        const errMessage = (errObj as Record<string, string>)['message'];
        const errCode = (errObj as Record<string, number>)['code'];
        if (errMessage) {
          msg = errMessage;
        } else if (errCode !== undefined) {
          msg = `错误代码: ${errCode}`;
        } else {
          msg = JSON.stringify(e);
        }
      } else {
        msg = String(e);
      }
      console.error('AddFeedPage', `Error: ${msg}`);
      this.errorMsg = `添加失败：${msg}`;
      this.isProcessing = false;
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
        .width(36).height(36)
        .backgroundColor(Color.Transparent)
        .onClick(() => this.getUIContext().getRouter().back())

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
