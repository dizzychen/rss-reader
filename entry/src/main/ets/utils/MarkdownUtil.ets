/**
 * Markdown 工具类
 * 用于 Markdown 格式解析、转换和章节提取
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

  /**
   * 提取 Markdown 中某个 ## 章节的内容
   * @param content Markdown 全文
   * @param header 章节标题（如 "## 订阅源偏好"）
   * @returns 章节内容（不含标题行），如果未找到返回空字符串
   */
  static extractSection(content: string, header: string): string {
    const lines = content.split('\n');
    let inSection = false;
    const sectionLines: string[] = [];
    for (const line of lines) {
      if (line.startsWith('## ')) {
        if (inSection) {
          break;
        }
        if (line.startsWith(header)) {
          inSection = true;
          continue;
        }
      }
      if (inSection) {
        sectionLines.push(line);
      }
    }
    return sectionLines.join('\n');
  }

  /**
   * 从 Markdown 中提取多个章节
   * @param content Markdown 全文
   * @param headers 章节标题数组
   * @returns 各章节内容的拼接
   */
  static extractSections(content: string, headers: string[]): string {
    if (!content.trim()) {
      return '';
    }
    const parts: string[] = [];
    for (const header of headers) {
      const section = MarkdownUtil.extractSection(content, header);
      if (section.trim()) {
        // 含标题一起输出
        parts.push(`${header}\n${section.trim()}`);
      }
    }
    return parts.join('\n\n');
  }
}
