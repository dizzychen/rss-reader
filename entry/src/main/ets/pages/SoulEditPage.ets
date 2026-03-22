// 灵魂档案编辑页面
import { MemoryService } from '../service/MemoryService';

@Entry
@Component
struct SoulEditPage {
  @State content: string = '';
  @State isLoading: boolean = true;
  @State isSaving: boolean = false;

  // 默认模板（备用方案，正常会从 rawfile 加载）
  private readonly defaultTemplate: string =
    `# 我的阅读灵魂档案

## 关于我
<!-- 简单描述你的职业、背景、身份 -->

## 阅读目的
<!-- 你为什么阅读？想从阅读中获得什么？ -->
- 

## 兴趣领域
<!-- 你最感兴趣的话题、领域、学科 -->
- 

## 不感兴趣的内容
<!-- 你希望过滤掉哪些内容类型 -->
- 

## 阅读哲学
<!-- 你的阅读观、价值观 -->

## 当前关注
<!-- 最近在研究或思考的问题 -->
- 
`;

  aboutToAppear() {
    this.loadSoul();
  }

  async loadSoul() {
    this.isLoading = true;
    try {
      const soul = await MemoryService.getInstance().getSoul();
      this.content = soul.trim() || this.defaultTemplate;
    } catch (e) {
      this.content = this.defaultTemplate;
    } finally {
      this.isLoading = false;
    }
  }

  async saveSoul() {
    if (this.isSaving) return;
    this.isSaving = true;
    try {
      await MemoryService.getInstance().updateSoul(this.content);
      this.getUIContext().getPromptAction().showToast({ message: '保存成功' });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.getUIContext().getPromptAction().showToast({ message: `保存失败：${msg}` });
    } finally {
      this.isSaving = false;
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

        Text('我的阅读档案')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
          .margin({ left: 8 })
          .layoutWeight(1)

        if (this.isSaving) {
          LoadingProgress().width(20).height(20).margin({ right: 8 })
        } else {
          Button('保存')
            .fontSize(14)
            .fontColor(Color.White)
            .backgroundColor($r('sys.color.ohos_id_color_activated'))
            .height(32)
            .borderRadius(16)
            .onClick(() => this.saveSoul())
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
      } else {
        Column({ space: 8 }) {
          Text('在此记录你的阅读偏好、兴趣领域和阅读目的，AI 将基于此为你提供个性化推荐。')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width('100%')
            .padding({ left: 16, right: 16, top: 8 })

          TextArea({ text: this.content, placeholder: '编辑你的阅读档案...' })
            .layoutWeight(1)
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 16 })
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .backgroundColor(Color.Transparent)
            .onChange((val: string) => {
              this.content = val;
            })
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
  }
}
