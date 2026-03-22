/**
 * Markdown 转可读纯文本工具
 * 用于将 AI 输出的 Markdown 格式转换为适合 Text 组件渲染的纯文本
 */
export class MarkdownUtil {
  /**
   * 将 Markdown 文本转换为可读纯文本
   * 处理：标题、粗体/斜体、列表、分隔线、代码块、链接、blockquote
   */
  static strip(md: string): string {
    return md
      // 代码块 ```...``` → 保留内容，去掉围栏
      .replace(/```[\w]*\n?([\s\S]*?)```/g, '$1')
      // 行内代码 `code` → code
      .replace(/`([^`]+)`/g, '$1')
      // 标题 ## Title → Title
      .replace(/^#{1,6}\s+(.+)$/gm, '$1')
      // 粗体 **text** / __text__ → text
      .replace(/\*\*(.+?)\*\*/g, '$1')
      .replace(/__(.+?)__/g, '$1')
      // 斜体 *text* / _text_ → text（注意不误匹配列表符号）
      .replace(/(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)/g, '$1')
      .replace(/(?<!_)_(?!_)(.+?)(?<!_)_(?!_)/g, '$1')
      // 链接 [text](url) → text
      .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
      // 图片 ![alt](url) → 空（图片在纯文本中无意义）
      .replace(/!\[[^\]]*\]\([^)]+\)/g, '')
      // 无序列表 - / * / + → • 
      .replace(/^[ \t]*[-*+] +/gm, '• ')
      // 有序列表 1. item → 保留序号
      .replace(/^[ \t]*(\d+)\. +/gm, '$1. ')
      // 分隔线 --- / *** / ___ → 空行
      .replace(/^[ \t]*[-*_]{3,}[ \t]*$/gm, '')
      // blockquote > text → text
      .replace(/^[ \t]*> */gm, '')
      // 合并连续空行（>2行 → 2行）
      .replace(/\n{3,}/g, '\n\n')
      .trim();
  }
}
