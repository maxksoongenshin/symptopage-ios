#!/bin/bash
# Renders every SwiftUI screen offscreen (macOS, Command Line Tools are enough) and fails on blank output.
# Usage: bash scripts/check_ui_render.sh [output-folder] [--store]
#   --store: instead of the check, writes App Store screenshots (1290×2796, EN/PL).
set -euo pipefail
cd "$(dirname "$0")/.."
out="${1:-${TMPDIR:-/tmp}/symptopage-screens}"
work="$(mktemp -d "${TMPDIR:-/tmp}/symptopage-render.XXXXXX")"
trap 'rm -rf "$work"' EXIT
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/symptopage-clang-cache"
# The app entry point is replaced by the render harness.
sed 's/^@main //' App/SymptoPageApp.swift > "$work/App.swift"
app="$work/Render.app/Contents"
mkdir -p "$app/MacOS" "$app/Resources"
swiftc -parse-as-library -suppress-warnings -module-cache-path "$CLANG_MODULE_CACHE_PATH" \
  Core/*.swift $(ls App/*.swift | grep -v SymptoPageApp.swift) "$work/App.swift" Watch/WatchStore.swift Watch/WatchViews.swift \
  scripts/render_screens.swift \
  -o "$app/MacOS/render"
cp App/Resources/Fonts/*.ttf "$app/Resources/"
cp App/Resources/Assets.xcassets/BrandLogo.imageset/*.png "$app/Resources/BrandLogo.png"
cp App/Resources/Assets.xcassets/BrandIconBlue.imageset/*.png "$app/Resources/BrandIconBlue.png"
cp App/Resources/Assets.xcassets/BrandLogoWhite.imageset/*.png "$app/Resources/BrandLogoWhite.png"
cp App/Resources/Assets.xcassets/BrandIconWhite.imageset/*.png "$app/Resources/BrandIconWhite.png"
"$app/MacOS/render" "$out" "${@:2}"
