# 003 · 残留物不占容量，尸体风干变成食物；满员时卵休眠

- 负责：Codex
- 分支：`codex/003-residue-decay`
- 依赖：PR #3、#4 已合并（任务 002 的实验框架 `residue.py` 会在本任务复用）
- 决定来源：`.collab/decisions.md` D5

## 背景

任务 002 证实：尸体和污渍计入总数，会挤占繁殖空间。R2 中定时清尸体后，最终活体 80 → 164。另外，即使零残留，满员时总数卡在 37，成熟卵会无限期停在「快孵化」状态（`Docs/residue-capacity-results.md`）。

负责人选择方案 D：残留不再挤占生态容量；尸体在原地慢慢风干，风干过程中给所在栖息地增加少量食物，然后消失。这样「不收拾尸体，会招来更多小虫」是规则自然组合出来的结果，不是剧情脚本。污渍不影响生态，会一直留着，直到用清洁剂擦掉，所以清洁剂仍然有用。

## 要做

所有生态规则双端同步（Swift / C#），随机数调用次数和顺序保持一致。下面的数值是第一轮取值，集中写成具名常量（双端同名），不要散落在代码里。

### 1. 容量只算活体和卵

- 定义「生态占用」= `adult` / `baby` / `gold` / `egg` 的数量。尸体、污渍、`hatched` 都不算。
- `World.add` 创建卵或幼体、孵化（原 `< capacity - 1`）、产卵（原 `< min(32, capacity - 2)`）三处，都改为使用生态占用，门槛数值不变。
- 残留物有自己的上限 `residueCap = 24`（尸体和污渍合计）。这是性能和桌面整洁的护栏，不是生态规则。
  - 超出时先移除最老的尸体（视为风干完）；没有尸体可移除时，移除最老的污渍。
  - 这类移除要记事件，`rule` 写 `residue-cap`。
- 排查所有以总数作上限的地方，按「活体 + 卵」与「残留」分开处理，并在实现记录里逐处列出。至少包括：
  - Swift `App.swift` 的 `maxResidents` 及其用法，包括读档时 `prefix(maxResidents)` 截断，以及 `LifeUI.swift:433`；
  - C# `Game.cs:251`；
  - WorldBridge 把 Resident 同步进 World 时，不能因为生态满员就丢掉尸体或污渍。目前 `add` 满员返回空字符串，会导致桌面上的残留被 `stepWorld` 删除。

### 2. 尸体风干

- 尸体新增持久字段 `residueAge`（活跃秒，默认 0）。旧存档里的尸体从读档时刻开始风干，**不追补离线时间**。
- 每步 `residueAge += dt`。暂停、专注期间不推进，和生态时间一致；不受生长倍率影响。
- 风干期间，每步给所在栖息地 `food += corpseFood × dt / corpseDecay`，`food` 上限为 1。
  - `corpseDecay = 600` 秒，`corpseFood = 0.25`（一次投喂是 +0.4，作为参照）。
- `residueAge >= corpseDecay` 时移除尸体，记事件：`trigger = "decay"`，`previous = "corpse"`，`new = "removed"`，`rule = "residue"`。
- 风干移除**不算**玩家的捕捉、清理、成就或金壳，也不调用任何玩家工具路径。
- 受保护个体本来就不会死，规则不变。

### 3. 污渍

不进入任何生态计算（容量、食物、偏好都不受影响），一直保留，直到被清洁剂擦掉或触发残留上限。现有清洁剂和扫描行为不变。

### 4. 满员时卵休眠

- 成熟卵（`age >= 180`）因生态占用不足而无法孵化时，进入休眠：`age` 停在 180，不再增长。
- 有空位后，下一步正常孵化，不额外延迟。
- 事件只在进入休眠时记一次（`trigger = "dormant"`），不要每步都记。
- 表现层：休眠卵的外观停在「发育完成但未开裂」，不显示即将孵化的裂纹。

### 5. 表现层（双端）

- 尸体按 `residueAge / corpseDecay` 逐渐变淡、颜色变干，从不透明度 1 降到约 0.35，最后消失。
- 不加文字提示或倒计时。
- 绘制函数不能写 World 状态（沿用 1.7.1 的约束）。

### 6. 测试与实验

- **Swift / C# 模型测试**新增：
  - 残留不计入生态占用；
  - 残留上限的淘汰顺序；
  - 尸体风干的移除时间和食物总量（误差在一步以内）；
  - 风干不发放奖励或成就；
  - 旧存档尸体从 0 开始风干；
  - 满员时卵休眠，有空位后孵化；
  - Resident 同步在生态满员时不丢残留。
- 新增场景 `Tests/Simulation/scenarios/J-corpse-decay.json`，它会自动进入 `run.py` 的双端比对。在 `run.py` 中加断言：
  - 尸体在 600 秒后消失；
  - 所在栖息地的食物比无尸体对照高；
  - 没有出现超出生态占用的出生。
