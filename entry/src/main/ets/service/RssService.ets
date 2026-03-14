import { http } from '@kit.NetworkKit';
import { xml } from '@kit.ArkTS';
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
        connectTimeout: 10000,
        readTimeout: 15000,
        header: {
          'User-Agent': 'HarmonyOS-RSSReader/1.0',
          'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*'
        }
      });
      if (response.responseCode !== 200) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      const result = response.result as string;
      return result;
    } finally {
      httpRequest.destroy();
    }
  }

  private parseXml(xmlContent: string): ParsedFeedInfo {
    // 判断是 RSS 还是 Atom
    if (xmlContent.includes('<rss') || xmlContent.includes('<channel>')) {
      return this.parseRss2(xmlContent);
    } else if (xmlContent.includes('<feed') && xmlContent.includes('xmlns')) {
      return this.parseAtom(xmlContent);
    }
    throw new Error('不支持的格式：无法识别RSS或Atom');
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
      const parser = new xml.XmlPullParser({
        chunk: xmlContent,
        encoding: 'utf-8'
      });

      let currentTag = '';
      let tagStack: string[] = [];
      let currentArticle: ParsedArticle | null = null;
      let inChannel = false;
      let inItem = false;
      let textBuffer = '';

      const options: xml.ParseOptions = {
        supportDoctype: false,
        ignoreNameSpace: true,
        tokenValueCallbackFunction: (eventType: xml.EventType, value: xml.ParseInfo) => {
          if (eventType === xml.EventType.START_TAG) {
            currentTag = value.getName();
            tagStack.push(currentTag);
            textBuffer = '';
            if (currentTag === 'channel') inChannel = true;
            if (currentTag === 'item') {
              inItem = true;
              currentArticle = {
                guid: '', title: '', summary: '', content: '',
                url: '', author: '', publishedAt: 0, coverImage: ''
              };
            }
            // 提取 enclosure 图片
            if (currentTag === 'enclosure' && currentArticle) {
              const type = value.getAttributeValue('', 'type') || '';
              if (type.startsWith('image/')) {
                currentArticle.coverImage = value.getAttributeValue('', 'url') || '';
              }
            }
          } else if (eventType === xml.EventType.TEXT) {
            textBuffer += value.getText();
          } else if (eventType === xml.EventType.END_TAG) {
            const tag = value.getName();
            const text = textBuffer.trim();
            tagStack.pop();

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
              }
            }
            textBuffer = '';
          }
          return true;
        }
      };
      parser.parse(options);
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
      const parser = new xml.XmlPullParser({
        chunk: xmlContent,
        encoding: 'utf-8'
      });

      let currentTag = '';
      let currentArticle: ParsedArticle | null = null;
      let inEntry = false;
      let textBuffer = '';
      let linkRel = '';
      let linkHref = '';

      const options: xml.ParseOptions = {
        supportDoctype: false,
        ignoreNameSpace: true,
        tokenValueCallbackFunction: (eventType: xml.EventType, value: xml.ParseInfo) => {
          if (eventType === xml.EventType.START_TAG) {
            currentTag = value.getName();
            textBuffer = '';
            if (currentTag === 'entry') {
              inEntry = true;
              currentArticle = {
                guid: '', title: '', summary: '', content: '',
                url: '', author: '', publishedAt: 0, coverImage: ''
              };
            }
            if (currentTag === 'link') {
              linkRel = value.getAttributeValue('', 'rel') || 'alternate';
              linkHref = value.getAttributeValue('', 'href') || '';
              if (inEntry && currentArticle && (linkRel === 'alternate' || linkRel === '')) {
                currentArticle.url = linkHref;
              } else if (!inEntry && (linkRel === 'alternate' || linkRel === '')) {
                if (!info.siteUrl) info.siteUrl = linkHref;
              }
            }
          } else if (eventType === xml.EventType.TEXT) {
            textBuffer += value.getText();
          } else if (eventType === xml.EventType.END_TAG) {
            const tag = value.getName();
            const text = textBuffer.trim();

            if (inEntry && currentArticle) {
              switch (tag) {
                case 'title': currentArticle.title = this.stripHtml(text); break;
                case 'id': if (!currentArticle.guid) currentArticle.guid = text; break;
                case 'summary': currentArticle.summary = this.stripHtml(text).slice(0, 300); break;
                case 'content': currentArticle.content = text; break;
                case 'name': if (!currentArticle.author) currentArticle.author = text; break;
                case 'updated':
                case 'published': if (!currentArticle.publishedAt) currentArticle.publishedAt = this.parseDate(text); break;
                case 'entry':
                  if (!currentArticle.guid) currentArticle.guid = currentArticle.url || currentArticle.title;
                  if (!currentArticle.content) currentArticle.content = `<p>${currentArticle.summary}</p>`;
                  info.articles.push(currentArticle);
                  currentArticle = null;
                  inEntry = false;
                  break;
              }
            } else if (!inEntry) {
              switch (tag) {
                case 'title': if (!info.title) info.title = this.stripHtml(text); break;
                case 'subtitle': if (!info.description) info.description = text; break;
              }
            }
            textBuffer = '';
          }
          return true;
        }
      };
      parser.parse(options);
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
