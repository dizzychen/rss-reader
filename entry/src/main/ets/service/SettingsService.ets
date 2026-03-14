import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Constants } from '../constants/Constants';
import { AppSettings } from '../model/Models';

export class SettingsService {
  private static instance: SettingsService;
  private prefs: preferences.Preferences | null = null;

  static getInstance(): SettingsService {
    if (!SettingsService.instance) {
      SettingsService.instance = new SettingsService();
    }
    return SettingsService.instance;
  }

  async init(context: common.Context): Promise<void> {
    this.prefs = await preferences.getPreferences(context, Constants.PREF_NAME);
  }

  async getSettings(): Promise<AppSettings> {
    return {
      refreshInterval: await this.prefs!.get(Constants.PREF_REFRESH_INTERVAL, Constants.DEFAULT_REFRESH_INTERVAL) as number,
      bgRefreshEnabled: await this.prefs!.get(Constants.PREF_BG_REFRESH, true) as boolean,
      notificationEnabled: await this.prefs!.get(Constants.PREF_NOTIFICATION, true) as boolean,
      fontSize: await this.prefs!.get(Constants.PREF_FONT_SIZE, Constants.DEFAULT_FONT_SIZE) as number,
      openOriginalInApp: await this.prefs!.get(Constants.PREF_OPEN_ORIGINAL, true) as boolean,
      cacheCountPerFeed: await this.prefs!.get(Constants.PREF_CACHE_COUNT, Constants.DEFAULT_CACHE_COUNT) as number
    };
  }

  async setSetting(key: string, value: preferences.ValueType): Promise<void> {
    await this.prefs!.put(key, value);
    await this.prefs!.flush();
  }
}
