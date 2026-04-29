---
name: openspec-apply-change
description: 根据 OpenSpec 变更实现任务。适用于用户开始实现、继续实现或逐条完成任务时。
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.0.0"
---

根据 OpenSpec 变更实现任务。

**Input**: 可选指定变更名称。若省略，先从对话上下文推断；如含糊或有歧义，必须提示选择可用变更。

**Steps**

1. **选择变更**

    若提供名称则使用。否则：
    - 从对话上下文推断是否提到某个变更
    - 若仅存在一个活跃变更则自动选择
    - 若有歧义，运行 `openspec list --json` 获取变更列表并用 **AskUserQuestion tool** 让用户选择

    始终声明："使用变更：<name>" 并说明如何切换（例如 `/opsx:apply <other>`）。

2. **检查状态以了解 schema**
   ```bash
   openspec status --change "<name>" --json
   ```
    解析 JSON 以了解：
    - `schemaName`: 使用的工作流（例如 "spec-driven"、"tdd"）
    - 任务所在的工件（spec-driven 通常为 "tasks"，其他以状态为准）

3. **获取 apply 指令**

   ```bash
   openspec instructions apply --change "<name>" --json
   ```

    返回内容：
    - 上下文文件路径（随 schema 不同：proposal/specs/design/tasks 或 spec/tests/implementation/docs）
    - 进度（总数、完成、剩余）
    - 带状态的任务列表
    - 基于当前状态的动态指令

    **处理状态：**
    - 若 `state: "blocked"`（缺少工件）：提示并建议使用 openspec-continue-change
    - 若 `state: "all_done"`：祝贺并建议归档
    - 否则：进入实现

4. **读取上下文文件**

    读取 apply 指令输出中的 `contextFiles` 列表。
    文件取决于所用 schema：
    - **spec-driven**：proposal、specs、design、tasks
    - **tdd**：spec、tests、implementation、docs
    - 其他 schema：以 CLI 输出的 contextFiles 为准

5. **展示当前进度**

    展示：
    - 当前 schema
    - 进度："N/M 任务完成"
    - 剩余任务概览
    - CLI 动态指令

6. **实现任务（循环直到完成或阻塞）**

    对每个待办任务：
    - 显示正在处理的任务
    - 进行必要的代码修改
    - 保持修改最小且聚焦
    - 在 tasks 文件中标记完成：`- [ ]` → `- [x]`
    - 继续下一个任务

    **遇到以下情况暂停：**
    - 任务不清楚 → 询问澄清
    - 实现暴露设计问题 → 建议更新工件
    - 遇到错误或阻塞 → 汇报并等待指示
    - 用户中断

7. **完成或暂停时展示状态**

    展示：
    - 本次完成的任务
    - 总进度："N/M 任务完成"
    - 若全部完成：建议归档
    - 若暂停：说明原因并等待指示

**实现过程中的输出**

```
## Implementing: <change-name> (schema: <schema-name>)

Working on task 3/7: <task description>
[...implementation happening...]
✓ Task complete

Working on task 4/7: <task description>
[...implementation happening...]
✓ Task complete
```

**完成时输出**

```
## Implementation Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 7/7 tasks complete ✓

### Completed This Session
- [x] Task 1
- [x] Task 2
...

所有任务已完成！可归档该变更。
```

**暂停时输出（遇到问题）**

```
## Implementation Paused

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 4/7 tasks complete

### Issue Encountered
<description of the issue>

**Options:**
1. <option 1>
2. <option 2>
3. Other approach

What would you like to do?
```

**约束**
- 持续处理任务直到完成或阻塞
- 开始前必须读取上下文文件（来自 apply 指令输出）
- 任务含糊则先暂停并询问
- 实现暴露问题则暂停并建议更新工件
- 修改尽量小且限定在任务范围
- 完成任务后立即勾选
- 遇到错误、阻塞或不清晰需求则暂停，不要猜测
- 使用 CLI 输出的 contextFiles，不要假设文件名

**流式工作流集成**

该技能支持“对变更的行动”模式：

- **可随时调用**：在所有工件完成前（若任务存在）、部分实现后、或与其他操作交错
- **允许更新工件**：若实现暴露设计问题，可建议更新工件——不按阶段锁死，保持流动
