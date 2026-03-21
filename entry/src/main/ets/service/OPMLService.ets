// OPML 导入导出服务
// OPML 2.0 标准格式：https://dev.opml.org/spec2.html

import { RssService, ParsedFeedInfo } from './RssService';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { Feed } from '../model/Models';

export interface ImportResult {
  success: number;
  failed: number;
  skipped: number;
  errors: string[];
}

export interface OPMLFeedItem {
  title: string;
  url: string;
  siteUrl?: string;
}

export class OPMLService {
  private static instance: OPMLService;

  static getInstance(): OPMLService {
    if (!OPMLService.instance) {
      OPMLService.instance = new OPMLService();
    }
    return OPMLService.instance;
  }

  // ===== 导出 =====

  /**
   * 将 Feed 列表生成标准 OPML 2.0 XML 字符串
   */
  generateOPML(feeds: Feed[]): string {
    const now = new Date();
    const dateStr = now.toUTCString();

    let lines: string[] = [];
    lines.push('<?xml version="1.0" encoding="UTF-8"?>');
    lines.push('<opml version="2.0">');
    lines.push('  <head>');
    lines.push('    <title>RssReader Subscriptions</title>');
    lines.push(`    <dateCreated>${dateStr}</dateCreated>`);
    lines.push('  </head>');
    lines.push('  <body>');

    for (const feed of feeds) {
      const title = this.escapeXML(feed.title || '');
      const xmlUrl = this.escapeXML(feed.url || '');
      const htmlUrl = this.escapeXML(feed.siteUrl || '');
      const desc = this.escapeXML(feed.description || '');

      let outline = `    <outline type="rss" text="${title}" title="${title}" xmlUrl="${xmlUrl}"`;
      if (htmlUrl) {
        outline += ` htmlUrl="${htmlUrl}"`;
      }
      if (desc) {
        outline += ` description="${desc}"`;
      }
      outline += '  />';
      lines.push(outline);
    }

    lines.push('  </body>');
    lines.push('</opml>');

    return lines.join('\n');
  }

  /**
   * 生成带时间戳的 OPML 文件名
   */
  generateOPMLFilename(): string {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');
    return `opml-export-${year}-${month}-${day}-${hours}${minutes}${seconds}.opml`;
  }

  // ===== 导入解析 =====

  /**
   * 解析 OPML XML 内容，提取所有 RSS 订阅源
   * 支持 OPML 1.0 和 2.0 格式，容错处理多种变体
   */
  parseOPML(xmlContent: string): OPMLFeedItem[] {
    const feeds: OPMLFeedItem[] = [];

    if (!xmlContent || xmlContent.trim().length === 0) {
      return feeds;
    }

    // 匹配 <outline> 标签 (type="rss" 或 type="atom"，大小写不敏感)
    // 支持属性顺序不固定，属性值用单引号或双引号的变体
    const outlinePattern = /<outline\b([^>]*\/?>)/gi;
    let match: RegExpExecArray | null;

    while ((match = outlinePattern.exec(xmlContent)) !== null) {
      const attrs = match[1];

      // 只处理 type="rss" 或 type="atom" 的节点（或无 type，但有 xmlUrl 的节点）
      const typeMatch = /\btype\s*=\s*["']([^"']*)["']/i.exec(attrs);
      const typeValue = typeMatch ? typeMatch[1].toLowerCase() : '';

      // 提取 xmlUrl
      const xmlUrlMatch = /\bxmlUrl\s*=\s*["']([^"']*)["']/i.exec(attrs);
      if (!xmlUrlMatch || !xmlUrlMatch[1]) {
        continue; // 没有 xmlUrl，跳过（如分组节点）
      }

      // 如果有 type，必须是 rss/atom；如果没有 type 但有 xmlUrl，也视为合法
      if (typeValue && typeValue !== 'rss' && typeValue !== 'atom' && typeValue !== 'link') {
        continue;
      }

      const xmlUrl = this.unescapeXML(xmlUrlMatch[1].trim());
      if (!xmlUrl || (!xmlUrl.startsWith('http://') && !xmlUrl.startsWith('https://'))) {
        continue;
      }

      // 提取 title（先取 title，再取 text）
      const titleMatch = /\btitle\s*=\s*["']([^"']*)["']/i.exec(attrs);
      const textMatch = /\btext\s*=\s*["']([^"']*)["']/i.exec(attrs);
      const title = this.unescapeXML(
        (titleMatch && titleMatch[1]) ? titleMatch[1] : (textMatch ? textMatch[1] : '')
      ).trim() || xmlUrl;

      // 提取 htmlUrl（可选）
      const htmlUrlMatch = /\bhtmlUrl\s*=\s*["']([^"']*)["']/i.exec(attrs);
      const siteUrl = htmlUrlMatch ? this.unescapeXML(htmlUrlMatch[1].trim()) : undefined;

      feeds.push({ title, url: xmlUrl, siteUrl });
    }

    return feeds;
  }

