// Offscreen render check: draws every screen and form in both languages, with empty and
// filled data, and fails if anything renders blank. Run via scripts/check_ui_render.sh.
import AppKit
import CoreText
import SwiftUI

@MainActor func render<V: View>(_ view: V, size: CGSize, scale: CGFloat? = nil) -> NSBitmapImageRep {
  let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
  host.frame = CGRect(origin: .zero, size: size)
  let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
  window.contentView = host
  host.layoutSubtreeIfNeeded()
  RunLoop.main.run(until: Date().addingTimeInterval(0.35))
  var rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
  if let scale {
    // A bitmap with more pixels than points renders the view at that scale (store screenshots).
    rep = NSBitmapImageRep(
      bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
      bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
  }
  host.cacheDisplay(in: host.bounds, to: rep)
  return rep
}
/// Number of distinct colours on a coarse grid; a blank or failed screen has very few.
func variety(_ rep: NSBitmapImageRep) -> Int {
  var colours = Set<UInt32>()
  for y in stride(from: 0, to: rep.pixelsHigh, by: max(rep.pixelsHigh / 90, 1)) {
    for x in stride(from: 0, to: rep.pixelsWide, by: max(rep.pixelsWide / 45, 1)) {
      guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
      colours.insert(
        UInt32(c.redComponent * 31) << 10 | UInt32(c.greenComponent * 31) << 5 | UInt32(c.blueComponent * 31))
    }
  }
  return colours.count
}

@MainActor func seed(_ store: AppStore) {
  let cal = Calendar.current
  _ = store.change { s in
    s.profileName = "Kasia"
    let d = Doctor(specialty: "cardiologist")
    let d2 = Doctor(specialty: "neurologist")
    s.doctors = [d, d2]
    var o = Observation(doctorID: d.id, reason: "Kołatanie serca wieczorem")
    o.symptom = "palpitations"
    let o2 = Observation(doctorID: d2.id, reason: "Bóle głowy rano")
    s.observations = [o, o2]
    var v = Visit(observationID: o.id, date: cal.date(byAdding: .day, value: 47, to: .now)!)
    v.questions = "Czy mogę pić kawę?"
    s.visits = [v, Visit(observationID: o2.id, date: cal.date(byAdding: .day, value: 12, to: .now)!)]
    for i in 0..<6 {
      var e = SymptomEvent(symptom: ["palpitations", "dizziness", "headache"][i % 3])
      e.observationIDs = [o.id]
      e.timestamp = Date().addingTimeInterval(-Double(i) * 50_000 - 600)
      e.intensity = i + 3
      e.note = i == 0 ? "Po kawie" : ""
      s.events.append(e)
    }
    s.checkIns = [DailyCheckIn(observationID: o.id, day: Day.key(.now), symptom: "palpitations", frequency: .once)]
    var n = WellbeingNote(text: "Spałam 5 godzin, po spacerze lepiej.", mood: .okay)
    n.tags = ["sleep", "activity"]
    s.notes = [n]
    var days: [HealthDay] = []
    for i in 0..<30 {
      var d = HealthDay(day: Day.key(cal.date(byAdding: .day, value: -i, to: .now)!))
      d.restingHR = 62 + (i * 7) % 9
      d.hrv = 38 + (i * 5) % 20
      d.steps = 4200 + (i * 1733) % 7800
      d.sleepMinutes = 330 + (i * 37) % 150
      days.append(d)
    }
    var run = Activity(id: "strava:1", source: .strava, sport: "Run", name: "Poranny bieg", start: Date().addingTimeInterval(-20_000), durationSeconds: 2400)
    run.distanceMeters = 6200
    run.averageHR = 146
    var walk = Activity(id: "health:1", source: .health, sport: "Walk", name: "Apple Watch", start: Date().addingTimeInterval(-200_000), durationSeconds: 3000)
    walk.distanceMeters = 3900
    HealthMerge.apply(days: days, activities: [run, walk], to: &s)
    s.integrations.healthEnabled = true
    s.integrations.stravaAthlete = "Kasia"
    s.integrations.lastHealthSync = .now
    s.events[0].heartRate = 118
    s.events[0].source = "watch"
    var m = Medication(name: "Bisoprolol", dosage: "2,5 mg", startDay: Day.key(.now), times: [DoseTime(hour: 0, minute: 1)])
    m.observationID = o.id
    s.medications = [m]
  }
}

/// App Store screenshot: caption on the brand gradient (icon colours) above a framed screen.
struct StoreShot: View {
  let title: String
  let subtitle: String
  let screens: [NSImage]
  let watch: Bool
  var body: some View {
    ZStack(alignment: .top) {
      LinearGradient(colors: [Color(red: 0.008, green: 0.18, blue: 0.345), Color(red: 0.086, green: 0.451, blue: 0.455)],
        startPoint: .top, endPoint: .bottom)
      Circle().fill(Color(red: 0.49, green: 0.81, blue: 0.78).opacity(0.18)).frame(width: 1100).offset(x: 520, y: 1500)
      Circle().fill(.white.opacity(0.06)).frame(width: 800).offset(x: -480, y: 380)
      VStack(spacing: 34) {
        Text(title).font(.custom("Manrope-ExtraBold", size: 92)).foregroundStyle(.white).multilineTextAlignment(.center)
          .lineSpacing(-6).fixedSize(horizontal: false, vertical: true)
        Text(subtitle).font(.custom("Manrope-SemiBold", size: 44)).foregroundStyle(Color(red: 0.70, green: 0.93, blue: 0.90))
          .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 20)
        if watch {
          HStack(spacing: 44) {
            ForEach(Array(screens.enumerated()), id: \.offset) { _, image in
              Image(nsImage: image).resizable().scaledToFit().frame(width: 520)
                .clipShape(RoundedRectangle(cornerRadius: 110, style: .continuous))
                .padding(30).background(Color(white: 0.07), in: RoundedRectangle(cornerRadius: 140, style: .continuous))
                .shadow(color: .black.opacity(0.4), radius: 40, y: 30)
            }
          }.padding(.bottom, 460)
        } else {
          Image(nsImage: screens[0]).resizable().scaledToFit().frame(width: 960)
            .clipShape(RoundedRectangle(cornerRadius: 110, style: .continuous))
            .padding(26).background(Color(white: 0.06), in: RoundedRectangle(cornerRadius: 136, style: .continuous))
            .shadow(color: .black.opacity(0.45), radius: 50, y: 30).offset(y: 120)
        }
      }.padding(.top, 170).padding(.horizontal, 90)
    }.frame(width: 1290, height: 2796).clipped()
  }
}

