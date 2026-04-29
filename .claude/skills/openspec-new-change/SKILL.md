---
name: openspec-new-change
description: 使用实验性工件工作流启动新的 OpenSpec 变更。适用于用户希望以结构化步骤创建新功能、修复或修改时。
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.0.0"
---

使用实验性工件驱动方式启动新变更。

**Input**: 用户请求应包含变更名称（kebab-case）或要构建的内容描述。

**Steps**

1. **若输入不清晰，询问想要构建的内容**

    使用 **AskUserQuestion tool**（开放式、无预设选项）提问：
    > "你想处理什么变更？描述你要构建或修复的内容。"

    根据描述生成 kebab-case 名称（例如 "add user authentication" → `add-user-auth`）。

    **IMPORTANT**: 未理解用户想要构建的内容前不要继续。

2. **确定工作流 schema**

    除非用户明确要求其他工作流，否则使用默认 schema（省略 `--schema`）。

    **仅在用户提及以下情况时切换 schema：**
    - "tdd" 或 "test-driven" → 使用 `--schema tdd`
    - 指定 schema 名称 → 使用 `--schema <name>`
    - "show workflows" 或 "what workflows" → 运行 `openspec schemas --json` 并让用户选择

    **否则**：省略 `--schema` 以使用默认值。

3. **创建变更目录**
   ```bash
   openspec new change "<name>"
   ```
    仅在用户指定工作流时添加 `--schema <name>`。
    该命令会在 `openspec/changes/<name>/` 下创建脚手架并应用所选 schema。

4. **展示工件状态**
   ```bash
   openspec status --change "<name>"
   ```
    该输出会显示哪些工件需要创建，以及哪些已就绪（依赖已满足）。

5. **获取首个工件的指令**
    首个工件取决于 schema（例如 spec-driven 为 `proposal`，tdd 为 `spec`）。
    查看状态输出，找到第一个状态为 "ready" 的工件。
   ```bash
   openspec instructions <first-artifact-id> --change "<name>"
   ```
    该命令会输出首个工件的模板与上下文。

6. **停止并等待用户指示**

**输出**

完成步骤后总结：
- 变更名称与位置
- 使用的 schema/工作流及其工件顺序
- 当前状态（0/N 工件完成）
- 首个工件的模板
- 提示语："准备创建第一个工件了吗？直接描述这个变更的内容，我会起草；或让我继续。"

**约束**
- 不要创建任何工件——只展示指令
- 不要继续到首个工件模板之外
- 名称不合法（非 kebab-case）时要求提供合法名称
- 若该名称已存在变更，建议继续该变更
- 使用非默认工作流时传入 --schema
