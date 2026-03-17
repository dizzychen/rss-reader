import { http } from '@kit.NetworkKit';
import { Feed, Article } from '../model/Models';
import * as parser from 'fast-xml-parser';

const TAG = 'RssService';

export interface ParsedFeedInfo {
  title: string;
  siteUrl: string;
  description: string;
  iconUrl: string;
  articles: ParsedArticle[];
}

export interface ParsedArticle {
  guid: string;
  title: string;
  summary: string;
  content: string;
  url: string;
  author: string;
  publishedAt: number;
  coverImage: string;
}

// 辅助函数：判断是否为字符串
function isString(val: unknown): boolean {
  try {
    return (val as string).length !== undefined && typeof (val as string) !== 'object';
  } catch {
    return false;
  }
}

// 辅助函数：安全提取字符串值
function extractString(val: unknown): string {
  if (val === null || val === undefined) {
    return '';
  }
  try {
    const strVal = val as string;
    if (strVal.length !== undefined) {
      // 检查是否有对象属性（如 #text）
      const objVal = val as Record<string, string>;
      if (objVal['#text']) {
        return objVal['#text'];
      }
      if (objVal.href) {
        return objVal.href;
      }
      return strVal;
    }
    return '';
  } catch {
    return '';
  }
}

// 辅助函数：提取属性值
function extractAttr(val: unknown, attrName: string): string {
  if (val === null || val === undefined) {
    return '';
  }
  const obj = val as Record<string, string>;
  return obj[attrName] || '';
}

export class RssService {
  private static instance: RssService;

  static getInstance(): RssService {
    if (!RssService.instance) {
      RssService.instance = new RssService();
    }
    return RssService.instance;
  }

  /**
   * 验证并获取 RSS 源基本信息（用于添加订阅时的预览）
   */
  async fetchFeedInfo(url: string): Promise<ParsedFeedInfo> {
    const xmlContent = await this.fetchXml(url);
    return this.parseXml(xmlContent);
  }

  /**
   * 刷新某个订阅源，返回解析到的文章列表
   */
  async refreshFeed(feedUrl: string): Promise<ParsedFeedInfo> {
    const xmlContent = await this.fetchXml(feedUrl);
    return this.parseXml(xmlContent);
  }

