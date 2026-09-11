# 旮旯乐园 · Gala Paradise

macOS / Windows 离线卡通桌面生态。当前版本 **1.7.0 — Emergent World V0**。

这一版验证：写世界的规律，让玩家行为与环境自己组合出事件。不新增动物、成就或 UI 页面，不调用 AI、云服务或服务器。

## 生态发生了什么变化

- 打开文件夹只向对应栖息地增加扰动；已有个体根据性格、记忆、药剂与拥挤程度决定逃、藏、停留或迁移。不会按打开次数凭空生成一群。
- 喂食留下虚拟食物；安静位置可能形成巢穴，吃饱的成虫在稳定巢穴中有概率产卵。卵经过孵化出现幼体，幼体成长时可能成为黄金旮杂。
- 点击喷雾会留下逐渐消退的药剂，按剂量、距离和耐受度累积影响。可能逃走、受影响或死亡；卵壳会延缓孵化。没有全体瞬间死亡，也没有清空后定时补一只的脚本。
- 猫鼠来访由生态活动、玩家交互、概率与冷却共同决定；不再有三分钟／十分钟解锁。
- 碎屑来自实际巢穴被经过的住客暴露；点击只发现现有巢穴，不生成奖励蟑螂。

少虫或空白桌面正常。彻底移除所有住客和卵可能使该存档生态归零，不会自动补怪；已有领养入口仍可接住客。正在验证规则，不承诺每个玩家都经历相同场景。

## 直接互动

![小工具盒](Resources/preview.png)

**左键使用当前工具，右键直接交朋友。** Mac 也支持 Control + 单击。鼠标靠近时动物稍停一下，菜单关闭后继续等一会儿；养成互动原地发生，不再要求先在手册里选择动物。

| 工具 | 普通旮杂 | 猫、老鼠与受保护住客 |
| --- | --- | --- |
| 捏一下 | 捕捉、奶油爆浆 | 摸摸、蹭手、呼噜 |
| 人字拖 | 拍打或飞行躲避 | 老鼠闪开、猫爪接住 |
| 蟑螂药 | 喷药 | 打喷嚏、抖掉泡沫 |
| 吸尘器 | 吸走 | 吹乱毛、按住吸嘴 |
| 清洁剂 | 擦去污渍 | 擦脸、闪光 |

点击后动物旁有短气泡、动作和工具效果。连续点击仍有回应，好感冷却只限制数值增长。伤害工具不会永久伤害猫鼠或已命名、已驯养、已领养的住客。

右键菜单提供抚摸、投喂、起名字、成为伙伴；黄金旮杂可收获金壳，猫鼠伙伴可去右侧巡逻。把复杂操作留给菜单，桌面上直接玩。

主界面缩为小工具盒，设置、文件夹联动、试玩和扫描移到右上角「···」及系统菜单。「我的小窝」分为四页，不再把所有功能堆在一张表上。

![我的小窝](Resources/life-preview.png)

## 保留的功能

「我的小窝」仍有伙伴、纸条、专注、成就四页。命名、伙伴与领养住客继续受保护；猫鼠的工具互动只产生安全反馈。纸条只保存主动提交的文字，随时取回、标记或删除；领养码仍是离线副本，不包含路径或纸条。22 张成就只记录真实完成的行为，不倒推补发历史。

关系数值保留在模型中，界面不再展示信任倒计数；有效互动仍有防连点奖励冷却与内部关系门槛。金壳兑换价格保持：拖鞋 2、喷雾 4、吸尘器 6、清洁剂 5；捏取免费。

专注期间隐藏住客并暂停生态；离线、暂停和安静时间不追补生态事件。生长 0.25× / 1× / 3×只影响繁殖、孵化和成长。清理入口清除游戏对象、巢穴和虚拟残渣，保留受保护住客和手动清洁的污渍；它不是真实杀毒或清理软件。

## 实现与边界

