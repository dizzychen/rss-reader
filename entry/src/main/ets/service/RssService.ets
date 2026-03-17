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

    const hasFeed = xmlContent.includes('<feed');
    const hasXmlns = xmlContent.includes('xmlns');
    const hasRss = xmlContent.includes('<rss');
    const hasChannel = xmlContent.includes('<channel>');
    const hasItem = xmlContent.includes('<item>');
    const hasEntry = xmlContent.includes('<entry>');

    console.info(TAG, `Format: feed=${hasFeed}, xmlns=${hasXmlns}, rss=${hasRss}, channel=${hasChannel}, item=${hasItem}, entry=${hasEntry}`);

    if ((hasFeed && hasXmlns) || hasEntry) {
      console.info(TAG, 'Detected Atom format');
      return this.parseAtom(xmlContent);
    }
    if (hasRss || hasChannel || hasItem) {
      console.info(TAG, 'Detected RSS format');
      return this.parseRss2(xmlContent);
    }
    throw new Error('不支持的格式：无法识别 RSS 或 Atom');
  }

  private stringToArrayBuffer(str: string): ArrayBuffer {
    const encoder = new util.TextEncoder();
    const uint8Array = encoder.encodeInto(str);
    return uint8Array.buffer as ArrayBuffer;
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

  /**
   * 预先解析 XML 中所有 enclosure 标签的属性
   */
  private extractEnclosures(xmlContent: string): Array<{ type: string; url: string }> {
    const enclosures: Array<{ type: string; url: string }> = [];
    const regex = /<enclosure\s+([^>]*?)\s*\/?>/gi;
    let match: RegExpExecArray | null;

    while ((match = regex.exec(xmlContent)) !== null) {
      const attrs = match[1];
      const typeMatch = attrs.match(/type\s*=\s*["']([^"']+)["']/i);
      const urlMatch = attrs.match(/url\s*=\s*["']([^"']+)["']/i);
      enclosures.push({
        type: typeMatch ? typeMatch[1] : '',
        url: urlMatch ? urlMatch[1] : ''
      });
    }

    return enclosures;
  }

  /**
   * 预先解析 XML 中所有 link 标签的属性
   */
  private extractLinks(xmlContent: string): Array<{ rel: string; href: string; inEntry: boolean }> {
    const links: Array<{ rel: string; href: string; inEntry: boolean }> = [];
    const regex = /<link\s+([^>]*?)\s*\/?>/gi;
    let match: RegExpExecArray | null;

    while ((match = regex.exec(xmlContent)) !== null) {
      const attrs = match[1];
      const relMatch = attrs.match(/rel\s*=\s*["']([^"']+)["']/i);
      const hrefMatch = attrs.match(/href\s*=\s*["']([^"']+)["']/i);

      const beforeLink = xmlContent.substring(0, match.index);
      const entryOpens = (beforeLink.match(/<entry>/g) || []).length;
      const entryCloses = (beforeLink.match(/<\/entry>/g) || []).length;
      const inEntry = entryOpens > entryCloses;

      links.push({
        rel: relMatch ? relMatch[1] : 'alternate',
        href: hrefMatch ? hrefMatch[1] : '',
        inEntry: inEntry
      });
    }

    return links;
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
      const enclosures = this.extractEnclosures(xmlContent);
      const buffer = this.stringToArrayBuffer(xmlContent);
      const parser = new xml.XmlPullParser(buffer, 'utf-8');

      let currentTag = '';
      let currentArticle: ParsedArticle | null = null;
      let inChannel = false;
      let inItem = false;
      let textBuffer = '';
      let enclosureIndex = 0;

      const options: xml.ParseOptions = {
        supportDoctype: false,
        ignoreNameSpace: true,
        tokenValueCallbackFunction: (eventType: xml.EventType, value: xml.ParseInfo): boolean => {
          if (eventType === xml.EventType.START_TAG) {
            currentTag = value.getName();
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
            if (currentTag === 'enclosure' && currentArticle) {
              const enc = enclosures[enclosureIndex];
              if (enc && enc.type.startsWith('image/') && enc.url) {
                currentArticle.coverImage = enc.url;
              }
              enclosureIndex++;
            }
          } else if (eventType === xml.EventType.TEXT || eventType === xml.EventType.CDSECT) {
            textBuffer += value.getText();
          } else if (eventType === xml.EventType.END_TAG) {
            const tag = value.getName();
            const text = textBuffer.trim();

            if (inItem && currentArticle) {
              if (tag === 'title') {
                currentArticle.title = text;
              } else if (tag === 'link') {
                if (!currentArticle.url) {
                  currentArticle.url = text;
                }
              } else if (tag === 'guid') {
                currentArticle.guid = text;
              } else if (tag === 'description') {
                currentArticle.summary = this.stripHtml(text).slice(0, 300);
              } else if (tag === 'content:encoded' || tag === 'encoded') {
                currentArticle.content = text;
              } else if (tag === 'author' || tag === 'dc:creator') {
                currentArticle.author = text;
              } else if (tag === 'pubDate') {
                currentArticle.publishedAt = this.parseDate(text);
              } else if (tag === 'item') {
                if (!currentArticle.guid) {
                  currentArticle.guid = currentArticle.url || currentArticle.title;
                }
                if (!currentArticle.content) {
                  currentArticle.content = `<p>${currentArticle.summary}</p>`;
                }
                info.articles.push(currentArticle);
                currentArticle = null;
                inItem = false;
              }
            } else if (inChannel && !inItem) {
              if (tag === 'title' && !info.title) {
                info.title = text;
              } else if (tag === 'link' && !info.siteUrl) {
                info.siteUrl = text;
              } else if (tag === 'description' && !info.description) {
                info.description = text;
              } else if (tag === 'channel') {
                inChannel = false;
              }
            }
            textBuffer = '';
          }
          return true;
        }
      };

      parser.parse(options);
      console.info(TAG, `RSS2 parse completed: ${info.articles.length} articles`);
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
      const links = this.extractLinks(xmlContent);
      const buffer = this.stringToArrayBuffer(xmlContent);
      const parser = new xml.XmlPullParser(buffer, 'utf-8');

      let inEntry = false;
      let currentArticle: ParsedArticle | null = null;
      let textBuffer = '';
      let linkIndex = 0;

      const options: xml.ParseOptions = {
        supportDoctype: false,
        ignoreNameSpace: true,
        tokenValueCallbackFunction: (eventType: xml.EventType, value: xml.ParseInfo): boolean => {
          if (eventType === xml.EventType.START_TAG) {
            const rawName = value.getName();
            const tagName = rawName.includes(':') ? rawName.split(':')[1] : rawName;
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
            if (tagName === 'link' && linkIndex < links.length) {
              const link = links[linkIndex];
              linkIndex++;

              if (inEntry && currentArticle && link.rel === 'alternate' && !currentArticle.url) {
                currentArticle.url = link.href;
              } else if (!inEntry && link.rel === 'alternate' && !info.siteUrl) {
                info.siteUrl = link.href;
              }
            }
          } else if (eventType === xml.EventType.TEXT || eventType === xml.EventType.CDSECT) {
            textBuffer += value.getText();
          } else if (eventType === xml.EventType.END_TAG) {
            const rawName = value.getName();
            const tagName = rawName.includes(':') ? rawName.split(':')[1] : rawName;
            const text = textBuffer.trim();

            if (inEntry && currentArticle) {
              if (tagName === 'title') {
                currentArticle.title = this.stripHtml(text);
              } else if (tagName === 'id' && !currentArticle.guid) {
                currentArticle.guid = text;
              } else if (tagName === 'summary') {
                currentArticle.summary = this.stripHtml(text).slice(0, 300);
              } else if (tagName === 'content') {
                currentArticle.content = text;
              } else if (tagName === 'name' && !currentArticle.author) {
                currentArticle.author = text;
              } else if (tagName === 'updated' || tagName === 'published') {
                if (!currentArticle.publishedAt) {
                  currentArticle.publishedAt = this.parseDate(text);
                }
              } else if (tagName === 'entry') {
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
              }
            } else if (!inEntry) {
              if (tagName === 'title' && !info.title) {
                info.title = this.stripHtml(text);
              } else if (tagName === 'subtitle' && !info.description) {
                info.description = text;
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
}
