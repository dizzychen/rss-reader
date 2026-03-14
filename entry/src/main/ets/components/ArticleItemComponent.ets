// 通用文章列表项组件
import { Article } from '../model/Models';
import { RssService } from '../service/RssService';

@Component
export struct ArticleItemComponent {
  article: Article = {} as Article;
  onTap: () => void = () => {};
  onStarToggle: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      // 封面图
      if (this.article.coverImage) {
        Image(this.article.coverImage)
          .width(80)
          .height(80)
          .borderRadius(8)
          .objectFit(ImageFit.Cover)
          .backgroundColor($r('sys.color.ohos_id_color_foreground_contrary'))
      }

      // 文章信息
      Column({ space: 6 }) {
        Text(this.article.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.article.isRead === 1
            ? $r('sys.color.ohos_id_color_text_secondary')
            : $r('sys.color.ohos_id_color_text_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(20)

        if (this.article.summary) {
          Text(this.article.summary)
            .fontSize(13)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }

        Row() {
          if (this.article.feedTitle) {
            Text(this.article.feedTitle)
              .fontSize(12)
              .fontColor($r('sys.color.ohos_id_color_activated'))
              .maxLines(1)
              .layoutWeight(1)
          }
          Text(RssService.getInstance().formatDate(this.article.publishedAt))
            .fontSize(12)
            .fontColor($r('sys.color.ohos_id_color_text_tertiary'))
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 收藏按钮
      Button({ type: ButtonType.Circle }) {
        Image(this.article.isStarred === 1 ? $r('app.media.ic_star_filled') : $r('app.media.ic_star'))
          .width(18)
          .height(18)
          .fillColor(this.article.isStarred === 1
            ? Color.Orange
            : $r('sys.color.ohos_id_color_text_tertiary'))
      }
      .width(32)
      .height(32)
      .backgroundColor(Color.Transparent)
      .onClick((e) => {
        e.stopPropagation();
        this.onStarToggle();
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.ohos_id_color_background'))
    .onClick(() => this.onTap())
  }
}
