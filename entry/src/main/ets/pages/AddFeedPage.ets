// 添加订阅源页面
import { router } from '@kit.ArkUI';
import { RssService } from '../service/RssService';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { FeedGroup } from '../model/Models';

@Entry
@Component
struct AddFeedPage {
  @State url: string = '';
  @State isValidating: boolean = false;
  @State errorMsg: string = '';
  @State previewTitle: string = '';
  @State previewDesc: string = '';
  @State groups: FeedGroup[] = [];
  @State selectedGroupId: number = 1;

  aboutToAppear() {
    this.loadGroups();
  }

  async loadGroups() {
    this.groups = await DatabaseHelper.getInstance().getAllGroups();
    if (this.groups.length > 0) {
      this.selectedGroupId = this.groups[0].id!;
    }
  }

  async validateAndPreview() {
    const trimUrl = this.url.trim();
    if (!trimUrl) {
      this.errorMsg = '请输入RSS链接';
      return;
    }
    if (!trimUrl.startsWith('http://') && !trimUrl.startsWith('https://')) {
      this.errorMsg = '请输入有效的HTTP/HTTPS链接';
      return;
    }

    this.isValidating = true;
    this.errorMsg = '';
    this.previewTitle = '';
    this.previewDesc = '';

    try {
      const info = await RssService.getInstance().fetchFeedInfo(trimUrl);
      this.previewTitle = info.title || '（无标题）';
      this.previewDesc = info.description || '';
    } catch (e) {
      const err = e as Error;
      this.errorMsg = `无法获取订阅源：${err?.message || String(e)}`;
    } finally {
      this.isValidating = false;
    }
  }

  async addFeed() {
    if (!this.previewTitle) {
      await this.validateAndPreview();
      if (this.errorMsg) return;
    }

    try {
      const info = await RssService.getInstance().fetchFeedInfo(this.url.trim());
      const db = DatabaseHelper.getInstance();
      const feedId = await db.insertFeed({
        title: info.title || this.url,
        url: this.url.trim(),
        siteUrl: info.siteUrl,
        iconUrl: info.iconUrl,
        description: info.description,
        groupId: this.selectedGroupId,
        lastUpdated: 0
      });

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

      router.back();
    } catch (e) {
      const err = e as Error;
      this.errorMsg = `添加失败：${err?.message || String(e)}`;
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
              .onSubmit(() => this.validateAndPreview())
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

          // 验证按钮
          Button(this.isValidating ? '验证中...' : '验证链接')
            .width('100%')
            .fontSize(15)
            .enabled(!this.isValidating)
            .onClick(() => this.validateAndPreview())

          // 预览
          if (this.previewTitle) {
            Column({ space: 8 }) {
              Row() {
                Image($r('app.media.ic_check'))
                  .width(16).height(16)
                  .fillColor(Color.Green)
                Text('验证成功').fontSize(13).fontColor(Color.Green).margin({ left: 4 })
              }
              Text(this.previewTitle)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('sys.color.ohos_id_color_text_primary'))
                .alignSelf(ItemAlign.Start)
              if (this.previewDesc) {
                Text(this.previewDesc)
                  .fontSize(13)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                  .alignSelf(ItemAlign.Start)
                  .maxLines(3)
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor($r('sys.color.ohos_id_color_background'))
            .borderRadius(12)
          }

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

          // 确认按钮
          Button('添加订阅源')
            .width('100%')
            .fontSize(15)
            .fontColor(Color.White)
            .enabled(this.previewTitle !== '')
            .opacity(this.previewTitle ? 1.0 : 0.5)
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
