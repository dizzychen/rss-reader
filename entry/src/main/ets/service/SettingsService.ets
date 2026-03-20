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
}
