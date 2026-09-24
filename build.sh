#!/bin/bash
# 构建剪贴板历史 .app（无需 Xcode 工程，直接用 swiftc 编译）
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="ClipboardHistory"
BUILD_DIR="build"
APP="$BUILD_DIR/$APP_NAME.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/$APP_NAME" \
  -framework AppKit \
  -framework Carbon \
  -framework CryptoKit

cp Info.plist "$APP/Contents/Info.plist"

codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "✅ 构建完成: $APP"
