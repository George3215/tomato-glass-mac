#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/番茄钟.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" .build/module-cache
for arch in arm64 x86_64; do
    xcrun swiftc -O -target "$arch-apple-macos13.0" -module-cache-path "$PWD/.build/module-cache" Sources/*.swift -framework AppKit -o ".build/Pomodoro-$arch"
done
lipo -create .build/Pomodoro-arm64 .build/Pomodoro-x86_64 -output "$APP/Contents/MacOS/Pomodoro"
xcrun swift -module-cache-path "$PWD/.build/module-cache" scripts/make-icon.swift "$PWD/.build/Tomato.iconset"
iconutil -c icns .build/Tomato.iconset -o "$APP/Contents/Resources/Tomato.icns"
ditto Resources "$APP/Contents/Resources"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>番茄钟</string>
<key>CFBundleDisplayName</key><string>番茄时光</string>
<key>CFBundleIdentifier</key><string>local.ry.menubar-pomodoro</string>
<key>CFBundleExecutable</key><string>Pomodoro</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.5.1</string>
<key>CFBundleVersion</key><string>7</string>
<key>CFBundleIconFile</key><string>Tomato</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign "${SIGNING_IDENTITY:--}" --options runtime "$APP"
codesign --verify --deep --strict "$APP"
touch "$APP"
echo "已构建 Universal app：$APP"
