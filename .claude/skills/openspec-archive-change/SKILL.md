---
name: openspec-archive-change
description: 归档实验性工作流中已完成的变更。用于用户完成实现后希望最终归档时。
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.0.0"
---

在实验性工作流中归档已完成的变更。

**输入**：可选指定变更名称。若省略，先从对话上下文推断；如含糊或有歧义，必须提示选择可用变更。

**步骤**

1. **未提供变更名称时，提示选择**

   运行 `openspec list --json` 获取可用变更，并使用 **AskUserQuestion tool** 让用户选择。

   仅展示活跃变更（未归档）。
   如可用，展示每个变更使用的 schema。

   **IMPORTANT**: 不要猜测或自动选择变更，必须由用户选择。

2. **检查工件完成状态**

   运行 `openspec status --change "<name>" --json` 检查工件完成情况。

   解析 JSON 以了解：
   - `schemaName`: 使用的工作流
   - `artifacts`: 工件列表及其状态（`done` 或其他）

   **若有工件未完成（非 `done`）：**
   - 显示警告并列出未完成的工件
   - 使用 **AskUserQuestion tool** 确认是否继续
   - 用户确认后继续

3. **检查任务完成状态**

   读取 tasks 文件（通常为 `tasks.md`）以检查未完成任务。

   统计 `- [ ]`（未完成）与 `- [x]`（完成）的数量。

   **若存在未完成任务：**
   - 显示警告并展示未完成任务数量
   - 使用 **AskUserQuestion tool** 确认是否继续
   - 用户确认后继续

   **若不存在 tasks 文件：** 无需任务警告，继续。

4. **评估增量规范同步状态**

   检查 `openspec/changes/<name>/specs/` 是否存在增量规范。若不存在，无需同步提示。

   **若存在增量规范：**
   - 将每个增量规范与对应主规范 `openspec/specs/<capability>/spec.md` 进行对比
   - 确定将应用的变更（新增/修改/删除/重命名）
   - 在提示前展示合并摘要

   **提示选项：**
    - 若需要同步："立即同步（推荐）"、"不同步直接归档"
    - 若已同步："立即归档"、"仍然同步"、"取消"

   若用户选择同步，执行 /opsx:sync 逻辑（使用 openspec-sync-specs 技能）。无论选择如何都继续归档流程。

5. **执行归档**

   若归档目录不存在则创建：
   ```bash
   mkdir -p openspec/changes/archive
   ```

   使用当前日期生成目标名称：`YYYY-MM-DD-<change-name>`

   **检查目标是否已存在：**
   - 若存在：报错并建议重命名已有归档或使用不同日期
   - 若不存在：将变更目录移动到归档

   ```bash
   mv openspec/changes/<name> openspec/changes/archive/YYYY-MM-DD-<name>
   ```

6. **展示摘要**

   展示归档完成摘要，包括：
   - 变更名称
   - 使用的 schema
   - 归档位置
   - 规范是否已同步（如适用）
   - 任何警告说明（工件/任务未完成）

**成功时输出**

```
## Archive Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Archived to:** openspec/changes/archive/YYYY-MM-DD-<name>/
**Specs:** ✓ Synced to main specs (or "No delta specs" or "Sync skipped")

所有工件完成，所有任务完成。
```

**约束**
- 未提供变更名称时必须提示选择
- 使用工件图（openspec status --json）检查完成情况
- 警告不阻塞归档——只需告知并确认
- 移动归档时保留 .openspec.yaml（随目录一起移动）
- 清晰展示发生了什么
- 若请求同步，使用 openspec-sync-specs 方法（agent-driven）
- 若存在增量规范，必须先进行同步评估并展示合并摘要再提示
