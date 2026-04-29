---
name: openspec-sync-specs
description: 将变更中的增量规范同步到主规范。适用于用户希望应用增量规范变化但不归档该变更时。
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.0.0"
---

将增量规范从变更同步到主规范。

这是一个 **agent-driven** 操作——你将读取增量规范并直接编辑主规范以应用变更。这允许智能合并（例如只新增场景而不复制整个需求）。

**Input**: 可选指定变更名称。若省略，先从对话上下文推断；如含糊或有歧义，必须提示选择可用变更。

**Steps**

1. **未提供变更名称时，提示选择**

    运行 `openspec list --json` 获取可用变更，并使用 **AskUserQuestion tool** 让用户选择。

    仅展示包含增量规范的变更（位于 `specs/` 目录）。

    **IMPORTANT**: 不要猜测或自动选择变更，必须由用户选择。

2. **查找增量规范**

    查找 `openspec/changes/<name>/specs/*/spec.md` 下的增量规范文件。

    每个增量规范文件包含以下章节：
   - `## ADDED Requirements` - New requirements to add
   - `## MODIFIED Requirements` - Changes to existing requirements
   - `## REMOVED Requirements` - Requirements to remove
   - `## RENAMED Requirements` - Requirements to rename (FROM:/TO: format)

    若未找到增量规范，告知用户并停止。

3. **针对每个增量规范应用到主规范**

    对于位于 `openspec/changes/<name>/specs/<capability>/spec.md` 的每个能力：

    a. **读取增量规范** 以理解变更意图

    b. **读取主规范** `openspec/specs/<capability>/spec.md`（可能尚不存在）

    c. **智能应用变更**：

       **ADDED Requirements:**
       - 主规范中不存在该需求 → 新增
       - 已存在该需求 → 更新以匹配（视为隐式 MODIFIED）

       **MODIFIED Requirements:**
       - 在主规范中定位需求
       - 应用变更，可包括：
         - 添加新场景（无需复制已有场景）
         - 修改已有场景
         - 修改需求描述
       - 保留增量未涉及的场景/内容

       **REMOVED Requirements:**
       - 从主规范中删除整个需求块

       **RENAMED Requirements:**
       - 找到 FROM 需求并重命名为 TO

    d. **若能力尚不存在主规范则创建**：
       - 创建 `openspec/specs/<capability>/spec.md`
       - 添加 Purpose 部分（可简略，标注 TBD）
       - 添加 Requirements 部分并填入 ADDED 需求

4. **展示摘要**

    应用完所有变更后总结：
    - 更新了哪些能力
    - 做了哪些变更（新增/修改/删除/重命名需求）

**增量规范格式参考**

```markdown
## ADDED Requirements

### Requirement: New Feature
The system SHALL do something new.

#### Scenario: Basic case
- **WHEN** user does X
- **THEN** system does Y

## MODIFIED Requirements

### Requirement: Existing Feature
#### Scenario: New scenario to add
- **WHEN** user does A
- **THEN** system does B

## REMOVED Requirements

### Requirement: Deprecated Feature

## RENAMED Requirements

- FROM: `### Requirement: Old Name`
- TO: `### Requirement: New Name`
```

**关键原则：智能合并**

不同于程序化合并，你可以进行 **局部更新**：
- 只需在 MODIFIED 下加入新增场景，无需复制既有场景
- 增量表达的是*意图*，不是整体替换
- 依据判断做合理合并

**成功时输出**

```
## Specs Synced: <change-name>

Updated main specs:

**<capability-1>**:
- Added requirement: "New Feature"
- Modified requirement: "Existing Feature" (added 1 scenario)

**<capability-2>**:
- Created new spec file
- Added requirement: "Another Feature"

主规范已更新。变更仍保持活跃——实现完成后再归档。
```

**约束**
- 修改前先读增量规范与主规范
- 保留增量未提及的现有内容
- 不清楚时先询问澄清
- 边改边展示变更内容
- 该操作应具备幂等性——重复执行结果相同
