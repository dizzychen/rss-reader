import { http } from '@kit.NetworkKit';

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
        connectTimeout: 30000,  // 增加到 30 秒
        readTimeout: 60000,     // 增加到 60 秒
        usingCache: false,      // 禁用系统 HTTP 缓存，确保每次拿到最新内容
        header: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 12) AppleWebKit/537.36 Chrome/100.0 Mobile Safari/537.36',
          'Accept': 'application/rss+xml, application/atom+xml, application/xml, text/xml, */*',
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache, no-store',
          'Pragma': 'no-cache'
        }
      });
      console.info(TAG, `HTTP response code: ${response.responseCode}`);
      if (response.responseCode !== 200) {
        throw new Error(`HTTP 请求失败 (${response.responseCode})`);
      }
      const result = typeof response.result === 'string' ? response.result : String(response.result);
      console.info(TAG, `Fetched XML length: ${result.length}`);
      if (!result || result.length === 0) {
        throw new Error('服务器返回空内容');
      }
      return result;
    } catch (e) {
      // 处理网络错误（BusinessError）
      if (e instanceof Error) {
        throw e;
      }
      // BusinessError 类型有 code 和 message 属性
      const errObj = e as object;
      const code = (errObj as Record<string, number>)['code'];
      const message = (errObj as Record<string, string>)['message'];
      if (code !== undefined) {
        // 提供更友好的错误提示
        let friendlyMsg = message || '请检查网络连接';
        if (code === 2300028) {
          friendlyMsg = '连接超时，请检查网络或稍后重试';
        } else if (code === 2300006) {
          friendlyMsg = '无法解析域名，请检查网络连接';
        } else if (code === 2300007) {
          friendlyMsg = '无法连接服务器';
        }
        throw new Error(`网络错误: ${friendlyMsg}`);
      }
      throw new Error(`请求失败: ${JSON.stringify(e)}`);
    } finally {
      httpRequest.destroy();
    }
  }

  // ======================== 纯正则 XML 解析引擎 ========================

  /**
   * 从 XML 标签中提取文本内容（支持 CDATA）。
   * 匹配 <tagName>内容</tagName> 或 <tagName ...>内容</tagName>
   * 支持命名空间前缀：同时匹配 <ns:tagName> 和 <tagName>
   */
  private getTagContent(xml: string, tagName: string): string {
    // 构建正则：匹配可能有命名空间前缀的标签
    // 如 tagName="title" 则匹配 <title>...</title> 或 <dc:title>...</dc:title> 等
    const pattern = new RegExp(
      '<(?:[a-zA-Z0-9_]+:)?' + this.escapeRegex(tagName) +
      '(?:\\s[^>]*)?>([\\s\\S]*?)</(?:[a-zA-Z0-9_]+:)?' + this.escapeRegex(tagName) + '\\s*>',
      'i'
    );
    const match = xml.match(pattern);
    if (!match) {
      return '';
    }
    return this.unwrapCdata(match[1]).trim();
  }

  /**
   * 获取标签的属性值
   */
  private getTagAttribute(xml: string, tagName: string, attrName: string): string {
    const pattern = new RegExp(
      '<(?:[a-zA-Z0-9_]+:)?' + this.escapeRegex(tagName) +
      '\\s[^>]*?' + this.escapeRegex(attrName) + '\\s*=\\s*["\']([^"\']*)["\']',
      'i'
    );
    const match = xml.match(pattern);
    return match ? match[1] : '';
  }

  /**
   * 提取所有匹配指定标签的块
   */
  private getTagBlocks(xml: string, tagName: string): string[] {
    const blocks: string[] = [];
    const openPattern = new RegExp(
      '<(?:[a-zA-Z0-9_]+:)?' + this.escapeRegex(tagName) + '(?:\\s[^>]*)?>',
      'gi'
    );
    let openMatch = openPattern.exec(xml);
    while (openMatch !== null) {
      const startIdx = openMatch.index;
      const afterOpen = openMatch.index + openMatch[0].length;
      // 找到对应的闭合标签
      const closePattern = new RegExp(
        '</(?:[a-zA-Z0-9_]+:)?' + this.escapeRegex(tagName) + '\\s*>',
        'gi'
      );
      closePattern.lastIndex = afterOpen;
      const closeMatch = closePattern.exec(xml);
      if (closeMatch) {
        blocks.push(xml.substring(startIdx, closeMatch.index + closeMatch[0].length));
      }
      openMatch = openPattern.exec(xml);
    }
    return blocks;
  }

  /**
   * 提取标签内部内容（不含标签自身）
   */
  private getTagInnerContent(block: string, tagName: string): string {
    const openPattern = new RegExp(
      '<(?:[a-zA-Z0-9_]+:)?' + this.escapeRegex(tagName) + '(?:\\s[^>]*)?>',
      'i'
    );
    const openMatch = block.match(openPattern);
    if (!openMatch) {
      return block;
    }
    const afterOpen = (openMatch.index || 0) + openMatch[0].length;
    const closePattern = new RegExp(
      '</(?:[a-zA-Z0-9_]+:)?' + this.escapeRegex(tagName) + '\\s*>',
      'i'
    );
    const closeMatch = closePattern.exec(block.substring(afterOpen));
    if (!closeMatch) {
      return block.substring(afterOpen);
    }
    return block.substring(afterOpen, afterOpen + closeMatch.index);
  }

  /**
   * 解包 CDATA：<![CDATA[content]]> → content
   */
  private unwrapCdata(text: string): string {
    // 处理 CDATA 包裹
    const cdataPattern = /^<!\[CDATA\[([\s\S]*?)]]>$/;
    const cdataMatch = text.trim().match(cdataPattern);
    if (cdataMatch) {
      return cdataMatch[1];
    }
    // 处理内嵌的多个 CDATA 块
    return text.replace(/<!\[CDATA\[([\s\S]*?)]]>/g, '$1');
  }

  /**
   * 转义正则特殊字符
   */
  private escapeRegex(str: string): string {
    return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  }

  /**
   * 解码 XML 实体
   */
  private decodeXmlEntities(text: string): string {
    return text
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&apos;/g, "'")
      .replace(/&#(\d+);/g, (_match: string, code: string) => {
        return String.fromCharCode(parseInt(code, 10));
      })
      .replace(/&#x([0-9a-fA-F]+);/g, (_match: string, code: string) => {
        return String.fromCharCode(parseInt(code, 16));
      });
  }

  // ======================== Feed 格式检测与分发 ========================

  private parseXml(xmlContent: string): ParsedFeedInfo {
    console.info(TAG, `parseXml called, content length: ${xmlContent.length}`);

    // 检测 feed 格式并分发到对应的解析器
    if (xmlContent.includes('<rss') || xmlContent.includes('<RSS')) {
      console.info(TAG, 'Detected RSS 2.0 format');
      return this.parseRss2Feed(xmlContent);
    }

    if (xmlContent.includes('<feed') || xmlContent.includes('<FEED')) {
      console.info(TAG, 'Detected Atom format');
      return this.parseAtomFeed(xmlContent);
    }

    if (xmlContent.includes('<RDF') || xmlContent.includes('<rdf:RDF') || xmlContent.includes('<rdf:rdf')) {
      console.info(TAG, 'Detected RDF format');
      return this.parseRdfFeed(xmlContent);
    }

    throw new Error('不支持的格式：无法识别 RSS、Atom 或 RDF');
  }

  // ======================== RSS 2.0 解析 ========================

  private parseRss2Feed(xml: string): ParsedFeedInfo {
    // 提取 <channel> 块
    const channelBlocks = this.getTagBlocks(xml, 'channel');
    if (channelBlocks.length === 0) {
      throw new Error('RSS 格式错误：找不到 <channel> 标签');
    }
    const channelXml = channelBlocks[0];

    const info: ParsedFeedInfo = {
      title: this.decodeXmlEntities(this.getTagContent(channelXml, 'title')),
      siteUrl: this.decodeXmlEntities(this.getTagContent(channelXml, 'link')),
      description: this.stripHtml(this.getTagContent(channelXml, 'description')),
      iconUrl: '',
      articles: []
    };

    // 提取所有 <item> 块
    const itemBlocks = this.getTagBlocks(channelXml, 'item');
    console.info(TAG, `Found ${itemBlocks.length} RSS items`);

    for (const itemXml of itemBlocks) {
      const title = this.decodeXmlEntities(this.getTagContent(itemXml, 'title'));
      const link = this.decodeXmlEntities(this.getTagContent(itemXml, 'link'));
      const guid = this.decodeXmlEntities(this.getTagContent(itemXml, 'guid')) || link || title;
      const description = this.getTagContent(itemXml, 'description');
      const contentEncoded = this.getTagContent(itemXml, 'encoded');
      const author = this.decodeXmlEntities(
        this.getTagContent(itemXml, 'author') ||
        this.getTagContent(itemXml, 'creator')
      );
      const pubDate = this.decodeXmlEntities(
        this.getTagContent(itemXml, 'pubDate') ||
        this.getTagContent(itemXml, 'date')
      );

      // 封面图：按优先级依次从 enclosure → media:content/media:thumbnail → HTML 内容提取
      let coverImage = '';
      // 1. 尝试从 enclosure 提取
      const enclosureType = this.getTagAttribute(itemXml, 'enclosure', 'type');
      const enclosureUrl = this.getTagAttribute(itemXml, 'enclosure', 'url');
      if (enclosureUrl) {
        if (enclosureType.startsWith('image/') || this.isImageUrl(enclosureUrl)) {
          coverImage = enclosureUrl;
          console.info(TAG, `Cover from enclosure: ${coverImage.substring(0, 80)}`);
        }
      }
      // 2. 尝试从 media:content 或 media:thumbnail 精确提取
      if (!coverImage) {
        coverImage = this.extractMediaImage(itemXml);
        if (coverImage) {
          console.info(TAG, `Cover from media tag: ${coverImage.substring(0, 80)}`);
        }
      }

      const article: ParsedArticle = {
        guid: guid,
        title: title,
        summary: this.stripHtml(description).slice(0, 300),
        content: contentEncoded || description || '',
        url: link,
        author: author,
        publishedAt: this.parseDate(pubDate),
        coverImage: coverImage
      };

      if (!article.coverImage && article.content) {
        article.coverImage = this.extractFirstImage(article.content);
        if (article.coverImage) {
          console.info(TAG, `Cover from HTML content: ${article.coverImage.substring(0, 80)}`);
        }
      }

      info.articles.push(article);
    }

    console.info(TAG, `RSS2 parse completed: ${info.articles.length} articles`);
    return info;
  }

  // ======================== Atom 解析 ========================

  private parseAtomFeed(xml: string): ParsedFeedInfo {
    // 提取 <feed> 块
    const feedBlocks = this.getTagBlocks(xml, 'feed');
    if (feedBlocks.length === 0) {
      throw new Error('Atom 格式错误：找不到 <feed> 标签');
    }
    const feedXml = feedBlocks[0];

    const info: ParsedFeedInfo = {
      title: this.decodeXmlEntities(this.getTagContent(feedXml, 'title')),
      siteUrl: '',
      description: this.decodeXmlEntities(this.getTagContent(feedXml, 'subtitle')),
      iconUrl: '',
      articles: []
    };

    // 提取 siteUrl：从 <link> 标签中找 rel="alternate" 的 href
    info.siteUrl = this.extractAtomLink(feedXml, 'alternate') ||
      this.extractAtomLink(feedXml, '') ||
      this.decodeXmlEntities(this.getTagContent(feedXml, 'link'));

    // 提取所有 <entry> 块
    const entryBlocks = this.getTagBlocks(feedXml, 'entry');
    console.info(TAG, `Found ${entryBlocks.length} Atom entries`);

    for (const entryXml of entryBlocks) {
      const title = this.decodeXmlEntities(this.getTagContent(entryXml, 'title'));
      const id = this.decodeXmlEntities(this.getTagContent(entryXml, 'id'));
      const summary = this.getTagContent(entryXml, 'summary');
      const content = this.getTagContent(entryXml, 'content');
      const updated = this.decodeXmlEntities(
        this.getTagContent(entryXml, 'updated') ||
        this.getTagContent(entryXml, 'published')
      );

      // 提取链接
      const url = this.extractAtomLink(entryXml, 'alternate') ||
        this.extractAtomLink(entryXml, '');

      // 提取作者
      let author = '';
      const authorBlocks = this.getTagBlocks(entryXml, 'author');
      if (authorBlocks.length > 0) {
        author = this.decodeXmlEntities(this.getTagContent(authorBlocks[0], 'name'));
      }

      const article: ParsedArticle = {
        guid: id || url || title,
        title: this.stripHtml(title),
        summary: this.stripHtml(summary || title).slice(0, 300),
        content: content || summary || `<p>${title}</p>`,
        url: url,
        author: author,
        publishedAt: this.parseDate(updated),
        coverImage: ''
      };

      // 先尝试从 media:content / media:thumbnail 提取封面图
      article.coverImage = this.extractMediaImage(entryXml);
      if (article.coverImage) {
        console.info(TAG, `Atom cover from media tag: ${article.coverImage.substring(0, 80)}`);
      }

      // 回退到从 HTML 内容中提取
      if (!article.coverImage && article.content) {
        article.coverImage = this.extractFirstImage(article.content);
        if (article.coverImage) {
          console.info(TAG, `Atom cover from HTML content: ${article.coverImage.substring(0, 80)}`);
        }
      }

      info.articles.push(article);
    }

    console.info(TAG, `Atom parse completed: ${info.articles.length} articles`);
    return info;
  }

  /**
   * 从 XML 片段中提取 Atom <link> 标签的 href 属性。
   * 优先匹配指定 rel 值，relFilter 为空则匹配无 rel 属性的 link。
   */
  private extractAtomLink(xml: string, relFilter: string): string {
    // 匹配所有 <link .../> 或 <link ...>...</link> 标签
    const linkPattern = /<link\s([^>]*?)\/?>(?:<\/link>)?/gi;
    let linkMatch = linkPattern.exec(xml);
    let fallbackHref = '';

    while (linkMatch !== null) {
      const attrs = linkMatch[1];
      const hrefMatch = attrs.match(/href\s*=\s*["']([^"']*?)["']/i);
      const relMatch = attrs.match(/rel\s*=\s*["']([^"']*?)["']/i);
      const href = hrefMatch ? hrefMatch[1] : '';
      const rel = relMatch ? relMatch[1] : '';

      if (relFilter && rel === relFilter && href) {
        return this.decodeXmlEntities(href);
      }
      if (!relFilter && !rel && href && !fallbackHref) {
        fallbackHref = href;
      }
      // 如果没指定 relFilter 且有 href，作为备选
      if (!fallbackHref && href) {
        fallbackHref = href;
      }
      linkMatch = linkPattern.exec(xml);
    }

    return fallbackHref ? this.decodeXmlEntities(fallbackHref) : '';
  }

  // ======================== RDF 解析 ========================

  private parseRdfFeed(xml: string): ParsedFeedInfo {
    const info: ParsedFeedInfo = {
      title: '',
      siteUrl: '',
      description: '',
      iconUrl: '',
      articles: []
    };

    // 提取 <channel> 元信息
    const channelBlocks = this.getTagBlocks(xml, 'channel');
    if (channelBlocks.length > 0) {
      const channelXml = channelBlocks[0];
      info.title = this.decodeXmlEntities(this.getTagContent(channelXml, 'title'));
      info.siteUrl = this.decodeXmlEntities(this.getTagContent(channelXml, 'link'));
      info.description = this.stripHtml(this.getTagContent(channelXml, 'description'));
    }

    // 提取所有 <item> 块
    const itemBlocks = this.getTagBlocks(xml, 'item');
    console.info(TAG, `Found ${itemBlocks.length} RDF items`);

    for (const itemXml of itemBlocks) {
      const title = this.decodeXmlEntities(this.getTagContent(itemXml, 'title'));
      const link = this.decodeXmlEntities(this.getTagContent(itemXml, 'link'));
      const description = this.getTagContent(itemXml, 'description');
      const author = this.decodeXmlEntities(this.getTagContent(itemXml, 'creator'));
      const dateStr = this.decodeXmlEntities(this.getTagContent(itemXml, 'date'));

      // rdf:about 属性
      const about = this.getTagAttribute(itemXml, 'item', 'about') ||
        this.getTagAttribute(itemXml, 'item', 'rdf:about');

      const article: ParsedArticle = {
        guid: about || link || title,
        title: title,
        summary: this.stripHtml(description).slice(0, 300),
        content: description || `<p>${title}</p>`,
        url: link,
        author: author,
        publishedAt: this.parseDate(dateStr),
        coverImage: ''
      };

      // 先尝试从 media:content / media:thumbnail 提取封面图
      article.coverImage = this.extractMediaImage(itemXml);
      if (article.coverImage) {
        console.info(TAG, `RDF cover from media tag: ${article.coverImage.substring(0, 80)}`);
      }

      // 回退到从 HTML 内容中提取
      if (!article.coverImage && article.content) {
        article.coverImage = this.extractFirstImage(article.content);
        if (article.coverImage) {
          console.info(TAG, `RDF cover from HTML content: ${article.coverImage.substring(0, 80)}`);
        }
      }

      info.articles.push(article);
    }

    console.info(TAG, `RDF parse completed: ${info.articles.length} articles`);
    return info;
  }

  // ======================== 通用工具方法 ========================

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
    // 1. 标准 <img src="...">
    const srcMatch = html.match(/<img[^>]+src\s*=\s*["']([^"']+)["']/i);
    if (srcMatch) {
      return srcMatch[1];
    }
    // 2. 懒加载属性：data-src, data-original, data-lazy-src
    const lazySrcMatch = html.match(/<img[^>]+(?:data-src|data-original|data-lazy-src)\s*=\s*["']([^"']+)["']/i);
    if (lazySrcMatch) {
      return lazySrcMatch[1];
    }
    // 3. 视频封面 <video poster="...">
    const posterMatch = html.match(/<video[^>]+poster\s*=\s*["']([^"']+)["']/i);
    if (posterMatch) {
      return posterMatch[1];
    }
    // 4. <source srcset="..."> 中第一个 URL
    const srcsetMatch = html.match(/<source[^>]+srcset\s*=\s*["']([^\s"',]+)/i);
    if (srcsetMatch) {
      return srcsetMatch[1];
    }
    return '';
  }

  /**
   * 从 XML 片段中提取 media:content 或 media:thumbnail 的图片 URL。
   * 精确匹配 media: 命名空间，支持自闭合标签和非自闭合标签。
   * 结合 medium/type 属性判断是否为图片，不仅依赖 URL 扩展名。
   */
  extractMediaImage(xml: string): string {
    // 匹配所有 <media:content ... /> 或 <media:content ...>...</media:content> 标签
    const mediaContentPattern = /<media:content\s([^>]*?)(?:\/>|>[\s\S]*?<\/media:content>)/gi;
    let mediaMatch = mediaContentPattern.exec(xml);
    while (mediaMatch !== null) {
      const attrs = mediaMatch[1];
      const urlMatch = attrs.match(/url\s*=\s*["']([^"']+)["']/i);
      if (urlMatch) {
        const url = urlMatch[1];
        // 通过 medium 或 type 属性判断是否为图片
        const mediumMatch = attrs.match(/medium\s*=\s*["']([^"']+)["']/i);
        const typeMatch = attrs.match(/type\s*=\s*["']([^"']+)["']/i);
        const isImage = (mediumMatch && mediumMatch[1].toLowerCase() === 'image') ||
          (typeMatch && typeMatch[1].toLowerCase().startsWith('image/')) ||
          this.isImageUrl(url);
        if (isImage) {
          return url;
        }
      }
      mediaMatch = mediaContentPattern.exec(xml);
    }

    // 匹配 <media:thumbnail url="..." />
    const thumbnailPattern = /<media:thumbnail\s([^>]*?)(?:\/>|>[\s\S]*?<\/media:thumbnail>)/gi;
    const thumbMatch = thumbnailPattern.exec(xml);
    if (thumbMatch) {
      const attrs = thumbMatch[1];
      const urlMatch = attrs.match(/url\s*=\s*["']([^"']+)["']/i);
      if (urlMatch) {
        return urlMatch[1];
      }
    }

    return '';
  }

  /**
   * 判断 URL 是否指向图片（基于扩展名）
   */
  private isImageUrl(url: string): boolean {
    const lower = url.toLowerCase().split('?')[0].split('#')[0];
    // 移除末尾的路径参数
    const lastSegment = lower.split('/').pop() || '';
    return lastSegment.endsWith('.jpg') || lastSegment.endsWith('.jpeg') || lastSegment.endsWith('.png') ||
      lastSegment.endsWith('.gif') || lastSegment.endsWith('.webp') || lastSegment.endsWith('.svg') ||
      lastSegment.endsWith('.bmp') || lastSegment.endsWith('.ico') ||
      // 兼容常见图片 CDN 路径模式
      lower.includes('/img/') || lower.includes('/image/') || lower.includes('/photo/') ||
      lower.includes('.img.') || lower.includes('imageview') ||
      // 常见图片 CDN 域名特征
      lower.includes('img.') || lower.includes('pic.') || lower.includes('photo.') ||
      lower.includes('image.') || lower.includes('cdn.');
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
