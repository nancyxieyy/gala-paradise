# 看板

更新于 2026-10-27。路线见 `decisions.md` D1：0 协作与 CI → 1 可读性 → 2 生态容量 → 3 渐进式体验。

| # | 任务 | 负责 | 状态 | 分支 |
| --- | --- | --- | --- | --- |
| 000 | 协作流程、AGENTS.md、CI | Claude | review（CI 全绿，等你合并 PR #1） | `claude/000-foundation` |
| 001 | [代码格式化，不改行为](tasks/001-readable-formatting.md) | Codex | review（本地等价与行为检查通过，CI 见 PR） | `codex/001-readable-formatting` |
| 002 | [验证尸体/污渍挤占容量](tasks/002-residue-capacity-evidence.md) | Codex | ready（001 合并后开始） | `codex/002-residue-capacity-evidence` |
| 003 | 修复容量问题 | — | 等 002 数据 + Q1 决定 | — |
| 004+ | 渐进式体验：玩家旅程设计 → 实现 | Claude 先出设计 | 规划中 | — |

## 给 Codex

000 合并到 main 之后，从 001 开始。按顺序做，一次一个任务。
