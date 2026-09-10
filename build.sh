#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
APP="$PWD/build/旮旯乐园.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -target "$(uname -m)-apple-macos13.0" -framework AppKit -framework ApplicationServices Sources/Game.swift Sources/Roaming.swift Sources/Art.swift Sources/App.swift Sources/main.swift -o "$APP/Contents/MacOS/GalaParadise"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
codesign --force --deep --sign - "$APP"
"$APP/Contents/MacOS/GalaParadise" --self-test
print "Built: $APP"
