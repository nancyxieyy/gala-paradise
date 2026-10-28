# 001 · 代码格式化（只改排版，不改行为）

- 负责：Codex
- 分支：`codex/001-readable-formatting`
- 依赖：000（CI 与 diff_base.py 已在 main）

## 背景

现有 Swift / C# 代码一行塞多条语句，最长的行接近 700 个字符。后面所有逻辑改动都要靠审查 diff 来把关，长行让每次改动都变成整行重写，无法审查。这一步只为可读性服务，**行为必须完全不变**。

## 要做

1. 加格式配置并提交：
   - Swift：`.swift-format`，`lineLength: 120`，缩进 4 空格；**关闭所有会改写代码的规则**（`rules` 全部设为 `false`），只让它调整空白和换行。
   - C#：`.editorconfig`，缩进 4 空格；用 `dotnet format whitespace` 或你自己的脚本，把一行多条语句拆成每行一条。
2. 格式化以下文件：
   - Swift：`Sources/*.swift`、`Tests/WorldTests.swift`、`Tests/Simulation/main.swift`
   - C#：`Windows/*.cs`、`Tests/CoreTests/Program.cs`、`Tests/Simulation/Program.cs`
   - 目标：每行一条语句；行宽 ≤ 120（超长的字符串字面量可以例外）。
3. 新增 `Tests/style_check.py`：
   - **行宽检查**：上述目录中，除「整行主要是一个字符串字面量」的情况外，任何超过 120 字符的行都报错。
   - **等价检查**：`python3 Tests/style_check.py --equivalent <base-ref>`。对每个改动过的 .swift / .cs 文件，去掉字符串、注释以外的所有空白后，与 base 版本的 token 序列逐一比较，必须完全一致。Swift 里格式化去掉的 `;` 可以在归一化时忽略；如果还有其他必须归一化的差异（比如尾随逗号），在脚本里逐条写明，并在实现记录里列出来。
   - 在 `.github/workflows/checks.yml` 的 Linux 任务里加一步运行行宽检查。
4. 分三个提交，方便审查：
   1. 配置文件 + 模型文件：`World` `WorldBridge` `Game` `Life` `LifeActions` `Progression` `Habitat` `ReadableDesktop` `BlindSession`（双端）
   2. 界面文件：其余 `Sources/*.swift` 和 `Windows/*.cs`
   3. 测试文件 + `style_check.py` + CI 改动

## 不做

- 不改名、不重排语句、不拆分或合并文件、不删注释、不改任何逻辑或数值。
- 不改 `Docs/`、`Resources/`、Python 实验脚本。
- 看到 bug 也不修：记在实现记录的「顺手发现」里，留给后续任务。

## 验收标准

- [ ] CI 全绿：Linux 模型任务（CoreTests、`run.py`）、macOS 构建与自检、Windows 构建与冒烟测试。
- [ ] CI Summary 里的「Ecology behaviour vs base」显示 **All scenarios identical to base**。
- [ ] `python3 Tests/style_check.py --equivalent origin/main` 通过（在实现记录里贴输出）。
- [ ] 行宽检查通过，并已加进 CI。
- [ ] 实现记录里写明：用了哪些工具和版本、哪些步骤在本地实际跑过、哪些只靠 CI。

## 问题

（Codex 有疑问写在这里）

## 实现记录

（Codex 完成后填写）