`Sources/World.swift` 与 `Windows/World.cs` 是两个平台的同规则实现，不共享二进制。World 保存种子、PRNG、生态时间、个体需求／记忆／意图、栖息地、巢穴、药剂、信号队列与近期事件。Life 继续负责关系、纸条、领养与成就；Resident 是原有渲染／直接工具交互的兼容投影。WorldBridge 将明确的工具结果与关系同步到世界，世界决定后续生态结果。

模拟每 2 个活跃秒计算一次；渲染继续插值。最多 38 个总住客、64 个游戏栖息地、128 条待处理信号、512 条近期事件。存档脏时每 30 秒合并落盘，正常退出立即写入。异常退出最多丢失最近约 30 秒变动。

文件夹只取前台位置身份与窗口边框，按 SHA-256 匿名存储；不分析文件名语义，不读取文件正文、剪贴板或键盘，不删除／移动用户文件。只有观察过的位置参与模拟，窗口几何仅在内存中。旧存档保留住客、名字、伙伴、纸条、已购工具、金壳及已获得成就；新生态字段填默认值，不追补离线年龄与历史事件。旧的定时碎屑标志不算存在巢穴的证据。

确定性范围是世界状态与事件；系统窗口位置、动画路径、真实时间下的玩家操作与原有直接工具飞行随机数不承诺逐像素重放。需要复现生态时使用固定初始状态、种子、动作序列和固定步长。

## 开发与模拟

需要 Xcode Command Line Tools、.NET 10 SDK。构建脚本支持 `GALA_DOTNET`，也支持仓库已有的 `build/toolchain/dotnet/dotnet`。

```sh
./build.sh
'build/旮旯乐园.app/Contents/MacOS/GalaParadise' --integration-test
python3 Tests/Simulation/run.py
./package-release.sh
```

模拟器无需桌面权限。七份场景位于 `Tests/Simulation/scenarios/`，覆盖高频文件夹、闲置位置、药剂冲击、卵后恢复、不同性格、两小时与一天。JSON 可以指定 seed、duration（秒，2 的倍数）、rate、初始栖息地和个体、actions。动作包括 visit / food / chemical / friendly / threat / defeat / remove / clean；at 是相对本次运行的秒数，every 为重复间隔。恢复测试可传 initial 世界快照。

```sh
build/world-sim Tests/Simulation/scenarios/C-chemical.json build/chemical.json
build/toolchain/dotnet/dotnet Tests/Simulation/bin/Release/net10.0/Simulation.dll Tests/Simulation/scenarios/C-chemical.json build/chemical-windows-model.json
```

输出 WorldState、完整 EventLog、每分钟样本、Population / Nests / Eggs / Deaths / Migrations / Births 与耗时。`unexpectedInteractions` 只是供人工审查的迁移／巢穴候选事件，不自动声称它们是新故事。开发时加 `--world-log` 可向 stdout 输出带序号的 JSON 事件；正式界面不显示日志。`--benchmark-idle` 是隔离的 30 秒原生性能测试，可加 `--paused`；不读写玩家存档。

[架构计划](Docs/emergent-world-v0-plan.md) · [实验结果与失败记录](Docs/emergent-world-v0-results.md) · [历史设计草案](Docs/玩法与支线设计草案.md) · [验收记录](Tests/VALIDATION.md)

## 运行与朋友测试包

- macOS 13+：Universal，Apple Silicon / Intel；Windows 10 22H2 / 11 x64：自带 .NET 运行时。
- 收起后用 Mac 顶部图标或 Windows 托盘换工具；退出旧程序再打开新版。
- 发布包：`releases/GalaParadise-1.7-macOS-Universal.zip`、`releases/GalaParadise-1.7-Windows-x64.zip`。
- Mac 存档：`~/Library/Application Support/GalaParadise/save.json`；Windows：`%LOCALAPPDATA%/GalaParadise/save.json`。旧 Mac habitat.json 只用于设置与初次迁移。
- Windows 原生鼠标、DPI、资源管理器仍需真机测试；交叉构建与模型通过不等于 Windows UI 通过。未配置发行签名或 Mac 公证。
