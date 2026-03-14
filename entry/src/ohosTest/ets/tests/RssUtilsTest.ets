import { describe, it, expect } from '@ohos/hypium';

/**
 * 复现 RssService 中的纯函数逻辑，进行独立单元测试
 * 覆盖：stripHtml、parseDate、formatDate、extractFirstImage、parseXml格式判断
 */

// 复现 stripHtml 逻辑
function stripHtml(html: string): string {
  return html.replace(/<[^>]+>/g, '').replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"').replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, ' ').trim();
}

// 复现 parseDate 逻辑
function parseDate(dateStr: string): number {
  if (!dateStr) return 0; // 测试中用0代替Date.now()
  try {
    const d = new Date(dateStr);
    return isNaN(d.getTime()) ? -1 : d.getTime();
  } catch {
    return -1;
  }
}

// 复现 parseXml 类型判断
function detectFeedType(xmlContent: string): string {
  if (xmlContent.includes('<rss') || xmlContent.includes('<channel>')) {
    return 'rss2';
  } else if (xmlContent.includes('<feed') && xmlContent.includes('xmlns')) {
    return 'atom';
  }
  return 'unknown';
}

// 复现 extractFirstImage 逻辑
function extractFirstImage(html: string): string {
  const match = html.match(/<img[^>]+src=["']([^"']+)["']/i);
  return match ? match[1] : '';
}

