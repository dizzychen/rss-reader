import { http } from '@kit.NetworkKit';
import { xml, util } from '@kit.ArkTS';
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

interface EnclosureData {
  type: string;
  url: string;
}

interface LinkData {
  rel: string;
  href: string;
  inEntry: boolean;
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

  private stringToArrayBuffer(str: string): ArrayBuffer {
    const encoder = new util.TextEncoder();
    const uint8Array = encoder.encodeInto(str);
    return uint8Array.buffer as ArrayBuffer;
  }

  /**
   * 从 XML 字符串中提取 enclosure 标签的属性
   */
  private extractEnclosures(xmlContent: string): Map<string, EnclosureData> {
    const enclosureMap = new Map<string, EnclosureData>();
    const enclosureRegex = /<enclosure\s+([^>]*?)\s*\/?>/gi;
    let enclosureMatch: RegExpExecArray | null;
    let enclosureIndex = 0;

    while ((enclosureMatch = enclosureRegex.exec(xmlContent)) !== null) {
      const attrs = enclosureMatch[1];
      const typeMatch = attrs.match(/type\s*=\s*["']([^"']+)["']/i);
      const urlMatch = attrs.match(/url\s*=\s*["']([^"']+)["']/i);

      if (typeMatch || urlMatch) {
        enclosureMap.set(`enclosure-${enclosureIndex}`, {
          type: typeMatch ? typeMatch[1] : '',
          url: urlMatch ? urlMatch[1] : ''
        });
        enclosureIndex++;
      }
    }

    return enclosureMap;
  }

