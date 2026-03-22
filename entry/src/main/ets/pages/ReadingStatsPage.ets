// 阅读统计页面
import { MemoryService } from '../service/MemoryService';
import { MemoryFileHelper } from '../service/MemoryFileHelper';
import { ProfileService } from '../service/ProfileService';
import { DailyStats } from '../model/Models';
import { Constants } from '../constants/Constants';
import { DateUtil } from '../utils/DateUtil';

@Entry
@Component
struct ReadingStatsPage {
  @State isLoading: boolean = true;
  @State totalDays: number = 0;
  @State totalArticles: number = 0;
  @State totalStars: number = 0;
  @State totalSearches: number = 0;
  @State avgDailyRead: number = 0;
  @State avgReadDuration: number = 0;
  @State recentStats: DailyStats[] = [];

  aboutToAppear() {
    this.loadStats();
  }

  async loadStats() {
    this.isLoading = true;
    try {
      const memSvc = MemoryService.getInstance();
      if (!memSvc.isReady()) {
        return;
      }
      const filesDir = memSvc.getFilesDir();
      const dailyDir = `${filesDir}/${Constants.MEMORY_DAILY_DIR}`;
      const files = await MemoryFileHelper.listFiles(dailyDir);

      const today = DateUtil.today();
      const cutoff = DateUtil.daysAgo(30);
      const statsList: DailyStats[] = [];
      const svc = ProfileService.getInstance();

      for (const file of files) {
        if (!file.endsWith('.md')) continue;
        const dateStr = file.replace('.md', '');
        if (dateStr < cutoff || dateStr > today) continue;
        const content = await MemoryFileHelper.readMarkdown(`${dailyDir}/${file}`);
        if (content.trim()) {
          statsList.push(svc.parseDailyLog(content, dateStr));
        }
      }

      // 按日期降序排列，取最近7天显示
      statsList.sort((a, b) => b.date.localeCompare(a.date));
      this.recentStats = statsList.slice(0, 7);

      // 计算汇总数据
      const activeDays = statsList.filter(d => d.readCount > 0 || d.starCount > 0);
      this.totalDays = activeDays.length;
      this.totalArticles = statsList.reduce((s, d) => s + d.readCount, 0);
      this.totalStars = statsList.reduce((s, d) => s + d.starCount, 0);
      this.totalSearches = statsList.reduce((s, d) => s + d.searchCount, 0);
      this.avgDailyRead = this.totalDays > 0 ? Math.round(this.totalArticles / this.totalDays) : 0;
      const withDuration = statsList.filter(d => d.avgReadDuration > 0);
      this.avgReadDuration = withDuration.length > 0
        ? Math.round(withDuration.reduce((s, d) => s + d.avgReadDuration, 0) / withDuration.length)
        : 0;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('ReadingStatsPage', `loadStats failed: ${msg}`);
    } finally {
      this.isLoading = false;
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

        Text('阅读统计')
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

      if (this.isLoading) {
        Column() {
          LoadingProgress().width(40).height(40)
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column({ space: 16 }) {
            // 总览卡片
            Text('近 30 天总览').fontSize(13)
              .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              .width('100%').padding({ left: 4, bottom: 4 })

            Column() {
              Row({ space: 0 }) {
                this.statItem('阅读天数', `${this.totalDays}天`)
                this.statItem('阅读文章', `${this.totalArticles}篇`)
              }
              .width('100%')

              Divider().color($r('sys.color.ohos_id_color_list_separator'))

              Row({ space: 0 }) {
                this.statItem('收藏文章', `${this.totalStars}篇`)
                this.statItem('搜索次数', `${this.totalSearches}次`)
              }
              .width('100%')

              Divider().color($r('sys.color.ohos_id_color_list_separator'))

              Row({ space: 0 }) {
                this.statItem('日均阅读', `${this.avgDailyRead}篇`)
                this.statItem('均阅读时长', DateUtil.formatDuration(this.avgReadDuration))
              }
              .width('100%')
            }
            .backgroundColor($r('sys.color.ohos_id_color_background'))
            .borderRadius(12)

            // 最近7天明细
            if (this.recentStats.length > 0) {
              Text('最近 7 天').fontSize(13)
                .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                .width('100%').padding({ left: 4, bottom: 4 })

              Column() {
                ForEach(this.recentStats, (stat: DailyStats, index: number) => {
                  Row() {
                    Text(stat.date)
                      .fontSize(14)
                      .fontColor($r('sys.color.ohos_id_color_text_primary'))
                      .layoutWeight(1)
                    Text(`${stat.readCount}篇`)
                      .fontSize(14)
                      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                      .margin({ right: 16 })
                    Text(stat.starCount > 0 ? `★${stat.starCount}` : '')
                      .fontSize(13)
                      .fontColor(Color.Orange)
                      .width(40)
                      .textAlign(TextAlign.End)
                  }
                  .width('100%').height(48).padding({ left: 16, right: 16 })

                  if (index < this.recentStats.length - 1) {
                    Divider().color($r('sys.color.ohos_id_color_list_separator')).margin({ left: 16 })
                  }
                }, (s: DailyStats) => s.date)
              }
              .backgroundColor($r('sys.color.ohos_id_color_background'))
              .borderRadius(12)
            } else {
              Column({ space: 12 }) {
                Text('暂无阅读数据')
                  .fontSize(15)
                  .fontColor($r('sys.color.ohos_id_color_text_secondary'))
              }
              .width('100%').padding(40).justifyContent(FlexAlign.Center)
            }
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

  @Builder
  statItem(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.ohos_id_color_text_primary'))
      Text(label)
        .fontSize(12)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
    }
    .layoutWeight(1)
    .padding({ top: 16, bottom: 16 })
    .alignItems(HorizontalAlign.Center)
  }
}
