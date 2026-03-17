import { http } from '@kit.NetworkKit';
import { Feed, Article } from '../model/Models';

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

    // 判断是 RSS 还是 Atom
    const hasFeed = xmlContent.includes('<feed');
    const hasXmlns = xmlContent.includes('xmlns');
    const hasRss = xmlContent.includes('<rss');
    const hasChannel = xmlContent.includes('<channel>');
    const hasRdf = xmlContent.includes('<rdf:RDF') || xmlContent.includes('<RDF');
    const hasItem = xmlContent.includes('<item>');
    const hasEntry = xmlContent.includes('<entry>');

    console.info(TAG,
      `Format check: hasFeed=${hasFeed}, hasXmlns=${hasXmlns}, hasRss=${hasRss}, hasChannel=${hasChannel}, hasRdf=${hasRdf}, hasItem=${hasItem}, hasEntry=${hasEntry}`);

    // Atom 检测：有 feed 标签且有 xmlns 命名空间，或者有 entry 标签
    if ((hasFeed && hasXmlns) || hasEntry) {
      console.info(TAG, 'Detected Atom format');
      return this.parseAtom(xmlContent);
    }
    // RSS 2.0 或 RDF/RSS 1.0
    if (hasRss || hasChannel || hasRdf || hasItem) {
      console.info(TAG, 'Detected RSS format');
      return this.parseRss2(xmlContent);
    }
    console.error(TAG, 'Unknown format');
    throw new Error('不支持的格式：无法识别 RSS 或 Atom');
  }

  /**
   * 从 XML 内容中提取标签文本内容
   */
  private extractTagContent(tagName: string, xml: string): string {
    const regex = new RegExp(`<${tagName}[^>]*>([\\s\\S]*?)</${tagName}>`, 'i');
    const match = xml.match(regex);
    if (match && match[1]) {
      // 处理 CDATA
      let content = match[1];
      const cdataMatch = content.match(/<!\[CDATA\[([\s\S]*?)\]\]>);
      if (cdataMatch) {
        content = cdataMatch[1];
      }
      return this.stripHtml(content.trim());
    }
    return '';
  }

  /**
   * 从 XML 内容中提取所有指定标签的内容
   */
  private extractAllTags(tagName: string, xml: string): string[] {
    const results: string[] = [];
    const regex = new RegExp(`<${tagName}[^>]*>([\\s\\S]*?)</${tagName}>`, 'gi');
    let match: RegExpMatchArray | null;
    while ((match = regex.exec(xml)) !== null) {
      let content = match[1];
      const cdataMatch = content.match(/<!\[CDATA\[([\s\S]*?)\]\]>);
      if (cdataMatch) {
        content = cdataMatch[1];
      }
      results.push(this.stripHtml(content.trim()));
    }
    return results;
  }

  /**
   * 提取标签的属性
   */
  private extractAttribute(tagContent: string, attrName: string): string {
    const regex = new RegExp(`${attrName}\\s*=\\s*["']([^"']+)["']`, 'i');
    const match = tagContent.match(regex);
    return match ? match[1] : '';
  }

  /**
   * 从 XML 中提取所有 item/entry 标签块
   */
  private extractItems(xml: string, itemName: string): string[] {
    const items: string[] = [];
    const regex = new RegExp(`<${itemName}[\\s\\S]*?</${itemName}>`, 'gi');
    let match: RegExpMatchArray | null;
    while ((match = regex.exec(xml)) !== null) {
      items.push(match[0]);
    }
    return items;
  }

  private parseRss2(xmlContent: string): ParsedFeedInfo {
    const info: ParsedFeedInfo = {
      title: '',
      siteUrl: '',
      description: '',
      iconUrl: '',
      articles: []
    };

    try {
      // 提取 channel 内容
      const channelRegex = /<channel[\s\S]*?<\/channel>/i;
      const channelMatch = xmlContent.match(channelRegex);

      if (!channelMatch) {
        console.error(TAG, 'No channel found');
        return info;
      }

      const channelXml = channelMatch[0];

      // 提取频道信息
      info.title = this.extractTagContent('title', channelXml);
      info.siteUrl = this.extractTagContent('link', channelXml);
      info.description = this.extractTagContent('description', channelXml);

      // 提取所有 item
      const items = this.extractItems(channelXml, 'item');
      console.info(TAG, `Found ${items.length} items`);

      for (const itemXml of items) {
        // 提取 enclosure 图片
        let coverImage = '';
        const enclosureRegex = /<enclosure\s+([^>]*?)\s*\/?>/gi;
        const enclosureMatch = itemXml.match(enclosureRegex);
        if (enclosureMatch) {
          const enclosureTag = enclosureMatch[0];
          const type = this.extractAttribute(enclosureTag, 'type');
          const url = this.extractAttribute(enclosureTag, 'url');
          if (type && type.startsWith('image/') && url) {
            coverImage = url;
          }
        }

        // 提取文章内容
        const title = this.extractTagContent('title', itemXml);
        const link = this.extractTagContent('link', itemXml);
        const guid = this.extractTagContent('guid', itemXml);
        const description = this.extractTagContent('description', itemXml);
        const contentEncoded = this.extractTagContent('content:encoded', itemXml) ||
                               this.extractTagContent('encoded', itemXml);
        const author = this.extractTagContent('author', itemXml) ||
                       this.extractTagContent('dc:creator', itemXml);
        const pubDate = this.extractTagContent('pubDate', itemXml);

        const article: ParsedArticle = {
          guid: guid || link || title,
          title: title,
          summary: description.slice(0, 300),
          content: contentEncoded || `<p>${description}</p>`,
          url: link,
          author: author,
          publishedAt: this.parseDate(pubDate),
          coverImage: coverImage
        };

        // 从 content 中提取第一张图片作为封面
        if (!article.coverImage && article.content) {
          article.coverImage = this.extractFirstImage(article.content);
        }

        info.articles.push(article);
      }

      console.info(TAG, `RSS2 parse completed, found ${info.articles.length} articles`);
    } catch (e) {
      console.error(TAG, `RSS2 parse error: ${e}`);
    }

    return info;
  }

  private parseAtom(xmlContent: string): ParsedFeedInfo {
    const info: ParsedFeedInfo = {
      title: '',
      siteUrl: '',
      description: '',
      iconUrl: '',
      articles: []
    };

    try {
      // 提取 feed 内容
      const feedRegex = /<feed[\s\S]*?<\/feed>/i;
      const feedMatch = xmlContent.match(feedRegex);

      if (!feedMatch) {
        console.error(TAG, 'No feed found');
        return info;
      }

      const feedXml = feedMatch[0];

      // 提取频道信息
      info.title = this.extractTagContent('title', feedXml);
      info.description = this.extractTagContent('subtitle', feedXml);

      // 提取 siteUrl - 处理 link 标签的属性
      const linkRegex = /<link\s+([^>]*?)\s*\/?>/gi;
      let linkMatch: RegExpMatchArray | null;
      while ((linkMatch = linkRegex.exec(feedXml)) !== null) {
        const linkTag = linkMatch[0];
        const rel = this.extractAttribute(linkTag, 'rel') || 'alternate';
        const href = this.extractAttribute(linkTag, 'href');
        if (rel === 'alternate' && !info.siteUrl && href) {
          info.siteUrl = href;
        }
      }

      // 提取所有 entry
      const entries = this.extractItems(feedXml, 'entry');
      console.info(TAG, `Found ${entries.length} entries`);

      for (const entryXml of entries) {
        // 提取文章 URL - 处理 entry 内的 link 标签
        let url = '';
        const entryLinkRegex = /<link\s+([^>]*?)\s*\/?>/gi;
        let entryLinkMatch: RegExpMatchArray | null;
        while ((entryLinkMatch = entryLinkRegex.exec(entryXml)) !== null) {
          const linkTag = entryLinkMatch[0];
          const rel = this.extractAttribute(linkTag, 'rel') || 'alternate';
          const href = this.extractAttribute(linkTag, 'href');
          if (rel === 'alternate' && !url && href) {
            url = href;
          }
        }

        // 提取作者
        let author = '';
        const authorRegex = /<author[\s\S]*?<\/author>/i;
        const authorMatch = entryXml.match(authorRegex);
        if (authorMatch) {
          author = this.extractTagContent('name', authorMatch[0]);
        }

        // 提取文章内容
        const title = this.extractTagContent('title', entryXml);
        const id = this.extractTagContent('id', entryXml);
        const summary = this.extractTagContent('summary', entryXml);
        const content = this.extractTagContent('content', entryXml);
        const updated = this.extractTagContent('updated', entryXml);
        const published = this.extractTagContent('published', entryXml);

        const article: ParsedArticle = {
          guid: id || url || title,
          title: title,
          summary: (summary || title).slice(0, 300),
          content: content || `<p>${summary || title}</p>`,
          url: url,
          author: author,
          publishedAt: this.parseDate(updated || published),
          coverImage: ''
        };

        // 从 content 中提取第一张图片作为封面
        if (!article.coverImage && article.content) {
          article.coverImage = this.extractFirstImage(article.content);
        }

        info.articles.push(article);
      }

      console.info(TAG, `Atom parse completed: ${info.articles.length} articles`);
    } catch (e) {
      console.error(TAG, `Atom parse error: ${e}`);
    }

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
