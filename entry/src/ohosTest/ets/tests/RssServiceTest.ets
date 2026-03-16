import { describe, it, expect, beforeAll } from '@ohos/hypium';
import { RssService } from '../../../main/ets/service/RssService';

// 测试用 RSS 2.0 XML 内容
const MOCK_RSS2_XML = `<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>测试RSS源</title>
    <link>https://example.com</link>
    <description>这是一个测试RSS源</description>
    <item>
      <title>文章标题1</title>
      <link>https://example.com/article1</link>
      <guid>https://example.com/article1</guid>
      <description>&lt;p&gt;这是文章1的摘要内容&lt;/p&gt;</description>
      <author>作者A</author>
      <pubDate>Mon, 01 Jan 2024 00:00:00 +0000</pubDate>
    </item>
    <item>
      <title>文章标题2</title>
      <link>https://example.com/article2</link>
      <guid>guid-unique-002</guid>
      <description>文章2摘要</description>
      <pubDate>Tue, 02 Jan 2024 00:00:00 +0000</pubDate>
      <enclosure url="https://example.com/image.jpg" type="image/jpeg"/>
    </item>
  </channel>
</rss>`;

// 测试用 Atom XML 内容
const MOCK_ATOM_XML = `<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom">
  <title>Atom测试源</title>
  <subtitle>Atom源描述</subtitle>
  <link href="https://atom.example.com" rel="alternate"/>
  <entry>
    <id>https://atom.example.com/entry1</id>
    <title>Atom文章1</title>
    <link href="https://atom.example.com/entry1" rel="alternate"/>
    <summary>Atom文章1摘要</summary>
    <content>Atom文章1完整内容</content>
    <author><name>Atom作者</name></author>
    <published>2024-01-01T00:00:00Z</published>
  </entry>
  <entry>
    <id>atom-entry-002</id>
    <title>Atom文章2</title>
    <link href="https://atom.example.com/entry2" rel="alternate"/>
    <summary>Atom文章2摘要</summary>
    <updated>2024-01-02T00:00:00Z</updated>
  </entry>
</feed>`;

// 不支持的格式
const MOCK_INVALID_XML = `<?xml version="1.0"?><root><data>invalid</data></root>`;

