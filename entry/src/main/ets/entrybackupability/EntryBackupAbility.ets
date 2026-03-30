import { hilog } from '@kit.PerformanceAnalysisKit';
import { BackupExtensionAbility, BundleVersion } from '@kit.CoreFileKit';

const TAG = 'EntryBackupAbility';
const DOMAIN = 0x0000;

export default class EntryBackupAbility extends BackupExtensionAbility {
  /**
   * 系统触发备份时回调（夜间充电、系统升级前等）
   * 备份路径已在 backup_config.json 的 includes 中声明，系统自动采集
   * 此处可执行备份前的准备工作（如刷写内存缓存到磁盘）
   */
  async onBackup(): Promise<void> {
    hilog.info(DOMAIN, TAG, '备份开始：记忆文件 + 数据库 + 偏好设置');
    // backup_config.json 中 includes 已声明路径，系统会自动备份这些文件
    // 无需额外操作，系统按声明路径自动采集
    hilog.info(DOMAIN, TAG, '备份完成');
  }

  /**
   * 系统触发恢复时回调（应用重装后首次启动、设备迁移等）
   * fullBackupOnly=false 时系统自动将文件恢复到原路径，无需手动处理
   * @param bundleVersion 备份时的应用版本信息，可用于数据迁移兼容
   */
  async onRestore(bundleVersion: BundleVersion): Promise<void> {
    hilog.info(DOMAIN, TAG,
      '恢复开始：来自版本 %{public}s (versionCode=%{public}d)',
      bundleVersion.name, bundleVersion.code);
    // fullBackupOnly=false：系统已自动将备份数据恢复到原路径
    // 记忆文件 → filesDir/memory/SOUL.md, PROFILE.md, LESSONS.md
    // 数据库   → database/rss_reader.db
    // 偏好设置 → preferences/rss_settings
    hilog.info(DOMAIN, TAG, '恢复完成：数据已就位，应用启动后 MemoryService.init 会检测到已有文件并保留');
  }
}
