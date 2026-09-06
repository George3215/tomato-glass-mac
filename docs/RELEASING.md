# 发布

1. 更新 `VERSION` 与 `docs/RELEASE_NOTES.md`。
2. 执行 `./scripts/test.sh --ui` 和 `./scripts/package-dmg.sh`。
3. 核对功能、签名状态及第三方许可，提交源码。
4. 推送与 VERSION 一致的 `v版本号` 标签。GitHub Actions 测试、构建 Universal DMG 并发布 Release；已有 Release 不会被覆盖。

仅将源码、测试、文档和授权资源放入 Git。应用包、缓存、DMG 和个人偏好不纳入仓库。

默认构建为 ad-hoc 签名、未经 Apple 公证。正式公证需要维护者自己的 Developer ID 证书和 Apple 凭据：设置 `SIGNING_IDENTITY` 后打包，用 `notarytool` 提交并确认 Accepted，再用 `stapler` 附加和校验票据，重新生成 SHA-256。按 [Apple 官方文档](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) 操作，勿上传私钥或凭据。

包含第三方壁纸和水波的安装包仅限非商业用途；发布时必须保留署名和许可。
