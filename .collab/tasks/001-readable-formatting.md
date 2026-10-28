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

无。

## 实现记录

### 改动与取舍

基于 `main` 的 `d19e827` 实现，仅调整指定 34 个 Swift / C# 文件的空白、换行与 Swift 可选语句分号。没有改标识符、语句顺序、数值、字符串或注释，也没有修改 `Docs/`、`Resources/` 或既有 Python 实验脚本。

新增 `.swift-format`（120 字符、4 空格、生成配置中所有 `rules` 均为 `false`）及 `.editorconfig`。使用 Apple `swift format`、`dotnet format whitespace` 和本地 Python 空白处理辅助脚本拆开紧凑语句并补足长行换行。格式工具会调整 C# 字符串插值内部的空白，因此最后恢复了原始字面量；这部分也按原文参与等价检查。

`Tests/style_check.py` 只用 Python 标准库，覆盖任务列出的文件。超过 120 字符时，只有单个字符串字面量占非缩进文本至少 80%、且其余部分仍不超过 120 字符的行可以例外，不能用多个短字符串豁免密集代码。等价检查保留字符串（包括插值表达式）、字符字面量及注释的原文，逐一比较其余词法元素。**唯一非空白归一化是忽略 Swift 字符串、注释之外的语句分号；没有尾随逗号或其他归一化。** Linux CI 已增加行宽检查。

按要求拆为三次提交：配置及模型；原生界面与交互；测试文件、检查脚本、CI 和本实现记录。看板仅把 001 改为 `review`，没有开始 002。

本地原先以 `github` 命名 GitHub 远程、以 `origin` 命名阿里云远程；已分别重命名为 `origin` 和 `codeup`，地址与历史均保留，使验收命令中的 `origin/main` 确实对应 GitHub 基线。

### 工具与本地验证

实际环境是 macOS 26.6.2 / Apple Silicon（不是 Linux）。Swift 为 Apple Swift 6.4（swiftlang-6.4.0.34.1），`swift format --version` 输出 `main`；.NET SDK 为 10.0.401，`dotnet format` 为 `10.0.401-servicing.26423.113+e34a38d2ae1fc26406a317517196e55c68ff83ab`；Python 为 3.9.6。没有新增项目依赖。

本地实际运行并通过：

```text
python3 Tests/style_check.py --equivalent origin/main
PASS line width: 34 files; limit 120 (single-literal lines excepted)
PASS token equivalence: 34 changed Swift/C# files vs origin/main
Normalization: whitespace outside literals/comments; Swift statement semicolons only.
```

- `python3 -m doctest -v Tests/style_check.py`：8 个可重复运行的正反例通过，覆盖空白、Swift / C# 分号、字符串、注释、数值、标识符和运算符改动；另在本地用 18 个词法用例及 4 个行宽用例验证了嵌套插值、raw / verbatim 字符串、嵌套注释、字面量例外和长代码拒绝。
- `./build.sh`：Mac 编译与 Swift 模型自检通过。
- `'build/旮旯乐园.app/Contents/MacOS/GalaParadise' --integration-test`：原生集成测试通过，包括窗口、左右键交互、暂停、专注、迁移与孵化投影。
- `build/toolchain/dotnet/dotnet run --project Tests/CoreTests -c Release`：Windows 玩法模型测试通过。
- `python3 Tests/Simulation/run.py`：A–I 九个场景的 Swift / C# 完整状态、事件、样本、重放、空生态对照与跨语言保存续跑检查全部通过。
- `python3 Tests/Simulation/diff_base.py --base origin/main --require-identical`：A–I 九个场景均为 `identical`，结论为 **All scenarios identical to base.**
- `git diff --check`：通过。

Linux 主机上的模型运行、CI macOS 环境以及 Windows 原生发布 / 冒烟测试依赖 PR 的 CI，不将本地 Mac 上的模型测试当成 Windows 原生验证；最终 CI 状态以 PR checks 与 Actions Summary 为准。

### 遗留与顺手发现

无阻塞问题，没有顺手修改 bug。未运行真人体验测试，未改变现有产品验证结论。等待 Claude 审查与负责人决定是否合并。