  // ===== 批量导入 =====

  /**
   * 批量导入订阅源
   * 重复 URL 时：覆盖更新 Feed 的元数据（标题、描述等）
   */
  async importFeeds(
    items: OPMLFeedItem[],
    groupId: number
  ): Promise<ImportResult> {
    const result: ImportResult = {
      success: 0,
      failed: 0,
      skipped: 0,
      errors: []
    };

    if (!items || items.length === 0) {
      return result;
    }

    const db = DatabaseHelper.getInstance();
    const rss = RssService.getInstance();

    for (const item of items) {
      try {
        console.info('OPMLService', `Importing: ${item.url}`);

        // 检查是否已存在
        const existing = await db.getFeedByUrl(item.url);

        // 抓取并解析订阅源
        let info: ParsedFeedInfo = {
          title: item.title,
          siteUrl: item.siteUrl || '',
          description: '',
          iconUrl: '',
          articles: []
        };

        try {
          info = await rss.fetchFeedInfo(item.url);
        } catch (fetchErr) {
          // 网络请求失败：若 URL 已存在则跳过，否则创建占位 Feed
          if (existing) {
            result.skipped++;
            console.warn('OPMLService', `Feed already exists, skipping fetch error for: ${item.url}`);
            continue;
          }
          // 创建基础占位 Feed（不抓取内容）
          info.title = item.title || item.url;
          info.siteUrl = item.siteUrl || '';
        }

        const feedData: Feed = {
          title: info.title || item.title || item.url,
          url: item.url,
          siteUrl: info.siteUrl || item.siteUrl || '',
          iconUrl: info.iconUrl || '',
          description: info.description || '',
          groupId: groupId,
          lastUpdated: Date.now()
        };

        let feedId: number;

        if (existing && existing.id) {
          // 覆盖更新现有 Feed（保留原有 id）
          feedData.id = existing.id;
          await db.updateFeed(feedData);
          feedId = existing.id;
          console.info('OPMLService', `Updated existing feed id=${feedId}`);
        } else {
          // 插入新 Feed
          feedId = await db.insertFeed(feedData);
          if (feedId === -1) {
            // 并发情况导致的冲突，查询已有的
            const found = await db.getFeedByUrl(item.url);
            if (found && found.id) {
              feedId = found.id;
            } else {
              throw new Error('数据库写入异常');
            }
          }
          console.info('OPMLService', `Inserted new feed id=${feedId}`);
        }

        result.success++;

        // 文章后台异步插入，不阻塞导入进度
        const articlesToSave = info.articles;
        const savedFeedId = feedId;
        Promise.resolve().then(async () => {
          for (const pa of articlesToSave) {
            try {
              const coverImage = pa.coverImage || rss.extractFirstImage(pa.content);
              await db.insertOrUpdateArticle({
                feedId: savedFeedId,
                guid: pa.guid,
                title: pa.title,
                summary: pa.summary,
                content: pa.content,
                url: pa.url,
                author: pa.author,
                publishedAt: pa.publishedAt,
                isRead: 0,
                isStarred: 0,
                coverImage: coverImage
              });
            } catch (articleErr) {
              // 文章插入失败不影响整体导入结果
              console.warn('OPMLService', `Article insert error: ${articleErr instanceof Error ? articleErr.message : String(articleErr)}`);
            }
          }
          console.info('OPMLService', `Background: inserted ${articlesToSave.length} articles for feed ${savedFeedId}`);
        }).catch((e: Error) => {
          console.error('OPMLService', `Background article insert error: ${e?.message || String(e)}`);
        });

      } catch (e) {
        const errMsg = e instanceof Error ? e.message : String(e);
        console.error('OPMLService', `Failed to import ${item.url}: ${errMsg}`);
        result.failed++;
        result.errors.push(`${item.url}: ${errMsg}`);
      }
    }

    return result;
  }

  // ===== 工具方法 =====

  /**
   * 转义 XML 特殊字符（用于生成 XML 输出）
   */
  private escapeXML(str: string): string {
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }

  /**
   * 反转义 XML 特殊字符（用于解析 XML 输入）
   */
  private unescapeXML(str: string): string {
    return str
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&apos;/g, "'")
      .replace(/&#39;/g, "'")
      .replace(/&#x27;/g, "'")
      .replace(/&#(\d+);/g, (_match: string, dec: string) => String.fromCharCode(parseInt(dec, 10)));
  }
}
