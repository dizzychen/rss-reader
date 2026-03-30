// 阅读画像查看页面
import { MemoryService } from '../service/MemoryService';
import { ProfileService } from '../service/ProfileService';
import { MarkdownUtil } from '../utils/MarkdownUtil';

@Component
struct SectionCardView {
  label: string = '';
  @BuilderParam content: () => void;

  build() {
    Column({ space: 0 }) {
      Text(this.label)
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .width('100%')
        .padding({ left: 4, bottom: 8 })

      Column() {
        this.content()
      }
      .width('100%')
      .backgroundColor($r('sys.color.ohos_id_color_background'))
      .borderRadius(12)
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    }
    .width('100%')
  }
}

/** 画像解析后的结构化数据 */
interface ProfileData {
  generatedAt: string;
  overviewRows: TableRow[];
  feedWeights: WeightRow[];
  topicWeights: WeightRow[];
  searchKeywords: string;
  readingStyle: string;
  trend: string;
  dislikePatterns: string;
  lessonsPreview: string;     // LESSONS.md 精简预览
  recHitRate: string;         // 推荐命中率展示文本
}

interface TableRow {
  label: string;
  value: string;
}

interface WeightRow {
  name: string;
  weight: number;
  date: string;
}

@Entry
@Component
struct ProfileViewPage {
  @State content: string = '';
  @State profileData: ProfileData | null = null;
  @State isLoading: boolean = true;
  @State isRegenerating: boolean = false;

  aboutToAppear() {
    this.loadProfile();
  }

  async loadProfile() {
    this.isLoading = true;
    try {
      this.content = await MemoryService.getInstance().getProfile();
      const lessons = await MemoryService.getInstance().getLessons();
      if (this.content.trim()) {
        this.profileData = this.parseProfileMarkdown(this.content);
        // 解析 LESSONS 预览
        if (lessons.trim()) {
          this.profileData.lessonsPreview = this.extractLessonsPreview(lessons);
          this.profileData.recHitRate = this.extractRecHitRate(lessons);
        }
      }
    } catch (e) {
      this.content = '';
      this.profileData = null;
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
      if (this.content.trim()) {
        this.profileData = this.parseProfileMarkdown(this.content);
      }
      this.getUIContext().getPromptAction().showToast({ message: '画像已更新' });
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      this.getUIContext().getPromptAction().showToast({ message: `更新失败：${msg}` });
    } finally {
      this.isRegenerating = false;
    }
  }

  /**
   * 解析画像 Markdown 为结构化数据
   */
  parseProfileMarkdown(md: string): ProfileData {
    const data: ProfileData = {
      generatedAt: '',
      overviewRows: [],
      feedWeights: [],
      topicWeights: [],
      searchKeywords: '',
      readingStyle: '',
      trend: '',
      dislikePatterns: '',
      lessonsPreview: '',
      recHitRate: ''
    };

    // 提取生成时间
    const timeMatch = md.match(/生成时间[：:]\s*(.+)/);
    if (timeMatch) {
      data.generatedAt = timeMatch[1].trim();
    }

    // 提取阅读概览表格
    const overviewSection = MarkdownUtil.extractSection(md, '## 阅读概览');
    if (overviewSection) {
      data.overviewRows = this.parseTableRows(overviewSection);
    }

    // 提取订阅源偏好
    const feedSection = MarkdownUtil.extractSection(md, '## 订阅源偏好');
    if (feedSection) {
      data.feedWeights = this.parseWeightRows(feedSection);
    }

    // 提取话题偏好
    const topicSection = MarkdownUtil.extractSection(md, '## 话题偏好');
    if (topicSection) {
      data.topicWeights = this.parseWeightRows(topicSection);
    }

    // 提取搜索兴趣
    const searchSection = MarkdownUtil.extractSection(md, '## 搜索兴趣');
    if (searchSection.trim()) {
      const kwMatch = searchSection.match(/近期高频搜索[：:]\s*(.+)/);
      if (kwMatch) {
        data.searchKeywords = kwMatch[1].trim();
      }
    }

    // 提取 AI 洞察
    const aiSection = MarkdownUtil.extractSection(md, '## AI 洞察');
    if (aiSection.trim()) {
      const styleMatch = aiSection.match(/阅读风格[：:]\s*(.+)/);
      if (styleMatch) data.readingStyle = styleMatch[1].trim();
      const trendMatch = aiSection.match(/兴趣变化[：:]\s*(.+)/);
      if (trendMatch) data.trend = trendMatch[1].trim();
      const dislikeMatch = aiSection.match(/不感兴趣的内容[：:]\s*(.+)/);
      if (dislikeMatch) data.dislikePatterns = dislikeMatch[1].trim();
    }

    return data;
  }

