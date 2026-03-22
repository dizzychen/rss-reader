// 阅读画像查看页面
import { MemoryService } from '../service/MemoryService';
import { ProfileService } from '../service/ProfileService';

@Entry
@Component
struct ProfileViewPage {
  @State content: string = '';
  @State isLoading: boolean = true;
  @State isRegenerating: boolean = false;

  aboutToAppear() {
    this.loadProfile();
  }

  async loadProfile() {
    this.isLoading = true;
    try {
      this.content = await MemoryService.getInstance().getProfile();
    } catch (e) {
      this.content = '';
    } finally {
      this.isLoading = false;
    }
  }

  async regenerate() {
    if (this.isRegenerating) return;
    this.isRegenerating = true;
    try {
      await ProfileService.getInstance().regenerate();
      this.content = await MemoryService.getInstance().getProfile();
      this.getUIContext().getPromptAction().showToast({ message: '画像已更新' });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.getUIContext().getPromptAction().showToast({ message: `更新失败：${msg}` });
    } finally {
      this.isRegenerating = false;
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

        Text('阅读画像')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 8 })
          .layoutWeight(1)

        if (this.isRegenerating) {
          LoadingProgress().width(20).height(20).margin({ right: 8 })
        } else {
          Button('重新生成')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_activated'))
            .backgroundColor(Color.Transparent)
            .height(32)
            .onClick(() => this.regenerate())
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 16 })
      .backgroundColor($r('sys.color.ohos_id_color_background'))

      Divider().color($r('sys.color.ohos_id_color_list_separator'))

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(40).height(40)
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (!this.content.trim()) {
        Column({ space: 16 }) {
          Text('暂无画像数据').fontSize(16).fontColor($r('sys.color.ohos_id_color_text_secondary'))
          Text('阅读更多文章后，点击「重新生成」生成你的阅读画像')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
            .textAlign(TextAlign.Center)
            .padding({ left: 32, right: 32 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Text(this.content)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 40 })
            .lineHeight(24)
            .wordBreak(WordBreak.BREAK_WORD)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }
}
