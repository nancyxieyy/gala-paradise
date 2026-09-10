#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/universal releases
APP="$PWD/build/universal/旮旯乐园.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos13.0" -framework AppKit -framework ApplicationServices Sources/Life.swift Sources/LifeUI.swift Sources/Game.swift Sources/Progression.swift Sources/Habitat.swift Sources/Roaming.swift Sources/Art.swift Sources/App.swift Sources/main.swift -o "build/universal/GalaParadise-$arch"
done
lipo -create build/universal/GalaParadise-arm64 build/universal/GalaParadise-x86_64 -output "$APP/Contents/MacOS/GalaParadise"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
"$APP/Contents/MacOS/GalaParadise" --self-test
print "Mac universal app ready: $APP"
DOTNET="${GALA_DOTNET:-$(command -v dotnet || true)}"
if [[ -z "$DOTNET" ]]; then DOTNET="$PWD/build/toolchain/dotnet/dotnet"; fi
if [[ ! -x "$DOTNET" ]]; then print 'Install .NET 10 SDK or set GALA_DOTNET to the dotnet executable'; exit 2; fi
export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
export DOTNET_GENERATE_ASPNET_CERTIFICATE=false
"$DOTNET" run --project Tests/CoreTests -c Release
"$DOTNET" publish Windows/GalaParadise.csproj -c Release -r win-x64 -o build/windows-x64
print "Windows self-contained EXE ready: build/windows-x64/GalaParadise.exe"
