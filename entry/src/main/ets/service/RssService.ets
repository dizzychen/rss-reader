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

  async fetchFeedInfo(url: string): Promise<ParsedFeedInfo> {
    const xmlContent = await this.fetchXml(url);
    return this.parseXml(xmlContent);
  }

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
    console.info(TAG, `Parsed result: ${JSON.stringify(result)}`);

    const resultObj = result as Record<string, Object>;

    if (resultObj['rss']) {
      const rss = resultObj['rss'] as Record<string, Object>;
      if (rss['channel']) {
        return this.parseRss2(rss['channel'] as Record<string, Object>);
      }
    }

    if (resultObj['feed']) {
      return this.parseAtom(resultObj['feed'] as Record<string, Object>);
    }

    if (resultObj['RDF']) {
      return this.parseRdf(resultObj['RDF'] as Record<string, Object>);
    }

    throw new Error('不支持的格式：无法识别 RSS 或 Atom');
  }

  private getTextValue(obj: Record<string, Object>, key: string): string {
    const val = obj[key];
    if (val === null || val === undefined) {
      return '';
    }
    const valStr = val as unknown as string;
    if (valStr !== null && valStr !== undefined) {
      const objVal = val as Record<string, string>;
      return objVal['#text'] || objVal.href || valStr;
    }
    return '';
  }

  private parseRss2(channel: Record<string, Object>): ParsedFeedInfo {
    const info: ParsedFeedInfo = {
      title: this.getTextValue(channel, 'title'),
      siteUrl: this.getTextValue(channel, 'link'),
      description: this.getTextValue(channel, 'description'),
      iconUrl: '',
      articles: []
    };

    const itemsObj = channel['item'];
    let items: Array<Record<string, Object>> = [];
    if (itemsObj) {
      if (Array.isArray(itemsObj)) {
        items = itemsObj as Array<Record<string, Object>>;
      } else {
        items = [itemsObj as Record<string, Object>];
      }
    }

    for (const item of items) {
      const itemRec = item as Record<string, Object>;

      let coverImage = '';
      const enclosureObj = itemRec['enclosure'];
      if (enclosureObj) {
        let enclosure: Record<string, string>;
        if (Array.isArray(enclosureObj)) {
          enclosure = enclosureObj[0] as Record<string, string>;
        } else {
          enclosure = enclosureObj as Record<string, string>;
        }
        const enclosureType = enclosure['@_type'] || '';
        const enclosureUrl = enclosure['@_url'] || '';
        if (enclosureType.startsWith('image/') && enclosureUrl) {
          coverImage = enclosureUrl;
        }
      }

      const contentEncoded = this.getTextValue(itemRec, 'content:encoded') || this.getTextValue(itemRec, 'encoded');
      const description = this.getTextValue(itemRec, 'description');
      const link = this.getTextValue(itemRec, 'link');
      const guid = this.getTextValue(itemRec, 'guid') || link || this.getTextValue(itemRec, 'title');
      const title = this.getTextValue(itemRec, 'title');
      const author = this.getTextValue(itemRec, 'author') || this.getTextValue(itemRec, 'dc:creator');
      const pubDate = this.getTextValue(itemRec, 'pubDate');

      const article: ParsedArticle = {
        guid: guid,
        title: title,
        summary: this.stripHtml(description).slice(0, 300),
        content: contentEncoded || `<p>${description}</p>`,
        url: link,
        author: author,
        publishedAt: this.parseDate(pubDate),
        coverImage: coverImage
      };

      if (!article.coverImage && article.content) {
        article.coverImage = this.extractFirstImage(article.content);
      }

      info.articles.push(article);
    }

    console.info(TAG, `RSS2 parse completed: ${info.articles.length} articles`);
    return info;
  }

  private parseAtom(feed: Record<string, Object>): ParsedFeedInfo {
    const info: ParsedFeedInfo = {
      title: this.getTextValue(feed, 'title'),
      siteUrl: '',
      description: this.getTextValue(feed, 'subtitle'),
      iconUrl: '',
      articles: []
    };

    const linkObj = feed['link'];
    if (linkObj) {
      let links: Array<Record<string, Object>> = [];
      if (Array.isArray(linkObj)) {
        links = linkObj as Array<Record<string, Object>>;
      } else {
        links = [linkObj as Record<string, Object>];
      }
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
    let entries: Array<Record<string, Object>> = [];
    if (entriesObj) {
      if (Array.isArray(entriesObj)) {
        entries = entriesObj as Array<Record<string, Object>>;
      } else {
        entries = [entriesObj as Record<string, Object>];
      }
    }

    for (const entry of entries) {
      const entryRec = entry as Record<string, Object>;

      let url = '';
      const entryLinkObj = entryRec['link'];
      if (entryLinkObj) {
        let entryLinks: Array<Record<string, Object>> = [];
        if (Array.isArray(entryLinkObj)) {
          entryLinks = entryLinkObj as Array<Record<string, Object>>;
        } else {
          entryLinks = [entryLinkObj as Record<string, Object>];
        }
        for (const link of entryLinks) {
          const linkRec = link as Record<string, string>;
          const rel = linkRec['@_rel'] || 'alternate';
          const href = linkRec['@_href'] || linkRec['#text'] || linkRec.href || '';
          if (rel === 'alternate' && !url && href) {
            url = href;
          }
        }
      }

      let author = '';
      const authorObj = entryRec['author'];
      if (authorObj) {
        const authorRec = authorObj as Record<string, string>;
        author = authorRec.name || authorRec['#text'] || '';
      }

      const title = this.getTextValue(entryRec, 'title');
      const summary = this.getTextValue(entryRec, 'summary');
      const content = this.getTextValue(entryRec, 'content');
      const id = this.getTextValue(entryRec, 'id');
      const updated = this.getTextValue(entryRec, 'updated') || this.getTextValue(entryRec, 'published');

      const article: ParsedArticle = {
        guid: id || url || title,
        title: this.stripHtml(title),
        summary: this.stripHtml(summary || title).slice(0, 300),
        content: content || `<p>${summary || title}</p>`,
        url: url,
        author: author,
        publishedAt: this.parseDate(updated),
        coverImage: ''
      };

      if (!article.coverImage && article.content) {
        article.coverImage = this.extractFirstImage(article.content);
      }

      info.articles.push(article);
    }

    console.info(TAG, `Atom parse completed: ${info.articles.length} articles`);
    return info;
  }

  private parseRdf(rdf: Record<string, Object>): ParsedFeedInfo {
    const info: ParsedFeedInfo = {
      title: '',
      siteUrl: '',
      description: '',
      iconUrl: '',
      articles: []
    };

    const channelObj = rdf['channel'];
    if (channelObj) {
      const channelRec = channelObj as Record<string, string>;
      info.title = channelRec.title || '';
      info.siteUrl = channelRec.link || '';
      info.description = channelRec.description || '';
    }

    const itemsObj = rdf['item'];
    let items: Array<Record<string, Object>> = [];
    if (itemsObj) {
      if (Array.isArray(itemsObj)) {
        items = itemsObj as Array<Record<string, Object>>;
      } else {
        items = [itemsObj as Record<string, Object>];
      }
    }

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

      if (!article.coverImage && article.content) {
        article.coverImage = this.extractFirstImage(article.content);
      }

      info.articles.push(article);
    }

    console.info(TAG, `RDF parse completed: ${info.articles.length} articles`);
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

  extractFirstImage(html: string): string {
    const match = html.match(/<img[^>]+src=["']([^"']+)["']/i);
    return match ? match[1] : '';
  }

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
