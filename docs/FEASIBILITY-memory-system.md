# 📊 技术可行性调研报告

# RSS 阅读器 - 三层记忆系统

---

| 文档信息 | |
|---------|---|
| **版本** | v1.0 |
| **调研日期** | 2026-03-21 |
| **目标平台** | HarmonyOS NEXT (API 12+) |
| **结论** | ✅ 所有技术点均可实现 |

---

## 一、调研结论

### 1.1 总体结论

经过对 HarmonyOS NEXT API 12+ 的全面调研，记忆系统设计方案中的**所有技术点都有对应的 API 支持**，且大部分已在项目中有实际使用案例。

### 1.2 技术点验证汇总

| 技术点 | API | 支持情况 | 验证来源 |
|--------|-----|---------|---------|
| 文件读取 | `fileIo.open()` + `fileIo.read()` | ✅ | `OPMLFileHelper.ets` |
| 文件覆盖写入 | `fileIo.OpenMode.TRUNC` | ✅ | `OPMLFileHelper.ets` |
| 文件追加写入 | `fileIo.OpenMode.APPEND` | ✅ | 官方文档 |
| 目录创建 | `fileIo.mkdir(path, true)` | ✅ | 官方文档 |
| 目录列表 | `fileIo.listFile()` | ✅ | 官方文档 |
| 文件存在检查 | `fileIo.access()` | ✅ | 官方文档 |
| 文件删除 | `fileIo.unlink()` | ✅ | 官方文档 |
| UTF-8 编码 | `util.TextEncoder` | ✅ | `OPMLFileHelper.ets` |
| UTF-8 解码 | `util.TextDecoder` | ✅ | `OPMLFileHelper.ets` |
| 日期处理 | `Date` API | ✅ | `RssService.ets` |
| 定时器 | `setTimeout/clearTimeout` | ✅ | 官方文档 |
| HTTP 请求 | `http.createHttp()` | ✅ | `RssService.ets` |
| 生命周期钩子 | `aboutToAppear/Disappear` | ✅ | `ArticleDetailPage.ets` |
| 单例模式 | `static getInstance()` | ✅ | `SettingsService.ets` |
| 沙箱目录 | `context.filesDir` | ✅ | `OPMLFileHelper.ets` |

---

## 二、详细验证

### 2.1 文件系统操作

#### 2.1.1 文件读写（已验证）

项目中 `OPMLFileHelper.ets` 已实现完整的文件读写操作：

```typescript
// 读取文件
const file = await fileIo.open(filePath, fileIo.OpenMode.READ_ONLY);
const stat = await fileIo.stat(file.fd);
const buf = new ArrayBuffer(stat.size);
await fileIo.read(file.fd, buf);
await fileIo.close(file.fd);

// 覆盖写入
const file = await fileIo.open(
  filePath,
  fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
);
await fileIo.write(file.fd, buffer.buffer);
await fileIo.close(file.fd);
```

#### 2.1.2 追加写入（官方文档确认）

追加写入是记忆系统日志的核心能力，官方文档确认支持：

```typescript
// OpenMode.APPEND = 0o2000
const file = await fileIo.open(
  filePath,
  fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.APPEND
);
await fileIo.write(file.fd, buffer.buffer);
await fileIo.close(file.fd);
```

#### 2.1.3 目录操作（官方文档确认）

```typescript
// 递归创建目录
await fileIo.mkdir(dirPath, true);

// 列出目录文件
const files = await fileIo.listFile(dirPath);

// 检查文件存在
await fileIo.access(filePath); // 不存在时抛异常

// 删除文件
await fileIo.unlink(filePath);
```

### 2.2 文本编解码

项目中已验证 UTF-8 编解码能力：

```typescript
import { util } from '@kit.ArkTS';

// 编码
const encoder = new util.TextEncoder();
const buffer = encoder.encodeInto(content);

// 解码
const decoder = util.TextDecoder.create('utf-8');
const content = decoder.decodeToString(new Uint8Array(buf, 0, bytesRead));
```

### 2.3 日期时间处理

项目中 `RssService.ets` 已验证日期 API：

```typescript
// 当前时间戳
const now = Date.now();

// 日期对象
const date = new Date(timestamp);

// 获取年月日
date.getFullYear();
date.getMonth();
date.getDate();

// ISO 格式
date.toISOString(); // "2026-03-21T08:00:00.000Z"

// 日期计算
date.setDate(date.getDate() - 1); // 昨天
```

