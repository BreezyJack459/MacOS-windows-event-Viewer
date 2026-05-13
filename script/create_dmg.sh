#!/usr/bin/env bash
set -euo pipefail

APP_NAME="WinEventLogViewer"
DISPLAY_NAME="Windows Event Log Viewer"
DMG_NAME="WindowsEventLogViewer.dmg"
VOLUME_SIZE="${VOLUME_SIZE:-160m}"
BACKGROUND_DIR_NAME="background"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$DIST_DIR/dmg-staging"
MOUNT_DIR="$DIST_DIR/dmg-mount"
TMP_DMG="$DIST_DIR/$APP_NAME.tmp.dmg"
FINAL_DMG="$DIST_DIR/$DMG_NAME"
BACKGROUND_SCRIPT="$ROOT_DIR/script/generate_dmg_background.swift"
BACKGROUND_FILE="$ROOT_DIR/Assets/DMGBackground.png"
BACKGROUND_TOOL="$DIST_DIR/generate_dmg_background"
SWIFT_MODULE_CACHE="$ROOT_DIR/.build/module-cache"
VERIFY_MOUNT_DIR="$DIST_DIR/dmg-verify-mount"
DMG_TOOLS_VENV="$ROOT_DIR/.build/dmg-tools-venv"
DMG_DSSTORE_SCRIPT="$ROOT_DIR/script/write_dmg_dsstore.py"

cd "$ROOT_DIR"

log() {
  printf '==> %s\n' "$*"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 127
  fi
}

detach_mount() {
  local mount_dir="$1"
  if mount | grep -F " on $mount_dir " >/dev/null 2>&1; then
    hdiutil detach "$mount_dir" >/dev/null 2>&1 || hdiutil detach -force "$mount_dir" >/dev/null 2>&1 || true
  fi
}

cleanup() {
  detach_mount "$MOUNT_DIR"
  detach_mount "$VERIFY_MOUNT_DIR"
}
trap cleanup EXIT

require_command swift
require_command swiftc
require_command iconutil
require_command hdiutil
require_command codesign
require_command plutil
require_command ditto
require_command xattr
require_command python3

ensure_dmg_tools() {
  if [[ ! -x "$DMG_TOOLS_VENV/bin/python" ]]; then
    python3 -m venv "$DMG_TOOLS_VENV"
  fi
  if ! "$DMG_TOOLS_VENV/bin/python" - <<'PY' >/dev/null 2>&1
import ds_store
import mac_alias
PY
  then
    "$DMG_TOOLS_VENV/bin/python" -m pip install ds_store mac_alias
  fi
}

log "Building release app bundle"
"$ROOT_DIR/script/build_and_run.sh" --package

log "Signing app bundle"
xattr -cr "$APP_BUNDLE" || true
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null
codesign --verify --deep --strict "$APP_BUNDLE"

detach_mount "$MOUNT_DIR"
detach_mount "$VERIFY_MOUNT_DIR"
rm -rf "$STAGING_DIR" "$MOUNT_DIR" "$VERIFY_MOUNT_DIR" "$TMP_DMG" "$FINAL_DMG"
mkdir -p "$STAGING_DIR/$BACKGROUND_DIR_NAME" "$MOUNT_DIR" "$VERIFY_MOUNT_DIR" "$SWIFT_MODULE_CACHE"

log "Rendering DMG background"
swiftc -module-cache-path "$SWIFT_MODULE_CACHE" "$BACKGROUND_SCRIPT" -o "$BACKGROUND_TOOL"
"$BACKGROUND_TOOL"

log "Staging DMG contents"
ditto --noextattr --noqtn "$APP_BUNDLE" "$STAGING_DIR/$APP_NAME.app"
cp "$BACKGROUND_FILE" "$STAGING_DIR/$BACKGROUND_DIR_NAME/DMGBackground.png"
ln -s /Applications "$STAGING_DIR/Applications"
xattr -cr "$STAGING_DIR/$APP_NAME.app" || true
plutil -lint "$STAGING_DIR/$APP_NAME.app/Contents/Info.plist" >/dev/null
test -x "$STAGING_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"

