// 完整备份/恢复服务
// 将订阅源、分组、配置项打包为 JSON 文件，支持重装后一键恢复

import { DatabaseHelper } from '../database/DatabaseHelper';
import { SettingsService } from './SettingsService';
import { Constants } from '../constants/Constants';
import { Feed, FeedGroup } from '../model/Models';

/** 备份数据结构 */
interface BackupData {
  version: number;            // 备份格式版本
  createdAt: string;          // 备份创建时间
  groups: BackupGroup[];      // 订阅分组
  feeds: BackupFeed[];        // 订阅源
  settings: BackupSettings;   // 配置项
}

interface BackupGroup {
  name: string;
  sortOrder: number;
}

interface BackupFeed {
  title: string;
  url: string;
  siteUrl: string;
  iconUrl: string;
  description: string;
  groupName: string;          // 通过分组名关联，而非 id
}

interface BackupSettings {
  refreshInterval: number;
  bgRefreshEnabled: boolean;
  notificationEnabled: boolean;
  fontSize: number;
  openOriginalInApp: boolean;
  cacheCountPerFeed: number;
  sortMode: string;
  aiProvider: string;
  aiApiKey: string;
  aiBaseUrl: string;
  aiModelName: string;
  briefingEnabled: boolean;
  briefingCount: number;
  autoBriefing: boolean;
  aiSortEnabled: boolean;
}

/** 恢复结果 */
export interface RestoreResult {
  groupCount: number;
  feedCount: number;
  skippedFeeds: number;       // 已存在跳过的订阅源
  settingsRestored: boolean;
}

export class BackupService {
  private static instance: BackupService;

  static getInstance(): BackupService {
    if (!BackupService.instance) {
      BackupService.instance = new BackupService();
    }
    return BackupService.instance;
  }

  /**
   * 生成完整备份 JSON 字符串
   */
  async generateBackup(): Promise<string> {
    const db = DatabaseHelper.getInstance();
    const settings = SettingsService.getInstance();

    // 1. 获取所有分组
    const groups: FeedGroup[] = await db.getAllGroups();
    const groupMap = new Map<number, string>();
    const backupGroups: BackupGroup[] = [];
    for (const g of groups) {
      groupMap.set(g.id!, g.name);
      backupGroups.push({ name: g.name, sortOrder: g.sortOrder });
    }

    // 2. 获取所有订阅源
    const feeds: Feed[] = await db.getAllFeeds();
    const backupFeeds: BackupFeed[] = feeds.map((f: Feed): BackupFeed => {
      const item: BackupFeed = {
        title: f.title,
        url: f.url,
        siteUrl: f.siteUrl,
        iconUrl: f.iconUrl,
        description: f.description,
        groupName: groupMap.get(f.groupId) ?? '默认'
      };
      return item;
    });

    // 3. 获取所有配置
    const appSettings = await settings.getSettings();
    const backupSettings: BackupSettings = {
      refreshInterval: appSettings.refreshInterval,
      bgRefreshEnabled: appSettings.bgRefreshEnabled,
      notificationEnabled: appSettings.notificationEnabled,
      fontSize: appSettings.fontSize,
      openOriginalInApp: appSettings.openOriginalInApp,
      cacheCountPerFeed: appSettings.cacheCountPerFeed,
      sortMode: await settings.getSortMode(),
      aiProvider: await settings.getAIProvider(),
      aiApiKey: '',  // 安全考虑：不将 API Key 明文导出到备份文件
      aiBaseUrl: await settings.getAIBaseUrl(),
      aiModelName: await settings.getAIModelName(),
      briefingEnabled: await settings.getBriefingEnabled(),
      briefingCount: await settings.getBriefingCount(),
      autoBriefing: await settings.getAutoBriefingEnabled(),
      aiSortEnabled: await settings.getAISortEnabled()
    };

    const backup: BackupData = {
      version: 1,
      createdAt: new Date().toISOString(),
      groups: backupGroups,
      feeds: backupFeeds,
      settings: backupSettings
    };

    return JSON.stringify(backup, null, 2);
  }

