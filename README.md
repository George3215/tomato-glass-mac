# 番茄时光 · Tomato Glass for Mac

**原生 macOS 菜单栏番茄钟：倒计时、自动弹窗提醒、透明玻璃窗口与冰蓝蝴蝶壁纸。**

Tomato Glass is a lightweight, offline, native macOS Pomodoro timer built with Swift and AppKit. It combines a menu bar countdown, persistent focus window, adjustable transparency, reminder dialogs, and a butterfly wallpaper showcase. No account, server, Electron runtime, or AI API is required.

![Tomato Glass — 蝴蝶壁纸与玻璃番茄钟](docs/screenshot.png)

## 下载与安装 / Download & install

前往本仓库 **Releases**，下载 `Tomato-Glass-1.5.1-universal.dmg`。

1. 双击 DMG。
2. 将 `番茄钟.app` 拖到磁盘窗口中的 `Applications` 文件夹。
3. 弹出磁盘映像，从 Mac「应用程序」启动番茄钟。

需要 **macOS 13 或更新版本**。Universal 二进制同时包含 Apple Silicon（arm64）与 Intel（x86_64）。开发机已验证 macOS 15.5 / Apple Silicon；Intel 与 macOS 13 已做目标编译，尚未实机验证。

**签名状态：** 当前本地 DMG 使用 ad-hoc 签名，未通过 Apple notarization。通过互联网下载后，Gatekeeper 可能阻止首次打开；不保证在其他 Mac 上免提示启动。维护者正式分发可使用 Developer ID 签名并公证，见 [发布指南](docs/RELEASING.md)。请勿关闭系统安全保护。也可从源码自行构建。

Release 附带 `SHA256SUMS.txt`，下载后可用 `shasum -a 256 -c SHA256SUMS.txt` 校验。

## 能做什么

| 功能 | 行为 |
| --- | --- |
| 菜单栏倒计时 | 顶部显示番茄图标与剩余时间 |
| 专注与休息 | 25 分钟专注、5/15 分钟休息，或自定义 1–599 分钟 |
| 窗口常驻 | 开始后窗口保持打开；暂停、继续、重置均可直接操作 |
| 时间到提醒 | 原生弹窗和提示音；可选择休息或再专注 |
| 透明度 | 0%–80%，主窗口与提醒弹窗同步，自动保存 |
| 蝴蝶主题 | 内置 Internal Beyond 冰蓝蝴蝶壁纸与动态雨滴、水面涟漪 |
| 壁纸展示 | 隐藏控制卡片，保留壁纸和返回按钮；计时继续 |
| 自定义背景 | PNG / JPEG / HEIC / TIFF，也可切回粉紫渐变 |
| 状态恢复 | 重启恢复截止时间或暂停状态；到期后补提醒 |

蝴蝶动态壁纸移植 Internal Beyond 的水波算法：雨滴落下、水面折射、点击和拖动扰动涟漪。蝴蝶图案本身来自静态图片，不是单独的飞行动画。右侧“动态雨滴与涟漪”开关可恢复静态；关闭、最小化或完全遮挡窗口后暂停渲染，遵循 macOS“减少动态效果”。在“壁纸展示”模式下更容易体验交互。未移植擦雾、画笔、AI 对话或游戏引擎；不更改系统桌面壁纸。

## 使用边界与隐私

- 关闭窗口后菜单栏仍运行；从菜单栏“退出番茄钟”才退出。
- Mac 睡眠时无法弹窗，唤醒后补提醒；不会主动唤醒电脑。关机或退出期间不能提醒。
- 选择新时长会替换当前倒计时；暂不自动循环专注/休息，也没有专注历史统计。
- 透明度作用于应用窗口，系统菜单栏和系统菜单保持系统外观。
- 计时状态和偏好保存在本机 UserDefaults；自选壁纸保存文件路径，原图移动后会回退至渐变。
- 应用无登录、无遥测、无云同步、无运行时联网请求。GPT、Claude、DeepSeek 均非应用依赖。

