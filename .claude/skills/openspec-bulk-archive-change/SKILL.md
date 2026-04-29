---
name: openspec-bulk-archive-change
description: 批量归档多个已完成变更。适用于同时归档多个并行变更。
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.0.0"
---

在一次操作中归档多个已完成变更。

该技能允许批量归档变更，并通过检查代码库智能处理规范冲突以判断真实实现情况。

**输入**：无需输入（会提示选择）

**步骤**

1. **获取活跃变更**

   运行 `openspec list --json` 获取所有活跃变更。

   若无活跃变更，告知用户并停止。

2. **提示选择变更**

   使用 **AskUserQuestion tool** 的多选让用户选择变更：
   - 展示每个变更及其 schema
   - 包含 "All changes" 选项
   - 允许选择任意数量（1+ 即可，典型为 2+）

   **IMPORTANT**: 不要自动选择，必须由用户选择。

3. **批量校验——收集所选变更的状态**

   对每个所选变更，收集：

   a. **工件状态** - 运行 `openspec status --change "<name>" --json`
      - 解析 `schemaName` 和 `artifacts` 列表
      - 记录哪些工件为 `done`，哪些为其他状态

   b. **任务完成情况** - 读取 `openspec/changes/<name>/tasks.md`
      - 统计 `- [ ]`（未完成）与 `- [x]`（完成）数量
       - 若没有 tasks 文件，记录为 "无任务"

   c. **增量规范** - 检查 `openspec/changes/<name>/specs/` 目录
      - 列出存在的 capability 规范
      - 对每个规范提取需求名称（匹配 `### Requirement: <name>` 的行）

4. **检测规范冲突**

   构建映射 `capability -> [changes that touch it]`：

   ```
   auth -> [change-a, change-b]  <- CONFLICT (2+ changes)
   api  -> [change-c]            <- OK (only 1 change)
   ```

   当 2+ 个所选变更对同一 capability 存在增量规范时视为冲突。

5. **以 agent 方式解决冲突**

   **针对每个冲突**，调查代码库：

   a. **读取各冲突变更的增量规范**，理解各自声明新增/修改内容

   b. **搜索代码库** 寻找实现证据：
      - 查找实现增量规范需求的代码
      - 检查相关文件、函数或测试

   c. **确定解决方案**：
      - 仅一个变更实际实现 -> 同步该变更的规范
      - 两者均已实现 -> 按时间顺序应用（先旧后新，新覆盖旧）
      - 均未实现 -> 跳过规范同步并警告

   d. **记录冲突解决方案**：
      - 应用哪个变更的规范
      - 应用顺序（如两者均实现）
      - 理由（代码库发现）

6. **展示汇总状态表**

   展示汇总所有变更的表格：

   ```
   | Change               | Artifacts | Tasks | Specs   | Conflicts | Status |
   |---------------------|-----------|-------|---------|-----------|--------|
   | schema-management   | Done      | 5/5   | 2 delta | None      | Ready  |
   | project-config      | Done      | 3/3   | 1 delta | None      | Ready  |
   | add-oauth           | Done      | 4/4   | 1 delta | auth (!)  | Ready* |
   | add-verify-skill    | 1 left    | 2/5   | None    | None      | Warn   |
   ```

   对于冲突，展示解决方案：
   ```
   * Conflict resolution:
     - auth spec: Will apply add-oauth then add-jwt (both implemented, chronological order)
   ```

   对于未完成的变更，展示警告：
   ```
   Warnings:
   - add-verify-skill: 1 incomplete artifact, 3 incomplete tasks
   ```

7. **确认批量操作**

   使用 **AskUserQuestion tool** 做一次确认：

    - "归档 N 个变更？" 并提供基于状态的选项
   - 选项可能包括：
      - "归档全部 N 个变更"
      - "仅归档已就绪的 N 个变更（跳过未完成）"
      - "取消"

   若存在未完成的变更，要明确会带警告归档。

8. **对每个确认的变更执行归档**

   按确定的顺序处理变更（遵循冲突解决顺序）：

   a. **如存在增量规范则先同步**：
      - 使用 openspec-sync-specs 方法（agent-driven 智能合并）
      - 对冲突按已解决顺序应用
      - 记录是否已同步

   b. **执行归档**：
      ```bash
      mkdir -p openspec/changes/archive
      mv openspec/changes/<name> openspec/changes/archive/YYYY-MM-DD-<name>
      ```

   c. **记录每个变更的结果**：
      - 成功：归档成功
      - 失败：归档时出错（记录错误）
      - 跳过：用户选择不归档（如适用）

9. **展示总结**

   展示最终结果：

   ```
   ## Bulk Archive Complete

   Archived 3 changes:
   - schema-management-cli -> archive/2026-01-19-schema-management-cli/
   - project-config -> archive/2026-01-19-project-config/
   - add-oauth -> archive/2026-01-19-add-oauth/

   Skipped 1 change:
   - add-verify-skill (user chose not to archive incomplete)

   Spec sync summary:
   - 4 delta specs synced to main specs
   - 1 conflict resolved (auth: applied both in chronological order)
   ```

   若有失败：
   ```
   Failed 1 change:
   - some-change: Archive directory already exists
   ```

**冲突解决示例**

示例 1：仅一个实现
```
Conflict: specs/auth/spec.md touched by [add-oauth, add-jwt]

Checking add-oauth:
- Delta adds "OAuth Provider Integration" requirement
- Searching codebase... found src/auth/oauth.ts implementing OAuth flow

Checking add-jwt:
- Delta adds "JWT Token Handling" requirement
- Searching codebase... no JWT implementation found

Resolution: Only add-oauth is implemented. Will sync add-oauth specs only.
```

示例 2：两者均实现
```
Conflict: specs/api/spec.md touched by [add-rest-api, add-graphql]

Checking add-rest-api (created 2026-01-10):
- Delta adds "REST Endpoints" requirement
- Searching codebase... found src/api/rest.ts

Checking add-graphql (created 2026-01-15):
- Delta adds "GraphQL Schema" requirement
- Searching codebase... found src/api/graphql.ts

Resolution: Both implemented. Will apply add-rest-api specs first,
then add-graphql specs (chronological order, newer takes precedence).
```

**成功时输出**

```
## Bulk Archive Complete

Archived N changes:
- <change-1> -> archive/YYYY-MM-DD-<change-1>/
- <change-2> -> archive/YYYY-MM-DD-<change-2>/

Spec sync summary:
- N delta specs synced to main specs
- No conflicts (or: M conflicts resolved)
```

**部分成功时输出**

```
## Bulk Archive Complete (partial)

Archived N changes:
- <change-1> -> archive/YYYY-MM-DD-<change-1>/

Skipped M changes:
- <change-2> (user chose not to archive incomplete)

Failed K changes:
- <change-3>: Archive directory already exists
```

**无可归档变更时输出**

```
## No Changes to Archive

No active changes found. Use `/opsx:new` to create a new change.
```

**约束**
- 允许选择任意数量的变更（1+ 即可，2+ 常见）
- 必须提示选择，禁止自动选择
- 尽早检测规范冲突并通过代码库解决
- 若两个变更都已实现，按时间顺序应用规范
- 仅在缺少实现时跳过规范同步（并警告）
- 确认前展示清晰的逐变更状态
- 整个批次只做一次确认
- 跟踪并汇报所有结果（成功/跳过/失败）
- 移动归档时保留 .openspec.yaml
- 归档目标使用当前日期：YYYY-MM-DD-<name>
- 若归档目标已存在，该变更失败但继续处理其他
