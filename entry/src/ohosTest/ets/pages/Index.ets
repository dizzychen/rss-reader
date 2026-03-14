@Entry
@Component
struct Index {
  build() {
    Row() {
      Column() {
        Text('Test Running...')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
    }
    .height('100%')
  }
}