  /**
   * 从 XML 字符串中提取 link 标签的属性
   */
  private extractLinks(xmlContent: string): LinkData[] {
    const allLinks: LinkData[] = [];
    const fullLinkRegex = /<link\s+([^>]*?)\s*\/?>/gi;
    let linkMatch: RegExpExecArray | null;

    while ((linkMatch = fullLinkRegex.exec(xmlContent)) !== null) {
      const attrs = linkMatch[1];
      const relMatch = attrs.match(/rel\s*=\s*["']([^"']+)["']/i);
      const hrefMatch = attrs.match(/href\s*=\s*["']([^"']+)["']/i);

      // 判断是否在 entry 标签内
      const linkStartPos = linkMatch.index;
      const beforeLink = xmlContent.substring(0, linkStartPos);
      const entryOpens = (beforeLink.match(/<entry>/g) || []).length;
      const entryCloses = (beforeLink.match(/<\/entry>/g) || []).length;
      const checkInEntry = entryOpens > entryCloses;

      const rel = relMatch ? relMatch[1] : 'alternate';
      const href = hrefMatch ? hrefMatch[1] : '';

      if (href) {
        allLinks.push({ rel, href, inEntry: checkInEntry });
      }
    }

    return allLinks;
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
      // 预先解析 enclosure 标签的属性
      const enclosureMap = this.extractEnclosures(xmlContent);

      const buffer = this.stringToArrayBuffer(xmlContent);
      const parser = new xml.XmlPullParser(buffer, 'utf-8');
      let currentTag: string = '';
      let tagStack: string[] = [];
      let currentArticle: ParsedArticle | null = null;
      let inChannel: boolean = false;
      let inItem: boolean = false;
      let textBuffer: string = '';
      let enclosureCounter = 0;

      const options: xml.ParseOptions = {
        supportDoctype: false,
        ignoreNameSpace: true,
        tokenValueCallbackFunction: (eventType: xml.EventType, value: xml.ParseInfo): boolean => {
          if (eventType === xml.EventType.START_TAG) {
            currentTag = value.getName();
            tagStack.push(currentTag);
            textBuffer = '';

            if (currentTag === 'channel') {
              inChannel = true;
            }
            if (currentTag === 'item') {
              inItem = true;
              currentArticle = {
                guid: '',
                title: '',
                summary: '',
                content: '',
                url: '',
                author: '',
                publishedAt: 0,
                coverImage: ''
              };
            }
            // 处理 enclosure 标签
            if (currentTag === 'enclosure' && currentArticle) {
              const enclosureData = enclosureMap.get(`enclosure-${enclosureCounter}`);
              if (enclosureData) {
                if (enclosureData.type && enclosureData.type.startsWith('image/') && enclosureData.url) {
                  currentArticle.coverImage = enclosureData.url;
                }
                enclosureCounter++;
              }
            }
          } else if (eventType === xml.EventType.TEXT || eventType === xml.EventType.CDSECT) {
            textBuffer += value.getText();
          } else if (eventType === xml.EventType.END_TAG) {
            const tag: string = value.getName();
            const text: string = textBuffer.trim();
            tagStack.pop();

            if (inItem && currentArticle) {
              switch (tag) {
                case 'title':
                  currentArticle.title = text;
                  break;
                case 'link':
                  if (!currentArticle.url) {
                    currentArticle.url = text;
                  }
                  break;
                case 'guid':
                  currentArticle.guid = text;
                  break;
                case 'description':
                  currentArticle.summary = this.stripHtml(text).slice(0, 300);
                  break;
                case 'content:encoded':
                case 'encoded':
                  currentArticle.content = text;
                  break;
                case 'author':
                case 'dc:creator':
                  currentArticle.author = text;
                  break;
                case 'pubDate':
                  currentArticle.publishedAt = this.parseDate(text);
                  break;
                case 'item':
                  if (!currentArticle.guid) {
                    currentArticle.guid = currentArticle.url || currentArticle.title;
                  }
                  if (!currentArticle.content) {
                    currentArticle.content = `<p>${currentArticle.summary}</p>`;
                  }
                  info.articles.push(currentArticle);
                  currentArticle = null;
                  inItem = false;
                  enclosureCounter = 0;
                  break;
              }
            } else if (inChannel && !inItem) {
              switch (tag) {
                case 'title':
                  if (!info.title) {
                    info.title = text;
                  }
                  break;
                case 'link':
                  if (!info.siteUrl) {
                    info.siteUrl = text;
                  }
                  break;
                case 'description':
                  if (!info.description) {
                    info.description = text;
                  }
                  break;
                case 'channel':
                  inChannel = false;
                  break;
              }
            }
            textBuffer = '';
          }
          return true;
        }
      };
      parser.parse(options);
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
      // 预先解析所有 link 标签的属性
      const allLinks = this.extractLinks(xmlContent);

      const buffer = this.stringToArrayBuffer(xmlContent);
      const parser = new xml.XmlPullParser(buffer, 'utf-8');
      let inEntry: boolean = false;
      let currentArticle: ParsedArticle | null = null;
      let textBuffer: string = '';
      let linkIdx: number = 0;

      const options: xml.ParseOptions = {
        supportDoctype: false,
        ignoreNameSpace: true,
        tokenValueCallbackFunction: (eventType: xml.EventType, value: xml.ParseInfo): boolean => {
          if (eventType === xml.EventType.START_TAG) {
            const rawName: string = value.getName();
            const tagName: string = rawName.includes(':') ? rawName.split(':')[1] : rawName;
            textBuffer = '';

            if (tagName === 'entry') {
              inEntry = true;
              currentArticle = {
                guid: '',
                title: '',
                summary: '',
                content: '',
                url: '',
                author: '',
                publishedAt: 0,
                coverImage: ''
              };
            }
            // 处理 link 标签 - 使用预提取的数据
            if (tagName === 'link' && linkIdx < allLinks.length) {
              const linkData = allLinks[linkIdx];
              linkIdx++;

              if (inEntry && currentArticle) {
                if (linkData.rel === 'alternate' && !currentArticle.url) {
                  currentArticle.url = linkData.href;
                }
              } else if (!inEntry) {
                if (linkData.rel === 'alternate' && !info.siteUrl) {
                  info.siteUrl = linkData.href;
                }
              }
            }
          } else if (eventType === xml.EventType.TEXT || eventType === xml.EventType.CDSECT) {
            textBuffer += value.getText() || '';
          } else if (eventType === xml.EventType.END_TAG) {
            const rawName: string = value.getName();
            const tagName: string = rawName.includes(':') ? rawName.split(':')[1] : rawName;
            const text: string = textBuffer.trim();

            if (inEntry && currentArticle) {
              switch (tagName) {
                case 'title':
                  currentArticle.title = this.stripHtml(text);
                  break;
                case 'id':
                  if (!currentArticle.guid) {
                    currentArticle.guid = text;
                  }
                  break;
                case 'summary':
                  currentArticle.summary = this.stripHtml(text).slice(0, 300);
                  break;
                case 'content':
                  currentArticle.content = text;
                  break;
                case 'name':
                  if (!currentArticle.author) {
                    currentArticle.author = text;
                  }
                  break;
                case 'updated':
                case 'published':
                  if (!currentArticle.publishedAt) {
                    currentArticle.publishedAt = this.parseDate(text);
                  }
                  break;
                case 'entry':
                  if (!currentArticle.guid) {
                    currentArticle.guid = currentArticle.url || currentArticle.title;
                  }
                  if (!currentArticle.content) {
                    currentArticle.content = `<p>${currentArticle.summary}</p>`;
                  }
                  if (!currentArticle.summary) {
                    currentArticle.summary = currentArticle.title;
                  }
                  info.articles.push(currentArticle);
                  currentArticle = null;
                  inEntry = false;
                  break;
              }
            } else if (!inEntry) {
              switch (tagName) {
                case 'title':
                  if (!info.title) {
                    info.title = this.stripHtml(text);
                  }
                  break;
                case 'subtitle':
                  if (!info.description) {
                    info.description = text;
                  }
                  break;
              }
            }

            textBuffer = '';
          }
          return true;
        }
      };
      parser.parse(options);
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