  private async fetchXml(url: string): Promise<string> {
    const httpRequest = http.createHttp();
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 15000,
        header: {
          'User-Agent': 'HarmonyOS-RSSReader/1.0',
          'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*'
        }
      });
      console.info(TAG, `HTTP response code: ${response.responseCode}`);
      if (response.responseCode !== 200) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      const result = response.result as string;
      console.info(TAG, `Fetched XML length: ${result.length}`);
      return result;
    } finally {
      httpRequest.destroy();
    }
  }

  private parseXml(xmlContent: string): ParsedFeedInfo {
    console.info(TAG, `parseXml called, content length: ${xmlContent.length}`);

    try {
      const options = {
        ignoreAttributes: false,
        attributeNamePrefix: '@_',
        parseAttributeValue: true,
        parseTagValue: false,
        removeNSPrefix: true,
        htmlDecode: true,
        textNodeName: '#text',
        ignoreDeclaration: true,
        alwaysCreateTextNode: false,
        ignoreOrder: false
      };

      const xmlParser = new parser.XMLParser(options);
      const result = xmlParser.parse(xmlContent);
      console.info(TAG, `Parsed result: ${JSON.stringify(result)}`);

      // 检测并解析 RSS 2.0
      const resultRec = result as Record<string, unknown>;
      if (resultRec['rss']) {
        const rss = resultRec['rss'] as Record<string, unknown>;
        if (rss.channel) {
          return this.parseRss2(rss.channel as Record<string, unknown>);
        }
      }

      // 检测并解析 Atom
      if (resultRec['feed']) {
        return this.parseAtom(resultRec['feed'] as Record<string, unknown>);
      }

      // 检测 RDF/RSS 1.0
      if (resultRec['RDF']) {
        return this.parseRdf(resultRec['RDF'] as Record<string, unknown>);
      }

      console.error(TAG, 'Unknown format');
      throw new Error('不支持的格式：无法识别 RSS 或 Atom');
    } catch (e) {
      console.error(TAG, `Parse error: ${e}`);
      throw e;
    }
  }

  private parseRss2(channel: Record<string, unknown>): ParsedFeedInfo {
    const info: ParsedFeedInfo = {
      title: extractString(channel['title']),
      siteUrl: extractString(channel['link']),
      description: extractString(channel['description']),
      iconUrl: '',
      articles: []
    };

    const itemsObj = channel['item'];
    const items: Record<string, unknown>[] = Array.isArray(itemsObj) ? itemsObj : (itemsObj ? [itemsObj as Record<string, unknown>] : []);

    for (const item of items) {
      const itemRec = item as Record<string, unknown>;
      const enclosureObj = itemRec['enclosure'];
      let coverImage = '';

      // 处理 enclosure 标签（RSS 标准图片）
      if (enclosureObj) {
        const enclosure = Array.isArray(enclosureObj) ? enclosureObj[0] : enclosureObj as Record<string, string>;
        const enclosureType = extractAttr(enclosure, '@_type');
        const enclosureUrl = extractAttr(enclosure, '@_url');
        if (enclosureType.startsWith('image/') && enclosureUrl) {
          coverImage = enclosureUrl;
        }
      }

      const contentStr = extractString(itemRec['content:encoded']) || extractString(itemRec['encoded']);
      const descriptionStr = extractString(itemRec['description']);
      const linkStr = extractString(itemRec['link']);
      const guidStr = extractString(itemRec['guid']) || linkStr || extractString(itemRec['title']);
      const titleStr = extractString(itemRec['title']);
      const authorStr = extractString(itemRec['author']) || extractString(itemRec['dc:creator']);
      const pubDateStr = extractString(itemRec['pubDate']);

      const article: ParsedArticle = {
        guid: guidStr,
        title: titleStr,
        summary: this.stripHtml(descriptionStr).slice(0, 300),
        content: contentStr || `<p>${descriptionStr}</p>`,
        url: linkStr,
        author: authorStr,
        publishedAt: this.parseDate(pubDateStr),
        coverImage: coverImage
      };

      // 从 content 中提取第一张图片作为封面
      if (!article.coverImage && article.content) {
        article.coverImage = this.extractFirstImage(article.content);
      }

      info.articles.push(article);
    }

    console.info(TAG, `RSS2 parse completed, found ${info.articles.length} articles`);
    return info;
  }

  private parseAtom(feed: Record<string, unknown>): ParsedFeedInfo {
    const info: ParsedFeedInfo = {
      title: extractString(feed['title']),
      siteUrl: '',
      description: extractString(feed['subtitle']),
      iconUrl: '',
      articles: []
    };

    // 处理 feed link
    const linkObj = feed['link'];
    if (linkObj) {
      const links: Record<string, unknown>[] = Array.isArray(linkObj) ? linkObj : [linkObj];
      for (const link of links) {
        const linkRec = link as Record<string, string>;
        const rel = linkRec['@_rel'] || 'alternate';
        const href = linkRec['@_href'] || linkRec['#text'] || linkRec.href || '';
        if (rel === 'alternate' && !info.siteUrl && href) {
          info.siteUrl = href;
        }
      }
    }

    const entriesObj = feed['entry'];
    const entries: Record<string, unknown>[] = Array.isArray(entriesObj) ? entriesObj : (entriesObj ? [entriesObj as Record<string, unknown>] : []);

    for (const entry of entries) {
      const entryRec = entry as Record<string, unknown>;

      // 处理 entry link
      let url = '';
      const entryLinkObj = entryRec['link'];
      if (entryLinkObj) {
        const entryLinks: Record<string, unknown>[] = Array.isArray(entryLinkObj) ? entryLinkObj : [entryLinkObj];
        for (const link of entryLinks) {
          const linkRec = link as Record<string, string>;
          const rel = linkRec['@_rel'] || 'alternate';
          const href = linkRec['@_href'] || linkRec['#text'] || linkRec.href || '';
          if (rel === 'alternate' && !url && href) {
            url = href;
          }
        }
      }

      // 处理作者
      let author = '';
      const authorObj = entryRec['author'];
      if (authorObj) {
        const authorRec = authorObj as Record<string, string>;
        author = authorRec.name || authorRec['#text'] || '';
      }

      const titleStr = extractString(entryRec['title']);
      const summaryStr = extractString(entryRec['summary']);
      const contentStr = extractString(entryRec['content']);
      const idStr = extractString(entryRec['id']);
      const updatedStr = extractString(entryRec['updated']) || extractString(entryRec['published']);

      const article: ParsedArticle = {
        guid: idStr || url || titleStr,
        title: this.stripHtml(titleStr),
        summary: this.stripHtml(summaryStr || titleStr).slice(0, 300),
        content: contentStr || `<p>${summaryStr || titleStr}</p>`,
        url: url,
        author: author,
        publishedAt: this.parseDate(updatedStr),
        coverImage: ''
      };

      // 从 content 中提取第一张图片作为封面
      if (!article.coverImage && article.content) {
        article.coverImage = this.extractFirstImage(article.content);
      }

      info.articles.push(article);
    }

    console.info(TAG, `Atom parse completed: ${info.articles.length} articles`);
    return info;
  }

  private parseRdf(rdf: Record<string, unknown>): ParsedFeedInfo {
    const info: ParsedFeedInfo = {
      title: '',
      siteUrl: '',
      description: '',
      iconUrl: '',
      articles: []
    };

    // RDF/RSS 1.0 格式
    const channelObj = rdf['channel'];
    if (channelObj) {
      const channelRec = channelObj as Record<string, string>;
      info.title = channelRec.title || '';
      info.siteUrl = channelRec.link || '';
      info.description = channelRec.description || '';
    }

    const itemsObj = rdf['item'];
    const items: Record<string, unknown>[] = Array.isArray(itemsObj) ? itemsObj : (itemsObj ? [itemsObj as Record<string, unknown>] : []);

    for (const item of items) {
      const itemRec = item as Record<string, string>;

      const article: ParsedArticle = {
        guid: itemRec['about'] || itemRec.link || itemRec.title || '',
        title: itemRec.title || '',
        summary: this.stripHtml(itemRec.description || '').slice(0, 300),
        content: `<p>${itemRec.description || ''}</p>`,
        url: itemRec.link || '',
        author: itemRec['dc:creator'] || '',
        publishedAt: this.parseDate(itemRec['dc:date'] || ''),
        coverImage: ''
      };

      // 从 content 中提取第一张图片作为封面
      if (!article.coverImage && article.content) {
        article.coverImage = this.extractFirstImage(article.content);
      }

      info.articles.push(article);
    }

    console.info(TAG, `RDF parse completed, found ${info.articles.length} articles`);
    return info;
  }

  private stripHtml(html: string): string {
    return html.replace(/<[^>]+>/g, '')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&nbsp;/g, ' ')
      .trim();
  }

  private parseDate(dateStr: string): number {
    if (!dateStr) {
      return Date.now();
    }
    try {
      const d = new Date(dateStr);
      return isNaN(d.getTime()) ? Date.now() : d.getTime();
    } catch {
      return Date.now();
    }
  }

  /**
   * 从文章 HTML 内容中提取第一张图片作为封面
   */
  extractFirstImage(html: string): string {
    const match = html.match(/<img[^>]+src=["']([^"']+)["']/i);
    return match ? match[1] : '';
  }

  /**
   * 格式化时间戳为可读字符串
   */
  formatDate(timestamp: number): string {
    const now = Date.now();
    const diff = now - timestamp;
    const minute = 60 * 1000;
    const hour = 60 * minute;
    const day = 24 * hour;

    if (diff < minute) {
      return '刚刚';
    }
    if (diff < hour) {
      return `${Math.floor(diff / minute)}分钟前`;
    }
    if (diff < day) {
      return `${Math.floor(diff / hour)}小时前`;
    }
    if (diff < 7 * day) {
      return `${Math.floor(diff / day)}天前`;
    }

    const date = new Date(timestamp);
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate())
      .padStart(2, '0')}`;
  }
}
