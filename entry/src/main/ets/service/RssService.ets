import { http } from '@kit.NetworkKit';
import { Feed, Article } from '../model/Models';
import { XMLParser } from 'fast-xml-parser';

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
        parseTagValue: true,
        removeNSPrefix: true,
        htmlDecode: true,
        textNodeName: '#text',
        ignoreDeclaration: true,
        alwaysCreateTextNode: false
      };

      const parser = new XMLParser(options);
      const result = parser.parse(xmlContent);
      console.info(TAG, `Parsed result keys: ${Object.keys(result)}`);

      // 检测并解析 RSS 2.0
      if (result.rss) {
        const rss = result.rss as Record<string, Object>;
        if (rss.channel) {
          return this.parseRss2(rss.channel);
        }
      }

      // 检测并解析 Atom
      if (result.feed) {
        return this.parseAtom(result.feed);
      }

      // 检测 RDF/RSS 1.0
      if (result.RDF) {
        return this.parseRdf(result.RDF);
      }

      console.error(TAG, 'Unknown format');
      throw new Error('不支持的格式：无法识别 RSS 或 Atom');
    } catch (e) {
      console.error(TAG, `Parse error: ${e}`);
      throw e;
    }
  }

  private getStringValue(obj: Object, key: string): string {
    const record = obj as Record<string, Object>;
    const val = record[key];
    if (typeof val === 'string') {
      return val;
    }
    if (val) {
      const valRecord = val as Record<string, string>;
      return valRecord['#text'] || valRecord.href || valRecord.toString();
    }
    return '';
  }

  private getOptionalString(obj: Object, key: string): string {
    const record = obj as Record<string, Object>;
    const val = record[key];
    if (!val) {
      return '';
    }
    if (typeof val === 'string') {
      return val;
    }
    const valRecord = val as Record<string, string>;
    return valRecord['#text'] || valRecord.href || '';
  }

  private parseRss2(channel: Object): ParsedFeedInfo {
    const info: ParsedFeedInfo = {
      title: this.getOptionalString(channel, 'title'),
      siteUrl: this.getOptionalString(channel, 'link'),
      description: this.getOptionalString(channel, 'description'),
      iconUrl: '',
      articles: []
    };

    const channelRecord = channel as Record<string, Object>;
    const itemsObj = channelRecord['item'];
    const items: Object[] = Array.isArray(itemsObj) ? itemsObj : (itemsObj ? [itemsObj] : []);

    for (const item of items) {
      const itemRecord = item as Record<string, Object>;
      const enclosureObj = itemRecord['enclosure'];
      let coverImage = '';

      // 处理 enclosure 标签（RSS 标准图片）
      if (enclosureObj) {
        const enclosure = Array.isArray(enclosureObj) ? enclosureObj[0] : enclosureObj;
        const enclosureRecord = enclosure as Record<string, string>;
        const enclosureType = enclosureRecord['@_type'] || '';
        const enclosureUrl = enclosureRecord['@_url'] || '';
        if (enclosureType && enclosureType.startsWith('image/') && enclosureUrl) {
          coverImage = enclosureUrl;
        }
      }

      const contentRaw = itemRecord['content:encoded'] || itemRecord['encoded'] || '';
      const contentStr = typeof contentRaw === 'string' ? contentRaw : (contentRaw as Record<string, string>)['#text'] || '';
      const descriptionRaw = itemRecord['description'] || '';
      const descriptionStr = typeof descriptionRaw === 'string' ? descriptionRaw : (descriptionRaw as Record<string, string>)['#text'] || '';
      const linkRaw = itemRecord['link'] || '';
      const linkStr = typeof linkRaw === 'string' ? linkRaw : (linkRaw as Record<string, string>)['#text'] || '';
      const guidRaw = itemRecord['guid'] || linkRaw || itemRecord['title'] || '';
      const guidStr = typeof guidRaw === 'string' ? guidRaw : (guidRaw as Record<string, string>)['#text'] || '';
      const titleRaw = itemRecord['title'] || '';
      const titleStr = typeof titleRaw === 'string' ? titleRaw : (titleRaw as Record<string, string>)['#text'] || '';
      const authorRaw = itemRecord['author'] || itemRecord['dc:creator'] || '';
      const authorStr = typeof authorRaw === 'string' ? authorRaw : (authorRaw as Record<string, string>)['#text'] || '';
      const pubDateRaw = itemRecord['pubDate'] || '';
      const pubDateStr = typeof pubDateRaw === 'string' ? pubDateRaw : (pubDateRaw as Record<string, string>)['#text'] || '';

      const article: ParsedArticle = {
        guid: guidStr || linkStr || titleStr,
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

  private parseAtom(feed: Object): ParsedFeedInfo {
    const feedRecord = feed as Record<string, Object>;

    const info: ParsedFeedInfo = {
      title: this.getOptionalString(feed, 'title'),
      siteUrl: '',
      description: this.getOptionalString(feed, 'subtitle'),
      iconUrl: '',
      articles: []
    };

    // 处理 feed link
    const linkObj = feedRecord['link'];
    if (linkObj) {
      const links: Object[] = Array.isArray(linkObj) ? linkObj : [linkObj];
      for (const link of links) {
        const linkRec = link as Record<string, string>;
        const rel = linkRec['@_rel'] || 'alternate';
        const href = linkRec['@_href'] || linkRec['#text'] || linkRec.href || '';
        if (rel === 'alternate' && !info.siteUrl) {
          info.siteUrl = href;
        }
      }
    }

    const entriesObj = feedRecord['entry'];
    const entries: Object[] = Array.isArray(entriesObj) ? entriesObj : (entriesObj ? [entriesObj] : []);

    for (const entry of entries) {
      const entryRecord = entry as Record<string, Object>;

      // 处理 entry link
      let url = '';
      const entryLinkObj = entryRecord['link'];
      if (entryLinkObj) {
        const entryLinks: Object[] = Array.isArray(entryLinkObj) ? entryLinkObj : [entryLinkObj];
        for (const link of entryLinks) {
          const linkRec = link as Record<string, string>;
          const rel = linkRec['@_rel'] || 'alternate';
          const href = linkRec['@_href'] || linkRec['#text'] || linkRec.href || '';
          if (rel === 'alternate' && !url) {
            url = href;
          }
        }
      }

      // 处理作者
      let author = '';
      const authorObj = entryRecord['author'];
      if (authorObj) {
        const authorRec = authorObj as Record<string, string>;
        author = authorRec.name || authorRec['#text'] || '';
      }

      const titleRaw = entryRecord['title'] || '';
      const titleStr = typeof titleRaw === 'string' ? titleRaw : (titleRaw as Record<string, string>)['#text'] || '';
      const summaryRaw = entryRecord['summary'] || '';
      const summaryStr = typeof summaryRaw === 'string' ? summaryRaw : (summaryRaw as Record<string, string>)['#text'] || '';
      const contentRaw = entryRecord['content'] || '';
      const contentStr = typeof contentRaw === 'string' ? contentRaw : (contentRaw as Record<string, string>)['#text'] || '';
      const idRaw = entryRecord['id'] || '';
      const idStr = typeof idRaw === 'string' ? idRaw : (idRaw as Record<string, string>)['#text'] || '';
      const updatedRaw = entryRecord['updated'] || entryRecord['published'] || '';
      const updatedStr = typeof updatedRaw === 'string' ? updatedRaw : (updatedRaw as Record<string, string>)['#text'] || '';

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

  private parseRdf(rdf: Object): ParsedFeedInfo {
    const rdfRecord = rdf as Record<string, Object>;

    const info: ParsedFeedInfo = {
      title: '',
      siteUrl: '',
      description: '',
      iconUrl: '',
      articles: []
    };

    // RDF/RSS 1.0 格式
    const channelObj = rdfRecord['channel'];
    if (channelObj) {
      const channelRec = channelObj as Record<string, string>;
      info.title = channelRec.title || '';
      info.siteUrl = channelRec.link || '';
      info.description = channelRec.description || '';
    }

    const itemsObj = rdfRecord['item'];
    const items: Object[] = Array.isArray(itemsObj) ? itemsObj : (itemsObj ? [itemsObj] : []);

    for (const item of items) {
      const itemRecord = item as Record<string, string>;

      const article: ParsedArticle = {
        guid: itemRecord['about'] || itemRecord.link || itemRecord.title || '',
        title: itemRecord.title || '',
        summary: this.stripHtml(itemRecord.description || '').slice(0, 300),
        content: `<p>${itemRecord.description || ''}</p>`,
        url: itemRecord.link || '',
        author: itemRecord['dc:creator'] || '',
        publishedAt: this.parseDate(itemRecord['dc:date'] || ''),
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