- 用任务 002 的 `residue.py` 在新规则下重跑同一个固定矩阵。
  - 结果写进**新文件** `Docs/residue-decay-results.md`，与 002 的结果逐单元对照。不要改 002 的结果文件。
  - 预期是 R1 的产卵量不再随残留增加而下降，但这只是预期，不是验收条件：如实报告。
- `diff_base.py` 预期会显示行为变化。在实现记录里贴出 CI 的行为差异表，并逐个场景解释原因：例如 F 场景的尸体现在会风干。

## 不做

- 不改工具价格、喷雾和扫描规则、迁移偏好公式。
- 不实现「忙时躲藏」（D6，另有设计和任务）。
- 不调整 `corpseDecay`、`corpseFood`、`residueCap` 去追求好看的数据。第一轮就用上面的值；如果数据显示明显不合理，写进「问题」，不要自己改。

## 验收标准

- [x] CI 全绿：Linux 模型（含新场景 J 的双端比对）、macOS 构建 + 自检 + 集成测试、Windows 发布 + 冒烟。
- [x] 上面列出的模型测试双端都有，并且通过。
- [x] 旧存档兼容：缺新字段时能读档，不追补离线时间。
- [x] 实现记录包含：容量上限位置清单；CI 行为差异表及逐场景解释；`Docs/residue-decay-results.md` 的结论摘要。
- [x] 在 Mac 上实际打开 app，确认尸体会逐渐变淡、消失，并附截图或描述（UI 任务，见 Q2）。

## 问题

无阻塞问题。按任务固定使用 600 秒 / 0.25 / 24，没有为实验结果调参。尸体对食物的贡献会改变后续随机分支，个别种子的产卵少于无尸体对照；完整反例保留在新结果中，未据此扩大任务范围。

## 实现记录

### 2026-10-29 · 实现与边界

从最新 main `eed4c99` 重新建立 `codex/003-residue-decay`，替换此前只记阻塞的提交；PR #3/#4/#5 均已合并。实现 PR：[#6](https://github.com/nancyxieyy/gala-paradise/pull/6)。仅推送 GitHub origin，没有合并 PR 或改动其他远端。

Swift / C# 同步实现生态占用 adult/baby/gold/egg、独立残留限额、600 活跃秒风干及累计 0.25 食物、持久休眠状态；维护路径不增加随机调用。暂停、专注和离线不推进风干，生长倍率也不影响它。读档缺字段时 residueAge=0、dormant=false；已有 age 不作离线补算。风干与护栏均直接移除模型对象，不经过玩家工具或奖励路径。

护栏在完整 World 步骤前后、Resident 桥接及读档边界执行，避免遍历个体时删数组。优先移除 residueAge 最大的尸体，才是最老污渍；同龄按数组顺序。污渍的 residueAge 仅供护栏排序，不用于容量、食物、栖息地创建或偏好。护栏移除记 residue-cap，不补未经历的风干食物。实验 26/30 残留的 0 秒快照保留名义剂量，第一步降至 24；新结果明确说明这一边界。

绘制层只读取模型：尸体颜色逐渐变干、窗口 alpha 从 1 降至 0.35；休眠卵保持完整外壳，不画裂纹。没有新增玩家提示或倒计时，没有修改喷雾、扫描、工具价格、迁移偏好公式或忙时隐藏行为。

### 容量入口排查清单

| 位置 | 处理 |
| --- | --- |
| 双端 World.add / Add | 活体及卵按 ecologicalCount / EcologicalCount 限额；尸体、污渍允许在生态满员时进入。 |
| 双端 World.step / Step 孵化、产卵 | 使用生态占用，保留 `< capacity - 1` 和 `< min(32, capacity - 2)`；孵化前排除已变成 hatched 的卵，两端一致。 |
| Swift App.swift：maxResidents、spawn | 保留 38 阈值，改用包含猫鼠的 populationCount；残留不占该阈值。 |
| Swift App.swift：读档原 prefix(maxResidents) | 改为 limitPopulation，先限活体与卵，再经桥接独立限制残留；排在前面的残留不会挤掉后面的活体。 |
| Swift LifeUI.swift：领养 | 同样使用 populationCount；不改领养保护规则。 |
| Windows Game.cs：Spawn、Restore | Spawn 分开判断残留和人口；Restore 移除 Take(38)，保留坐标有效性校验，独立限制人口和残留。 |
| Windows LifeActions.cs：领养 | 使用 PopulationCount，阈值仍为 38。 |
| 双端 WorldBridge：reconcileWorld / ReconcileWorld | 满生态仍可同步残留；限额后同步删除 Resident，防止下一次桥接复活。阶段变化时重置新字段。 |
| 双端 WorldBridge：stepWorld / StepWorld | 生态容量继续为 38 减猫鼠，保留原共享人口上限；自然风干移除不会计入 captures / cleaned / XP / kills / cards / shells。 |
| 原生集成测试的 maxResidents 断言 | 原来生成 38 个活体的测试保持有效，仍通过；没有继续拿总数当生产入口限制。 |

