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

无阻塞问题。背景中清理入口和历史 F 数值存在需要纠正的事实，已在下方核对及结果中注明，没有改变实验范围或产品规则。

## 实现记录

### 先后顺序与范围

已拉取 `main` 到 `f351d45`，确认该提交已合并任务 001（PR #2），再创建指定分支。先单独提交 `Docs/residue-capacity-plan.md` 为 **`a4bab2e`**，此时尚未实现或运行实验；之后才增加测试框架、运行固定矩阵和生成结果。框架及场景提交为 `42db973`，结果、证据与本记录在后续提交中加入，计划文件未根据结果调整。

只改两个无界面模拟入口，并新增实验场景、独立运行脚本和三份新实验文档。`Sources/`、`Windows/` 全部产品文件均无 diff，旧实验与证据没有改动。没有开始任务 003，也没有对 Q1 提出处理方案。

### 背景推测的双端位置核对

以下为产品基线 `f351d45` 的行号；本任务没有改这些文件，因此行号保持不变。

| 背景中的说法 | Swift 位置 | C# 位置 | 核对结论 |
| --- | --- | --- | --- |
| WorldBridge 同步非猫鼠住客，包括污渍和尸体 | `Sources/Game.swift:60` 定义 friend；`Sources/WorldBridge.swift:37` 遍历、`:42` 添加、`:54` 同步 stage；初次迁移另见 `:15` | `Windows/Game.cs:79` 定义 Friend；`Windows/WorldBridge.cs:30` 建集合、`:34` 遍历、`:39` 添加、`:50` 同步 stage；初次迁移 `:21` | 支持。只排除猫鼠，没有排除 stain/corpse；添加仍受 World.add 容量限制，并非无限制插入。 |
| 添加、孵化、产卵都用总 creatures 数 | `Sources/World.swift:57` 默认 38；`:101` add 门槛；`:252` 孵化；`:348` 产卵 | `Windows/World.cs:139` 默认 38；`:226` Add 门槛；`:391` 孵化；`:479` 产卵 | 支持。分别是 `<capacity`、`<capacity-1`、`<min(32,capacity-2)`，均未过滤残留。桌面桥接还会扣除猫鼠名额，见 Swift `WorldBridge.swift:72` / C# `WorldBridge.cs:74`；本次纯 World 实验没有猫鼠占额。 |
| 捏一下留污渍，人字拖和药剂留尸体 | `Sources/Game.swift:147` 命中后按工具转 stage；`Sources/World.swift:285` 药剂致死 | `Windows/Game.cs:495` 命中后转 Kind；`Windows/World.cs:422` 药剂致死 | 对未受保护且命中的个体成立。逃飞、保护、朋友等原有例外仍保留，实验不改它们。 |
| 捏取免费，吸尘器 6、清洁剂 5；只有吸尘器能清尸体 | `Sources/Progression.swift:9` 至 `:15` 是金壳价格，`:38` 至 `:42` 为兑换；`Sources/Game.swift:151` 清污渍、`:157` 清卵/尸体；另见 `Sources/App.swift:484`、`:495` 扫描 | `Windows/Game.cs:17` 价格，`:186` 至 `:195` 兑换；`:502` 至 `:505` 清理；另见 `:236`、`:241` 扫描 | 价格正确，且是一次性解锁成本，不是每次使用付费。**“尸体只能用吸尘器”不完整**：4 金壳喷雾解锁后的全局扫描也移除未受保护尸体；扫描保留 stain，污渍仍用清洁剂。 |
| 不清理导致停止产卵、已有卵无法孵化；F 结束 20 尸体 + 14 活体 | 容量条件见 `Sources/World.swift:252`、`:348`，剩余非活体不会自行移除（`:358` 仅删除 hatched） | `Windows/World.cs:391`、`:479`；`:486` 仅删除 hatched | 是否、何时发生不能只靠静态条件推出。结果支持占额和产卵受限，成熟卵滞留并非所有单元都有。背景 F 数字对应既有 1.7.1 evidence 的 seed 42 / control；当前默认 treatment 的本次 seed 42 是 18 尸体 + 18 活体 = 36，成熟卵滞留为 0。 |

