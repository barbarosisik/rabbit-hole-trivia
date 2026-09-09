#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Darwin ]]; then echo 'Build this app on macOS.' >&2; exit 1; fi
APP="$PWD/Rabbit Hole.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" macOS/.build/module-cache
xcrun swiftc -target "$(uname -m)-apple-macos13.0" -swift-version 5 -O -module-cache-path "$PWD/macOS/.build/module-cache" -framework AppKit -framework SwiftUI -framework WebKit macOS/RabbitHole.swift macOS/SelfTests.swift -o "$APP/Contents/MacOS/RabbitHole"
cp 'Rabbit Hole/game.html' "$APP/Contents/Resources/game.html"
xcrun swift -module-cache-path "$PWD/macOS/.build/module-cache" macOS/MakeIcon.swift "$PWD/macOS/.build/RabbitHole.iconset"
iconutil -c icns "$PWD/macOS/.build/RabbitHole.iconset" -o "$APP/Contents/Resources/RabbitHole.icns"
cp macOS/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
echo "Built $APP"
