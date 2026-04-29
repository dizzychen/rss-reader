---
name: openspec-ff-change
description: 快进完成 OpenSpec 工件创建。适用于用户希望快速生成所有实现所需工件，而不逐个创建时。
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.0.0"
---

快进完成工件创建，一次性生成开始实现所需的一切。

**Input**: 用户请求应包含变更名称（kebab-case）或要构建的内容描述。

**Steps**

1. **若输入不清晰，询问要构建的内容**

    使用 **AskUserQuestion tool**（开放式、无预设选项）提问：
    > "你想处理什么变更？描述你要构建或修复的内容。"

    根据描述生成 kebab-case 名称（例如 "add user authentication" → `add-user-auth`）。

    **IMPORTANT**: 未理解用户想要构建的内容前不要继续。

2. **创建变更目录**
   ```bash
   openspec new change "<name>"
   ```
    该命令会在 `openspec/changes/<name>/` 下创建脚手架。

3. **获取工件构建顺序**
   ```bash
   openspec status --change "<name>" --json
   ```
    解析 JSON 获取：
    - `applyRequires`: 实现前需要完成的工件 ID 列表（例如 `["tasks"]`）
    - `artifacts`: 所有工件及其状态与依赖

4. **按顺序创建工件直到可 apply**

    使用 **TodoWrite tool** 跟踪工件创建进度。

    按依赖顺序遍历工件（先处理无待完成依赖的工件）：

    a. **对于状态为 `ready` 的工件（依赖已满足）**：
      - Get instructions:
        ```bash
        openspec instructions <artifact-id> --change "<name>" --json
        ```
      - 指令 JSON 包含：
        - `context`: 项目背景（对你是约束，不要写入输出）
        - `rules`: 工件规则（对你是约束，不要写入输出）
        - `template`: 输出文件结构
        - `instruction`: 该工件的 schema 指导
        - `outputPath`: 输出路径
        - `dependencies`: 需读取的已完成工件
      - 读取已完成依赖工件作为上下文
      - 使用 `template` 作为结构创建工件文件
      - 将 `context` 与 `rules` 作为约束，但不要复制进文件
      - 简要展示进度："✓ Created <artifact-id>"

    b. **继续直到所有 `applyRequires` 工件完成**
       - 每创建一个工件后重跑 `openspec status --change "<name>" --json`
       - 检查 `applyRequires` 中的每个工件 ID 是否在 artifacts 中为 `status: "done"`
       - 当所有 `applyRequires` 工件完成时停止

    c. **若某工件需要用户输入**（上下文不清楚）：
       - 使用 **AskUserQuestion tool** 进行澄清
       - 然后继续创建

5. **展示最终状态**
   ```bash
   openspec status --change "<name>"
   ```

**输出**

完成所有工件后总结：
- 变更名称与位置
- 已创建工件列表与简述
- 就绪提示："所有工件已创建！可开始实现。"
- 提示语："运行 `/opsx:apply` 或让我开始实现任务。"

**工件创建指南**

 - 按 `openspec instructions` 的 `instruction` 字段执行每个工件类型
 - schema 定义了每个工件应包含的内容，严格遵循
 - 创建新工件前先读取依赖工件作为上下文
 - 使用 `template` 作为输出结构并填写内容
 - **IMPORTANT**: `context` 与 `rules` 仅作为你的约束，不是文件内容
   - 不要把 `<context>`、`<rules>`、`<project_context>` 复制进工件
   - 它们只用于指导书写，不能出现在输出中

**约束**
- 创建实现所需的所有工件（由 schema 的 `apply.requires` 定义）
- 创建新工件前必须读取依赖工件
- 若上下文严重不清楚，先询问用户，但尽量做合理判断以保持推进
- 若该名称已有变更，建议继续该变更
- 写入后确认工件文件存在，再继续下一个