清理实验发送的是现有 remove 信号，处理位置为 `Sources/World.swift:169` 至 `:179`、`Windows/World.cs:313` 至 `:324`；保护检查未绕开。两端 applySignals 都会增加 interactions（Swift `World.swift:132` / C# `World.cs:265`），所以 R2 不是隔离其他变化的纯容量干预，结果文档明确保留这一限制。

### 实验实现与产出

双端新增可选 `removeCorpsesEvery`，不填/null/非正数不清理。正间隔只在指定边界对当前 corpse 发送信号，保留原个体顺序和原动作顺序，不清污渍、卵或活体。观察代码不调用随机数或发送额外信号；总数门槛、成熟卵积分、计数序列独立输出为 capacityEvidence，旧 world / eventLog / samples 不变。

独立脚本为 `Tests/Simulation/experiments/residue/residue.py`，自行编译 Swift / .NET，不 import run。R1 采用真实模拟器的 0 秒初始化快照，使同一种子的各剂量保持相同成虫、rng 和 serial；R2 的保留输入与 F 完全一致，清理组仅增加一个字段。12 份固定场景 × 五个种子完整执行，共 60 正式单元、120 次双端模拟，没有改变预定参数或排除种子。

框架检查覆盖省略字段、null、0、负数、清理时点、非整步间隔、只清尸体、保护规则与已知成熟卵积分。每个正式单元都独立复算压缩计数序列的首达时间和两类积分，核对终点阶段计数及 births = 产卵事件 + 2 × 孵化事件，并比对两端完整世界、事件、分钟样本和新增观测。

结果见 `Docs/residue-capacity-results.md`，包含 R1 全部 50 行、R2 全部 10 行、固定分组汇总和配对差值。`Docs/residue-capacity-evidence.json` 约 451 KB，包含每单元双端指标、共同原始计数序列、事件分类计数、终点阶段分布、输入/输出及 19 份源文件哈希；完整输入和双端输出在 `build/simulation/residue/`，可由脚本重建。

数据支持残留物占容量、压低繁殖空间，但没有支持“残留越多，成熟卵滞留越严重”的单调说法。高残留组没产卵，不能冒充孵化失败；零残留也会滞留。R2 五种子清理组最终活体和产卵均更多，合计成熟卵·秒更少，但 seed 19、42 有反例，死亡数也更高。没有把清理的全部差值归因为容量，更没有提出修改方案。

### 本地实际命令和结果

环境为 macOS 26.6.2 / Apple Silicon，Apple Swift 6.4（swiftlang-6.4.0.34.1）、.NET SDK 10.0.401、Python 3.9.6。没有新增第三方依赖，脚本自动使用本地已有 dotnet 工具链。

```text
python3 Tests/Simulation/experiments/residue/residue.py
PASS framework: omitted/null/disabled, cleanup time/type/protection, odd boundary, integrals
PASS complete 60-cell / 120-engine matrix; evidence written

python3 Tests/Simulation/run.py
PASS A-E hypotheses, no-egg control, empty-world control, cross-language save/resume
（A–I 全部状态、事件、样本和重复重放通过）

python3 Tests/Simulation/diff_base.py --base origin/main --require-identical
All scenarios identical to base.

python3 Tests/style_check.py
PASS line width: 34 files; limit 120 (single-literal lines excepted)

git diff --check
（通过）
```

另独立检查了矩阵单元数及唯一性、双端指标、19 份已记录源文件哈希、结果/计划链接，以及 `git diff origin/main -- Sources Windows` 为空。未为本次无产品改动重复运行本地 AppKit/Windows GUI；Linux、macOS、Windows 的最终构建、自检与原生冒烟以本 PR CI 为准，不声称本地执行过 Windows 原生测试。

### 遗留问题

无阻塞问题。完整证据已交付，产品处理留待 Q1 决定与后续任务；本任务不合并 PR，不修改产品规则。
