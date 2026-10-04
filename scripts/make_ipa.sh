#!/bin/bash
# Archives SymptoPage and exports an .ipa. Requires the paid Apple Developer Program.
#
#   bash scripts/make_ipa.sh TEAM_ID [testflight|adhoc] [bundle-id]
#
# testflight (default): uploads to App Store Connect → TestFlight; testers install via link.
# adhoc: .ipa for registered devices (UDIDs added on developer.apple.com).
set -euo pipefail
cd "$(dirname "$0")/.."
team="${1:?Team ID required (Xcode → Settings → Accounts)}"
mode="${2:-testflight}"
bundle="${3:-${SYMPTOPAGE_BUNDLE_ID:-app.symptopage.ios}}"
out="build/ipa-$mode"
rm -rf "$out" && mkdir -p "$out"
python3 scripts/generate_project.py >/dev/null

xcodebuild -project SymptoPage.xcodeproj -scheme SymptoPage -configuration Release \
  -destination "generic/platform=iOS" -archivePath "$out/SymptoPage.xcarchive" -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$team" APP_BUNDLE_ID="$bundle" CODE_SIGN_STYLE=Automatic \
  STRAVA_CLIENT_ID="${STRAVA_CLIENT_ID:-}" STRAVA_TOKEN_URL="${STRAVA_TOKEN_URL:-}" archive | tail -5

method=$([ "$mode" = adhoc ] && echo release-testing || echo app-store-connect)
destination=$([ "$mode" = adhoc ] && echo export || echo upload)
cat > "$out/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>$method</string>
  <key>destination</key><string>$destination</string>
  <key>teamID</key><string>$team</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
xcodebuild -exportArchive -archivePath "$out/SymptoPage.xcarchive" -exportPath "$out" \
  -exportOptionsPlist "$out/ExportOptions.plist" -allowProvisioningUpdates | tail -5
if [ "$destination" = upload ]; then
  echo "Uploaded. In App Store Connect → TestFlight add testers; they install with the TestFlight app."
else
  ls -la "$out"/*.ipa
fi
