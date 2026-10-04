# 0.8.0 Apple Watch, Apple Health, Strava

- Apple Health import (iPhone): resting heart rate, heart rate, HRV, steps, sleep, active energy and workouts; heart rate at the moment of each symptom is attached automatically. Read-only.
- Strava (official API v3, OAuth): workouts with time, distance and heart rate; tokens refresh automatically; duplicates of Strava workouts that Strava also wrote to Health are dropped.
- Automatic sync on launch and when the app becomes active (at most hourly); "Sync" button for manual refresh.
- Apple Watch app (watchOS 10): one-tap "!!! Now!" → symptom → intensity with the Digital Crown (heart rate from the watch attached); today's question per doctor; mood in one tap. Entries reach the iPhone via WatchConnectivity, also when the phone app is closed; delivery is idempotent.
- Start: "Resting HR" in the header (as in the design), "From your watch & Strava" card, or a one-tap invitation to connect. New "Body & activity" screen with charts and workouts; "Connections" screen.
- PDF: navy header with the owner's white wordmark; new "Activity and watch data" block: tiles, resting HR / steps / sleep charts, workouts table with Strava / Apple Health badges; heart rate shown at each symptom in the timeline.
- New brand files from the owner: white wordmark, light and dark icons (higher resolution); app icon rebuilt from the dark icon without white corners (`scripts/import_brand_assets.swift`).
- Data: `healthDays`, `activities`, `integrations`, event `heartRate`/`source`; older files open unchanged. Secrets only in the Keychain.
- Tests: 39 core checks (Strava parsing and mocked OAuth/paging, merge/dedupe, heart-rate attach, watch entries, back-compat, PDF), HealthKit and watch typechecks, 56 rendered screens incl. 6 watch screens.

# 0.7.0 Three tabs, notes, catalog and designed PDF

- Three tabs as in the design: Start, Report, Settings. Journal and Doctors & medication open from Start tiles; Journal also from Report.
- Manrope (from the supplied `ekrany.zip`) bundled as four static TTFs and registered at runtime; used in the app and the PDF, scales with Dynamic Type.
- Symptom catalog: 30 symptoms in 8 categories with icons; 16 specialties, each with typical symptoms (first one is the default daily question). Stored keys unchanged.
- Wellbeing notes: mood (5 levels), text, tags, observation links; editable and deletable; included in the report.
- Journal: one timeline grouped by day, filter by type, search; event, answer and note cards.
- Buttons: capsule primary/secondary/destructive styles; dose status as three visible buttons instead of a menu.
- Report tab: 7/30/90 days or custom, summary tiles, preview/save/print.
- PDF: teal header with logo and patient name, summary tiles, symptom table with bars, colour grid of daily answers with legend, compact sections, running header, "Page X / N", headings kept with their text.
- Older files open unchanged (`notes` defaults to empty). Schema version stays 3.
- Tests: 33 core checks, AppStore notes check, offscreen render of 38 screens (`scripts/check_ui_render.sh`), `scripts/check_all.sh`; UI tests updated for three tabs and notes.

# 0.6.0 iOS design update

- Start, welcome and visit screens rebuilt in SwiftUI from the supplied SymptoPad screens (`work/design-reference/ekrany`): colours, chips, cards and the floating "!!! Now / Teraz!" button follow the design.
- Welcome screen with language choice; shown while no visit exists.
- Empty start screen: choose a specialist (Cardiologist, Neurologist, Internist, Other) and a date and add the visit in one tap. Full form remains under "More details".
- Active observations as a swipeable carousel: day countdown, "until dd.MM.yyyy", inline daily question with None / Once / Several and a note. The last page adds another doctor.
- Each observation keeps its own daily-question symptom (suggested for cardiology and neurology, otherwise chosen by the user).
- Optional first name for the greeting (Settings). Bell opens today's medication plan and marks overdue unconfirmed doses.
- New `internist` specialty. Schema stays 3: new fields are optional, older files and backups open unchanged.
- First tab renamed "Start". Core test and UI tests extended.

# 0.5.1 iOS reliability update

- Preserve prescription history when editing or stopping courses, including past unconfirmed doses.
- Keep original medication details in dose confirmations and reports.
- Migrate schema 2 to 3 after preserving a backup; retain sub-second timestamps.
- Honor explicit postponement across the last course midnight.
- Move edited daily entries without duplicates; reject collisions with another existing entry.
- Use stable identities for editable dose-time rows and prevent duplicate times before saving.
- Expand core and UI regression coverage.

# 0.5.0 iOS working build

- New native SwiftUI iPhone/iPad project and shared Mac inspection preview.
- Multi-doctor observations, visit lifecycle and follow-ups.
- Symptom journal, custom symptoms, optional intensity/duration/context and shared observation links.
- Daily check-ins with explicit answer selection and preserved drafts when switching context.
- Visit outcomes, documents and prescription transcription.
- Medication courses, confirmations and bounded local notification scheduling.
- Bilingual PDF, printing entry point, full backups and Windows 0.4.0 import.
- Supplied SymptoPage branding.
- Core tests, Simulator test sources, reproducible Xcode project and CI configuration.

Not a signed iPhone release. iOS device validation remains pending because full Xcode is not installed in the build environment.