log "Creating read-write image"
hdiutil create \
  -volname "$DISPLAY_NAME" \
  -srcfolder "$STAGING_DIR" \
  -fs HFS+ \
  -format UDRW \
  -size "$VOLUME_SIZE" \
  "$TMP_DMG" >/dev/null

log "Mounting image for layout metadata"
hdiutil attach "$TMP_DMG" \
  -readwrite \
  -noverify \
  -noautoopen \
  -mountpoint "$MOUNT_DIR" >/dev/null

log "Writing Finder layout metadata"
ensure_dmg_tools
"$DMG_TOOLS_VENV/bin/python" "$DMG_DSSTORE_SCRIPT" \
  --mount "$MOUNT_DIR" \
  --app-name "$APP_NAME" \
  --background "$MOUNT_DIR/$BACKGROUND_DIR_NAME/DMGBackground.png"

if command -v SetFile >/dev/null 2>&1; then
  SetFile -a V "$MOUNT_DIR/$BACKGROUND_DIR_NAME" || true
fi

log "Verifying mounted image contents"
xattr -cr "$MOUNT_DIR/$APP_NAME.app" || true
test -d "$MOUNT_DIR/$APP_NAME.app"
test -L "$MOUNT_DIR/Applications"
test -f "$MOUNT_DIR/.DS_Store"
test -f "$MOUNT_DIR/$BACKGROUND_DIR_NAME/DMGBackground.png"
if ! "$DMG_TOOLS_VENV/bin/python" - "$MOUNT_DIR/.DS_Store" <<'PY'
import sys
from ds_store import DSStore

with DSStore.open(sys.argv[1], "r") as store:
    icvp = store["."]["icvp"]
    if icvp.get("backgroundType") != 2 or "backgroundImageAlias" not in icvp:
        raise SystemExit(1)
PY
then
  echo "error: Finder did not persist the DMG background image in .DS_Store." >&2
  exit 1
fi
test -x "$MOUNT_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
plutil -lint "$MOUNT_DIR/$APP_NAME.app/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict "$MOUNT_DIR/$APP_NAME.app"

sync
detach_mount "$MOUNT_DIR"

log "Compressing final DMG"
hdiutil convert "$TMP_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$FINAL_DMG" >/dev/null

log "Verifying final DMG can load"
hdiutil verify "$FINAL_DMG" >/dev/null
hdiutil attach "$FINAL_DMG" \
  -readonly \
  -noverify \
  -noautoopen \
  -nobrowse \
  -mountpoint "$VERIFY_MOUNT_DIR" >/dev/null
test -d "$VERIFY_MOUNT_DIR/$APP_NAME.app"
test -L "$VERIFY_MOUNT_DIR/Applications"
test -f "$VERIFY_MOUNT_DIR/.DS_Store"
test -f "$VERIFY_MOUNT_DIR/$BACKGROUND_DIR_NAME/DMGBackground.png"
if ! "$DMG_TOOLS_VENV/bin/python" - "$VERIFY_MOUNT_DIR/.DS_Store" <<'PY'
import sys
from ds_store import DSStore

with DSStore.open(sys.argv[1], "r") as store:
    icvp = store["."]["icvp"]
    if icvp.get("backgroundType") != 2 or "backgroundImageAlias" not in icvp:
        raise SystemExit(1)
PY
then
  echo "error: final DMG is missing persisted background image metadata." >&2
  exit 1
fi
test -x "$VERIFY_MOUNT_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
codesign --verify --deep --strict "$VERIFY_MOUNT_DIR/$APP_NAME.app"
detach_mount "$VERIFY_MOUNT_DIR"
trap - EXIT

rm -rf "$STAGING_DIR" "$MOUNT_DIR" "$VERIFY_MOUNT_DIR" "$TMP_DMG"

echo "$FINAL_DMG"
