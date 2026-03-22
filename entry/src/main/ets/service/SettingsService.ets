import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Constants } from '../constants/Constants';
import { AppSettings } from '../model/Models';

export class SettingsService {
  private static instance: SettingsService;
  private prefs: preferences.Preferences | null = null;
  private initPromise: Promise<void> | null = null;

  static getInstance(): SettingsService {
    if (!SettingsService.instance) {
      SettingsService.instance = new SettingsService();
    }
    return SettingsService.instance;
  }

  init(context: common.Context): Promise<void> {
    if (this.initPromise) {
      return this.initPromise;
    }
    this.initPromise = preferences.getPreferences(context, Constants.PREF_NAME).then(p => {
      this.prefs = p;
    }).catch((e: Error) => {
      console.warn('SettingsService', `init skipped: ${e?.message}`);
    });
    return this.initPromise;
  }

  async getSettings(): Promise<AppSettings> {
    const p = this.prefs;
    if (!p) {
      return {
        refreshInterval: Constants.DEFAULT_REFRESH_INTERVAL,
        bgRefreshEnabled: true,
        notificationEnabled: true,
        fontSize: Constants.DEFAULT_FONT_SIZE,
        openOriginalInApp: true,
        cacheCountPerFeed: Constants.DEFAULT_CACHE_COUNT
      };
    }
    const toNum = (v: preferences.ValueType, def: number): number =>
      typeof v === 'number' ? v : def;
    const toBool = (v: preferences.ValueType, def: boolean): boolean =>
      typeof v === 'boolean' ? v : def;
    return {
      refreshInterval: toNum(
        await p.get(Constants.PREF_REFRESH_INTERVAL, Constants.DEFAULT_REFRESH_INTERVAL),
        Constants.DEFAULT_REFRESH_INTERVAL),
      bgRefreshEnabled: toBool(await p.get(Constants.PREF_BG_REFRESH, true), true),
      notificationEnabled: toBool(await p.get(Constants.PREF_NOTIFICATION, true), true),
      fontSize: toNum(await p.get(Constants.PREF_FONT_SIZE, Constants.DEFAULT_FONT_SIZE), Constants.DEFAULT_FONT_SIZE),
      openOriginalInApp: toBool(await p.get(Constants.PREF_OPEN_ORIGINAL, true), true),
      cacheCountPerFeed: toNum(
        await p.get(Constants.PREF_CACHE_COUNT, Constants.DEFAULT_CACHE_COUNT),
        Constants.DEFAULT_CACHE_COUNT)
    };
  }

  async setSetting(key: string, value: preferences.ValueType): Promise<void> {
    if (!this.prefs) return;
    await this.prefs.put(key, value);
    await this.prefs.flush();
  }

  // ===== AI 相关设置 =====

  async getAIApiKey(): Promise<string> {
    if (!this.prefs) return '';
    const v = await this.prefs.get(Constants.PREF_AI_API_KEY, '');
    return typeof v === 'string' ? v : '';
  }

  async setAIApiKey(key: string): Promise<void> {
    await this.setSetting(Constants.PREF_AI_API_KEY, key);
  }

  async getBriefingEnabled(): Promise<boolean> {
    if (!this.prefs) return true;
    const v = await this.prefs.get(Constants.PREF_DAILY_BRIEFING_ENABLED, true);
    return typeof v === 'boolean' ? v : true;
  }

  async setBriefingEnabled(val: boolean): Promise<void> {
    await this.setSetting(Constants.PREF_DAILY_BRIEFING_ENABLED, val);
  }

  async getAISortEnabled(): Promise<boolean> {
    if (!this.prefs) return false;
    const v = await this.prefs.get(Constants.PREF_AI_SORT_ENABLED, false);
    return typeof v === 'boolean' ? v : false;
  }

  async setAISortEnabled(val: boolean): Promise<void> {
    await this.setSetting(Constants.PREF_AI_SORT_ENABLED, val);
  }

  async getLastMaintenanceDate(): Promise<string> {
    if (!this.prefs) return '';
    const v = await this.prefs.get(Constants.PREF_LAST_MAINTENANCE_DATE, '');
    return typeof v === 'string' ? v : '';
  }

  async setLastMaintenanceDate(date: string): Promise<void> {
    await this.setSetting(Constants.PREF_LAST_MAINTENANCE_DATE, date);
  }

  // ===== AI 提供商配置 =====

  async getAIProvider(): Promise<string> {
    if (!this.prefs) return 'qwen';
    const v = await this.prefs.get(Constants.PREF_AI_PROVIDER, 'qwen');
    return typeof v === 'string' ? v : 'qwen';
  }

  async setAIProvider(provider: string): Promise<void> {
    await this.setSetting(Constants.PREF_AI_PROVIDER, provider);
  }

  async getAIBaseUrl(): Promise<string> {
    if (!this.prefs) return '';
    const v = await this.prefs.get(Constants.PREF_AI_BASE_URL, '');
    return typeof v === 'string' ? v : '';
  }

  async setAIBaseUrl(url: string): Promise<void> {
    await this.setSetting(Constants.PREF_AI_BASE_URL, url);
  }

  async getAIModelName(): Promise<string> {
    if (!this.prefs) return '';
    const v = await this.prefs.get(Constants.PREF_AI_MODEL_NAME, '');
    return typeof v === 'string' ? v : '';
  }

  async setAIModelName(name: string): Promise<void> {
    await this.setSetting(Constants.PREF_AI_MODEL_NAME, name);
  }
}
