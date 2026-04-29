---
name: openspec-verify-change
description: 验证实现是否与变更工件匹配。适用于用户在归档前验证实现是否完整、正确且一致。
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.0.0"
---

验证实现是否与变更工件（specs、tasks、design）一致。

**输入**：可选指定变更名称。若省略，先从对话上下文推断；如含糊或有歧义，必须提示选择可用变更。

**步骤**

1. **未提供变更名称时，提示选择**

   运行 `openspec list --json` 获取可用变更，并使用 **AskUserQuestion tool** 让用户选择。

   仅展示包含实现任务的变更（存在 tasks 工件）。
   如可用，展示每个变更使用的 schema。
   对未完成任务的变更标记为 "(In Progress)"。

   **IMPORTANT**: 不要猜测或自动选择变更，必须由用户选择。

2. **检查状态以了解 schema**
   ```bash
   openspec status --change "<name>" --json
   ```
   解析 JSON 以了解：
   - `schemaName`: 使用的工作流（例如 "spec-driven"、"tdd"）
   - 该变更存在哪些工件

3. **获取变更目录并加载工件**

   ```bash
   openspec instructions apply --change "<name>" --json
   ```

   该命令返回变更目录和上下文文件。读取 `contextFiles` 中的所有可用工件。

4. **初始化验证报告结构**

   构建包含三个维度的报告结构：
   - **Completeness**：跟踪任务与规范覆盖
   - **Correctness**：跟踪需求实现与场景覆盖
   - **Coherence**：跟踪设计遵循与模式一致性

   每个维度可能出现 CRITICAL、WARNING 或 SUGGESTION 问题。

5. **验证 Completeness**

   **任务完成情况**：
   - 若 contextFiles 中存在 tasks.md，读取它
   - 解析复选框：`- [ ]`（未完成）与 `- [x]`（完成）
   - 统计完成数量与总数
   - 若存在未完成任务：
     - 为每个未完成任务添加 CRITICAL 问题
      - 建议语："完成任务：<description>" 或 "若已实现请标记为完成"

   **规范覆盖**：
   - 若 `openspec/changes/<name>/specs/` 存在增量规范：
     - 提取所有需求（以 "### Requirement:" 标记）
     - 对每个需求：
       - 在代码库中搜索相关关键词
       - 评估是否存在实现迹象
     - 若需求疑似未实现：
        - 添加 CRITICAL 问题："未找到需求实现：<requirement name>"
        - 建议语："实现需求 X：<description>"

6. **验证 Correctness**

   **需求实现映射**：
   - 对每个增量规范需求：
     - 搜索代码库中的实现证据
     - 若找到，记录文件路径与行范围
     - 评估实现是否符合需求意图
     - 若发现偏差：
        - 添加 WARNING："实现可能偏离规范：<details>"
        - 建议语："对照需求 X 检查 <file>:<lines>"

     **场景覆盖**：
    - 针对增量规范中的每个场景（以 "#### Scenario:" 标记）：
      - 检查代码中是否处理了场景条件
      - 检查是否有覆盖该场景的测试
      - 若场景疑似未覆盖：
        - 添加 WARNING："场景未覆盖：<scenario name>"
        - 建议语："为场景补充测试或实现：<description>"

7. **验证 Coherence**

   **设计遵循**：
   - 若 contextFiles 中存在 design.md：
     - 提取关键决策（查找 "Decision:"、"Approach:"、"Architecture:" 等部分）
     - 验证实现是否遵循这些决策
     - 若发现矛盾：
       - 添加 WARNING："Design decision not followed: <decision>"
       - 建议语："Update implementation or revise design.md to match reality"
    - 若不存在 design.md：跳过设计遵循检查，并注明 "无 design.md 可供校验"

   **代码模式一致性**：
   - 审查新代码是否符合项目模式
   - 检查文件命名、目录结构、编码风格
   - 若偏差显著：
     - 添加 SUGGESTION："Code pattern deviation: <details>"
     - 建议语："Consider following project pattern: <example>"

8. **生成验证报告**

   **总结记分卡**：
   ```
   ## Verification Report: <change-name>

   ### Summary
   | Dimension    | Status           |
   |--------------|------------------|
   | Completeness | X/Y tasks, N reqs|
   | Correctness  | M/N reqs covered |
   | Coherence    | Followed/Issues  |
   ```

   **按优先级列出问题**：

   1. **CRITICAL**（归档前必须修复）：
      - 未完成任务
      - 需求实现缺失
      - 每条都要给出具体可执行的建议

   2. **WARNING**（应修复）：
      - 规范/设计偏差
      - 场景覆盖缺失
      - 每条都有明确建议

   3. **SUGGESTION**（可优化）：
      - 模式不一致
      - 轻微改进
      - 每条都有明确建议

   **最终评估**：
    - 若存在 CRITICAL："发现 X 个关键问题。归档前需修复。"
    - 若仅有 WARNING："无关键问题。仍有 Y 个警告需考虑。可归档（附改进建议）。"
    - 若全部通过："所有检查通过。可归档。"

**验证启发式**

- **Completeness**：关注客观清单项（复选框、需求列表）
- **Correctness**：使用关键词搜索、路径分析、合理推断——不要求完美确定性
- **Coherence**：关注明显不一致，不要纠结风格细节
- **False Positives**：不确定时，优先 SUGGESTION，其次 WARNING，再到 CRITICAL
- **Actionability**：每个问题必须有具体建议，必要时包含文件/行引用

**降级策略**

- 仅有 tasks.md：仅验证任务完成，跳过规范/设计
- 有 tasks + specs：验证完整性与正确性，跳过设计
- 全量工件：验证三个维度
- 总是说明跳过了哪些检查以及原因

**输出格式**

使用清晰的 markdown：
- 汇总记分卡表格
- 问题分组列表（CRITICAL/WARNING/SUGGESTION）
- 代码引用格式：`file.ts:123`
- 具体、可执行的建议
- 避免模糊措辞如 "consider reviewing"
