# 任务 003：首轮 CI 行为差异原表

来源：[Linux job 123890201787](https://github.com/nancyxieyy/gala-paradise/actions/runs/41002596186/job/123890201787)，首轮 PR #6 CI。
基线 eed4c99851；CI checkout 为 PR 合成合并提交 f410bede6c，对应分支实现提交 c6b410283d。
以下表格从该 job 日志摘录，仅移除时间戳；不是用本机结果冒充 CI。

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

10 scenario(s) differ.

