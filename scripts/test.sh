#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/module-cache
xcrun swiftc -module-cache-path .build/module-cache Sources/Countdown.swift Tests/main.swift -o .build/countdown-tests
.build/countdown-tests
if [[ "${1:-}" == "--ui" ]]; then
    python3 Tests/prepare-ui-smoke.py
    testapp="$PWD/.build/PomodoroSmoke.app"
    mkdir -p "$testapp/Contents/MacOS" "$testapp/Contents/Resources"
    xcrun swiftc -O -module-cache-path .build/module-cache Sources/Countdown.swift Sources/GlassTheme.swift Sources/RippleWater.swift Sources/WindowUI.swift .build/Smoke/AppDelegate.swift .build/Smoke/main.swift -framework AppKit -o "$testapp/Contents/MacOS/PomodoroSmoke"
    ditto Resources "$testapp/Contents/Resources"
    cat > "$testapp/Contents/Info.plist" <<'PLIST'
<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>local.tomato-glass.smoke</string><key>CFBundleExecutable</key><string>PomodoroSmoke</string></dict></plist>
PLIST
    "$testapp/Contents/MacOS/PomodoroSmoke"
fi