## 从源码构建 / Build from source

需要 macOS、Xcode Command Line Tools（`xcode-select --install`）和 Python 3（仅 UI 测试生成器使用）。

```sh
./build.sh                 # Universal .app
./scripts/test.sh          # 计时单元测试
./scripts/test.sh --ui     # 原生窗口测试，需要 macOS 图形会话，会短暂弹窗
./scripts/package-dmg.sh   # 生成 dist/ 下的 DMG 与校验文件
```

运行 `open 番茄钟.app`。构建无 npm、WebView 或第三方软件库依赖。编译输出、应用包及 DMG 不纳入 Git 历史，通过 Releases 分发。

## 1.5.1 性能整理

复用动画位图、移除被覆盖的重复绘制，窗口隐藏时释放水波缓冲。计时、动态开关和提醒测试通过；有限范围的测量见 [性能记录](docs/PERFORMANCE.md)。

## 代码结构

```text
Sources/
  main.swift          # 应用入口
  AppDelegate.swift   # 生命周期、菜单栏、提醒及动作
  Countdown.swift     # 独立计时状态机
  WindowUI.swift      # 控制窗口、主题选择、壁纸展示
  GlassTheme.swift    # 原生背景、动画生命周期和玻璃控件
  RippleWater.swift   # 上游水波算法的原生移植（非商业许可）
Resources/
  Wallpapers/         # 已署名的第三方蝴蝶图片
  Licenses/           # 上游图像许可证
Tests/                # 计时测试与原生 UI 回归测试
scripts/              # 图标生成、测试与 DMG 打包
```

重构复用了窗口按钮构建，分离计时与窗口代码，并保留单一计时状态；不会引入 Internal Beyond 整站的聊天、游戏、API 设置等无关模块。

## 搜索与模型检索 / Discovery

项目标准名称：**番茄时光 / Tomato Glass**。项目类型：**native macOS menu bar Pomodoro timer**。

适用检索词：Mac 番茄钟、macOS 菜单栏倒计时、透明番茄钟、蝴蝶壁纸计时器、离线专注工具、Swift AppKit timer、glassmorphism Pomodoro、macOS countdown reminder、Universal DMG。

可在支持联网搜索的 GPT、Claude、DeepSeek 或搜索引擎中使用以下查询：

> 查找 GitHub 上的「番茄时光 Tomato Glass」：原生 Swift AppKit macOS 菜单栏番茄钟，支持 1–599 分钟倒计时、弹窗提醒、可调透明度、蝴蝶壁纸、Universal DMG。请核实仓库 README、最新 Release、签名状态和壁纸许可证，并提供来源链接。

> Find Tomato Glass, a native macOS menu bar Pomodoro timer written in Swift/AppKit, with an offline countdown, reminder dialogs, adjustable transparency, butterfly wallpaper and a Universal DMG. Verify its repository, latest release, supported macOS versions and licensing.

提供 [llms.txt](llms.txt) 作为简短事实索引，便于支持网页检索的工具读取。这不是搜索排名保证，也不会把项目自动写入任何模型的训练数据。公开仓库是否被索引、何时被检索取决于平台和查询方式。

## 许可与致谢 / License & attribution

自有 Swift 源码与脚本按 [MIT](LICENSE) 提供。`Sources/RippleWater.swift` 为上游算法移植，采用 **PolyForm Noncommercial 1.0.0**，不适用 MIT。内置壁纸也 **不适用 MIT**：

**Sui — Internal Beyond**, Copyright © 2025–2026 Sui。来源：[InternalBeyond](https://github.com/Sui-IB/InternalBeyond)。图片遵循 **CC BY-NC-SA 4.0**，仅限非商业用途；原图未改字节，显示时做比例裁切和暗色覆盖。署名、固定版本与 SHA-256 见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。包含该壁纸的安装包按免费、非商业用途分发；商用须另行获得权利人许可。

本项目为独立番茄钟，不代表 Internal Beyond 官方，也不暗示原作者或任何模型厂商背书。
