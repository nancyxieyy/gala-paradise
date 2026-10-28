# 旮旯乐园 · Gala Paradise

让电脑桌面的角落，长出一个小小的动物世界。

Gala Paradise is an offline desktop pet and ecosystem simulation for macOS and Windows. Feed, befriend, and interact with tiny residents as they roam, nest, and grow across your desktop.

![旮旯乐园的小工具盒](Resources/preview.png)

旮旯乐园是一款离线卡通桌宠与生态模拟游戏。小住客会在桌面上走动、躲藏、迁移、筑巢和成长。你可以投喂、抚摸、起名字，也可以拿起人字拖、喷雾或吸尘器，看看它们会怎样回应。

这里没有安排好的固定剧情。住客的性格、记忆、环境和你的互动共同影响生态，每个人的桌面会有不同的变化。

## 可以怎么玩

- **直接在桌面上互动**：左键使用当前工具，右键交朋友；Mac 也支持 Control + 单击。命名、驯养和领养的住客受保护。
- **观察小小的生态**：投喂留下食物，安静的位置可能形成巢穴；卵会孵化，幼体会成长，也可能迎来猫鼠来访和黄金旮杂。
- **让文件夹成为栖息地**：可选连接 Finder / 资源管理器，让访问和闲置影响对应位置的生态。
- **留一点陪伴**：「我的小窝」提供伙伴、纸条、专注计时和成就，也支持离线领养。

少虫或暂时安静都是正常状态。生态不会为了热闹自动补怪；彻底移除所有住客和卵后，可以通过领养接来住客。

![我的小窝](Resources/life-preview.png)

## 当前状态

当前版本为 **1.7.1 — Readable Emergence**，处于朋友测试阶段。

| 平台 | 最低环境 | 验证情况 |
| --- | --- | --- |
| macOS | macOS 13+，Apple Silicon / Intel | Apple Silicon 已有模型和原生组件测试记录；Intel 为交叉构建 |
| Windows | Windows 10 22H2 / 11，x64 | 已有交叉构建和模型测试记录；原生界面、DPI 与资源管理器联动仍待真机验证 |

目前没有正式发行签名或 macOS 公证，也没有真人体验验证结果。完整边界见 [验收记录](Tests/VALIDATION.md)。

本仓库提供源码。本地生成的应用、安装包和工具链位于 `build/`、`releases/`，不随源码提交。

## 本地运行

### macOS

安装 Xcode Command Line Tools 后，在终端执行：

```sh
git clone https://github.com/nancyxieyy/gala-paradise.git
cd gala-paradise
./build.sh
open 'build/旮旯乐园.app'
```

`build.sh` 编译当前 Mac 架构并运行自检。Finder 联动是可选功能，需要按应用提示授予辅助功能权限；不影响其他桌宠玩法。

### Windows

安装 .NET 10 SDK 后，在 PowerShell 中执行：

```powershell
git clone https://github.com/nancyxieyy/gala-paradise.git
cd gala-paradise
dotnet run --project Windows/GalaParadise.csproj -c Release
```

生成自带 .NET 运行时的 Windows x64 应用：

```powershell
dotnet publish Windows/GalaParadise.csproj -c Release -r win-x64 -o build/windows-x64
```

收起面板后，可以从 Mac 顶部图标或 Windows 系统托盘重新打开；退出请使用图标菜单中的「退出」。

## 隐私与存档

应用不依赖 AI、云服务或服务器，游戏数据只保存在本地。文件夹联动仅使用位置身份和窗口边框，位置按 SHA-256 匿名存储；不读取文件正文、剪贴板或按键，不删除或移动你的文件。纸条只保存你主动提交的文字。

- macOS 存档：`~/Library/Application Support/GalaParadise/save.json`
- Windows 存档：`%LOCALAPPDATA%/GalaParadise/save.json`

专注期间隐藏住客并暂停生态；暂停和离线时间不补算生态事件。这个项目是桌面游戏，不提供真实文件清理或杀毒功能。

## 开发与测试

macOS 使用 **Swift / AppKit**，Windows 使用 **C# / WinForms**，两端分别实现同一套生态规则。跨平台构建需要 macOS、Xcode Command Line Tools 和 .NET 10 SDK；模拟脚本另需 Python 3。

```sh
# macOS 构建及模型自检
./build.sh

# Windows 玩法模型测试（可在 macOS 运行）
dotnet run --project Tests/CoreTests -c Release

# 双端生态状态、事件、重放及保存续跑检查
python3 Tests/Simulation/run.py

# 构建 macOS Universal / Windows x64 并生成朋友测试包
./package-release.sh
```

未将 `dotnet` 加入 PATH 时，可以通过 `GALA_DOTNET` 指定可执行文件。GitHub Actions 中保留了可手动运行的 [Windows 验证工作流](.github/workflows/windows.yml)。

| 目录 | 内容 |
| --- | --- |
| `Sources/` | macOS 原生应用与生态模型 |
| `Windows/` | Windows 原生应用与生态模型 |
| `Resources/` | 图标、预览图与独立试玩启动脚本 |
| `Tests/` | 模型测试、模拟场景与验收记录 |
| `Docs/` | 规则设计、实验数据与朋友测试资料 |

## 更多资料

- [开发、生态规则与实验说明](Docs/development.md)
- [1.7.1 实验结果与局限](Docs/readable-emergence-v1.7.1-results.md)
- [朋友测试说明](Docs/朋友测试说明.txt)
- [观察者盲测指南](Docs/blind-playtest-guide.md)与[记录模板](Docs/blind-playtest-template.md)
- [历史玩法与支线设计草案](Docs/玩法与支线设计草案.md)

## 授权说明

本项目暂未指定开源许可证。随包分发的 .NET 相关许可与第三方声明保留在 `Docs/` 中。
