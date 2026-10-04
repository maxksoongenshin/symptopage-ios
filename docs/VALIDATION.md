# Validation · 2026-10-04

## 0.8.0

- `bash scripts/check_all.sh`: 39 core checks; AppStore integration; HealthKit adapter typechecked against the macOS SDK with its iOS path enabled (verified that the path is compiled); watch sources typechecked; Xcode project (3 targets incl. watchOS, embed phase, HealthKit entitlements) regenerated and valid; preview build; 56 screens rendered (incl. 6 Apple Watch screens) in EN/PL.
- Strava client tested against a mocked HTTP layer: token refresh, form encoding of the secret, paging (100 + 1), 401 handling. Not tested against the live Strava API (no owner credentials here).
- Not run here: HealthKit queries on a device, WatchConnectivity delivery between real devices, watchOS build (no Xcode/watchOS SDK), Digital Crown and haptics.

## 0.7.0

- `bash scripts/check_all.sh` passes: 33 core checks; AppStore integration incl. wellbeing notes; Xcode project regenerated and valid; preview build; 38 screens (19 × EN/PL) rendered offscreen with Manrope registered, none blank.
- New core checks: catalog consistency and legacy keys; notes backward compatibility and validation; report notes and summary with doctor filter; designed PDF with bundled Manrope keeps Polish text, page numbers and daily-answer section.
- Owner's existing preview data (`work/ios-user-data/records.json`, written by 0.5/0.6) decodes and re-encodes unchanged.
- Sample PDF inspected visually (4 pages for a month of data).
- Not run: XCUITests (no Xcode/Simulator), iPhone font rendering, AirPrint.

## 0.6.0 design update

- Core: 29 checks pass, including the new optional daily-question symptom / profile name (decode of pre-0.6.0 files, round trip, validation limits).
- AppStore check passes, including persistence of the name and daily-question symptom.
- Preview app and all App sources compile with no warnings (Swift 6.3.2). Xcode project regenerated (0.6.0, build 3) and passes plutil.
- Welcome, empty start, active carousel with answered daily question and the add-visit card were rendered offscreen (NSHostingView, light and dark system appearance) and compared to the supplied design. Interactive clicking in the running preview was not re-done for 0.6.0 (no screen-recording/automation permission in this environment).
- UI tests updated for the welcome screen and a quick-visit/daily-answer test was added; they are not executed (no Xcode/Simulator).

## Passed locally (0.5.x)

- Swift 6.3.2 in Swift 5 compatibility mode: compilation/linking of SymptoCore and the shared SwiftUI macOS preview.
- 27 core checks from Tests/CoreTests.swift, executed via the Command Line Tools runner (XCTest framework is absent locally). Includes atomic-write failures, no mutation on failure, corrupt-file preservation, backup replacement, duplicate IDs, relation validation, Windows version-1 migration, attachments and size limits, explicit daily summaries, course dates, weekdays, DST, timezone changes, confirmed-dose suppression, queue bounds, postponed doses, midnight visibility, report filters and multi-page Polish PDF text. Also covers prescription schedule history, stop/restart, no-op edits, early confirmation snapshots, schema-2 migration backups and postponement beyond the final course midnight.
- AppStore integration check: editing without duplicate events, future timestamp rejection, daily upsert with stable ID, moving edited daily entries and rejecting collisions, postponed → taken replacement, language/data persistence, invalid import preservation.
- UserNotifications adapter typechecked using the available macOS SDK with its iOS code path enabled for syntax/API validation. This is not an iOS build or delivery test.
- Generated project.pbxproj and privacy manifest pass plutil validation.
- Supplied blue app icon packaged as opaque 1024×1024 PNG. Original files retained.
- Native Mac preview manually opened; onboarding and form rendered, test visit saved and retained after restart, Now form opened and cancel left no event. Branded dashboard and navigation rendered. In isolated 0.5.1 QA data, created a visit, saved and edited a linked symptom without duplication, created a course with two dose times, changed its dose and expanded the preserved previous plan. Native UI automation encountered intermittent menu timeouts; a complete end-to-end manual UI pass is not claimed.

## Not yet verified

- Build against an actual iOS SDK, Simulator UI tests and real iPhone launch: no full Xcode/iOS runtime installed.
- Notification delivery/background/Focus/permission behavior on iPhone.
- iPhone document picker, share/export destination, Quick Look and AirPrint.
- VoiceOver, largest Dynamic Type sizes, iPad layout, device rotation and performance with large backups.
- Signing, TestFlight, App Store and remote CI. No signed IPA produced.

## Commands

```sh
python3 scripts/check_core.py
swiftc -module-cache-path /tmp/symptopage-clang-cache Core/*.swift App/AppStore.swift App/NotificationService.swift App/HealthService.swift App/StravaService.swift App/PhoneWatchBridge.swift scripts/check_app_store.swift -o /tmp/symptopage-store-check
/tmp/symptopage-store-check
bash scripts/build_preview.sh
```

With full Xcode installed: `bash scripts/check_ios.sh`. UI tests are source artifacts until that command passes. Test data lives in temporary or separate validation paths, never in the delivered empty preview profile.
