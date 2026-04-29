---
name: "OPSX: Continue"
description: 继续推进变更——创建下一个工件（实验性）
category: Workflow
tags: [workflow, artifacts, experimental]
---

通过创建下一个工件继续变更。

**输入**：可选在 `/opsx:continue` 后指定变更名称（例如 `/opsx:continue add-auth`）。若省略，先从对话上下文推断；如含糊或有歧义，必须提示选择可用变更。

**步骤**

1. **未提供变更名称时，提示选择**

   运行 `openspec list --json` 获取按最近修改排序的变更列表。然后使用 **AskUserQuestion tool** 让用户选择要继续的变更。

   以最近修改的 3-4 个变更作为选项，展示：
   - 变更名称
   - Schema（若有 `schema` 字段则使用，否则为 "spec-driven"）
   - 状态（例如 "0/5 tasks"、"complete"、"no tasks"）
   - 最近修改时间（来自 `lastModified` 字段）

   将最近修改的变更标记为 "(Recommended)"，因为它最可能是用户要继续的。

   **IMPORTANT**: 不要猜测或自动选择变更，必须由用户选择。

2. **检查当前状态**
   ```bash
   openspec status --change "<name>" --json
   ```
   解析 JSON 了解当前状态。响应包含：
   - `schemaName`: 正在使用的工作流 schema（例如 "spec-driven"、"tdd"）
   - `artifacts`: 工件数组及其状态（"done"、"ready"、"blocked"）
   - `isComplete`: 是否所有工件已完成的布尔值

3. **根据状态采取行动**：

   ---

   **若所有工件完成（`isComplete: true`）**：
   - 祝贺用户
   - 展示最终状态（包含所用 schema）
    - 建议："所有工件已创建！现在可以实现该变更或将其归档。"
   - 停止

   ---

   **若有可创建的工件**（状态中存在 `status: "ready"`）：
   - 选择状态输出中第一个 `status: "ready"` 的工件
   - 获取其指令：
     ```bash
     openspec instructions <artifact-id> --change "<name>" --json
     ```
   - 解析 JSON。关键字段包括：
     - `context`: 项目背景（对你是约束，不要写入输出）
     - `rules`: 工件规则（对你是约束，不要写入输出）
     - `template`: 输出文件结构
     - `instruction`: schema 指导说明
     - `outputPath`: 输出路径
     - `dependencies`: 需读取的已完成工件
   - **创建工件文件**：
     - 读取已完成依赖工件作为上下文
     - 使用 `template` 作为结构并填写内容
     - 写入时将 `context` 与 `rules` 作为约束，但不要复制进文件
     - 写入指令给定的输出路径
   - 展示已创建内容与新解锁内容
   - 创建一个工件后停止

   ---

   **若没有可用工件（全部 blocked）**：
   - 这在有效 schema 下不应发生
   - 展示状态并建议检查问题

4. **创建工件后展示进度**
   ```bash
   openspec status --change "<name>"
   ```

**输出**

每次执行后展示：
- 已创建的工件
- 当前使用的 schema 工作流
- 进度（N/M 完成）
- 新解锁的工件
- 提示语："运行 `/opsx:continue` 以创建下一个工件"

**工件创建指南**

工件类型及其用途取决于 schema。通过指令输出中的 `instruction` 字段了解应创建的内容。

常见工件模式：

**spec-driven schema**（proposal → specs → design → tasks）：
- **proposal.md**：若变更不清晰先询问用户，填写 Why、What Changes、Capabilities、Impact。
  - Capabilities 部分至关重要——每个能力都需要一个 spec 文件。
- **specs/*.md**：为提案中每个能力创建一个规范。
- **design.md**：记录技术决策、架构与实现方案。
- **tasks.md**：将实现拆解为可勾选任务。

**tdd schema**（spec → tests → implementation → docs）：
- **spec.md**：功能规范，定义要构建内容。
- **tests/*.test.ts**：在实现前编写测试（TDD 红阶段）。
- **src/*.ts**：实现以通过测试（TDD 绿阶段）。
- **docs/*.md**：为已实现功能编写文档。

其他 schema 按 CLI 输出中的 `instruction` 执行。

**约束**
 - 每次只创建一个工件
 - 创建前必须读取依赖工件
 - 不要跳过工件或乱序创建
 - 上下文不清楚时先询问用户
 - 写入后确认文件存在再标记进度
 - 按 schema 的工件顺序执行，不要猜测工件名称
 - **IMPORTANT**: `context` 与 `rules` 仅作为你的约束，不是文件内容
   - 不要把 `<context>`、`<rules>`、`<project_context>` 复制进工件
   - 它们只用于指导书写，不能出现在输出中
