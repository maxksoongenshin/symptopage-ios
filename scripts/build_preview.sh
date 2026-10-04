#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/symptopage-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/tmp}/symptopage-swift-cache"
build_dir="${TMPDIR:-/tmp}/symptopage-preview-build"
swift build --disable-sandbox --cache-path "${TMPDIR:-/tmp}/symptopage-package-cache" --config-path "${TMPDIR:-/tmp}/symptopage-package-config" --scratch-path "$build_dir" --product SymptoPagePreview
binary="$build_dir/debug/SymptoPagePreview"
python3 scripts/package_preview.py "$binary"