@MainActor func storeScreenshots(_ out: URL) {
  let base = FileManager.default.temporaryDirectory.appendingPathComponent("symptopage-store-\(UUID().uuidString)")
  defer { try? FileManager.default.removeItem(at: base) }
  for language in Language.allCases {
    let store = AppStore(url: base.appendingPathComponent("\(language.rawValue)/records.json"))
    seed(store)
    _ = store.change { $0.language = language }
    func screen<V: View>(_ v: V) -> NSImage {
      let rep = render(
        v.environmentObject(store).environment(\.locale, store.language.locale).tint(Theme.teal)
          .font(.brand(.body)).preferredColorScheme(.light), size: CGSize(width: 390, height: 844), scale: 3)
      let image = NSImage(size: rep.size)
      image.addRepresentation(rep)
      return image
    }
    let watch = WatchStore(defaults: UserDefaults(suiteName: "store-\(language.rawValue)")!, preview: WatchContext.make(from: store.state))
    watch.setPreviewHeartRate(78)
    func wscreen<V: View>(_ v: V) -> NSImage {
      let rep = render(
        v.environmentObject(watch).tint(WTheme.mint).padding(8).frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(.black).preferredColorScheme(.dark), size: CGSize(width: 198, height: 242), scale: 3)
      let image = NSImage(size: rep.size)
      image.addRepresentation(rep)
      return image
    }
    let t = { (en: String, pl: String) in language.text(en, pl) }
    let shots: [(String, String, [NSImage], Bool)] = [
      (t("Record symptoms.\nShow your doctor.", "Zapisuj objawy.\nPokaż je lekarzowi."),
       t("Countdown to the visit and one daily question", "Licznik do wizyty i jedno pytanie dziennie"),
       [screen(RootView())], false),
      (t("One tap on\nApple Watch", "Jedno dotknięcie\nna Apple Watch"),
       t("Symptom, intensity and heart rate in seconds", "Objaw, nasilenie i tętno w kilka sekund"),
       [wscreen(NavigationStack { WatchNowPage() }), wscreen(WatchIntensityView(symptom: "palpitations"))], true),
      (t("Heart rate, sleep\nand workouts", "Tętno, sen\ni treningi"),
       t("From Apple Health and Strava — automatically", "Z Apple Health i Strava — automatycznie"),
       [screen(NavigationStack { HealthView() })], false),
      (t("A clear PDF\nfor the visit", "Przejrzysty PDF\nna wizytę"),
       t("Symptoms, answers, notes and activity on one report", "Objawy, odpowiedzi, notatki i aktywność w jednym raporcie"),
       [screen(NavigationStack { ReportView() })], false),
      (t("Everything\nin one journal", "Wszystko\nw jednym dzienniku"),
       t("Notes, moods and answers day by day", "Notatki, nastrój i odpowiedzi dzień po dniu"),
       [screen(NavigationStack { JournalView() })], false),
    ]
    for (index, shot) in shots.enumerated() {
      let rep = render(StoreShot(title: shot.0, subtitle: shot.1, screens: shot.2, watch: shot.3),
        size: CGSize(width: 1290, height: 2796), scale: 1)
      let file = out.appendingPathComponent("\(language.rawValue)-\(index + 1).png")
      try? rep.representation(using: .png, properties: [:])?.write(to: file)
      print("store screenshot \(file.lastPathComponent) \(rep.pixelsWide)×\(rep.pixelsHigh)")
    }
  }
}

