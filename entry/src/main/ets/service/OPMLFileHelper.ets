// OPML 文件读写辅助类
// 使用 HarmonyOS @kit.CoreFileKit 进行文件 I/O 操作
// 使用 DocumentViewPicker 提供系统文件选择器

import { fileIo, picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

// OPML 文件大小限制：10MB
const MAX_OPML_FILE_SIZE = 10 * 1024 * 1024;

export class OPMLFileHelper {
  /**
   * 弹出系统保存对话框，让用户选择存储路径并保存 OPML 文件
   * @param context - UIAbility 上下文
   * @param opmlContent - OPML XML 字符串
   * @param filename - 默认文件名（如 "opml-export-2026-03-21-120000.opml"）
   * @returns 用户选择的保存路径 URI，用户取消时返回空字符串
   */
  static async saveOPMLFile(
    context: common.UIAbilityContext,
    opmlContent: string,
    filename: string
  ): Promise<string> {
    // 1. 先写入临时文件（cacheDir）
    const tmpPath = `${context.cacheDir}/${filename}`;
    let tmpFile: fileIo.File | undefined;
    try {
      tmpFile = await fileIo.open(
        tmpPath,
        fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC
      );
      const encoder = new util.TextEncoder();
      const buffer = encoder.encodeInto(opmlContent);
      await fileIo.write(tmpFile.fd, buffer.buffer);
      await fileIo.close(tmpFile.fd);
      tmpFile = undefined;
    } catch (e) {
      if (tmpFile !== undefined) {
        try { await fileIo.close(tmpFile.fd); } catch (_) {}
      }
      throw new Error(`写入临时文件失败: ${e instanceof Error ? e.message : String(e)}`);
    }

    // 2. 弹出系统保存对话框，让用户选择目标路径
    try {
      const documentPicker = new picker.DocumentViewPicker(context);
      const saveOptions = new picker.DocumentSaveOptions();
      saveOptions.newFileNames = [filename];
      // 根据文件后缀动态设置可选格式
      if (filename.endsWith('.json')) {
        saveOptions.fileSuffixChoices = ['.json'];
      } else if (filename.endsWith('.md')) {
        saveOptions.fileSuffixChoices = ['.md'];
      } else {
        saveOptions.fileSuffixChoices = ['.opml', '.xml'];
      }

      const uris = await documentPicker.save(saveOptions);

      if (!uris || uris.length === 0) {
        // 用户取消保存，清理临时文件
        try { await fileIo.unlink(tmpPath); } catch (_) {}
        throw new Error('用户取消保存');
      }

      const destUri = uris[0];

      // 3. 将临时文件内容写入用户选择的目标路径
      let destFile: fileIo.File | undefined;
      let srcFile: fileIo.File | undefined;
      try {
        srcFile = await fileIo.open(tmpPath, fileIo.OpenMode.READ_ONLY);
        destFile = await fileIo.open(destUri, fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
        await fileIo.copyFile(srcFile.fd, destFile.fd);
        await fileIo.close(srcFile.fd);
        srcFile = undefined;
        await fileIo.close(destFile.fd);
        destFile = undefined;
      } catch (copyErr) {
        if (srcFile !== undefined) { try { await fileIo.close(srcFile.fd); } catch (_) {} }
        if (destFile !== undefined) { try { await fileIo.close(destFile.fd); } catch (_) {} }
        throw new Error(`复制文件失败: ${copyErr instanceof Error ? copyErr.message : String(copyErr)}`);
      } finally {
        // 清理临时文件
        try { await fileIo.unlink(tmpPath); } catch (_) {}
      }

      console.info('OPMLFileHelper', `File saved to user path: ${destUri}`);
      return destUri;
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg === '用户取消保存') throw new Error(msg);
      throw new Error(`保存文件失败: ${msg}`);
    }
  }

  /**
   * 打开系统文件选择器让用户选择 OPML 文件
   * @param context - UIAbility 上下文
   * @returns 选中文件的 URI
   */
  static async selectOPMLFile(
    context: common.UIAbilityContext
  ): Promise<string> {
    try {
      const documentPicker = new picker.DocumentViewPicker(context);
      const options = new picker.DocumentSelectOptions();

      // 筛选 .opml 和 .xml 文件
      options.fileSuffixFilters = ['OPML|.opml', 'XML|.xml'];
      options.maxSelectNumber = 1;

      const uris = await documentPicker.select(options);

      if (!uris || uris.length === 0) {
        throw new Error('未选择文件');
      }

      console.info('OPMLFileHelper', `Selected file URI: ${uris[0]}`);
      return uris[0];
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg === '未选择文件') {
        throw new Error(msg);
      }
      throw new Error(`选择文件失败: ${msg}`);
    }
  }

  /**
   * 打开系统文件选择器让用户选择 JSON 备份文件
   */
  static async selectJSONFile(
    context: common.UIAbilityContext
  ): Promise<string> {
    try {
      const documentPicker = new picker.DocumentViewPicker(context);
      const options = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = ['JSON|.json'];
      options.maxSelectNumber = 1;
      const uris = await documentPicker.select(options);
      if (!uris || uris.length === 0) {
        throw new Error('未选择文件');
      }
      return uris[0];
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg === '未选择文件') throw new Error(msg);
      throw new Error(`选择文件失败: ${msg}`);
    }
  }

  /**
   * 读取 OPML 文件内容为 UTF-8 字符串
   * @param fileUri - 文件 URI（由 selectOPMLFile 返回）
   * @returns OPML XML 字符串
   */
  static async readOPMLFile(fileUri: string): Promise<string> {
    let file: fileIo.File | undefined;

    try {
      file = await fileIo.open(fileUri, fileIo.OpenMode.READ_ONLY);
      const stat = await fileIo.stat(file.fd);

      if (stat.size > MAX_OPML_FILE_SIZE) {
        await fileIo.close(file.fd);
        file = undefined;
        throw new Error(`文件过大（超过 ${MAX_OPML_FILE_SIZE / 1024 / 1024}MB），请选择更小的文件`);
      }

      if (stat.size === 0) {
        await fileIo.close(file.fd);
        file = undefined;
        throw new Error('文件为空');
      }

      const buf = new ArrayBuffer(stat.size);
      const bytesRead = await fileIo.read(file.fd, buf);
      await fileIo.close(file.fd);
      file = undefined;

      const decoder = new util.TextDecoder('utf-8');
      const content = decoder.decodeToString(new Uint8Array(buf, 0, bytesRead));

      console.info('OPMLFileHelper', `Read ${bytesRead} bytes from file`);
      return content;
    } catch (e) {
      if (file !== undefined) {
        try {
          await fileIo.close(file.fd);
        } catch (_) {
          // 忽略关闭错误
        }
      }
      const msg = e instanceof Error ? e.message : String(e);
      if (msg.startsWith('文件') || msg.startsWith('选择')) {
        throw new Error(msg);
      }
      throw new Error(`读取文件失败: ${msg}`);
    }
  }
}