### 本机验证

环境：macOS 26.6.2、Swift 6.4、.NET 10.0.401、Python 3.9.6。dotnet 不在 shell PATH，实际用仓库本地工具链。

- `./build.sh`：通过，含 Swift 模型自检与新增残留测试。
- `'build/旮旯乐园.app/Contents/MacOS/GalaParadise' --integration-test`：通过，含实际 panel alpha、暂停/专注冻结及恢复推进；未读写正式存档。
- `build/toolchain/dotnet/dotnet run --project Tests/CoreTests -c Release`：通过，含对应 C# 模型测试、读档人口与残留分离、暂停/专注冻结及恢复。
- `python3 Tests/Simulation/run.py`：A–J 全量世界/事件/样本双端比对、重放、跨端存档续跑与控制组全部通过。J 在 600 秒只记一次 decay、无尸体对照食物更低、无凭空出生；全部场景观测生态占用不超过 38。
- `python3 Tests/Simulation/experiments/residue/residue.py`：60 单元 × 双端 = 120 次正式运行全部一致；框架自检也通过。源码哈希与计数序列复核通过。
- `python3 Tests/Simulation/diff_base.py --base origin/main`：通过并报告预期行为变化，表格及解释见下。
- `python3 Tests/style_check.py`、`git diff --check`：通过。

双端新增测试覆盖：残留不占生态容量、尸体优先/最老排序、600 秒风干和净食物贡献 0.25、生长倍率独立、无玩家奖励、旧字段默认值、休眠只记一次、保存恢复不重记、腾空下一步孵化，以及满员桥接不丢残留。污渍位于未知位置也不会创建生态栖息地。

### Mac 原生实测

实际启动 app 的 `--residue-preview`，使用正常计时器和隔离存档，未加速 World。5/305/605 秒回调截取真实 PetView 并合成当时窗口 alpha；实际观测的生态时间分别为 4、304、606 秒。初期 alpha=0.9957，中期 alpha=0.6707 且棕色变为干淡色，最后 Resident=0、panel 已移除（截图全透明）。图像来自原生渲染，不是另画的示意图。

| 初期：4 活跃秒 | 中期：304 活跃秒 | 消失：606 活跃秒 |
| --- | --- | --- |
| ![fresh](../../Docs/residue-decay-visual/fresh.png) | ![dry](../../Docs/residue-decay-visual/dry.png) | ![gone](../../Docs/residue-decay-visual/gone.png) |

原始观测：[observations.txt](../../Docs/residue-decay-visual/observations.txt)。复验命令：`'build/旮旯乐园.app/Contents/MacOS/GalaParadise' --residue-preview`，保持电脑唤醒，约 10 分钟后自动退出，输出位于 build/task003/visual，不触碰正式存档。

### 固定矩阵结论

新结果：[residue-decay-results.md](../../Docs/residue-decay-results.md)；新证据：[residue-decay-evidence.json](../../Docs/residue-decay-evidence.json)。任务 002 的计划、结果、证据文件未改动；全部 60 单元按原 10 项指标逐项对照，并附无损计数序列、基线及源码哈希。

污渍所有剂量在同一种子下的产卵/孵化/活体与零残留完全一致，26/30 残留不再导致零产卵。尸体组所有正剂量不再随剂量上升下降，但 seed 7 的产卵比零残留少（15→12），seed 42 更多（13→15）；不承诺每次不清理都增产。R2 保留尸体组五种子活体合计 80→169、产卵 70→157；定时清理组活体 164→167、产卵 156→165。成熟卵仍可能受原容量门槛限制，只是现在明确休眠且可恢复。没有调常量或补剧情来迎合预期。

### CI 行为差异及逐场景解释