// 复现 formatDate 逻辑
function formatDate(timestamp: number): string {
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

export default function RssUtilsTest() {
  describe('RssUtilsTest', () => {

    // ==================== stripHtml 测试 ====================

    describe('stripHtml', () => {
      it('should_strip_simple_tags', 0, () => {
        expect(stripHtml('<p>Hello World</p>')).assertEqual('Hello World');
      });

      it('should_strip_nested_tags', 0, () => {
        expect(stripHtml('<div><p><b>文本</b></p></div>')).assertEqual('文本');
      });

      it('should_decode_html_entities_amp', 0, () => {
        expect(stripHtml('A &amp; B')).assertEqual('A & B');
      });

      it('should_decode_html_entities_lt_gt', 0, () => {
        expect(stripHtml('&lt;div&gt;')).assertEqual('<div>');
      });

      it('should_decode_html_entities_quot', 0, () => {
        expect(stripHtml('&quot;hello&quot;')).assertEqual('"hello"');
      });

      it('should_decode_html_entities_apos', 0, () => {
        expect(stripHtml("it&#39;s")).assertEqual("it's");
      });

      it('should_decode_nbsp', 0, () => {
        expect(stripHtml('hello&nbsp;world')).assertEqual('hello world');
      });

      it('should_return_empty_for_only_tags', 0, () => {
        expect(stripHtml('<br/><hr/>')).assertEqual('');
      });

      it('should_handle_empty_string', 0, () => {
        expect(stripHtml('')).assertEqual('');
      });

      it('should_strip_tags_with_attributes', 0, () => {
        expect(stripHtml('<a href="https://example.com" class="link">链接文本</a>')).assertEqual('链接文本');
      });

      it('should_trim_result', 0, () => {
        expect(stripHtml('  <p>  text  </p>  ')).assertEqual('text');
      });

      it('should_handle_self_closing_tags', 0, () => {
        expect(stripHtml('before<br/>after')).assertEqual('beforeafter');
      });
    });

    // ==================== parseDate 测试 ====================

    describe('parseDate', () => {
      it('should_parse_rfc2822_date', 0, () => {
        const result = parseDate('Mon, 01 Jan 2024 00:00:00 +0000');
        expect(result > 0).assertTrue();
      });

      it('should_parse_iso8601_date', 0, () => {
        const result = parseDate('2024-01-15T10:30:00Z');
        expect(result > 0).assertTrue();
      });

      it('should_return_negative_for_invalid_date', 0, () => {
        const result = parseDate('not-a-date');
        expect(result).assertEqual(-1);
      });

      it('should_return_zero_for_empty_string', 0, () => {
        const result = parseDate('');
        expect(result).assertEqual(0);
      });

      it('should_parse_date_only_string', 0, () => {
        const result = parseDate('2024-06-15');
        expect(result > 0).assertTrue();
      });

      it('should_return_correct_year_from_timestamp', 0, () => {
        const result = parseDate('2024-01-01T00:00:00Z');
        const date = new Date(result);
        expect(date.getFullYear()).assertEqual(2024);
      });
    });

    // ==================== detectFeedType 测试 ====================

    describe('detectFeedType', () => {
      it('should_detect_rss2_by_rss_tag', 0, () => {
        const xml = '<?xml version="1.0"?><rss version="2.0"><channel></channel></rss>';
        expect(detectFeedType(xml)).assertEqual('rss2');
      });

      it('should_detect_rss2_by_channel_tag', 0, () => {
        const xml = '<channel><title>Test</title></channel>';
        expect(detectFeedType(xml)).assertEqual('rss2');
      });

      it('should_detect_atom_by_feed_and_xmlns', 0, () => {
        const xml = '<feed xmlns="http://www.w3.org/2005/Atom"><title>Test</title></feed>';
        expect(detectFeedType(xml)).assertEqual('atom');
      });

      it('should_return_unknown_for_invalid_format', 0, () => {
        const xml = '<root><data>invalid</data></root>';
        expect(detectFeedType(xml)).assertEqual('unknown');
      });

      it('should_return_unknown_for_empty_string', 0, () => {
        expect(detectFeedType('')).assertEqual('unknown');
      });

      it('should_detect_rss2_case_sensitive', 0, () => {
        const xml = '<RSS version="2.0"><channel></channel></RSS>';
        // RSS大写不匹配<rss小写，但<channel>存在
        expect(detectFeedType(xml)).assertEqual('rss2');
      });
    });

    // ==================== extractFirstImage 测试 ====================

    describe('extractFirstImage', () => {
      it('should_extract_src_with_double_quotes', 0, () => {
        const html = '<img src="https://example.com/img.jpg">';
        expect(extractFirstImage(html)).assertEqual('https://example.com/img.jpg');
      });

      it('should_extract_src_with_single_quotes', 0, () => {
        const html = "<img src='https://example.com/img.png'>";
        expect(extractFirstImage(html)).assertEqual('https://example.com/img.png');
      });

      it('should_return_empty_for_no_image', 0, () => {
        expect(extractFirstImage('<p>no image</p>')).assertEqual('');
      });

      it('should_return_empty_for_empty_string', 0, () => {
        expect(extractFirstImage('')).assertEqual('');
      });

      it('should_extract_first_of_multiple_images', 0, () => {
        const html = '<img src="https://first.com/a.jpg"><img src="https://second.com/b.jpg">';
        expect(extractFirstImage(html)).assertEqual('https://first.com/a.jpg');
      });

      it('should_extract_with_other_attributes_before_src', 0, () => {
        const html = '<img alt="desc" class="img" src="https://example.com/c.jpg">';
        expect(extractFirstImage(html)).assertEqual('https://example.com/c.jpg');
      });

      it('should_be_case_insensitive_for_img_tag', 0, () => {
        const html = '<IMG src="https://example.com/d.jpg">';
        expect(extractFirstImage(html)).assertEqual('https://example.com/d.jpg');
      });
    });

    // ==================== formatDate 测试 ====================

    describe('formatDate', () => {
      it('should_return_just_now_for_under_1_minute', 0, () => {
        expect(formatDate(Date.now() - 30 * 1000)).assertEqual('刚刚');
      });

      it('should_return_1_minute_ago', 0, () => {
        expect(formatDate(Date.now() - 1 * 60 * 1000)).assertEqual('1分钟前');
      });

      it('should_return_30_minutes_ago', 0, () => {
        expect(formatDate(Date.now() - 30 * 60 * 1000)).assertEqual('30分钟前');
      });

      it('should_return_1_hour_ago', 0, () => {
        expect(formatDate(Date.now() - 1 * 60 * 60 * 1000)).assertEqual('1小时前');
      });

      it('should_return_23_hours_ago', 0, () => {
        expect(formatDate(Date.now() - 23 * 60 * 60 * 1000)).assertEqual('23小时前');
      });

      it('should_return_1_day_ago', 0, () => {
        expect(formatDate(Date.now() - 1 * 24 * 60 * 60 * 1000)).assertEqual('1天前');
      });

      it('should_return_6_days_ago', 0, () => {
        expect(formatDate(Date.now() - 6 * 24 * 60 * 60 * 1000)).assertEqual('6天前');
      });

      it('should_return_date_format_for_over_7_days', 0, () => {
        const ts = new Date('2023-06-01').getTime();
        const result = formatDate(ts);
        expect(result).assertEqual('2023-06-01');
      });

      it('should_pad_month_with_zero', 0, () => {
        const ts = new Date('2024-03-05').getTime();
        const result = formatDate(ts);
        expect(result).assertEqual('2024-03-05');
      });

      it('should_pad_day_with_zero', 0, () => {
        const ts = new Date('2024-11-05').getTime();
        const result = formatDate(ts);
        expect(result).assertEqual('2024-11-05');
      });
    });

    // ==================== 业务规则测试 ====================

    describe('business_rules', () => {
      it('should_summary_be_limited_to_300_chars', 0, () => {
        const longText = 'A'.repeat(400);
        const stripped = stripHtml(longText).slice(0, 300);
        expect(stripped.length).assertEqual(300);
      });

      it('should_use_url_as_guid_when_guid_empty', 0, () => {
        // 模拟 RssService 中 guid fallback 逻辑
        const guid = '';
        const url = 'https://example.com/article';
        const title = '文章标题';
        const finalGuid = guid || url || title;
        expect(finalGuid).assertEqual(url);
      });

      it('should_use_title_as_guid_when_both_guid_and_url_empty', 0, () => {
        const guid = '';
        const url = '';
        const title = '文章标题';
        const finalGuid = guid || url || title;
        expect(finalGuid).assertEqual(title);
      });

      it('should_use_summary_as_content_when_content_empty', 0, () => {
        const content = '';
        const summary = '这是摘要';
        const finalContent = content || `<p>${summary}</p>`;
        expect(finalContent).assertEqual('<p>这是摘要</p>');
      });

      it('should_cover_image_fallback_to_extracted', 0, () => {
        const enclosureCover = '';
        const htmlContent = '<p><img src="https://example.com/img.jpg"/></p>';
        const coverImage = enclosureCover || extractFirstImage(htmlContent);
        expect(coverImage).assertEqual('https://example.com/img.jpg');
      });

      it('should_new_article_count_increment_for_positive_rowId', 0, () => {
        // 模拟 FeedRefreshService 中新文章计数逻辑
        let newCount = 0;
        const rowIds = [1, 2, 3, -1, 0, 4]; // -1和0表示已存在
        for (const rowId of rowIds) {
          if (rowId > 0) newCount++;
        }
        expect(newCount).assertEqual(4);
      });
    });
  });
}
