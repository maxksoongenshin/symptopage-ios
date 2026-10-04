# SymptoPage 1.0 · iOS

**Record symptoms. Show your doctor.** A private symptom journal for iPhone (SwiftUI, iOS 17+, English / Polski) that turns everyday observations into a clear report for the next visit.

## Install on iPhone (no Xcode)

1. Download `SymptoPage-iPhone-1.0.ipa` from [Releases](https://github.com/maxksoongenshin/symptopage-ios/releases/latest).
2. Install [Sideloadly](https://sideloadly.io), connect the iPhone by cable, enable *Settings → Privacy & Security → Developer Mode*.
3. Drag the `.ipa` into Sideloadly, enter your Apple ID, press **Start**.
4. On the iPhone: *Settings → General → VPN & Device Management* → trust your Apple ID.

A free Apple ID works; the app then runs for 7 days and can be re-installed without losing data.

## Run from source

Open `SymptoPage.xcodeproj` in Xcode 16+, choose the scheme **SymptoPage** and an iPhone simulator, press **Run**. Entry point: `App/SymptoPageApp.swift`. No account, server or API keys are needed.

## Features

- **"!!! Now!"** – record a symptom in one tap: time, intensity, duration, note.
- **Doctors and visits** – countdown to each visit, one daily question per doctor (None / Once / Several), delete a doctor with a long press.
- **Symptom trend** – chart of symptoms per day for 7 / 14 / 30 days with the change against the previous period.
- **Report for the doctor** – designed PDF with summary, symptom table and daily-answer grid; print or share.
- **Medication** – courses, dose confirmations and reminders.
- **Notifications** – daily question at 20:00, visit reminders the day before and in the morning, medication reminders, test notification in Settings.
- **Apple Health** – resting heart rate, HRV, sleep and steps next to your symptoms (read-only).
- **Private** – data stays on the device; no login, no analytics; backup and restore.

## Project structure

| Folder | Contents |
|---|---|
| `App/` | iPhone UI (SwiftUI), storage access, notifications, HealthKit |
| `Core/` | Models, validation, persistence, scheduling, PDF report |
| `Tests/`, `UITests/` | Core tests and UI tests |
| `scripts/` | Project generator and checks (`bash scripts/check_all.sh`) |

Developer notes in Russian: [docs/DEVELOPMENT_RU.md](docs/DEVELOPMENT_RU.md).

SymptoPage records personal observations. It does not provide a diagnosis.
