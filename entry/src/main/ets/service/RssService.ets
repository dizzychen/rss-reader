import { http } from '@kit.NetworkKit';
import { xml, util } from '@kit.ArkTS';
import { Feed, Article } from '../model/Models';

const TAG = 'RssParser';

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
   * 验证并获取RSS源基本信息（用于添加订阅时的预览）
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
    // Atom: <feed xmlns="...">
    // RSS: <rss version="..."> 或 <channel>
    const hasFeed = xmlContent.includes('<feed');
    const hasXmlns = xmlContent.includes('xmlns');
    const hasRss = xmlContent.includes('<rss');
    const hasChannel = xmlContent.includes('<channel>');
    const hasRdf = xmlContent.includes('<rdf:RDF') || xmlContent.includes('<RDF');
    const hasItem = xmlContent.includes('<item>');
    const hasEntry = xmlContent.includes('<entry>');

    console.info(TAG, `Format check: hasFeed=${hasFeed}, hasXmlns=${hasXmlns}, hasRss=${hasRss}, hasChannel=${hasChannel}, hasRdf=${hasRdf}, hasItem=${hasItem}, hasEntry=${hasEntry}`);

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
    throw new Error('不支持的格式：无法识别RSS或Atom');
  }

  private stringToArrayBuffer(str: string): ArrayBuffer {
    const encoder = new util.TextEncoder();
    const uint8Array = encoder.encodeInto(str);
    return uint8Array.buffer as ArrayBuffer;
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
      const buffer = this.stringToArrayBuffer(xmlContent);
      const parser = new xml.XmlPullParser(buffer, 'utf-8');
      let currentTag: string = '';
      let tagStack: string[] = [];
      let currentArticle: ParsedArticle | null = null;
      let inChannel: boolean = false;
      let inItem: boolean = false;
      let textBuffer: string = '';
      // 用于暂存 enclosure 属性
      let pendingEnclosureType: string = '';
      let pendingEnclosureUrl: string = '';
      // 标记是否正在处理 enclosure 标签
      let isProcessingEnclosure: boolean = false;

      const options: xml.ParseOptions = {
        supportDoctype: false,
        ignoreNameSpace: true,
        // 使用 attributeWithTagCallbackFunction 获取属性（SDK 20+）
        attributeWithTagCallbackFunction: (tagName: string, key: string, value: string): boolean => {
          console.info(TAG, `attributeWithTagCallback: tag=${tagName}, key=${key}, value=${value}`);
          if (tagName === 'enclosure') {
            isProcessingEnclosure = true;
            if (key === 'type') pendingEnclosureType = value;
            if (key === 'url') pendingEnclosureUrl = value;
          }
          return true;
        },
        tokenValueCallbackFunction: (eventType: xml.EventType, value: xml.ParseInfo): boolean => {
          if (eventType === xml.EventType.START_TAG) {
            currentTag = value.getName();
            tagStack.push(currentTag);
            textBuffer = '';

            console.info(TAG, `START_TAG: ${currentTag}, inChannel=${inChannel}, inItem=${inItem}, isEnclosure=${isProcessingEnclosure}`);

            if (currentTag === 'channel') inChannel = true;
            if (currentTag === 'item') {
              inItem = true;
              currentArticle = {
                guid: '', title: '', summary: '', content: '',
                url: '', author: '', publishedAt: 0, coverImage: ''
              };
            }
            // enclosure 的属性已由 attributeWithTagCallbackFunction 收集
            if (currentTag === 'enclosure' && currentArticle && isProcessingEnclosure) {
              console.info(TAG, `Processing enclosure: type=${pendingEnclosureType}, url=${pendingEnclosureUrl}`);
              if (pendingEnclosureType && pendingEnclosureType.startsWith('image/') && pendingEnclosureUrl) {
                currentArticle.coverImage = pendingEnclosureUrl;
              }
              pendingEnclosureType = '';
              pendingEnclosureUrl = '';
              isProcessingEnclosure = false;
            }
          } else if (eventType === xml.EventType.TEXT || eventType === xml.EventType.CDSECT) {
            // TEXT：普通文本；CDSECT：<![CDATA[...]]> 内容，两者都累积到 buffer
            textBuffer += value.getText();
          } else if (eventType === xml.EventType.END_TAG) {
            const tag: string = value.getName();
            const text: string = textBuffer.trim();
            tagStack.pop();

            console.info(TAG, `END_TAG: ${tag}, textLen=${text.length}, inItem=${inItem}`);

            if (inItem && currentArticle) {
              switch (tag) {
                case 'title': currentArticle.title = text; break;
                case 'link': if (!currentArticle.url) currentArticle.url = text; break;
                case 'guid': currentArticle.guid = text; break;
                case 'description': currentArticle.summary = this.stripHtml(text).slice(0, 300); break;
                case 'content:encoded':
                case 'encoded': currentArticle.content = text; break;
                case 'author':
                case 'dc:creator': currentArticle.author = text; break;
                case 'pubDate': currentArticle.publishedAt = this.parseDate(text); break;
                case 'item':
                  if (!currentArticle.guid) currentArticle.guid = currentArticle.url || currentArticle.title;
                  if (!currentArticle.content) currentArticle.content = `<p>${currentArticle.summary}</p>`;
                  console.info(TAG, `Adding article: ${currentArticle.title}, url=${currentArticle.url}, guid=${currentArticle.guid}`);
                  info.articles.push(currentArticle);
                  currentArticle = null;
                  inItem = false;
                  break;
              }
            } else if (inChannel && !inItem) {
              switch (tag) {
                case 'title': if (!info.title) info.title = text; break;
                case 'link': if (!info.siteUrl) info.siteUrl = text; break;
                case 'description': if (!info.description) info.description = text; break;
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
      const buffer = this.stringToArrayBuffer(xmlContent);
      const parser = new xml.XmlPullParser(buffer, 'utf-8');
      let inEntry: boolean = false;
      let currentArticle: ParsedArticle | null = null;
      let textBuffer: string = '';
      // 用于暂存 link 标签的属性
      let pendingLinkRel: string = '';
      let pendingLinkHref: string = '';
      let isProcessingLink: boolean = false;

      const options: xml.ParseOptions = {
        supportDoctype: false,
        ignoreNameSpace: true,
        // 使用 attributeWithTagCallbackFunction 获取属性（SDK 20+）
        attributeWithTagCallbackFunction: (tagName: string, key: string, value: string): boolean => {
          if (tagName === 'link') {
            isProcessingLink = true;
            if (key === 'rel') pendingLinkRel = value;
            if (key === 'href') pendingLinkHref = value;
          }
          return true;
        },
        tokenValueCallbackFunction: (eventType: xml.EventType, value: xml.ParseInfo): boolean => {
          if (eventType === xml.EventType.START_TAG) {
            const rawName: string = value.getName();
            const tagName: string = rawName.includes(':') ? rawName.split(':')[1] : rawName;
            textBuffer = '';

            console.info(TAG, `START_TAG: ${tagName}, inEntry=${inEntry}, isProcessingLink=${isProcessingLink}`);

            if (tagName === 'entry') {
              inEntry = true;
              currentArticle = {
                guid: '', title: '', summary: '', content: '',
                url: '', author: '', publishedAt: 0, coverImage: ''
              };
            }
            // 处理 link 标签 - 属性已由 attributeWithTagCallbackFunction 收集
            if (tagName === 'link' && isProcessingLink) {
              const rel: string = pendingLinkRel || 'alternate';
              const href: string = pendingLinkHref;

              console.info(TAG, `  -> Link: rel="${rel}", href="${href}"`);

              if (href) {
                if (inEntry && currentArticle) {
                  if (rel === 'alternate' && !currentArticle.url) {
                    currentArticle.url = href;
                    console.info(TAG, `  -> Set article URL: ${href}`);
                  }
                } else if (!inEntry) {
                  if (rel === 'alternate' && !info.siteUrl) {
                    info.siteUrl = href;
                    console.info(TAG, `  -> Set site URL: ${href}`);
                  }
                }
              }
              // 重置暂存的属性
              pendingLinkRel = '';
              pendingLinkHref = '';
              isProcessingLink = false;
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
                  if (!currentArticle.guid) currentArticle.guid = text;
                  break;
                case 'summary':
                  currentArticle.summary = this.stripHtml(text).slice(0, 300);
                  break;
                case 'content':
                  currentArticle.content = text;
                  break;
                case 'name':
                  if (!currentArticle.author) currentArticle.author = text;
                  break;
                case 'updated':
                case 'published':
                  if (!currentArticle.publishedAt) currentArticle.publishedAt = this.parseDate(text);
                  break;
                case 'entry':
                  if (!currentArticle.guid) currentArticle.guid = currentArticle.url || currentArticle.title;
                  if (!currentArticle.content) currentArticle.content = `<p>${currentArticle.summary}</p>`;
                  if (!currentArticle.summary) currentArticle.summary = currentArticle.title;
                  info.articles.push(currentArticle);
                  console.info(TAG, `  -> Completed article: "${currentArticle.title}" url="${currentArticle.url}"`);
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
                  if (!info.description) info.description = text;
                  break;
              }
            }

            textBuffer = '';
          }
          return true;
        }
      };
      parser.parse(options);
      console.info(TAG, `Atom parse completed: ${info.articles.length} articles, title="${info.title}", siteUrl="${info.siteUrl}"`);
    } catch (e) {
      console.error(TAG, `Atom parse error: ${e}`);
    }

    return info;
  }

  private stripHtml(html: string): string {
    return html.replace(/<[^>]+>/g, '').replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
      .replace(/&nbsp;/g, ' ').trim();
  }

  private parseDate(dateStr: string): number {
    if (!dateStr) return Date.now();
    try {
      const d = new Date(dateStr);
      return isNaN(d.getTime()) ? Date.now() : d.getTime();
    } catch {
      return Date.now();
    }
  }

  /**
   * 从文章HTML内容中提取第一张图片作为封面
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

    if (diff < minute) return '刚刚';
    if (diff < hour) return `${Math.floor(diff / minute)}分钟前`;
    if (diff < day) return `${Math.floor(diff / hour)}小时前`;
    if (diff < 7 * day) return `${Math.floor(diff / day)}天前`;

    const date = new Date(timestamp);
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  }
}
