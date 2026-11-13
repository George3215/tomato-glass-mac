#!/usr/bin/env bash
# 安装 Tomato Glass Linux 版到当前用户 (无需 root)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
BIN="$HOME/.local/bin"; APPS="$HOME/.local/share/applications"
mkdir -p "$BIN" "$APPS"
install -m 755 "$HERE/tomato_glass.py" "$BIN/tomato-glass"
cat > "$APPS/tomato-glass.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Tomato Glass 番茄时光
Comment=Pomodoro timer
Exec=$BIN/tomato-glass
Icon=appointment-soon
Terminal=false
Categories=Utility;
EOF
python3 -c "import tkinter" 2>/dev/null || echo "提示: 需要 Tkinter，请运行 sudo apt install python3-tk"
echo "已安装: 运行 tomato-glass 或在应用菜单中搜索 “番茄时光”"
