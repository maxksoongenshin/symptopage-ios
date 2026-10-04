#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! xcodebuild -version >/dev/null 2>&1; then
  echo 'Full Xcode is required. Open IOS_SETUP_RU.md.' >&2
  exit 1
fi
python3 scripts/generate_project.py
swift test
simulator_id="$(xcrun simctl list devices available -j | python3 -c 'import json,sys; data=json.load(sys.stdin); phones=[d["udid"] for runtime,ds in data["devices"].items() if "iOS" in runtime for d in ds if d.get("isAvailable") and "iPhone" in d["name"]]; print(phones[0] if phones else "")')"
if [ -z "$simulator_id" ]; then
  echo 'Install an iOS Simulator runtime in Xcode Settings > Components.' >&2
  exit 1
fi
xcodebuild -project SymptoPage.xcodeproj -scheme SymptoPage -destination "platform=iOS Simulator,id=$simulator_id" -derivedDataPath DerivedData -resultBundlePath "${TMPDIR:-/tmp}/SymptoPage-$(date +%s).xcresult" CODE_SIGNING_ALLOWED=NO test