@main struct RenderCheck {
  @MainActor static func main() {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.prohibited)
    BrandFonts.register()
    WFont.register()
    let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? NSTemporaryDirectory())
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    if CommandLine.arguments.contains("--store") {
      storeScreenshots(out)
      return
    }
    var failures: [String] = []
    if CTFontCopyPostScriptName(CTFontCreateWithName("Manrope-ExtraBold" as CFString, 12, nil)) as String
      != "Manrope-ExtraBold"
    {
      failures.append("Manrope fonts were not registered")
    }
    let base = FileManager.default.temporaryDirectory.appendingPathComponent("symptopage-render-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: base) }
    var count = 0
    for language in Language.allCases {
      let empty = AppStore(url: base.appendingPathComponent("empty-\(language.rawValue)/records.json"))
      let full = AppStore(url: base.appendingPathComponent("full-\(language.rawValue)/records.json"))
      _ = empty.change { $0.language = language }
      seed(full)
      _ = full.change { $0.language = language }
      let o = full.state.observations[0]
      let screens: [(String, AppStore, AnyView, CGSize)] = [
        ("welcome", empty, AnyView(RootView()), CGSize(width: 390, height: 844)),
        ("start-empty", empty, AnyView(NavigationStack { TodayView() }), CGSize(width: 390, height: 1100)),
        ("start", full, AnyView(NavigationStack { TodayView() }), CGSize(width: 390, height: 1500)),
        ("tabs", full, AnyView(RootView()), CGSize(width: 480, height: 860)),
        ("report", full, AnyView(NavigationStack { ReportView() }), CGSize(width: 390, height: 1400)),
        ("journal", full, AnyView(NavigationStack { JournalView() }), CGSize(width: 390, height: 1400)),
        ("journal-empty", empty, AnyView(NavigationStack { JournalView() }), CGSize(width: 390, height: 844)),
        ("settings", full, AnyView(NavigationStack { SettingsView() }), CGSize(width: 390, height: 1200)),
        ("health", full, AnyView(NavigationStack { HealthView() }), CGSize(width: 390, height: 1700)),
        ("integrations", empty, AnyView(NavigationStack { IntegrationsView() }), CGSize(width: 390, height: 1500)),
        ("integrations-on", full, AnyView(NavigationStack { IntegrationsView() }), CGSize(width: 390, height: 1100)),
        ("care", full, AnyView(NavigationStack { CareView() }), CGSize(width: 390, height: 1000)),
        ("observation", full, AnyView(NavigationStack { ObservationDetail(observationID: o.id) }), CGSize(width: 390, height: 1000)),
        ("visit", full, AnyView(NavigationStack { VisitDetail(visitID: full.state.visits[0].id) }), CGSize(width: 390, height: 1000)),
        ("medications", full, AnyView(NavigationStack { MedicationPlanView() }), CGSize(width: 390, height: 1000)),
        ("dose-sheet", full, AnyView(DosePlanSheet()), CGSize(width: 390, height: 844)),
        ("form-event", full, AnyView(EventForm()), CGSize(width: 390, height: 1400)),
        ("form-checkin", full, AnyView(CheckInForm(observationID: o.id, symptom: "palpitations")), CGSize(width: 390, height: 1400)),
        ("form-note", full, AnyView(NoteForm()), CGSize(width: 390, height: 1100)),
        ("form-visit", full, AnyView(NewObservationForm()), CGSize(width: 390, height: 1100)),
        ("form-question", full, AnyView(DailySymptomForm(observation: o)), CGSize(width: 390, height: 1400)),
        ("form-medication", full, AnyView(MedicationForm(observationID: o.id)), CGSize(width: 390, height: 1200)),
      ]
      for (name, store, view, size) in screens {
        let rep = render(
          view.environmentObject(store).environment(\.locale, store.language.locale).tint(Theme.teal)
            .font(.brand(.body)).preferredColorScheme(.light), size: size)
        let file = out.appendingPathComponent("\(name)-\(language.rawValue).png")
        try? rep.representation(using: .png, properties: [:])?.write(to: file)
        let v = variety(rep)
        if v < 12 { failures.append("\(name)-\(language.rawValue): looks blank (\(v) colours)") }
        count += 1
      }
      // Apple Watch screens (45 mm: 198 × 242 pt), dark as on the device.
      let watch = WatchStore(defaults: UserDefaults(suiteName: "render-\(language.rawValue)")!, preview: WatchContext.make(from: full.state))
      watch.setPreviewHeartRate(78)
      let item = watch.context!.observations.first { $0.symptom != nil }!
      let watchScreens: [(String, AnyView)] = [
        ("watch-now", AnyView(NavigationStack { WatchNowPage() })),
        ("watch-symptoms", AnyView(NavigationStack { WatchSymptomList() })),
        ("watch-intensity", AnyView(WatchIntensityView(symptom: "palpitations"))),
        ("watch-saved", AnyView(WatchSavedView(symptom: "palpitations", intensity: 7))),
        ("watch-question", AnyView(WatchQuestionPage(item: item))),
        ("watch-mood", AnyView(WatchMoodPage())),
      ]
      for (name, view) in watchScreens {
        let rep = render(
          view.environmentObject(watch).tint(WTheme.mint).padding(8).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black).preferredColorScheme(.dark), size: CGSize(width: 198, height: 242))
        try? rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent("\(name)-\(language.rawValue).png"))
        if variety(rep) < 8 { failures.append("\(name)-\(language.rawValue): looks blank") }
        count += 1
      }
    }
    if failures.isEmpty {
      print("PASS \(count) screens rendered in EN and PL → \(out.path)")
    } else {
      failures.forEach { print("FAIL " + $0) }
      exit(1)
    }
  }
}
