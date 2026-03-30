// AI 设置页面 - 多提供商 API 配置
import { AIService } from '../service/AIService';
import { SettingsService } from '../service/SettingsService';
import { Constants } from '../constants/Constants';

interface SelectOption {
  value: ResourceStr;
}

@Entry
@Component
struct AISettingsPage {
  @State providerIndex: number = 0;
  @State apiKey: string = '';
  @State baseUrl: string = '';
  @State modelName: string = '';
  @State isSaving: boolean = false;
  @State briefingEnabled: boolean = true;
  @State aiSortEnabled: boolean = false;
  @State briefingCountIndex: number = 1; // 默认 5 篇（索引 1）
  @State autoBriefingEnabled: boolean = true;
  @State loaded: boolean = false;

  aboutToAppear() {
    this.loadSettings();
  }

  async loadSettings() {
    try {
      this.apiKey = await SettingsService.getInstance().getAIApiKey();
      this.briefingEnabled = await SettingsService.getInstance().getBriefingEnabled();
      this.aiSortEnabled = await SettingsService.getInstance().getAISortEnabled();

      const briefingCount = await SettingsService.getInstance().getBriefingCount();
      const bcIdx = Constants.BRIEFING_COUNT_OPTIONS.indexOf(briefingCount);
      this.briefingCountIndex = bcIdx >= 0 ? bcIdx : 1;

      const provider = await SettingsService.getInstance().getAIProvider();
      const idx = Constants.AI_PROVIDER_KEYS.indexOf(provider);
      this.providerIndex = idx >= 0 ? idx : 0;

      this.baseUrl = await SettingsService.getInstance().getAIBaseUrl();
      this.modelName = await SettingsService.getInstance().getAIModelName();
    } catch (e) {
      console.error('AISettingsPage', `loadSettings: ${e}`);
    } finally {
      this.loaded = true;
    }
  }

  private onProviderSelect(index: number) {
    this.providerIndex = index;
    // 选择预设提供商时，自动填充默认模型（不覆盖用户已手动修改的 Base URL）
    if (index < Constants.AI_PROVIDER_DEFAULT_MODELS.length) {
      this.modelName = Constants.AI_PROVIDER_DEFAULT_MODELS[index];
    }
    // 选择非自定义提供商时，清空 baseUrl 以使用预设
    if (index !== Constants.AI_PROVIDER_KEYS.indexOf('custom')) {
      this.baseUrl = '';
    }
  }

