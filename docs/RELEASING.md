# 发布指南

建议公开仓库名：`tomato-glass-mac`；简介：Native macOS Pomodoro timer with menu bar countdown, glass UI, butterfly wallpaper and DMG installer.

建议 topics：`macos`, `pomodoro`, `swift`, `appkit`, `menu-bar`, `countdown`, `productivity`, `glassmorphism`, `offline`, `dmg`。

## 本地安装包

运行 `./scripts/package-dmg.sh`。输出 DMG 仅包含应用、Applications 链接、安装说明和署名；源码、缓存、个人偏好不进入安装包。

版本号当前为 1.5.1；升级版本时同步 build.sh 中的 Info.plist 版本、package-dmg.sh 文件名和 README。

## 正式签名与公证

当前不含开发者身份和 Apple 凭据，本地结果为 ad-hoc 签名。维护者拥有 Developer ID Application 证书后可设置 `SIGNING_IDENTITY` 再打包：

```sh
SIGNING_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' ./scripts/package-dmg.sh
```

使用 Xcode 的 `xcrun notarytool submit` 将 DMG 提交到 Apple，使用维护者自己的钥匙串配置；等待 Accepted 后用 `xcrun stapler staple` 附加票据，再做 `stapler validate` 和 Gatekeeper 验证。重新生成 SHA256SUMS.txt 后发布。不要上传证书私钥、API 密钥或钥匙串文件。相关命令和当前要求以 [Apple notarization 文档](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) 为准。

## GitHub 发布

必须先确定真实的 GitHub 账号/组织与仓库，并使用该账号授权登录；不要在 README 填写虚构下载链接。

1. 创建公开仓库，提交源码、测试、文档、壁纸和许可证。不要提交 .build、.app、DMG、ZIP、个人偏好。
2. 配置 topics 和中英文简介。
3. 推送 `v1.5.1` 标签会触发 `.github/workflows/release.yml`，运行测试并构建 DMG，发布 Release（当前已授权公开发布）。
4. 发布前核对版本、签名说明与壁纸许可；推送版本标签即表示确认公开发布。工作流测试和构建成功后上传安装包及 SHA-256。

默认 Actions 构建为未公证的 ad-hoc 版本，不应标记为已通过 Apple 安全认证。如上传另行公证的包，替换对应 DMG 和校验文件，并准确更新 Release 说明。

## Release 文本

番茄时光 1.5.1：原生 macOS 菜单栏番茄钟，加入 Internal Beyond 冰蓝蝴蝶动态雨滴、水波折射与展示模式；重构窗口和计时模块；提供 macOS 13+ Universal DMG。

已验证：计时逻辑与 Apple Silicon / macOS 15.5 原生窗口。Intel 和 macOS 13 尚未实机测试。当前构建为 ad-hoc 签名、未公证。蝴蝶壁纸由 Sui — Internal Beyond 提供，CC BY-NC-SA 4.0，水波算法按 PolyForm Noncommercial 1.0.0 提供，安装包仅限非商业用途。无账号、无 AI API、无运行时联网依赖。
