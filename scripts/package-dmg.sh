#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: package-dmg.sh <release-app> <output-dmg> <stage-dir> <mount-dir>" >&2
  exit 64
fi

absolute_path() {
  local path="$1"
  local dir
  dir="$(dirname "$path")"
  local base
  base="$(basename "$path")"
  mkdir -p "$dir"
  printf "%s/%s\n" "$(cd "$dir" && pwd)" "$base"
}

release_app="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
output_dmg="$(absolute_path "$2")"
stage_dir="$(absolute_path "$3")"
mount_dir="$(absolute_path "$4")"
volume_name="Audiyo"
rw_dmg="${output_dmg%.dmg}-rw.dmg"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "$release_app" ]]; then
  echo "release app not found: $release_app" >&2
  exit 66
fi

cleanup() {
  if [[ -d "$mount_dir" ]] && mount | grep -Fq "on $mount_dir "; then
    hdiutil detach "$mount_dir" >/dev/null || true
  fi
}
trap cleanup EXIT

cleanup
rm -rf "$stage_dir" "$mount_dir" "$output_dmg" "$rw_dmg"
mkdir -p "$stage_dir/.background" "$(dirname "$output_dmg")" "$mount_dir"

ditto "$release_app" "$stage_dir/Audiyo.app"
ln -s /Applications "$stage_dir/Applications"
swift "$script_dir/generate-dmg-background.swift" "$stage_dir/.background/background.png"

hdiutil create -volname "$volume_name" -srcfolder "$stage_dir" -ov -format UDRW "$rw_dmg" >/dev/null
hdiutil attach "$rw_dmg" -nobrowse -mountpoint "$mount_dir" >/dev/null

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$volume_name"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {120, 120, 760, 540}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 96
    set background picture of viewOptions to POSIX file "$mount_dir/.background/background.png" as alias
    set position of item "Audiyo.app" of container window to {178, 222}
    set position of item "Applications" of container window to {462, 222}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
APPLESCRIPT

sync
hdiutil detach "$mount_dir" >/dev/null
hdiutil convert "$rw_dmg" -format UDZO -imagekey zlib-level=9 -o "$output_dmg" >/dev/null
rm -f "$rw_dmg"
rm -rf "$mount_dir"
