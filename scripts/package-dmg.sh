#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
./build.sh
mkdir -p dist
stage=$(mktemp -d "$PWD/.build/dmg-stage.XXXXXX")
trap 'rm -rf "$stage"' EXIT
ditto 番茄钟.app "$stage/番茄钟.app"
ln -s /Applications "$stage/Applications"
cp docs/INSTALL.txt "$stage/安装说明.txt"
cp THIRD_PARTY_NOTICES.md "$stage/壁纸来源与许可.md"
hdiutil create -volname '番茄时光 - 拖入 Applications' -srcfolder "$stage" -format UDZO -ov dist/Tomato-Glass-1.5.1-universal.dmg
hdiutil verify dist/Tomato-Glass-1.5.1-universal.dmg
(cd dist && shasum -a 256 Tomato-Glass-1.5.1-universal.dmg > SHA256SUMS.txt)
