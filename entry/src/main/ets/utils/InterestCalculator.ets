// EMA 兴趣权重计算器
import { InterestWeight } from '../model/Models';
import { Constants } from '../constants/Constants';

export class InterestCalculator {

  /**
   * 使用 EMA（指数移动平均）更新兴趣权重
   * 公式：newWeight = α × signal + (1-α) × oldWeight
   *
   * @param existing 已有权重列表
   * @param signals  新信号（key -> 信号强度 [0,1]）
   * @param date     更新日期字符串 YYYY-MM-DD
   * @returns 更新后的权重列表
   */
  static update(
    existing: InterestWeight[],
    signals: Map<string, number>,
    date: string
  ): InterestWeight[] {
    const alpha = Constants.EMA_ALPHA;
    const result = new Map<string, InterestWeight>();

    // 复制已有权重
    for (const iw of existing) {
      result.set(iw.key, { key: iw.key, weight: iw.weight, updatedAt: iw.updatedAt });
    }

    // 对有信号的 key 进行 EMA 更新
    signals.forEach((signal, key) => {
      const existing_item = result.get(key);
      if (existing_item) {
        const newWeight = alpha * signal + (1 - alpha) * existing_item.weight;
        result.set(key, {
          key: key,
          weight: Math.round(newWeight * 1000) / 1000,  // 保留3位小数
          updatedAt: date
        });
      } else {
        // 新 key，直接使用信号值作为初始权重
        result.set(key, {
          key: key,
          weight: Math.round(signal * 1000) / 1000,
          updatedAt: date
        });
      }
    });

    // 对没有新信号的 key 进行衰减（乘以 1-α）
    result.forEach((iw, key) => {
      if (!signals.has(key)) {
        const decayed = (1 - alpha) * iw.weight;
        result.set(key, {
          key: iw.key,
          weight: Math.round(decayed * 1000) / 1000,
          updatedAt: iw.updatedAt
        });
      }
    });

    // 过滤掉权重极低的条目（< 0.01），避免长期积累无用数据
    const filtered: InterestWeight[] = [];
    result.forEach((iw) => {
      if (iw.weight >= 0.01) {
        filtered.push(iw);
      }
    });

    // 按权重降序排列
    return filtered.sort((a, b) => b.weight - a.weight);
  }

  /**
   * 从文章阅读行为计算信号强度
   * @param readCount    阅读次数
   * @param starCount    收藏次数
   * @param totalDays    计算周期天数（归一化分母）
   * @param avgDuration  该源平均阅读时长（秒），0 表示无数据
   * @param dislikeCount 用户主动标记不感兴趣的次数
   * @returns 信号强度 [0, 1]
   */
  static calcSignal(readCount: number, starCount: number, totalDays: number,
    avgDuration: number = 0, dislikeCount: number = 0): number {
    if (totalDays <= 0) {
      return 0;
    }
    let durationFactor = 1.0;
    if (avgDuration > 180) {
      durationFactor = 1.5;
    } else if (avgDuration > 0 && avgDuration < 30) {
      durationFactor = 0.5;
    }
    const dislikePenalty = dislikeCount > 0 ? Math.pow(0.5, dislikeCount) : 1.0;
    const score = (readCount * durationFactor + starCount * 3) / totalDays;
    return (1 / (1 + Math.exp(-score + 2))) * dislikePenalty;
  }

  /**
   * 序列化兴趣权重列表为 Markdown 表格行
   */
  static serializeToMarkdown(weights: InterestWeight[]): string {
    if (weights.length === 0) {
      return '（暂无数据）\n';
    }
    let lines = '| 名称 | 权重 | 更新日期 |\n|------|------|----------|\n';
    for (const iw of weights.slice(0, 20)) {  // 最多显示前20条
      const bar = '█'.repeat(Math.round(iw.weight * 10));
      lines += `| ${iw.key} | ${bar} ${iw.weight.toFixed(3)} | ${iw.updatedAt} |\n`;
    }
    return lines;
  }

  /**
   * 从 Markdown 表格解析兴趣权重（简单解析，不依赖正则）
   */
  static parseFromMarkdown(markdown: string): InterestWeight[] {
    const result: InterestWeight[] = [];
    const lines = markdown.split('\n');
    for (const line of lines) {
      if (!line.startsWith('|') || line.startsWith('| 名称') || line.startsWith('|---')) {
        continue;
      }
      const parts = line.split('|').map(s => s.trim()).filter(s => s.length > 0);
      if (parts.length >= 3) {
        const key = parts[0];
        // 权重列格式：█████ 0.350
        const weightParts = parts[1].split(' ');
        const weightStr = weightParts[weightParts.length - 1];
        const weight = parseFloat(weightStr);
        const updatedAt = parts[2];
        if (key && !isNaN(weight) && updatedAt) {
          result.push({ key, weight, updatedAt });
        }
      }
    }
    return result;
  }
}
