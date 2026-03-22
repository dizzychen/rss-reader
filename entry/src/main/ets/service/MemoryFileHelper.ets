// 记忆系统文件操作工具类
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';

export class MemoryFileHelper {

  /**
   * 读取 Markdown 文件内容，文件不存在则返回 ''
   */
  static async readMarkdown(filePath: string): Promise<string> {
    try {
      const exists = await MemoryFileHelper.exists(filePath);
      if (!exists) {
        return '';
      }
      const file = await fs.open(filePath, fs.OpenMode.READ_ONLY);
      try {
        const stat = await fs.stat(file.fd);
        const size = stat.size;
        if (size === 0) {
          return '';
        }
        const buf = new ArrayBuffer(size);
        const bytesRead = await fs.read(file.fd, buf);
        const decoder = new util.TextDecoder('utf-8');
        return decoder.decodeToString(new Uint8Array(buf, 0, bytesRead));
      } finally {
        await fs.close(file.fd);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryFileHelper', `readMarkdown failed: ${filePath}: ${msg}`);
      return '';
    }
  }

  /**
   * 覆写 Markdown 文件
   */
  static async writeMarkdown(filePath: string, content: string): Promise<void> {
    try {
      // 确保父目录存在
      const lastSlash = filePath.lastIndexOf('/');
      if (lastSlash > 0) {
        await MemoryFileHelper.ensureDir(filePath.substring(0, lastSlash));
      }
      // CREATE | WRITE_ONLY | TRUNC：不存在则创建，存在则截断覆盖
      const encoder = new util.TextEncoder();
      const bytes = encoder.encodeInto(content);
      const file = await fs.open(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        await fs.write(file.fd, bytes.buffer);
        console.info('MemoryFileHelper', `文件写入成功: ${filePath} (${bytes.byteLength} bytes)`);
      } finally {
        await fs.close(file.fd);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryFileHelper', `writeMarkdown failed: ${filePath}: ${msg}`);
      throw new Error(`writeMarkdown failed: ${msg}`);
    }
  }

  /**
   * 追加内容到 Markdown 文件（文件不存在则创建，自动创建父目录）
   */
  static async appendMarkdown(filePath: string, content: string): Promise<void> {
    try {
      // 首先确保父目录存在
      const lastSlash = filePath.lastIndexOf('/');
      if (lastSlash > 0) {
        const parentDir = filePath.substring(0, lastSlash);
        try {
          await MemoryFileHelper.ensureDir(parentDir);
        } catch (parentErr) {
          const msg = parentErr instanceof Error ? parentErr.message : String(parentErr);
          console.error('MemoryFileHelper', `创建父目录失败: ${parentDir}: ${msg}`);
          throw new Error(`Parent directory creation failed: ${msg}`);
        }
      }

      // 然后追加内容
      const encoder = new util.TextEncoder();
      const bytes = encoder.encodeInto(content);
      const file = await fs.open(filePath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.APPEND);
      try {
        await fs.write(file.fd, bytes.buffer);
      } finally {
        await fs.close(file.fd);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryFileHelper', `appendMarkdown failed: ${filePath}: ${msg}`);
      throw new Error(`appendMarkdown failed: ${msg}`);
    }
  }

  /**
   * 判断文件/目录是否存在（使用 statSync 以获得更准确的结果）
   */
  static async exists(path: string): Promise<boolean> {
    try {
      fs.statSync(path);
      return true;
    } catch {
      return false;
    }
  }

  /**
   * 确保目录存在（不存在则递归创建，已存在则跳过）
   */
  static async ensureDir(dirPath: string): Promise<void> {
    try {
      fs.mkdirSync(dirPath, true);
      console.info('MemoryFileHelper', `目录就绪: ${dirPath}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      // HarmonyOS mkdirSync(path, true) 对已存在目录会抛 "File exists"，属于正常情况
      if (msg.includes('File exists') || msg.includes('file exists') || msg.includes('17')) {
        console.info('MemoryFileHelper', `目录已存在(忽略): ${dirPath}`);
        return;
      }
      console.error('MemoryFileHelper', `ensureDir 失败: ${dirPath}: ${msg}`);
      throw new Error(`ensureDir failed: ${msg}`);
    }
  }

  /**
   * 列出目录下的文件名列表（仅文件，不含目录），按名称排序
   */
  static async listFiles(dirPath: string): Promise<string[]> {
    try {
      const exists = await MemoryFileHelper.exists(dirPath);
      if (!exists) {
        return [];
      }
      // 使用 listFileSync 代替 opendirSync（兼容性更好）
      const fileNames: string[] = [];
      const fileList = fs.listFileSync(dirPath);
      for (const name of fileList) {
        const fullPath = `${dirPath}/${name}`;
        const stat = fs.statSync(fullPath);
        if (stat.isFile()) {
          fileNames.push(name);
        }
      }
      return fileNames.sort();
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryFileHelper', `listFiles failed: ${dirPath}: ${msg}`);
      return [];
    }
  }

  /**
   * 获取文件字节大小，文件不存在或出错返回 -1
   */
  static async fileSize(filePath: string): Promise<number> {
    try {
      const stat = fs.statSync(filePath);
      return stat.size;
    } catch {
      return -1;
    }
  }

  /**
   * 删除文件（文件不存在时静默忽略）
   */
  static async deleteFile(filePath: string): Promise<void> {
    try {
      const exists = await MemoryFileHelper.exists(filePath);
      if (exists) {
        fs.unlinkSync(filePath);
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      console.error('MemoryFileHelper', `deleteFile failed: ${filePath}: ${msg}`);
    }
  }
}
