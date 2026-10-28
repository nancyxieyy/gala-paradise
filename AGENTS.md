# AGENTS.md — 给 Codex（以及任何写代码的 agent）

旮旯乐园是离线桌宠 + 生态模拟。macOS 用 Swift / AppKit（`Sources/`），Windows 用 C# / WinForms（`Windows/`），**两端各自实现同一套生态规则**，靠跨语言模拟比对保持一致。先读 `README.md` 和 `Docs/development.md`。

## 协作方式

- 本仓库由 Claude（规划、审查）和 Codex（写代码）协作，**只通过仓库交流**。流程见 `.collab/README.md`，当前进度见 `.collab/STATUS.md`。
- 开工前：`git pull`，读 `.collab/STATUS.md`，找到分配给你的任务文件 `.collab/tasks/NNN-*.md`，严格按「要做 / 不做 / 验收标准」执行。
- 在分支 `codex/NNN-简短名` 上工作，不要直接提交到 `main`。
- 完成后在任务文件末尾的「实现记录」里写：改了什么、为什么这样做、跑了哪些命令和结果、遗留问题。然后 push 分支并开 PR。
- 任务里有不清楚或做不到的地方：不要自己扩大范围，写进任务文件的「问题」一节，push 后停下等回复。

## 硬规则

1. **生态规则必须双端同步。** 改 `Sources/World.swift` 就必须同样改 `Windows/World.cs`（WorldBridge、ReadableDesktop 等同理），随机数调用的次数和顺序也要一致。`python3 Tests/Simulation/run.py` 必须通过。
2. **不写剧情脚本。** 不加「某事件后强制发生某事」的导演代码、不凭空补怪、不按游玩时长解锁。生态结果只能来自规则组合（见 `Docs/emergent-world-v0-results.md` 第 3 节和 1.7.1 结果第 7 节）。
3. **存档兼容。** 新字段必须有默认值，旧存档能读；不追补离线时间。
4. **隐私。** 不读取文件内容、剪贴板、按键；位置只存 SHA-256；盲测日志不记录名字、纸条、路径。
5. **不改行为的任务就真的不改行为。** 行为差异检查（下面）必须显示与 base 完全一致。
6. 不要修改 `Docs/` 里已发布的实验结果和证据文件；新实验写新文件。

## 构建与测试

Linux（你的环境和 CI 都是 Linux）能跑的：

```sh
dotnet run --project Tests/CoreTests -c Release      # Windows 端玩法模型测试（不依赖 WinForms）
python3 Tests/Simulation/run.py                      # Swift / C# 生态全量比对 + 重放 + 存档续跑（需要 swiftc 和 dotnet）
python3 Tests/Simulation/diff_base.py --base origin/main   # 本分支与 main 的生态行为差异报告
python3 Tests/Simulation/diff_base.py --base origin/main --require-identical  # 纯重构时用：任何差异都失败
```

只能在 macOS 跑的（CI 的 macOS 任务会跑）：

```sh
./build.sh                                            # 编译 + --self-test（Swift 模型测试）
'build/旮旯乐园.app/Contents/MacOS/GalaParadise' --integration-test
```

只能在 Windows 跑的（CI 的 Windows 任务会跑）：发布 + `GalaParadise.exe --smoke-test`。

本地没有某个工具链时，在实现记录里写明「未在本地运行，依赖 CI」，不要声称通过。

## CI

`.github/workflows/checks.yml`（Linux 模型 + macOS 构建）与 `.github/workflows/windows.yml` 在每次 push 和 PR 时运行。PR 合并的前提是 CI 全绿。行为差异报告会写进 Actions 的 Summary。

## 代码风格

- 现有代码非常紧凑（一行多条语句）。任务 001 之后统一为每行一条语句、行宽 ≤ 120 的常规格式；在那之前，改动的代码按常规格式写，不要继续堆长行。
- 不引入第三方依赖，除非任务明确要求。
- 提交信息用中文或英文都可以，写清楚改了什么。