export default function RssServiceTest() {
  describe('RssServiceTest', () => {
    let service: RssService;

    beforeAll(() => {
      service = RssService.getInstance();
    });

    // ==================== 单例模式测试 ====================

    describe('getInstance', () => {
      it('should_return_same_instance', 0, () => {
        const s1 = RssService.getInstance();
        const s2 = RssService.getInstance();
        expect(s1).assertEqual(s2);
      });
    });

    // ==================== formatDate 测试 ====================

    describe('formatDate', () => {
      it('should_return_just_now_for_recent_time', 0, () => {
        const now = Date.now();
        const result = service.formatDate(now - 10000); // 10秒前
        expect(result).assertEqual('刚刚');
      });

      it('should_return_minutes_ago', 0, () => {
        const now = Date.now();
        const result = service.formatDate(now - 5 * 60 * 1000); // 5分钟前
        expect(result).assertEqual('5分钟前');
      });

      it('should_return_hours_ago', 0, () => {
        const now = Date.now();
        const result = service.formatDate(now - 3 * 60 * 60 * 1000); // 3小时前
        expect(result).assertEqual('3小时前');
      });

      it('should_return_days_ago', 0, () => {
        const now = Date.now();
        const result = service.formatDate(now - 2 * 24 * 60 * 60 * 1000); // 2天前
        expect(result).assertEqual('2天前');
      });

      it('should_return_formatted_date_for_old_article', 0, () => {
        const timestamp = new Date('2024-01-15').getTime();
        const result = service.formatDate(timestamp);
        expect(result).assertEqual('2024-01-15');
      });

      it('should_return_just_now_for_exactly_now', 0, () => {
        const result = service.formatDate(Date.now());
        expect(result).assertEqual('刚刚');
      });

      it('should_return_59_minutes_ago_for_boundary', 0, () => {
        const now = Date.now();
        const result = service.formatDate(now - 59 * 60 * 1000);
        expect(result).assertEqual('59分钟前');
      });

      it('should_return_date_for_7_days_ago', 0, () => {
        const now = Date.now();
        const sevenDaysAgo = now - 7 * 24 * 60 * 60 * 1000;
        const result = service.formatDate(sevenDaysAgo);
        // 7天前应返回日期格式
        expect(result.includes('-')).assertTrue();
        expect(result.length).assertEqual(10); // YYYY-MM-DD
      });
    });

    // ==================== extractFirstImage 测试 ====================

    describe('extractFirstImage', () => {
      it('should_extract_image_with_double_quotes', 0, () => {
        const html = '<p><img src="https://example.com/img.jpg" alt="test"/></p>';
        const result = service.extractFirstImage(html);
        expect(result).assertEqual('https://example.com/img.jpg');
      });

      it('should_extract_image_with_single_quotes', 0, () => {
        const html = "<img src='https://example.com/photo.png'>";
        const result = service.extractFirstImage(html);
        expect(result).assertEqual('https://example.com/photo.png');
      });

      it('should_return_empty_string_when_no_image', 0, () => {
        const html = '<p>纯文字内容，没有图片</p>';
        const result = service.extractFirstImage(html);
        expect(result).assertEqual('');
      });

      it('should_return_empty_string_for_empty_html', 0, () => {
        const result = service.extractFirstImage('');
        expect(result).assertEqual('');
      });

      it('should_extract_first_image_when_multiple_exist', 0, () => {
        const html = '<img src="https://first.com/img.jpg"><img src="https://second.com/img.png">';
        const result = service.extractFirstImage(html);
        expect(result).assertEqual('https://first.com/img.jpg');
      });

      it('should_extract_image_with_extra_attributes', 0, () => {
        const html = '<img class="cover" width="100" src="https://example.com/cover.jpg" height="100">';
        const result = service.extractFirstImage(html);
        expect(result).assertEqual('https://example.com/cover.jpg');
      });
    });

    // ==================== stripHtml 测试 ====================

    describe('stripHtml', () => {
      it('should_remove_html_tags', 0, () => {
        const html = '<p>Hello <b>World</b></p>';
        const result = (service as any).stripHtml(html);
        expect(result).assertEqual('Hello World');
      });

      it('should_decode_html_entities', 0, {
        const html = 'Tom &amp; Jerry &lt;3';
        const result = (service as any).stripHtml(html);
        expect(result).assertEqual('Tom & Jerry <3');
      });

      it('should_handle_empty_string', 0, () => {
        const result = (service as any).stripHtml('');
        expect(result).assertEqual('');
      });

      it('should_handle_plain_text', 0, () => {
        const result = (service as any).stripHtml('Just plain text');
        expect(result).assertEqual('Just plain text');
      });
    });

    // ==================== parseDate 测试 ====================

    describe('parseDate', () => {
      it('should_parse_iso_date', 0, () => {
        const result = (service as any).parseDate('2024-03-15T10:30:00Z');
        expect(result).assertGreaterThan(0);
      });

      it('should_parse_rfc822_date', 0, () => {
        const result = (service as any).parseDate('Fri, 15 Mar 2024 10:30:00 GMT');
        expect(result).assertGreaterThan(0);
      });

      it('should_return_now_for_empty', 0, () => {
        const now = Date.now();
        const result = (service as any).parseDate('');
        expect(result).assertGreaterThan(now - 1000);
      });

      it('should_return_now_for_invalid', 0, () => {
        const now = Date.now();
        const result = (service as any).parseDate('invalid');
        expect(result).assertGreaterThan(now - 1000);
      });
    });

    // ==================== parseRss2 测试 ====================

    describe('parseRss2', () => {
      it('should_parse_rss2_feed', 0, () => {
        const result = (service as any).parseRss2(MOCK_RSS2_XML);
        expect(result.title).assertEqual('测试 RSS 源');
        expect(result.siteUrl).assertEqual('https://example.com');
        expect(result.articles.length).assertEqual(2);
      });

      it('should_parse_enclosure_image', 0, () => {
        const result = (service as any).parseRss2(MOCK_RSS2_XML);
        expect(result.articles[1].coverImage).assertEqual('https://example.com/image.jpg');
      });

      it('should_decode_html_in_description', 0, () => {
        const result = (service as any).parseRss2(MOCK_RSS2_XML);
        // 摘要应包含 HTML 解码后的内容
        expect(result.articles[0].summary).assertContain('文章 1');
      });

      it('should_fallback_guid_to_url', 0, () => {
        const rssNoGuid = `<?xml version="1.0"?>
        <rss version="2.0"><channel><title>Test</title>
        <item><title>No Guid</title><link>https://example.com/item</link></item>
        </channel></rss>`;
        const result = (service as any).parseRss2(rssNoGuid);
        expect(result.articles[0].guid).assertEqual('https://example.com/item');
      });
    });

    // ==================== parseAtom 测试 ====================

    describe('parseAtom', () => {
      it('should_parse_atom_feed', 0, () => {
        const result = (service as any).parseAtom(MOCK_ATOM_XML);
        expect(result.title).assertEqual('Atom 测试源');
        expect(result.siteUrl).assertEqual('https://atom.example.com');
        expect(result.articles.length).assertEqual(2);
      });

      it('should_parse_link_href', 0, () => {
        const result = (service as any).parseAtom(MOCK_ATOM_XML);
        expect(result.articles[0].url).assertEqual('https://atom.example.com/entry1');
      });

      it('should_parse_author_name', 0, () => {
        const result = (service as any).parseAtom(MOCK_ATOM_XML);
        expect(result.articles[0].author).assertEqual('Atom 作者');
      });

      it('should_fallback_guid_to_url', 0, () => {
        const result = (service as any).parseAtom(MOCK_ATOM_XML);
        expect(result.articles[1].guid).assertEqual('atom-entry-002');
      });
    });

    // ==================== parseXml 格式检测测试 ====================

    describe('parseXml Format Detection', () => {
      it('should_detect_rss2', 0, () => {
        const result = (service as any).parseXml(MOCK_RSS2_XML);
        expect(result).toBeDefined();
      });

      it('should_detect_atom', 0, () => {
        const result = (service as any).parseXml(MOCK_ATOM_XML);
        expect(result).toBeDefined();
      });

      it('should_throw_for_invalid_format', 0, () => {
        try {
          (service as any).parseXml(MOCK_INVALID_XML);
          expect(true).assertEqual(false); // Should not reach
        } catch (e) {
          expect((e as Error).message).assertContain('不支持的格式');
        }
      });
    });
  });
}