  /**
   * 生成备份文件名
   */
  generateBackupFilename(): string {
    const now = new Date();
    const y = now.getFullYear();
    const m = String(now.getMonth() + 1).padStart(2, '0');
    const d = String(now.getDate()).padStart(2, '0');
    const h = String(now.getHours()).padStart(2, '0');
    const min = String(now.getMinutes()).padStart(2, '0');
    return `rssreader-backup-${y}${m}${d}-${h}${min}.json`;
  }

  /**
   * 从 JSON 字符串恢复备份
   */
  async restoreBackup(jsonContent: string): Promise<RestoreResult> {
    const result: RestoreResult = {
      groupCount: 0,
      feedCount: 0,
      skippedFeeds: 0,
      settingsRestored: false
    };

    let backup: BackupData;
    try {
      backup = JSON.parse(jsonContent) as BackupData;
    } catch (e) {
      throw new Error('备份文件格式错误，无法解析');
    }

    if (!backup.version || !backup.feeds) {
      throw new Error('无效的备份文件');
    }

    const db = DatabaseHelper.getInstance();
    const settings = SettingsService.getInstance();

    // 1. 恢复分组（跳过默认分组，避免重复）
    const groupNameToId = new Map<string, number>();
    // 先获取已有分组
    const existingGroups = await db.getAllGroups();
    for (const eg of existingGroups) {
      groupNameToId.set(eg.name, eg.id!);
    }
    // 创建不存在的分组
    if (backup.groups) {
      for (const bg of backup.groups) {
        if (!groupNameToId.has(bg.name)) {
          const newId = await db.insertGroup({ name: bg.name, sortOrder: bg.sortOrder });
          if (newId > 0) {
            groupNameToId.set(bg.name, newId);
            result.groupCount++;
          }
        }
      }
    }

    // 2. 恢复订阅源（已存在的 URL 跳过）
    for (const bf of backup.feeds) {
      const existing = await db.getFeedByUrl(bf.url);
      if (existing) {
        result.skippedFeeds++;
        continue;
      }
      const groupId = groupNameToId.get(bf.groupName) ?? 1;
      const feedId = await db.insertFeed({
        title: bf.title,
        url: bf.url,
        siteUrl: bf.siteUrl,
        iconUrl: bf.iconUrl,
        description: bf.description,
        groupId: groupId,
        lastUpdated: 0
      });
      if (feedId > 0) {
        result.feedCount++;
      }
    }

    // 3. 恢复配置
    if (backup.settings) {
      const s = backup.settings;
      try {
        await settings.setSetting(Constants.PREF_REFRESH_INTERVAL, s.refreshInterval);
        await settings.setSetting(Constants.PREF_BG_REFRESH, s.bgRefreshEnabled);
        await settings.setSetting(Constants.PREF_NOTIFICATION, s.notificationEnabled);
        await settings.setSetting(Constants.PREF_FONT_SIZE, s.fontSize);
        await settings.setSetting(Constants.PREF_OPEN_ORIGINAL, s.openOriginalInApp);
        await settings.setSetting(Constants.PREF_CACHE_COUNT, s.cacheCountPerFeed);
        await settings.setSortMode(s.sortMode);
        if (s.aiProvider) {
          await settings.setAIProvider(s.aiProvider);
        }
        if (s.aiApiKey) {
          await settings.setAIApiKey(s.aiApiKey);
        }
        if (s.aiBaseUrl) {
          await settings.setAIBaseUrl(s.aiBaseUrl);
        }
        if (s.aiModelName) {
          await settings.setAIModelName(s.aiModelName);
        }
        await settings.setBriefingEnabled(s.briefingEnabled);
        await settings.setBriefingCount(s.briefingCount);
        await settings.setAutoBriefingEnabled(s.autoBriefing);
        await settings.setAISortEnabled(s.aiSortEnabled);
        result.settingsRestored = true;
      } catch (e) {
        console.error('BackupService', `Settings restore partial failure: ${e}`);
      }
    }

    return result;
  }
}
