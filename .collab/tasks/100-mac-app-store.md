# 100 — Mac App Store 上架准备

用户直接要求通过 Xcode 上架 macOS 版，并指定使用 Xcode MCP。本分支以 `origin/main` 的 1.7.1 为首发基线，003 的生态改动仍按原 PR 审查。

## 实现记录

- 加入可直接打开的 Xcode 工程。商店目标保留原 Bundle ID 和版本号，构建号设为 13，Release 支持 Apple Silicon 和 Intel，启用 App Sandbox 和 Hardened Runtime。
- 商店构建移除跨进程 Finder 观察及开发诊断入口，保留应用内试玩文件夹。商店版在沙盒里新建存档，原试用版继续使用原路径。用既有图标配置 Xcode 资产，附上隐私政策及应用内入口。
- Xcode MCP 的 `XcodeOpenWorkspace`、`XcodeUpdate`、`BuildProject` 和 `RunProject` 实际通过。通过本机窗口验证了投喂、商店版菜单、隐私政策和沙盒落盘。MCP 当前没有归档、分发或送审工具。
- `./build.sh`、`--integration-test`、Windows `CoreTests`、`Tests/style_check.py` 和 `Tests/Simulation/run.py` 均通过。`diff_base.py --base origin/main --require-identical` 比较 `eed4c99` 与 `630e365`，九个生态场景完全一致。Windows 原生冒烟在本机未运行，依赖 CI。
- Xcode 本地归档和发行签名包导出通过，检查了 Apple 签名、沙盒 entitlement 和两种架构。Organizer 已在 App Store Connect 创建简体中文的 macOS 应用记录，并显示 1.7.1 (13) 上传成功。构建待后台处理和送审。商店文案见 [上架说明](../../Docs/mac-app-store.md)，两张 1440 × 900 的原生界面截图备在本机 `build/app-store/screenshots/`。

## 问题

继续送审需完成 App Store Connect 的必填资料并确认价格、地区和发布安排。中国大陆商店的游戏审批按 Apple 后台要求处理。

## 送审准备补记（2026-11-22）

- 正式发行版本从默认 1.0 改为 1.7.1，填写简体中文商店资料并上传两张 Mac 截图。设为审核通过后手动发布。
- `main` 上的原隐私政策链接在 PR 合并前返回 404。改用已公开且通过匿名访问验证的政策版本，应用与后台使用同一个链接。用 Xcode MCP 修改和构建，通过原生签名检查并上传 1.7.1 (14)。在发行页选中构建 14，完成加密问卷。
- 年龄分级按实际玩法填写。卡通拍打、捏取和喷雾纳入问卷，Apple 在大部分地区给出 13+。
