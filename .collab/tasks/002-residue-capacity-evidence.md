# 002 · 验证：尸体和污渍是否挤占生态容量（只做实验，不改规则）

- 负责：Codex
- 分支：`codex/002-residue-capacity-evidence`
- 依赖：001 合并之后再开始（避免和格式化冲突）

## 背景

Claude 读代码时发现的疑点，需要数据确认后才能决定怎么改（见 `.collab/decisions.md` 的 Q1）：

- `WorldBridge.reconcileWorld()` 把所有非猫鼠 Resident 都放进 `world.creatures`，包括污渍（stain）和尸体（corpse）。
- `World.add()`（`count < capacity`）、孵化（`count < capacity - 1`）、产卵（`count < min(32, capacity - 2)`）都用 `creatures.count`，所以尸体和污渍也算在容量里。
- 免费工具「捏一下」留下污渍，人字拖留下尸体，药剂致死也留下尸体；只有吸尘器（6 金壳）能清尸体，只有清洁剂（5 金壳）能清污渍。
- 推测：不花钱清理的玩家，生态会逐渐停止产卵，已有的卵也孵不出来。F 场景结束时尸体 20 + 活体 14 = 34 ≥ 32，后期停滞可能部分来自这个原因。

## 要做

1. **先核对推测**：在实现记录里列出上述每一条在 Swift 和 C# 里对应的代码位置（文件:行号）。如果哪条推测是错的，直接写出来。
2. **实验框架**（只改测试代码，双端同步）：
   - 在 `Tests/Simulation/main.swift` 和 `Tests/Simulation/Program.cs` 的场景格式里加一个可选字段 `removeCorpsesEvery`（秒）：每隔这么久，对当时所有 `corpse` 发送 `remove` 信号。不填时行为完全不变（`diff_base.py` 必须 identical）。
   - 新建 `Tests/Simulation/experiments/residue/`，放场景和运行脚本 `residue.py`。脚本自己编译 Swift 模拟器，不要 `import run`（那会把全套测试再跑一遍）。
3. **实验设计**（先把设计写进 `Docs/residue-capacity-plan.md` 并提交，再跑实验，和 1.7.1 的做法一致）：
   - 种子固定为 7、19、42、73、101，时长 2 小时。
   - **R1 剂量反应**：一个稳定、可筑巢、有食物的栖息地，8 只成虫，初始放 0 / 10 / 20 / 26 / 30 个残留物；残留物分「全是 corpse」和「全是 stain」两组。
   - **R2 现实对照**：F 场景原样运行，与 `removeCorpsesEvery: 60` 对比。
   - 每次运行记录：最终活体数、产卵次数、孵化次数、births、`creatures.count` 首次达到 32 的时间、卵年龄 ≥180 但没有孵化的累计时长、巢穴数、死亡数。
4. 结果写进 `Docs/residue-capacity-results.md`，原始数据写进 `Docs/residue-capacity-evidence.json`。结果只陈述数据和是否支持推测，**不提修改方案**。

## 不做

- 不改 `Sources/World.swift`、`Windows/World.cs`、`WorldBridge` 等任何产品代码。
- 不调参数、不挑种子，五个种子全部报告。

## 验收标准

- [ ] CI 全绿；`diff_base.py` 对已有场景显示 identical。
- [ ] `run.py` 仍然通过（新字段在双端解析一致）。
- [ ] 计划文件的提交早于结果文件。
- [ ] 结果表覆盖 R1（2 组 × 5 档 × 5 种子）和 R2（2 组 × 5 种子），附可复现的命令。
- [ ] 实现记录包含第 1 步的代码位置核对。

## 问题

（Codex 有疑问写在这里）

## 实现记录

（Codex 完成后填写）
