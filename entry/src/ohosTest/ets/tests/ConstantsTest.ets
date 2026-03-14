import { describe, it, expect } from '@ohos/hypium';
import { Constants } from '../../../main/ets/constants/Constants';

export default function ConstantsTest() {
  describe('ConstantsTest', () => {

    // ==================== 数据库配置测试 ====================

    describe('database_constants', () => {
      it('should_have_correct_db_name', 0, () => {
        expect(Constants.DB_NAME).assertEqual('rss_reader.db');
      });

      it('should_have_correct_db_version', 0, () => {
        expect(Constants.DB_VERSION).assertEqual(1);
      });

      it('should_have_correct_table_names', 0, () => {
        expect(Constants.TABLE_FEEDS).assertEqual('feeds');
        expect(Constants.TABLE_ARTICLES).assertEqual('articles');
        expect(Constants.TABLE_GROUPS).assertEqual('groups');
        expect(Constants.TABLE_TAGS).assertEqual('tags');
        expect(Constants.TABLE_ARTICLE_TAGS).assertEqual('article_tags');
      });
    });

    // ==================== Preferences 键名测试 ====================

    describe('preferences_keys', () => {
      it('should_have_pref_name', 0, () => {
        expect(Constants.PREF_NAME).assertEqual('rss_settings');
      });

      it('should_have_all_pref_keys', 0, () => {
        expect(Constants.PREF_REFRESH_INTERVAL).assertEqual('refresh_interval');
        expect(Constants.PREF_BG_REFRESH).assertEqual('bg_refresh_enabled');
        expect(Constants.PREF_NOTIFICATION).assertEqual('notification_enabled');
        expect(Constants.PREF_FONT_SIZE).assertEqual('font_size');
        expect(Constants.PREF_OPEN_ORIGINAL).assertEqual('open_original_in_app');
        expect(Constants.PREF_CACHE_COUNT).assertEqual('cache_count_per_feed');
      });
    });

    // ==================== 默认值测试 ====================

    describe('default_values', () => {
      it('should_have_correct_default_refresh_interval', 0, () => {
        expect(Constants.DEFAULT_REFRESH_INTERVAL).assertEqual(30);
      });

      it('should_have_correct_default_cache_count', 0, () => {
        expect(Constants.DEFAULT_CACHE_COUNT).assertEqual(50);
      });

      it('should_have_correct_default_font_size', 0, () => {
        expect(Constants.DEFAULT_FONT_SIZE).assertEqual(16);
      });
    });

    // ==================== 字体档位测试 ====================

    describe('font_sizes', () => {
      it('should_have_4_font_sizes', 0, () => {
        expect(Constants.FONT_SIZES.length).assertEqual(4);
      });

      it('should_have_font_sizes_in_ascending_order', 0, () => {
        const sizes = Constants.FONT_SIZES;
        for (let i = 1; i < sizes.length; i++) {
          expect(sizes[i] > sizes[i - 1]).assertTrue();
        }
      });

      it('should_have_matching_font_size_labels', 0, () => {
        expect(Constants.FONT_SIZE_LABELS.length).assertEqual(Constants.FONT_SIZES.length);
      });

      it('should_contain_default_font_size', 0, () => {
        expect(Constants.FONT_SIZES.indexOf(Constants.DEFAULT_FONT_SIZE) >= 0).assertTrue();
      });

      it('should_have_correct_font_size_labels', 0, () => {
        expect(Constants.FONT_SIZE_LABELS[0]).assertEqual('小');
        expect(Constants.FONT_SIZE_LABELS[1]).assertEqual('中');
        expect(Constants.FONT_SIZE_LABELS[2]).assertEqual('大');
        expect(Constants.FONT_SIZE_LABELS[3]).assertEqual('超大');
      });
    });

    // ==================== 刷新间隔测试 ====================

    describe('refresh_intervals', () => {
      it('should_have_5_refresh_intervals', 0, () => {
        expect(Constants.REFRESH_INTERVALS.length).assertEqual(5);
      });

      it('should_contain_zero_interval_for_disable', 0, () => {
        expect(Constants.REFRESH_INTERVALS[0]).assertEqual(0);
      });

      it('should_contain_default_refresh_interval', 0, () => {
        expect(Constants.REFRESH_INTERVALS.indexOf(Constants.DEFAULT_REFRESH_INTERVAL) >= 0).assertTrue();
      });

      it('should_have_matching_refresh_labels', 0, () => {
        expect(Constants.REFRESH_INTERVAL_LABELS.length).assertEqual(Constants.REFRESH_INTERVALS.length);
      });

      it('should_have_first_label_as_off', 0, () => {
        expect(Constants.REFRESH_INTERVAL_LABELS[0]).assertEqual('关闭');
      });
    });

    // ==================== 缓存数量选项测试 ====================

    describe('cache_count_options', () => {
      it('should_have_cache_count_options', 0, () => {
        expect(Constants.CACHE_COUNT_OPTIONS.length > 0).assertTrue();
      });

      it('should_contain_default_cache_count', 0, () => {
        expect(Constants.CACHE_COUNT_OPTIONS.indexOf(Constants.DEFAULT_CACHE_COUNT) >= 0).assertTrue();
      });

      it('should_have_options_in_ascending_order', 0, () => {
        const opts = Constants.CACHE_COUNT_OPTIONS;
        for (let i = 1; i < opts.length; i++) {
          expect(opts[i] > opts[i - 1]).assertTrue();
        }
      });
    });
  });
}
