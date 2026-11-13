#!/usr/bin/env bash
# 安装 Tomato Glass Linux 版到当前用户 (无需 root)
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP="$HOME/.local/share/tomato-glass/app"
BIN="$HOME/.local/bin"; APPS="$HOME/.local/share/applications"
/usr/bin/python3 -c "import tkinter, PIL.ImageTk" 2>/dev/null || {
  echo "缺少依赖，请先运行: sudo apt install python3-tk python3-pil python3-pil.imagetk libnotify-bin"; exit 1; }
rm -rf "$APP"; mkdir -p "$APP/linux" "$BIN" "$APPS"
cp "$REPO/linux/tomato_glass.py" "$APP/linux/"
cp -r "$REPO/Resources" "$APP/Resources"
printf '#!/bin/sh\nexec /usr/bin/python3 "%s/linux/tomato_glass.py" "$@"\n' "$APP" > "$BIN/tomato-glass"
chmod 755 "$BIN/tomato-glass"
cat > "$APPS/tomato-glass.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Tomato Glass 番茄时光
Comment=Pomodoro timer
Exec=$BIN/tomato-glass
Icon=appointment-soon
Terminal=false
Categories=Utility;
DESK
echo "已安装: 运行 tomato-glass 或在应用菜单中搜索 “番茄时光”"
