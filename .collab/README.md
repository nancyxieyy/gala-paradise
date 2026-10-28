# 协作流程

三方：**你**（项目负责人，做产品决定）、**Claude**（规划、写任务、审查）、**Codex**（写代码）。Claude 和 Codex 只通过这个仓库交流。

## 文件

| 路径 | 谁写 | 内容 |
| --- | --- | --- |
| `.collab/STATUS.md` | Claude 维护 | 看板：每个任务的状态、负责方、分支 |
| `.collab/tasks/NNN-名字.md` | Claude 写前半部分，Codex 补「实现记录」 | 一个任务一个文件 |
| `.collab/reviews/NNN.md` | Claude | 对某个任务分支的审查意见，按轮次追加 |
| `.collab/decisions.md` | Claude 记录，你拍板 | 需要产品决定的问题和结论 |

## 一个任务的生命周期

1. **Claude 写任务**：在 `main` 上新增 `.collab/tasks/NNN-*.md`，STATUS 标为 `ready`，push。
2. **Codex 实现**：从 `main` 拉出 `codex/NNN-*` 分支；实现；在任务文件末尾写「实现记录」；push 并开 PR；STATUS 改为 `review`（在分支里改即可）。
3. **Claude 审查**：拉取分支，看 diff、CI 结果和行为差异报告；把意见写进 `.collab/reviews/NNN.md`，push 到同一分支。
   - 需要修改：STATUS 标 `changes-requested`，Codex 拉取后按意见改，再次 push，回到第 3 步。
   - 通过：STATUS 标 `done`，Claude 合并到 `main`（squash）。
4. 涉及产品取舍的问题（数值手感、要不要某个玩法），Claude 写进 `decisions.md` 并标 `待你决定`，任务暂停在 `blocked`。

## 状态

`ready` 可以开工 · `in-progress` 正在做 · `review` 等审查 · `changes-requested` 需要修改 · `blocked` 等决定 · `done` 已合并

## 规则

- 合并条件：CI 全绿（Linux 模型、macOS 构建、Windows 构建与冒烟），审查通过。
- 一个分支只做一个任务。任务太大就在「问题」里提出拆分，不要自行扩大范围。
- 任何人都不直接改别人负责的部分：Codex 不改任务的「要做 / 验收标准」，Claude 不在 Codex 的分支上改产品代码（只加审查文件）。
- 你随时可以在任何文件里留言或推翻决定；以你的话为准。