首轮实现提交 `c6b410283d` 的 PR CI 三项均成功：[Linux + macOS](https://github.com/nancyxieyy/gala-paradise/actions/runs/41002596186)、[Windows 发布 + 原生冒烟](https://github.com/nancyxieyy/gala-paradise/actions/runs/41002596281)。macOS 的 informational 集成步骤本次也实际成功。后续提交补齐证据与本记录，并加强暂停/专注测试的恢复对照；最终提交 CI 状态以 [PR #6 checks](https://github.com/nancyxieyy/gala-paradise/pull/6/checks) 为准。

以下原样摘自首轮 [Linux job](https://github.com/nancyxieyy/gala-paradise/actions/runs/41002596186/job/123890201787) 日志，仅去时间戳。Base=`eed4c99851`；Head=`f410bede6c` 是 GitHub 的 PR 合成合并提交，对应分支实现 `c6b410283d`。可独立查看[原表副本](../../Docs/residue-decay-ci.md)。

| Scenario | Result | Metrics (base → head) | First difference |
| --- | --- | --- | --- |
| A-frequent | **differs** | population 32 · eggs 0 · nests 1 · deaths 0 · migrations 19 · births 36 | event log identical; world state or samples differ |
| B-abandoned | **differs** | population 14 · eggs 2 · nests 2 · deaths 0 · migrations 2 · births 14 | event log identical; world state or samples differ |
| C-chemical | **differs** | population 32 → **36** · eggs 0 → **1** · nests 2 · deaths 2 · migrations 25 → **24** · births 33 → **40** | event #58: base `t=398 created absent→egg @Archive` / head `t=360 migration edge→Downloads @Downloads` |
| D-eggs | **differs** | population 12 → **8** · eggs 1 · nests 2 → **1** · deaths 6 · migrations 11 → **9** · births 17 → **11** | event #55: base `t=516 utility nest→eat @Downloads` / head `t=406 utility nest→eat @Archive` |
| E-personality | **differs** | population 2 · eggs 0 · nests 0 · deaths 0 · migrations 2 · births 0 | event log identical; world state or samples differ |
| F-two-hours | **differs** | population 18 → **34** · eggs 0 · nests 2 · deaths 18 → **28** · migrations 296 → **390** · births 42 → **81** | event #244: base `t=1244 incubation egg→hatched @Downloads` / head `t=1244 utility explore→eat @Archive` |
| G-one-day | **differs** | population 32 · eggs 0 · nests 1 · deaths 0 · migrations 12 · births 39 | event log identical; world state or samples differ |
| H-oscillation | **differs** | population 34 · eggs 0 · nests 2 · deaths 0 · migrations 22 · births 39 | event log identical; world state or samples differ |
| I-recovery | **differs** | population 12 → **8** · eggs 1 · nests 2 → **1** · deaths 6 · migrations 11 → **9** · births 17 → **11** | event #55: base `t=516 utility nest→eat @Downloads` / head `t=406 utility nest→eat @Archive` |
| J-corpse-decay | **differs** | population 0 · eggs 0 · nests 0 · deaths 0 · migrations 0 · births 0 | event #0: base `(none)` / head `t=600 decay corpse→removed @edge` |

逐场景解释（状态比较包含序列化字段，不能把所有 differs 都当成随机行为改变）：

| 场景 | 原因与核对 |
| --- | --- |
| A-frequent | 无尸体或休眠变化。事件与分钟样本完全相同；从 head 个体中去掉 residueAge=0、dormant=false 两个默认字段后，整个 world 与 base 完全相同。 |
| B-abandoned | 同样仅新增默认字段；保留 14 活体、2 卵，事件、样本及去默认字段的世界全部相同。 |
| C-chemical | 30 秒时药剂造成两具尸体，新规则从后续步骤回流食物、630 秒风干移除；食物改变意图和后续随机分支，最终 births 33→40。喷雾剂量与死亡规则没改。 |
| D-eggs | 120 秒 defeat 信号在 122 秒步记录六具尸体，尸体食物开始影响剩余卵孵出的幼体，首个事件差异在 406 秒；720 秒移除尸体。新规则并不保证后续巢穴或出生增加，此例 births 17→11，如实保留。 |
| E-personality | 无残留或休眠触发，行为完全保持；去两个默认字段后世界相同，事件及样本原本相同。 |
| F-two-hours | 首具药剂尸体在 1218 秒产生，生态容量已释放、食物开始回流，1244 秒出现事件分支差异；1818 秒起陆续自然风干。两小时活体 18→34、births 42→81，增加的生态周转也使死亡 18→28，未调药剂规则。 |
| G-one-day | 无死亡/残留触发，仅默认字段；全部事件、样本及去默认字段的世界保持相同，出生仍为 39。 |
| H-oscillation | 迁移规则未改，迁移仍 22、births 39；事件、样本及去默认字段的世界保持相同。 |
| I-recovery | 与 D 使用相同初始压力和六次 defeat 路径，食物/容量分离改变后续意图与巢穴，结果同为活体 12→8、births 17→11；不是恢复时补怪。 |
| J-corpse-decay | 新场景无活体和卵；base 尸体永远存在，head 在 600 秒记 decay/corpse→removed/residue，食物高于无尸体对照，births 始终 0。 |

遗留问题：无阻塞项。保持原 37 附近孵化门槛，成熟卵仍可能长期休眠；这是本任务明确保留的容量规则。Windows 原生发布和冒烟已由 CI 运行，本机为 macOS，不声称完成 Windows 真人体验验收。任务 004 尚未开始。
