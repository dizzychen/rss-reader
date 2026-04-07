// 数据操作助手：抽取 MePage/SettingsPage 共用的备份、恢复、导入导出、记忆管理方法
import { util } from '@kit.ArkTS';
import { DatabaseHelper } from '../database/DatabaseHelper';
import { MemoryService } from './MemoryService';
import { OPMLService } from './OPMLService';
import { OPMLFileHelper } from './OPMLFileHelper';
import { BackupService } from './BackupService';
import { common } from '@kit.AbilityKit';

/** 操作结果（成功消息或错误消息） */
export interface OperationResult {
  success: boolean;
  message: string;
  cancelled: boolean; // 用户取消
}

export class DataOperationHelper {
  private static instance: DataOperationHelper;

  static getInstance(): DataOperationHelper {
    if (!DataOperationHelper.instance) {
      DataOperationHelper.instance = new DataOperationHelper();
    }
    return DataOperationHelper.instance;
  }

  /** 导出 OPML */
  async exportOPML(ctx: common.UIAbilityContext): Promise<OperationResult> {
    try {
      const feeds = await DatabaseHelper.getInstance().getAllFeeds();
      if (feeds.length === 0) {
        return { success: false, message: '没有订阅源可导出', cancelled: false };
      }
      const opmlContent = OPMLService.getInstance().generateOPML(feeds);
      const filename = OPMLService.getInstance().generateOPMLFilename();
      await OPMLFileHelper.saveOPMLFile(ctx, opmlContent, filename);
      return { success: true, message: `导出成功，共 ${feeds.length} 个订阅源`, cancelled: false };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg === '用户取消保存') return { success: false, message: '', cancelled: true };
      return { success: false, message: `导出失败：${msg}`, cancelled: false };
    }
  }

  /** 完整备份 */
  async doFullBackup(ctx: common.UIAbilityContext): Promise<OperationResult> {
    try {
      const svc = BackupService.getInstance();
      const json = await svc.generateBackup();
      const parsed = JSON.parse(json) as Record<string, Object>;
      const feedCount = (parsed['feeds'] as Object[])?.length ?? 0;
      if (feedCount === 0) {
        return { success: false, message: '没有数据可备份', cancelled: false };
      }
      const filename = svc.generateBackupFilename();
      await OPMLFileHelper.saveOPMLFile(ctx, json, filename);
      return { success: true, message: `备份成功：${feedCount} 个订阅源 + 全部配置`, cancelled: false };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg === '用户取消保存') return { success: false, message: '', cancelled: true };
      return { success: false, message: `备份失败：${msg}`, cancelled: false };
    }
  }

  /** 恢复备份 */
  async doRestore(ctx: common.UIAbilityContext): Promise<OperationResult> {
    try {
      const fileUri = await OPMLFileHelper.selectJSONFile(ctx);
      const content = await OPMLFileHelper.readOPMLFile(fileUri);
      const result = await BackupService.getInstance().restoreBackup(content);
      let msg = `恢复完成：${result.feedCount} 个订阅源`;
      if (result.groupCount > 0) msg += `、${result.groupCount} 个分组`;
      if (result.skippedFeeds > 0) msg += `（${result.skippedFeeds} 个已存在跳过）`;
      if (result.settingsRestored) msg += '，配置已恢复';
      return { success: true, message: msg, cancelled: false };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg === '未选择文件') return { success: false, message: '', cancelled: true };
      return { success: false, message: `恢复失败：${msg}`, cancelled: false };
    }
  }

  /** 导入 OPML */
  async importOPML(ctx: common.UIAbilityContext): Promise<OperationResult> {
    try {
      const fileUri = await OPMLFileHelper.selectOPMLFile(ctx);
      const opmlContent = await OPMLFileHelper.readOPMLFile(fileUri);
      const items = OPMLService.getInstance().parseOPML(opmlContent);
      if (items.length === 0) {
        return { success: false, message: '文件中未找到有效的 RSS 订阅', cancelled: false };
      }
      const result = await OPMLService.getInstance().importFeeds(items, 1);
      let msg = `解析 ${items.length} 个订阅，成功 ${result.success} 个`;
      if (result.skipped > 0) msg += `，跳过 ${result.skipped} 个`;
      if (result.failed > 0) msg += `，失败 ${result.failed} 个`;
      return { success: true, message: msg, cancelled: false };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg === '未选择文件') return { success: false, message: '', cancelled: true };
      return { success: false, message: `导入失败：${msg}`, cancelled: false };
    }
  }

  /** 导出记忆数据 */
  async exportMemory(ctx: common.UIAbilityContext): Promise<OperationResult> {
    try {
      const content = await MemoryService.getInstance().exportMemoryData();
      if (!content.trim()) {
        return { success: false, message: '暂无记忆数据可导出', cancelled: false };
      }
      const filename = `memory_export_${new Date().toISOString().slice(0, 10)}.md`;
      await OPMLFileHelper.saveOPMLFile(ctx, content, filename);
      return { success: true, message: '记忆数据导出成功', cancelled: false };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg === '用户取消保存') return { success: false, message: '', cancelled: true };
      return { success: false, message: `导出失败：${msg}`, cancelled: false };
    }
  }

  /** 清除记忆数据 */
  async clearMemory(): Promise<OperationResult> {
    try {
      await MemoryService.getInstance().clearAllMemory();
      return { success: true, message: '记忆数据已清除', cancelled: false };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { success: false, message: `清除失败：${msg}`, cancelled: false };
    }
  }

  /** 重置为默认模板 */
  async resetToTemplate(ctx: common.UIAbilityContext): Promise<OperationResult> {
    try {
      const soulRaw = await ctx.resourceManager.getRawFileContent('memory/SOUL.md');
      const profileRaw = await ctx.resourceManager.getRawFileContent('memory/PROFILE.md');
      const decoder = new util.TextDecoder('utf-8');
      const soulTemplate = decoder.decodeToString(soulRaw);
      const profileTemplate = decoder.decodeToString(profileRaw);
      await MemoryService.getInstance().resetToTemplate(soulTemplate, profileTemplate);
      return { success: true, message: '已重置为默认模板', cancelled: false };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { success: false, message: `重置失败：${msg}`, cancelled: false };
    }
  }

  /** 清除缓存 */
  async clearCache(): Promise<OperationResult> {
    try {
      const feeds = await DatabaseHelper.getInstance().getAllFeeds();
      for (const f of feeds) {
        await DatabaseHelper.getInstance().cleanOldCache(f.id!, 0);
      }
      return { success: true, message: '缓存已清除', cancelled: false };
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      return { success: false, message: `清除失败：${msg}`, cancelled: false };
    }
  }
}
