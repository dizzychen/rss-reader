import { http } from '@kit.NetworkKit';
import { Feed, Article } from '../model/Models';
import parser from 'fast-xml-parser';

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

      const result = parser.parse(xmlContent, options);
      console.info(TAG, `Parsed result: ${JSON.stringify(result)}`);

      // 检测并解析 RSS 2.0
      if (result.rss && result.rss.channel) {
        return this.parseRss2(result.rss.channel);
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

  private parseRss2(channel: any): ParsedFeedInfo {
    const info: ParsedFeedInfo = {
      title: channel.title || '',
      siteUrl: channel.link || '',
      description: channel.description || '',
      iconUrl: '',
      articles: []
    };

    // 处理 channel.link 可能是对象的情况
    if (channel.link && typeof channel.link === 'object') {
      info.siteUrl = channel.link['#text'] || channel.link.href || '';
    }

    const items = channel.item || [];
    const itemsArray = Array.isArray(items) ? items : [items];

    for (const item of itemsArray) {
      const article: ParsedArticle = {
        guid: item.guid || item.link || item.title || '',
        title: item.title || '',
        summary: this.stripHtml(item.description || '').slice(0, 300),
        content: item['content:encoded'] || item.encoded || `<p>${item.description || ''}</p>`,
        url: item.link || '',
        author: item.author || item['dc:creator'] || '',
        publishedAt: this.parseDate(item.pubDate || ''),
        coverImage: ''
      };

      // 处理 enclosure 标签（RSS 标准图片）
      if (item.enclosure) {
        const enclosure = Array.isArray(item.enclosure) ? item.enclosure[0] : item.enclosure;
        const enclosureType = enclosure['@_type'] || '';
        const enclosureUrl = enclosure['@_url'] || '';
        if (enclosureType.startsWith('image/') && enclosureUrl) {
          article.coverImage = enclosureUrl;
        }
      }

      // 从 content 中提取第一张图片作为封面
      if (!article.coverImage && article.content) {
        article.coverImage = this.extractFirstImage(article.content);
      }

      info.articles.push(article);
    }

    console.info(TAG, `RSS2 parse completed, found ${info.articles.length} articles`);
    return info;
  }

  private parseAtom(feed: any): ParsedFeedInfo {
    const info: ParsedFeedInfo = {
      title: feed.title || '',
      siteUrl: '',
      description: feed.subtitle || '',
      iconUrl: '',
      articles: []
    };

    // 处理 feed link
    if (feed.link) {
      const links = Array.isArray(feed.link) ? feed.link : [feed.link];
      for (const link of links) {
        const rel = link['@_rel'] || 'alternate';
        const href = link['@_href'] || link['#text'] || link.href || '';
        if (rel === 'alternate' && !info.siteUrl) {
          info.siteUrl = href;
        }
      }
    }

    const entries = feed.entry || [];
    const entriesArray = Array.isArray(entries) ? entries : [entries];

    for (const entry of entriesArray) {
      const article: ParsedArticle = {
        guid: entry.id || entry.link || entry.title || '',
        title: this.stripHtml(entry.title || ''),
        summary: this.stripHtml(entry.summary || entry.title || '').slice(0, 300),
        content: entry.content || `<p>${entry.summary || entry.title || ''}</p>`,
        url: '',
        author: '',
        publishedAt: this.parseDate(entry.updated || entry.published || ''),
        coverImage: ''
      };

      // 处理 entry link
      if (entry.link) {
        const links = Array.isArray(entry.link) ? entry.link : [entry.link];
        for (const link of links) {
          const rel = link['@_rel'] || 'alternate';
          const href = link['@_href'] || link['#text'] || link.href || '';
          if (rel === 'alternate' && !article.url) {
            article.url = href;
          }
        }
      }

      // 处理作者
      if (entry.author) {
        const author = entry.author;
        article.author = author.name || author['#text'] || '';
      }

      // 从 content 中提取第一张图片作为封面
      if (!article.coverImage && article.content) {
        article.coverImage = this.extractFirstImage(article.content);
      }

      info.articles.push(article);
    }

    console.info(TAG, `Atom parse completed: ${info.articles.length} articles`);
    return info;
  }

  private parseRdf(rdf: any): ParsedFeedInfo {
    const info: ParsedFeedInfo = {
      title: '',
      siteUrl: '',
      description: '',
      iconUrl: '',
      articles: []
    };

    // RDF/RSS 1.0 格式
    const channel = rdf.channel || {};
    info.title = channel.title || '';
    info.siteUrl = channel.link || '';
    info.description = channel.description || '';

    const items = rdf.item || [];
    const itemsArray = Array.isArray(items) ? items : [items];

    for (const item of itemsArray) {
      const article: ParsedArticle = {
        guid: item['about'] || item.link || item.title || '',
        title: item.title || '',
        summary: this.stripHtml(item.description || '').slice(0, 300),
        content: `<p>${item.description || ''}</p>`,
        url: item.link || '',
        author: item['dc:creator'] || '',
        publishedAt: this.parseDate(item['dc:date'] || ''),
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
