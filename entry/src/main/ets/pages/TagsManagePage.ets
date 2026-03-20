// 标签管理页
import { router } from '@kit.ArkUI';
import { Tag } from '../model/Models';
import { DatabaseHelper } from '../database/DatabaseHelper';

@Entry
@Component
struct TagsManagePage {
  @State tags: Tag[] = [];
  @State newTagName: string = '';

  aboutToAppear() {
    this.loadTags();
  }

  async loadTags() {
    this.tags = await DatabaseHelper.getInstance().getAllTags();
  }

  async addTag() {
    const name = this.newTagName.trim();
    if (!name) return;
    await DatabaseHelper.getInstance().insertTag(name);
    this.newTagName = '';
    await this.loadTags();
  }

  async deleteTag(tag: Tag) {
    await DatabaseHelper.getInstance().deleteTag(tag.id!);
    await this.loadTags();
  }

  build() {
    Column() {
      Row() {
        Button({ type: ButtonType.Circle }) {
          SymbolGlyph($r('sys.symbol.arrow_left'))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_text_primary')])
        }
        .width(36).height(36).backgroundColor(Color.Transparent)
        .onClick(() => this.getUIContext().getRouter().back())

        Text('标签管理')
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

      // 添加标签
      Row({ space: 8 }) {
        TextInput({ placeholder: '新标签名称...', text: this.newTagName })
          .layoutWeight(1)
          .onChange(val => this.newTagName = val)
          .onSubmit(() => this.addTag())
        Button('添加')
          .fontSize(14)
          .onClick(() => this.addTag())
      }
      .width('100%')
      .padding(16)
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      if (this.tags.length === 0) {
        Column() {
          Text('暂无标签').fontSize(15).fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.tags, (tag: Tag) => {
            ListItem() {
              Row() {
                Text(`# ${tag.name}`)
                  .fontSize(15)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .layoutWeight(1)
                Button({ type: ButtonType.Circle }) {
                  SymbolGlyph($r('sys.symbol.trash'))
                    .fontSize(18)
                    .fontColor([Color.Red])
                }
                .width(32).height(32).backgroundColor(Color.Transparent)
                .onClick(() => {
                  this.getUIContext().showAlertDialog({
                    title: '删除标签',
                    message: `删除标签「${tag.name}」？文章关联也会解除。`,
                    primaryButton: {
                      value: '删除',
                      fontColor: Color.Red,
                      action: () => this.deleteTag(tag)
                    },
                    secondaryButton: { value: '取消', action: () => {} }
                  });
                })
              }
              .width('100%')
              .height(52)
              .padding({ left: 16, right: 16 })
              .backgroundColor($r('sys.color.ohos_id_color_background'))
            }
          }, (t: Tag) => `${t.id}`)
        }
        .divider({ strokeWidth: 0.5, color: $r('sys.color.ohos_id_color_list_separator') })
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
