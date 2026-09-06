# Third-party notices / 第三方署名

## Butterfly wallpaper / 冰蓝蝴蝶壁纸

- Credit: **Sui — Internal Beyond**, Copyright © 2025–2026 Sui.
- Project: https://github.com/Sui-IB/InternalBeyond
- Source file: `bg-canvas.png`
- Source revision: `4da91e09c72c9b927bd0f96ecc1ddc03981b1ff3`
- Source URL: https://github.com/Sui-IB/InternalBeyond/blob/4da91e09c72c9b927bd0f96ecc1ddc03981b1ff3/bg-canvas.png
- Bundled file: `Resources/Wallpapers/internal-beyond-butterfly.png`
- SHA-256: `2203f12f67313aa54ab2bc79bd7a108dec5a25115680637c67001a4a353aa4ad`
- License: **CC BY-NC-SA 4.0**. https://creativecommons.org/licenses/by-nc-sa/4.0/
- Upstream notice: [Resources/Licenses/InternalBeyond-ASSETS.md](Resources/Licenses/InternalBeyond-ASSETS.md)
- Changes: original image bytes retained, filename changed; runtime aspect-fill cropping and dark overlay for text readability. Any adapted wallpaper composition is offered under CC BY-NC-SA 4.0.
- This is an independent Pomodoro app. Sui and Internal Beyond do not endorse this release.

The bundled wallpaper is for noncommercial use. Paid distribution or commercial use of this asset requires separate permission from its rights holder. No Internal Beyond chat/game code, branding or AI API features are included.

应用源码另见 LICENSE；上述第三方图像不适用源码许可证。安装包内已保留壁纸署名及原始许可说明。

## Dynamic water simulation / 动态水波算法

Required Notice: Copyright © 2025–2026 Sui. Internal Beyond (https://github.com/Sui-IB/InternalBeyond)

`Sources/RippleWater.swift` adapts the `gw-ripple` JavaScript block in InternalBeyond.html from the same upstream revision identified above. It ports damped wave propagation, refraction shading, rain impacts and pointer disturbances to Swift/AppKit. Changes include native drawing and coordinates, a fixed 30 Hz update, and app-controlled rendering lifecycle. It does not port the whole website or the fog-painting module.

License: **PolyForm Noncommercial License 1.0.0**, full terms in `Resources/Licenses/InternalBeyond-CODE.md`. The MIT license does not apply to this adapted file. This contribution to the adapted simulation is distributed under the same noncommercial terms. The source screenshot is an adapted wallpaper composition under CC BY-NC-SA 4.0.
