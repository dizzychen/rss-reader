// 本地话题关键词提取工具类（无 AI 降级方案）
import { Constants } from '../constants/Constants';

/** 话题条目（名称 + 权重） */
export interface TopicEntry {
  name: string;
  weight: number;
}

export class TopicExtractor {
  private static stopWordsSet: Set<string> | null = null;

  /**
   * 获取停用词集合（懒初始化）
   */
  private static getStopWords(): Set<string> {
    if (!TopicExtractor.stopWordsSet) {
      TopicExtractor.stopWordsSet = new Set<string>();
      for (const w of Constants.STOP_WORDS) {
        TopicExtractor.stopWordsSet.add(w.toLowerCase());
      }
    }
    return TopicExtractor.stopWordsSet;
  }

  /**
   * 判断字符是否为 CJK 统一汉字
   */
  private static isCJK(char: string): boolean {
    const code = char.charCodeAt(0);
    return code >= 0x4E00 && code <= 0x9FFF;
  }

  /**
   * 判断字符是否为英文字母
   */
  private static isAlpha(char: string): boolean {
    const code = char.charCodeAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  /**
   * 从标题列表中提取话题关键词
   * - CJK：按字符 bigram 分词
   * - 英文：按空格分词
   * - 过滤停用词和短词
   * - 按频次 Top N 输出
   *
   * @param titles     文章标题列表
   * @param topN       返回前 N 个话题（默认 8）
   * @returns 话题列表（按权重降序）
   */
  static extractFromTitles(titles: string[], topN: number = 8): TopicEntry[] {
    const freq = new Map<string, number>();
    const stopWords = TopicExtractor.getStopWords();

    for (const title of titles) {
      const tokens = TopicExtractor.tokenize(title);
      // 去重同一标题内的重复 token
      const seen = new Set<string>();
      for (const token of tokens) {
        const lower = token.toLowerCase();
        if (seen.has(lower) || stopWords.has(lower)) {
          continue;
        }
        seen.add(lower);
        freq.set(lower, (freq.get(lower) ?? 0) + 1);
      }
    }

    // 按频次排序
    const entries: Array<[string, number]> = [];
    freq.forEach((count, word) => {
      entries.push([word, count]);
    });
    entries.sort((a, b) => b[1] - a[1]);

    // 取 Top N，权重归一化为 [0, 1]
    const topEntries = entries.slice(0, topN);
    if (topEntries.length === 0) {
      return [];
    }
    const maxCount = topEntries[0][1];
    const result: TopicEntry[] = [];
    for (const entry of topEntries) {
      result.push({
        name: entry[0],
        weight: Math.round((entry[1] / maxCount) * 1000) / 1000
      });
    }
    return result;
  }

  /**
   * 合并标题话题与搜索关键词
   * @param titleTopics  从标题提取的话题
   * @param searchKeywords  用户搜索关键词
   * @param searchBaseWeight  搜索词基础权重（默认 0.6）
   * @returns 合并后的话题列表（去重，按权重降序）
   */
  static mergeWithSearchKeywords(
    titleTopics: TopicEntry[],
    searchKeywords: string[],
    searchBaseWeight: number = 0.6
  ): TopicEntry[] {
    const merged = new Map<string, number>();

    // 先加入标题话题
    for (const t of titleTopics) {
      merged.set(t.name.toLowerCase(), t.weight);
    }

    // 合并搜索关键词（取较大权重）
    for (const kw of searchKeywords) {
      const lower = kw.toLowerCase().trim();
      if (!lower) {
        continue;
      }
      const existing = merged.get(lower) ?? 0;
      merged.set(lower, Math.max(existing, searchBaseWeight));
    }

    // 排序输出
    const result: TopicEntry[] = [];
    merged.forEach((weight, name) => {
      result.push({ name, weight });
    });
    result.sort((a, b) => b.weight - a.weight);
    return result;
  }

  /**
   * 分词：CJK bigram + 英文空格分词
   */
  private static tokenize(text: string): string[] {
    const tokens: string[] = [];
    let englishBuffer = '';

    for (let i = 0; i < text.length; i++) {
      const char = text[i];

      if (TopicExtractor.isCJK(char)) {
        // 先 flush 英文 buffer
        if (englishBuffer.length >= 2) {
          tokens.push(englishBuffer);
        }
        englishBuffer = '';

        // CJK bigram：当前字 + 下一个 CJK 字
        if (i + 1 < text.length && TopicExtractor.isCJK(text[i + 1])) {
          tokens.push(char + text[i + 1]);
        }
      } else if (TopicExtractor.isAlpha(char)) {
        englishBuffer += char;
      } else {
        // 非字母非 CJK（空格、标点等）：flush 英文 buffer
        if (englishBuffer.length >= 2) {
          tokens.push(englishBuffer);
        }
        englishBuffer = '';
      }
    }

    // flush 最后的英文 buffer
    if (englishBuffer.length >= 2) {
      tokens.push(englishBuffer);
    }

    return tokens;
  }
}
