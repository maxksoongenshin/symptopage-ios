#!/bin/bash
# Everything that can be verified without full Xcode: core tests, store integration,
# preview build and the offscreen render of every screen. Stops at the first failure.
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/symptopage-clang-cache"
echo "== Core tests"; python3 scripts/check_core.py | tail -1
echo "== AppStore integration"
swiftc -suppress-warnings -module-cache-path "$CLANG_MODULE_CACHE_PATH" Core/*.swift App/AppStore.swift \
  App/NotificationService.swift App/HealthService.swift App/StravaService.swift App/PhoneWatchBridge.swift \
  scripts/check_app_store.swift -o "${TMPDIR:-/tmp}/symptopage-store-check"
"${TMPDIR:-/tmp}/symptopage-store-check"
echo "== HealthKit code (iOS path, typechecked with the macOS SDK)"
swiftc -typecheck -module-cache-path "$CLANG_MODULE_CACHE_PATH" -D HEALTHKIT_TYPECHECK Core/*.swift App/HealthService.swift && echo OK
echo "== Apple Watch sources (Core subset + Watch/)"
swiftc -typecheck -module-cache-path "$CLANG_MODULE_CACHE_PATH" Core/{Catalog,Models,MedicationHistory,Scheduling,Health,WatchMessages,Persistence}.swift Watch/*.swift && echo OK
echo "== Xcode project is up to date"
python3 scripts/generate_project.py >/dev/null
plutil -lint SymptoPage.xcodeproj/project.pbxproj
echo "== Preview build"; bash scripts/build_preview.sh | tail -1
echo "== Screens"; bash scripts/check_ui_render.sh "${1:-${TMPDIR:-/tmp}/symptopage-screens}"
if xcodebuild -version >/dev/null 2>&1; then echo "== iOS (Xcode)"; bash scripts/check_ios.sh; else echo "== iOS skipped: full Xcode not installed"; fi
echo "ALL CHECKS PASSED"
