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
ICON="$HOME/.local/share/icons/hicolor/256x256/apps/tomato-glass.png"; mkdir -p "$(dirname "$ICON")"
/usr/bin/python3 -I -c "import sys; sys.path.insert(0, sys.argv[1]); import tomato_glass as t; t.tomato_icon(256).save(sys.argv[2])" "$APP/linux" "$ICON"
cat > "$APPS/tomato-glass.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Tomato Glass 番茄时光
Comment=Pomodoro timer
Exec=$BIN/tomato-glass
Icon=$ICON
StartupWMClass=TomatoGlass
Terminal=false
Categories=Utility;
DESK
DESKTOP="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME/Desktop")"
if [ -d "$DESKTOP" ]; then
  cp "$APPS/tomato-glass.desktop" "$DESKTOP/tomato-glass.desktop"; chmod +x "$DESKTOP/tomato-glass.desktop"
  gio set "$DESKTOP/tomato-glass.desktop" metadata::trusted true 2>/dev/null || true
fi
update-desktop-database "$APPS" 2>/dev/null || true
echo "已安装: 运行 tomato-glass 或在应用菜单中搜索 “番茄时光”"