  /**
   * 解析 Markdown 表格为 label-value 行
   */
  parseTableRows(section: string): TableRow[] {
    const rows: TableRow[] = [];
    const lines = section.split('\n');
    for (const line of lines) {
      if (!line.startsWith('|') || line.startsWith('| 指标') || line.startsWith('|---')) {
        continue;
      }
      const parts = line.split('|').map(s => s.trim()).filter(s => s.length > 0);
      if (parts.length >= 2) {
        rows.push({ label: parts[0], value: parts[1] });
      }
    }
    return rows;
  }

  /**
   * 解析兴趣权重表格
   */
  parseWeightRows(section: string): WeightRow[] {
    const rows: WeightRow[] = [];
    const lines = section.split('\n');
    for (const line of lines) {
      if (!line.startsWith('|') || line.startsWith('| 名称') || line.startsWith('|---')) {
        continue;
      }
      const parts = line.split('|').map(s => s.trim()).filter(s => s.length > 0);
      if (parts.length >= 3) {
        const name = parts[0];
        const weightParts = parts[1].split(' ');
        const weightStr = weightParts[weightParts.length - 1];
        const weight = parseFloat(weightStr);
        const date = parts[2];
        if (name && !isNaN(weight)) {
          rows.push({ name, weight, date });
        }
      }
    }
    return rows;
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
      } else if (!this.content.trim() || this.profileData === null) {
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
          Column({ space: 16 }) {
            // 生成时间
            if (this.profileData.generatedAt) {
              Text(`生成时间：${this.profileData.generatedAt}`)
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
                .width('100%')
            }

            // 阅读概览卡片
            if (this.profileData.overviewRows.length > 0) {
              SectionCardView({ label: '阅读概览' }) {
                this.overviewCard()
              }
            }

            // 订阅源偏好
            if (this.profileData.feedWeights.length > 0) {
              SectionCardView({ label: '订阅源偏好' }) {
                this.weightList(this.profileData!.feedWeights)
              }
            }

            // 话题偏好
            if (this.profileData.topicWeights.length > 0) {
              SectionCardView({ label: '话题偏好' }) {
                this.weightList(this.profileData!.topicWeights)
              }
            }

            // 搜索兴趣
            if (this.profileData.searchKeywords) {
              SectionCardView({ label: '搜索兴趣' }) {
                this.keywordsCard()
              }
            }

            // AI 洞察
            if (this.profileData.readingStyle || this.profileData.trend || this.profileData.dislikePatterns) {
              SectionCardView({ label: 'AI 洞察' }) {
                this.aiInsightCard()
              }
            }

            // 推荐命中率
            if (this.profileData.recHitRate) {
              SectionCardView({ label: '推荐效果' }) {
                this.recHitRateCard()
              }
            }

            // 经验教训
            if (this.profileData.lessonsPreview) {
              SectionCardView({ label: '经验教训' }) {
                this.lessonsCard()
              }
            }
          }
          .padding({ left: 16, right: 16, top: 12, bottom: 40 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.ohos_id_color_sub_background'))
  }

  @Builder
  overviewCard() {
    ForEach(this.profileData!.overviewRows, (row: TableRow, index: number) => {
      Row() {
        Text(row.label)
          .fontSize(14)
          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
          .layoutWeight(1)
        Text(row.value)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.ohos_id_color_text_primary'))
      }
      .width('100%')
      .height(40)

      if (index < this.profileData!.overviewRows.length - 1) {
        Divider().color($r('sys.color.ohos_id_color_list_separator'))
      }
    }, (row: TableRow, index: number) => `overview_${index}`)
  }

  @Builder
  weightList(weights: WeightRow[]) {
    ForEach(weights, (row: WeightRow, index: number) => {
      Column({ space: 4 }) {
        Row() {
          Text(row.name)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .layoutWeight(1)
          Text(row.weight.toFixed(3))
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
        .width('100%')

        // 进度条模拟权重
        Row() {
          Row()
            .width(`${Math.round(row.weight * 100)}%`)
            .height(6)
            .borderRadius(3)
            .backgroundColor($r('sys.color.ohos_id_color_activated'))
        }
        .width('100%')
        .height(6)
        .borderRadius(3)
        .backgroundColor('#1A000000')
      }
      .width('100%')
      .padding({ top: 8, bottom: 8 })

      if (index < weights.length - 1) {
        Divider().color($r('sys.color.ohos_id_color_list_separator'))
      }
    }, (row: WeightRow, index: number) => `weight_${index}`)
  }

  @Builder
  keywordsCard() {
    Text(this.profileData!.searchKeywords)
      .fontSize(14)
      .fontColor($r('sys.color.ohos_id_color_text_primary'))
      .width('100%')
      .lineHeight(22)
  }

  @Builder
  aiInsightCard() {
    Column({ space: 12 }) {
      if (this.profileData!.readingStyle) {
        Row({ space: 8 }) {
          Text('阅读风格')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width(90)
          Text(this.profileData!.readingStyle)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .layoutWeight(1)
            .lineHeight(22)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      if (this.profileData!.trend) {
        Row({ space: 8 }) {
          Text('兴趣变化')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width(90)
          Text(this.profileData!.trend)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .layoutWeight(1)
            .lineHeight(22)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
      if (this.profileData!.dislikePatterns) {
        Row({ space: 8 }) {
          Text('不感兴趣')
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
            .width(90)
          Text(this.profileData!.dislikePatterns)
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_primary'))
            .layoutWeight(1)
            .lineHeight(22)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      }
    }
    .width('100%')
  }

  @Builder
  recHitRateCard() {
    Column({ space: 8 }) {
      Text(this.profileData!.recHitRate)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_activated'))
      Text('最近推荐命中率')
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  lessonsCard() {
    Text(this.profileData!.lessonsPreview)
      .fontSize(13)
      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      .width('100%')
      .lineHeight(20)
  }

  /**
   * 从 LESSONS.md 中提取精简预览（提取所有三级标题）
   */
  private extractLessonsPreview(lessons: string): string {
    const lines = lessons.split('\n');
    const previews: string[] = [];
    let currentSection = '';
    for (const line of lines) {
      if (line.startsWith('## ') && !line.includes('推荐效果追踪')) {
        currentSection = line.replace('## ', '').trim();
      } else if (line.startsWith('### ')) {
        const title = line.replace('### ', '').replace(/\[|\]/g, '').trim();
        if (title && currentSection) {
          previews.push(`${currentSection}: ${title}`);
        }
      }
    }
    return previews.length > 0 ? previews.join('\n') : '';
  }

  /**
   * 从 LESSONS.md 推荐效果追踪表中提取最新命中率
   */
  private extractRecHitRate(lessons: string): string {
    const lines = lessons.split('\n');
    let lastDataRow = '';
    let inTrackingTable = false;
    for (const line of lines) {
      if (line.includes('推荐效果追踪')) {
        inTrackingTable = true;
        continue;
      }
      if (inTrackingTable && line.startsWith('| ') && !line.startsWith('| 日期') && !line.startsWith('|---')) {
        lastDataRow = line;
      }
      if (inTrackingTable && line.startsWith('## ') && !line.includes('推荐效果追踪')) {
        break;
      }
    }
    if (!lastDataRow) {
      return '';
    }
    const parts = lastDataRow.split('|').map(s => s.trim()).filter(s => s.length > 0);
    if (parts.length >= 2) {
      return parts[1]; // 命中率列
    }
    return '';
  }
}
