# Architecture and data

SwiftUI views → MainActor AppStore → validated value-type AppState → StateRepository → atomic JSON. No dependencies or network requests. The Xcode iOS target compiles Core and App sources in one module. SwiftPM exposes Core as SymptoCore and builds the same App sources as a macOS preview.

Schema 3 uses ISO-8601 timestamps with fractional seconds (older whole-second timestamps remain readable). Calendar-day strings are Gregorian yyyy-MM-dd; check-ins retain the recording timezone. Doctors, observations, visits, events, check-ins, courses and attachments have UUIDs. A dose ID is medicationUUID/local-day/HH:mm, stable across timezone reconciliation, so an already confirmed dose is not scheduled again. DST gaps move to the next valid wall time; repeated hours fire once.

Each observation belongs to one doctor. Multiple observations and visits may belong to that doctor. Events reference multiple observation IDs without duplication. Check-ins are unique by observation/day/symptom and remain distinct from individual events. General records with no observation are visible under All doctors and intentionally excluded by a doctor-specific filter.

AppStore changes a copy, validates and persists it, then publishes success. Failed persistence leaves the committed value unchanged. Unsupported or corrupt files are not reset. Recovery can export the original and restore a verified backup while preserving the original locally.

Attachments are embedded as base64 through Codable Data; 8 MB each, 30 MB total, 50 MB JSON maximum. This trades scalability for a self-contained backup. Large clinical archives are not the current use case. Import replaces the complete dataset after user confirmation; it does not merge. Previous data is backed up to a sibling JSON file. These backups occupy space and may be included in device backups according to system settings.

Windows version-1 records.json imports into schema 3. IDs, timestamps, text and language are retained; the single legacy visit maps to one doctor and observation. Schema-2 iOS data migrates to schema 3 with empty medication histories and a backup of the original file. Windows date-only visit data imports at local midnight because the source has no time. The user should set the actual appointment time before enabling visit reminders. Import of the earlier Mac dictionary format is not implemented.

Local notifications use UNUserNotificationCenter. The adapter serializes reconciliations, replaces matching IDs and removes obsolete pending requests. It schedules up to 48 medication notifications within 30 days and 8 visit reminders one day before the visit. The queue horizon is visible. No background refresh guarantee, continuous monitoring, or notification-delivery guarantee is claimed. A notification is not proof of medication intake.

iOS storage uses completeFileProtectionUntilFirstUserAuthentication for normal writes. Exported JSON is plaintext. No custom encryption or sync is claimed. Temporary PDF/document previews use the app's temporary directory. No third-party telemetry is present.

The report is deterministic and derived only from entered data. Events, daily check-ins, medication confirmations, visit notes and questions are clearly separated. CoreText paginates all text rather than clipping long notes. Attachments are not automatically embedded in the doctor's PDF.

No watch target, medical triage algorithm, OCR, HealthKit or licensing work is part of this build.

Medication edits append immutable previous-plan intervals [from, until); the new plan becomes effective at save time. Dose planning on a historical day intersects each version with its effective interval, including unconfirmed past doses. Dose confirmations retain a prescription snapshot, including early confirmations. Report filtering and dose rows use historical details. Stopping a course removes future planned notifications but preserves its past schedule. Explicit postponement across the last course midnight is retained unless the course is stopped.
