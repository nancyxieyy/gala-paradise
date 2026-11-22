# 旮旯乐园 Mac App Store 版

`GalaParadise.xcodeproj` 的 `GalaParadise` 是商店版方案。版本为 1.7.1，构建号为 14。它支持 macOS 13 起的 Apple Silicon 和 Intel Mac，使用 `studio.gala.paradise` 作为 Bundle ID。

商店版启用了 App Sandbox。桌面上的小住客、工具、喂食、伙伴和小窝照常使用；文件夹生态可在「试玩文件夹」里体验。商店版不会读取 Finder 窗口，首次启动会在应用容器内新建存档。朋友测试版的存档仍在原来的位置。

## 构建和归档

在 Xcode 打开工程并选中 `GalaParadise` 方案。Debug 构建使用本地临时签名，适合在 My Mac 上试跑。归档前，在 Signing & Capabilities 为 Release 选择拥有此 Bundle ID 的 Apple Developer 团队，然后执行 Product → Archive。归档在 Organizer 里验证并上传到已建立的 macOS 应用记录。

Xcode MCP 的 `XcodeOpenWorkspace` 和 `BuildProject` 可打开项目并构建。归档、发行签名和上传使用 Xcode 的 Archive、Organizer 或 `xcodebuild`。提交审核在 App Store Connect 完成。

## 商品页文案

**名称** 旮旯乐园

**副标题** 长在桌面角落的小动物世界

**类别** 游戏 → 模拟

**描述**

让电脑桌面的角落，长出一个小小的动物世界。

在旮旯乐园，小住客会在桌面走动、躲藏、筑巢和长大。你可以撒点面包屑、摸摸它、给它起个名字，也可以换上人字拖、喷雾或吸尘器，看看它会怎么回应。

左键使用当前工具，右键或按住 Control 点按小住客，就能和它交朋友。打开「我的小窝」还能照看伙伴、留纸条、开始一段专注时间。想安静一会儿，可以随时暂停并隐藏住客。

每个桌面都会长出自己的故事。游戏可离线运行，无需账号。

**关键词** 桌宠,桌面宠物,生态模拟,动物,养成,离线,专注,治愈

**隐私政策 URL** [Mac App Store 版隐私政策](https://github.com/nancyxieyy/gala-paradise/blob/630e365313f6e92dd0728e915c0142c54ce3e3c9/Resources/MacAppStore/PrivacyPolicy.txt)。应用和商店页面指向与该构建附带文本一致的公开版本，应用菜单也可离线查看政策全文。更新政策时，上传新文本并同步更新两处链接。

**支持 URL 草案** [旮旯乐园问题反馈](https://github.com/nancyxieyy/gala-paradise/issues)。发布前核对公开支持入口和版权署名。

**审核备注** 无需账号。启动后在面板点击「＋ 喂一点」，然后右键点按桌面上的住客，尝试投喂或命名。收起窗口后可用菜单栏图标重新打开面板、暂停或退出。「我的小窝」中可查看伙伴、纸条、专注和成就。工具只作用于游戏对象。

## 提交前核对

- 在商店后台确认应用记录、团队和版本，上传至少一张符合 Apple 规格的真实 Mac 界面截图，选择处理完成的构建。
- 按实际内容填写年龄分级。工具包含对卡通小虫的拍打、喷雾和吸走互动。按实际发布主体填写出口合规、价格、地区与发布日期，确认好再送审。
- 如果要在中国大陆销售或分发游戏，先核对 Apple 要求的游戏审批号及相关资料。[Apple 地区合规说明](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-compliance-information/)
