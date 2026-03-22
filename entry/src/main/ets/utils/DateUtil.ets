// 日期工具类

export class DateUtil {
  /**
   * 获取今日日期字符串 YYYY-MM-DD
   */
  static today(): string {
    return DateUtil.formatDateStr(new Date());
  }

  /**
   * 获取昨日日期字符串 YYYY-MM-DD
   */
  static yesterday(): string {
    const d = new Date();
    d.setDate(d.getDate() - 1);
    return DateUtil.formatDateStr(d);
  }

  /**
   * 获取 n 天前的日期字符串 YYYY-MM-DD
   */
  static daysAgo(n: number): string {
    const d = new Date();
    d.setDate(d.getDate() - n);
    return DateUtil.formatDateStr(d);
  }

  /**
   * 格式化 Date 为 YYYY-MM-DD
   */
  static formatDateStr(d: Date): string {
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  /**
   * 格式化时间为 HH:mm:ss
   */
  static formatTime(d: Date): string {
    const h = String(d.getHours()).padStart(2, '0');
    const min = String(d.getMinutes()).padStart(2, '0');
    const sec = String(d.getSeconds()).padStart(2, '0');
    return `${h}:${min}:${sec}`;
  }

  /**
   * 格式化持续时间（秒）为可读字符串
   * 例如：65 -> "1分05秒", 3600 -> "1小时00分"
   */
  static formatDuration(seconds: number): string {
    if (seconds < 60) {
      return `${Math.floor(seconds)}秒`;
    } else if (seconds < 3600) {
      const m = Math.floor(seconds / 60);
      const s = Math.floor(seconds % 60);
      return `${m}分${String(s).padStart(2, '0')}秒`;
    } else {
      const h = Math.floor(seconds / 3600);
      const m = Math.floor((seconds % 3600) / 60);
      return `${h}小时${String(m).padStart(2, '0')}分`;
    }
  }

  /**
   * 获取当前时间戳（ms）
   */
  static now(): number {
    return Date.now();
  }

  /**
   * 解析 YYYY-MM-DD 字符串为 Date 对象（本地时区）
   */
  static parseDateStr(dateStr: string): Date {
    const parts = dateStr.split('-');
    if (parts.length !== 3) {
      return new Date();
    }
    const y = parseInt(parts[0], 10);
    const m = parseInt(parts[1], 10) - 1;
    const d = parseInt(parts[2], 10);
    return new Date(y, m, d);
  }
}
