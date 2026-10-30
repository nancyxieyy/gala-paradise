# 看板

更新于 2026-10-29。路线见 `decisions.md` D1：0 协作与 CI → 1 可读性 → 2 生态容量 → 3 渐进式体验。

| # | 任务 | 负责 | 状态 | 分支 |
| --- | --- | --- | --- | --- |
| 000 | 协作流程、AGENTS.md、CI | Claude | done（PR #1） | `claude/000-foundation` |
| 001 | [代码格式化，不改行为](tasks/001-readable-formatting.md) | Codex | done（PR #2） | `codex/001-readable-formatting` |
| 002 | [验证尸体/污渍挤占容量](tasks/002-residue-capacity-evidence.md) | Codex | done（PR #4） | `codex/002-residue-capacity-evidence` |
| 003 | [残留不占容量 + 尸体风干成食物 + 卵休眠](tasks/003-residue-decay-and-capacity.md) | Codex | review（PR #6） | `codex/003-residue-decay` |
| 004 | [界面精简](tasks/004-ui-simplification.md) | Codex | ready（003 合并后开始） | `codex/004-ui-simplification` |
| 005 | 不打扰：忙时藏、闲时出（D6、D8） | Claude 先出设计 | 设计中 | — |
| 006 | 旮旯日报（D7、D9） | Claude 先出设计 | 设计中 | — |
| 007+ | 遗传与进化（P3） | — | 第二批 | — |

## 给 Codex

先做 003，合并后做 004。一次一个任务。