// 通用文章列表项组件
import { Article } from '../model/Models';
import { RssService } from '../service/RssService';
import { Constants } from '../constants/Constants';

@Component
export struct ArticleItemComponent {
  @Prop article: Article = {
    feedId: 0, guid: '', title: '', summary: '', content: '',
    url: '', author: '', publishedAt: 0, isRead: 0, isStarred: 0, coverImage: ''
  };
  @Prop recommendReason: string = '';
  @State coverLoadFailed: boolean = false;
  onTap: () => void = () => {};
  onStarToggle: () => void = () => {};

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 主内容区
      Row({ space: 12 }) {
        // 文章信息
        Column({ space: 6 }) {
          Text(RssService.getInstance().convertEmojiShortcodes(this.article.title))
            .fontSize(15)
            .fontWeight(this.article.isRead === 1 ? FontWeight.Normal : FontWeight.Medium)
            .fontColor(this.article.isRead === 1
              ? $r('sys.color.ohos_id_color_text_tertiary')
              : $r('sys.color.ohos_id_color_text_primary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .lineHeight(20)
            .fontFamily('HarmonyOS Sans, Apple Color Emoji, Segoe UI Emoji, Noto Color Emoji')

          if (this.article.summary) {
            Text(this.article.summary)
              .fontSize(13)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .opacity(this.article.isRead === 1 ? 0.6 : 1)
          }

          Row({ space: 6 }) {
            if (this.article.feedTitle) {
              Text(this.article.feedTitle)
                .fontSize(12)
                .fontColor($r('sys.color.ohos_id_color_activated'))
                .maxLines(1)
                .constraintSize({ maxWidth: '50%' })
                .opacity(this.article.isRead === 1 ? 0.6 : 1)
            }
            Blank()
            Text(RssService.getInstance().formatDate(this.article.publishedAt))
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
          }
          .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 封面图（加载失败时隐藏，不显示占位符）
        if (this.article.coverImage && !this.coverLoadFailed) {
          Image(this.article.coverImage)
            .width(80)
            .height(80)
            .borderRadius(8)
            .objectFit(ImageFit.Contain)
            .opacity(this.article.isRead === 1 ? 0.5 : 1)
            .onError(() => {
              this.coverLoadFailed = true;
            })
        }

      }
      .width('100%')
      .padding(16)

      // 推荐理由角标（绝对定位，不影响布局流）
      if (this.recommendReason) {
        Text(this.recommendReason)
          .fontSize(9)
          .fontColor(Color.White)
          .backgroundColor(Constants.COLOR_PRIMARY)
          .borderRadius({ topLeft: 0, bottomRight: 8 })
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
      }

    }
    .width('100%')
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .onClick(() => this.onTap())
  }
}
