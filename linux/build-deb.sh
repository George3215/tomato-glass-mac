#!/usr/bin/env bash
# 构建 Debian/Ubuntu 安装包: dist/tomato-glass_<版本>_all.deb
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
VER="$(tr -d '[:space:]' < "$REPO/VERSION")"
ROOT="$(mktemp -d)"; trap 'rm -rf "$ROOT"' EXIT
APP="$ROOT/opt/tomato-glass"
mkdir -p "$APP/linux" "$ROOT/usr/bin" "$ROOT/usr/share/applications" "$ROOT/usr/share/icons/hicolor/256x256/apps" "$ROOT/DEBIAN"
cp "$REPO/linux/tomato_glass.py" "$APP/linux/"
cp -r "$REPO/Resources" "$APP/Resources"
/usr/bin/python3 -I -c "import sys; sys.path.insert(0, sys.argv[1]); import tomato_glass as t; t.tomato_icon(256).save(sys.argv[2])" \
  "$REPO/linux" "$ROOT/usr/share/icons/hicolor/256x256/apps/tomato-glass.png"
printf '#!/bin/sh\nexec /usr/bin/python3 /opt/tomato-glass/linux/tomato_glass.py "$@"\n' > "$ROOT/usr/bin/tomato-glass"
chmod 755 "$ROOT/usr/bin/tomato-glass"
cat > "$ROOT/usr/share/applications/tomato-glass.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=Tomato Glass 番茄时光
Name[zh_CN]=番茄时光
Comment=Pomodoro timer
Exec=tomato-glass
Icon=tomato-glass
Terminal=false
Categories=Utility;
StartupWMClass=TomatoGlass
DESK
cat > "$ROOT/DEBIAN/control" <<CTL
Package: tomato-glass
Version: $VER
Architecture: all
Maintainer: George3215
Depends: python3, python3-tk, python3-pil, python3-pil.imagetk
Recommends: libnotify-bin, pulseaudio-utils
Section: utils
Priority: optional
Description: Tomato Glass 番茄时光 - Pomodoro timer for Linux
 Glass-style Pomodoro and countdown timer, same look as the macOS version.
CTL
find "$ROOT" -type d -exec chmod 755 {} +
mkdir -p "$REPO/dist"
dpkg-deb --root-owner-group --build "$ROOT" "$REPO/dist/tomato-glass_${VER}_all.deb"