  async saveAll() {
    if (this.isSaving) return;
    this.isSaving = true;
    try {
      const provider = Constants.AI_PROVIDER_KEYS[this.providerIndex];
      await SettingsService.getInstance().setAIApiKey(this.apiKey.trim());
      await SettingsService.getInstance().setAIProvider(provider);
      await SettingsService.getInstance().setAIBaseUrl(this.baseUrl.trim());
      await SettingsService.getInstance().setAIModelName(this.modelName.trim());

      // 同步到 AIService 运行时
      const ai = AIService.getInstance();
      ai.setApiKey(this.apiKey.trim());
      ai.setProvider(provider);
      ai.setBaseUrl(this.baseUrl.trim());
      ai.setModel(this.modelName.trim());

      this.getUIContext().getPromptAction().showToast({ message: '已保存' });
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

        Text('AI 设置')
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

      if (!this.loaded) {
        Column() {
          LoadingProgress().width(40).height(40)
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 16 }) {

            // ===== AI 提供商 =====
            Text('AI 提供商').fontSize(13)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%').padding({ left: 4, bottom: 4 })

            Column() {
              Row() {
                Text('提供商')
                  .fontSize(15)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .layoutWeight(1)
                Select(Constants.AI_PROVIDER_LABELS.map((l: string): SelectOption => ({ value: l })))
                  .selected(this.providerIndex)
                  .value(Constants.AI_PROVIDER_LABELS[this.providerIndex])
                  .onSelect((index: number) => {
                    this.onProviderSelect(index);
                  })
                  .font({ size: 14 })
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })
            }
            .backgroundColor($r('sys.color.ohos_id_color_background'))
            .borderRadius(12)

            // ===== 连接设置 =====
            Text('连接设置').fontSize(13)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%').padding({ left: 4, bottom: 4 })

            Column() {
              // API Key
              Row() {
                Text('API Key')
                  .fontSize(15)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .layoutWeight(1)
                if (AIService.getInstance().hasApiKey()) {
                  Text('已配置')
                    .fontSize(13)
                    .fontColor($r('sys.color.ohos_id_color_activated'))
                } else {
                  Text('未配置')
                    .fontSize(13)
                    .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                }
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              Row() {
                TextInput({ placeholder: '粘贴你的 API Key', text: this.apiKey })
                  .layoutWeight(1)
                  .fontSize(14)
                  .type(InputType.Password)
                  .maxLength(300)
                  .onChange((val: string) => {
                    this.apiKey = val;
                  })
              }
              .width('100%').height(56).padding({ left: 16, right: 16 })

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              // Base URL
              Row() {
                Text('Base URL')
                  .fontSize(15)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .width(80)
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              Row() {
                TextInput({
                  placeholder: this.getBaseUrlPlaceholder(),
                  text: this.baseUrl
                })
                  .layoutWeight(1)
                  .fontSize(14)
                  .maxLength(300)
                  .onChange((val: string) => {
                    this.baseUrl = val;
                  })
              }
              .width('100%').height(56).padding({ left: 16, right: 16 })

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              // 模型名称
              Row() {
                Text('模型名称')
                  .fontSize(15)
                  .fontColor($r('sys.color.ohos_id_color_text_primary'))
                  .width(80)
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              Row() {
                TextInput({
                  placeholder: this.getModelPlaceholder(),
                  text: this.modelName
                })
                  .layoutWeight(1)
                  .fontSize(14)
                  .maxLength(100)
                  .onChange((val: string) => {
                    this.modelName = val;
                  })
              }
              .width('100%').height(56).padding({ left: 16, right: 16 })
            }
            .backgroundColor($r('sys.color.ohos_id_color_background'))
            .borderRadius(12)

            // 提示信息
            Text(this.getProviderTip())
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
              .width('100%')
              .padding({ left: 4 })

            // 保存按钮
            Button(this.isSaving ? '保存中...' : '保存设置')
              .width('100%')
              .height(44)
              .fontSize(15)
              .fontColor(Color.White)
              .backgroundColor($r('sys.color.ohos_id_color_activated'))
              .borderRadius(12)
              .enabled(!this.isSaving)
              .onClick(() => {
                this.saveAll();
              })

            // ===== AI 功能开关 =====
            Text('AI 功能').fontSize(13)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%').padding({ left: 4, bottom: 4 })

            Column() {
              Row() {
                Column({ space: 2 }) {
                  Text('智能排序').fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary'))
                  Text('根据阅读偏好对文章排序').fontSize(12)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Start)
                Toggle({ type: ToggleType.Switch, isOn: this.aiSortEnabled })
                  .onChange((val: boolean) => {
                    this.aiSortEnabled = val;
                    SettingsService.getInstance().setAISortEnabled(val);
                  })
              }
              .width('100%').height(60).padding({ left: 16, right: 16 })

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              Row() {
                Column({ space: 2 }) {
                  Text('每日简报').fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary'))
                  Text('首页显示 AI 生成的今日阅读推荐').fontSize(12)
                    .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Start)
                Toggle({ type: ToggleType.Switch, isOn: this.briefingEnabled })
                  .onChange((val: boolean) => {
                    this.briefingEnabled = val;
                    SettingsService.getInstance().setBriefingEnabled(val);
                  })
              }
              .width('100%').height(60).padding({ left: 16, right: 16 })

              Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })

              Row() {
                Text('简报推荐数量')
                  .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary')).layoutWeight(1)
                Select(Constants.BRIEFING_COUNT_LABELS.map((l: string): SelectOption => ({ value: l })))
                  .selected(this.briefingCountIndex)
                  .value(Constants.BRIEFING_COUNT_LABELS[this.briefingCountIndex])
                  .onSelect((index: number) => {
                    this.briefingCountIndex = index;
                    SettingsService.getInstance().setBriefingCount(Constants.BRIEFING_COUNT_OPTIONS[index]);
                  })
                  .font({ size: 14 })
              }
              .width('100%').height(52).padding({ left: 16, right: 16 })
            }
            .backgroundColor($r('sys.color.ohos_id_color_background'))
            .borderRadius(12)

          }
          .padding(16)
        }
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  private getBaseUrlPlaceholder(): string {
    const idx = this.providerIndex;
    if (idx < Constants.AI_PROVIDER_URLS.length) {
      const preset = Constants.AI_PROVIDER_URLS[idx];
      if (preset.length > 0 && idx !== 0) {
        return `留空使用预设：${preset}`;
      }
    }
    return '例如 http://localhost:11434/v1';
  }

  private getModelPlaceholder(): string {
    const idx = this.providerIndex;
    if (idx < Constants.AI_PROVIDER_DEFAULT_MODELS.length) {
      const defaultModel = Constants.AI_PROVIDER_DEFAULT_MODELS[idx];
      if (defaultModel.length > 0) {
        return `留空使用默认：${defaultModel}`;
      }
    }
    return '输入模型名称';
  }

  private getProviderTip(): string {
    const idx = this.providerIndex;
    const keys = Constants.AI_PROVIDER_KEYS;
    if (idx < keys.length) {
      const key = keys[idx];
      if (key === 'qwen') {
        return '前往 dashscope.aliyun.com 申请 API Key（有免费额度）';
      } else if (key === 'openai') {
        return '前往 platform.openai.com 申请 API Key';
      } else if (key === 'deepseek') {
        return '前往 platform.deepseek.com 申请 API Key（价格低廉）';
      } else if (key === 'groq') {
        return '前往 console.groq.com 申请 API Key（免费，速度极快）';
      } else if (key === 'custom') {
        return '填写兼容 OpenAI 接口协议的自定义端点，如 Ollama 或代理服务';
      }
    }
    return '';
  }
}
