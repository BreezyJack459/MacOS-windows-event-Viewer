#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="WinEventLogViewer"
BUNDLE_ID="com.local.WinEventLogViewer"
MIN_SYSTEM_VERSION="13.0"
APP_VERSION="${APP_VERSION:-1.0.0}"
APP_BUILD="${APP_BUILD:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ICON_SCRIPT="$ROOT_DIR/script/generate_app_icon.swift"
ICON_FILE="$ROOT_DIR/Assets/AppIcon.icns"
SWIFT_BUILD_DIR="$ROOT_DIR/.build"
SWIFT_CACHE_DIR="$SWIFT_BUILD_DIR/swiftpm-cache"
SWIFT_CONFIG_DIR="$SWIFT_BUILD_DIR/swiftpm-config"
SWIFT_SECURITY_DIR="$SWIFT_BUILD_DIR/swiftpm-security"
SWIFT_MODULE_CACHE="$SWIFT_BUILD_DIR/module-cache"

cd "$ROOT_DIR"

mkdir -p "$DIST_DIR" "$SWIFT_CACHE_DIR" "$SWIFT_CONFIG_DIR" "$SWIFT_SECURITY_DIR" "$SWIFT_MODULE_CACHE"

export SWIFTPM_MODULECACHE_OVERRIDE="$SWIFT_MODULE_CACHE"
export CLANG_MODULE_CACHE_PATH="$SWIFT_MODULE_CACHE"

SWIFT_PM_ARGS=(
  --disable-sandbox
  --scratch-path "$SWIFT_BUILD_DIR"
  --cache-path "$SWIFT_CACHE_DIR"
  --config-path "$SWIFT_CONFIG_DIR"
  --security-path "$SWIFT_SECURITY_DIR"
  --manifest-cache local
)

case "$MODE" in
  --package|package)
    BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-release}"
    ;;
  *)
    BUILD_CONFIGURATION="${BUILD_CONFIGURATION:-debug}"
    pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    ;;
esac

swift build "${SWIFT_PM_ARGS[@]}" -c "$BUILD_CONFIGURATION" --product "$APP_NAME"
BUILD_BINARY="$(swift build "${SWIFT_PM_ARGS[@]}" -c "$BUILD_CONFIGURATION" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ ! -f "$ICON_FILE" || "$ICON_SCRIPT" -nt "$ICON_FILE" ]]; then
  ICON_TOOL="$DIST_DIR/generate_app_icon"
  swiftc -module-cache-path "$ROOT_DIR/.build/icon-module-cache" "$ICON_SCRIPT" -o "$ICON_TOOL"
  "$ICON_TOOL"
  iconutil -c icns "$ROOT_DIR/Assets/AppIcon.iconset" -o "$ICON_FILE"
fi

cp "$ICON_FILE" "$APP_RESOURCES/AppIcon.icns"



cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>Windows Event Log Viewer</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

plutil -lint "$INFO_PLIST" >/dev/null
test -x "$APP_BINARY"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  --package|package)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--package|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
