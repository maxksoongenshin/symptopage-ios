#!/bin/bash
# Builds SymptoPage (+ Apple Watch app) signed with YOUR Apple ID and installs it on the
# iPhone connected by cable / on the same Wi-Fi. Works with a free Apple ID (app expires
# after 7 days, re-run this script) or a paid Developer Program team.
#
#   bash scripts/install_on_iphone.sh [TEAM_ID] [bundle-id]
#
# Before the first run: install Xcode, open it once, Xcode → Settings → Accounts → add your
# Apple ID. On the iPhone: Settings → Privacy & Security → Developer Mode → On.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Xcode is not installed or not selected. Install it from the App Store, then run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app && sudo xcodebuild -runFirstLaunch"
  exit 1
fi

team="${1:-${SYMPTOPAGE_TEAM:-}}"
if [ -z "$team" ]; then
  # Team IDs of accounts added in Xcode → Settings → Accounts.
  team=$(defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier 2>/dev/null \
    | grep -Eo 'teamID = "?[A-Z0-9]{10}' | grep -Eo '[A-Z0-9]{10}$' | head -1 || true)
fi
if [ -z "$team" ]; then
  echo "Team ID not found. Xcode → Settings → Accounts → your Apple ID → Team ID (10 characters),"
  echo "then: bash scripts/install_on_iphone.sh ABCDE12345"
  exit 1
fi
# A free Apple ID cannot use app.symptopage.ios if someone else registered it: use a personal one.
bundle="${2:-${SYMPTOPAGE_BUNDLE_ID:-app.symptopage.$(echo "$team" | tr '[:upper:]' '[:lower:]')}}"

device=$(xcrun devicectl list devices --hide-default-columns --columns Identifier --columns State --columns Model 2>/dev/null \
  | awk '/iPhone/ && /(connected|available)/ {print $1; exit}')
if [ -z "$device" ]; then
  echo "No iPhone found. Connect it with a cable, unlock it and tap 'Trust this computer'."
  xcrun devicectl list devices || true
  exit 1
fi

echo "Team $team · bundle $bundle · device $device"
python3 scripts/generate_project.py >/dev/null
xcodebuild -project SymptoPage.xcodeproj -scheme SymptoPage -configuration Release \
  -destination "generic/platform=iOS" -derivedDataPath build/DerivedData -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$team" APP_BUNDLE_ID="$bundle" CODE_SIGN_STYLE=Automatic \
  STRAVA_CLIENT_ID="${STRAVA_CLIENT_ID:-}" STRAVA_TOKEN_URL="${STRAVA_TOKEN_URL:-}" build | tail -5

app="build/DerivedData/Build/Products/Release-iphoneos/SymptoPage.app"
xcrun devicectl device install app --device "$device" "$app"
xcrun devicectl device process launch --device "$device" "$bundle" || \
  echo "Installed. If it does not open: iPhone Settings → General → VPN & Device Management → trust your Apple ID."