### 2.4 定时器

官方文档确认 API 11+ 支持定时器：

```typescript
// 设置定时器
const timer = setTimeout(() => {
  // 延迟执行
}, 500);

// 清除定时器
clearTimeout(timer);
```

**用途**：用于行为采集的 500ms 防抖处理。

### 2.5 HTTP 请求

项目中 `RssService.ets` 已实现 HTTP 请求：

```typescript
import { http } from '@kit.NetworkKit';

const httpRequest = http.createHttp();
try {
  const response = await httpRequest.request(url, {
    method: http.RequestMethod.POST,
    header: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`
    },
    extraData: JSON.stringify(data)
  });
  // 处理响应...
} finally {
  httpRequest.destroy();
}
```

### 2.6 组件生命周期

项目中 `ArticleDetailPage.ets` 已使用生命周期钩子：

```typescript
@Entry
@Component
struct ArticleDetailPage {
  aboutToAppear() {
    // 组件创建时调用
    // 可用于记录 READ 行为
  }
  
  aboutToDisappear() {
    // 组件销毁时调用
    // 可用于记录 READ_END 行为
  }
}
```

### 2.7 单例模式

项目中 `SettingsService.ets` 已实现单例模式：

```typescript
export class SettingsService {
  private static instance: SettingsService;
  
  static getInstance(): SettingsService {
    if (!SettingsService.instance) {
      SettingsService.instance = new SettingsService();
    }
    return SettingsService.instance;
  }
}
```

### 2.8 应用沙箱目录

项目中已使用沙箱目录：

```typescript
// Stage 模型
const filesDir = context.filesDir;   // /data/storage/el2/base/files/
const cacheDir = context.cacheDir;   // /data/storage/el2/base/cache/
```

---

## 三、技术风险评估

| 风险点 | 风险等级 | 说明 | 应对措施 |
|--------|----------|------|---------|
| 文件损坏 | 低 | 写入中途断电可能导致损坏 | 写入前备份，异常回滚 |
| 并发写入 | 低 | 多处同时写入可能冲突 | 统一通过 MemoryService 写入 |
| 存储空间 | 低 | 日志文件可能占用过多空间 | 30 天自动清理 |
| AI API 限流 | 中 | 调用频率过高可能被限制 | 缓存结果，降级处理 |

---

## 四、技术实现建议

### 4.1 文件路径拼接

HarmonyOS 不支持 Node.js 的 `path` 模块，使用字符串拼接：

```typescript
// ✅ 正确
const memoryDir = `${context.filesDir}/memory`;
const dailyDir = `${memoryDir}/daily`;
const todayLog = `${dailyDir}/${DateUtil.today()}.md`;

// ❌ 错误（不支持）
import path from 'path';
path.join(context.filesDir, 'memory');
```

### 4.2 异步操作

所有文件操作都应使用 async/await：

```typescript
// ✅ 正确
async recordBehavior(behavior: UserBehavior): Promise<void> {
  await this.ensureDir(this.dailyDir);
  await this.appendToFile(this.todayLogPath, formatted);
}
```

### 4.3 错误处理

文件操作应优雅处理「文件不存在」的情况：

```typescript
// ✅ 正确
async readMarkdown(filePath: string): Promise<string> {
  try {
    await fileIo.access(filePath);
    // 读取文件...
  } catch {
    return '';  // 文件不存在返回空字符串
  }
}
```

---

## 五、验证结论

| 功能模块 | 依赖技术 | 可行性 | 备注 |
|---------|---------|--------|------|
| **MemoryService 核心** | fileIo, util, Date | ✅ | 所有 API 已验证 |
| **行为采集埋点** | 生命周期钩子, setTimeout | ✅ | 已有使用案例 |
| **SOUL 初始化** | 文件读写, UI 组件 | ✅ | 标准 ArkUI |
| **PROFILE 自动更新** | 文件操作, 日期计算 | ✅ | 纯计算逻辑 |
| **AI 集成** | HTTP 请求 | ✅ | 已有网络请求案例 |

---

## 六、结论

**所有技术点均已验证可行，可以按照技术设计文档开始实现。**

建议实现顺序：
1. Phase 1：MemoryFileHelper + DateUtil + MemoryService 骨架
2. Phase 2：行为采集埋点
3. Phase 3：SOUL 编辑页
4. Phase 4：PROFILE 自动更新
5. Phase 5：AI 集成

---

**文档结束**
