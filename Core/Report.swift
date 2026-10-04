import Foundation

public struct ReportSection: Sendable {
  public enum Kind: Sendable { case text, header, symptoms, health }
  public var title: String
  public var body: String
  public var kind: Kind
  public init(title: String, body: String, kind: Kind = .text) {
    self.title = title
    self.body = body
    self.kind = kind
  }
}
/// Numbers and tables drawn graphically on the first PDF page.
public struct ReportSummary: Sendable {
  public struct SymptomRow: Sendable {
    public var label: String
    public var count: Int
    public var intensity: String
    public var last: String
  }
  public struct StripRow: Sendable {
    public var label: String
    /// One value per day in `days`; nil means no answer that day.
    public var values: [Frequency?]
  }
  public var title: String
  public var period: String
  public var patient: String?
  public var doctors: String
  public var generated: String
  public var disclaimer: String
  public var tiles: [(value: String, label: String)]
  public var symptoms: [SymptomRow]
  public var symptomTitle: String
  public var symptomHeaders: [String]
  public var days: [String]
  /// Localized labels for the first and last day of the strip.
  public var dayRange: (first: String, last: String)
  public var strip: [StripRow]
  public var stripTitle: String
  public var legend: [(Frequency?, String)]
  public var pageLabel: String
  public var health: HealthBlock?
}
/// Apple Watch / Apple Health / Strava part of the report, drawn as tiles, charts and a table.
public struct HealthBlock: Sendable {
  public struct ActivityRow: Sendable {
    public var date: String
    public var sport: String
    public var name: String
    public var duration: String
    public var distance: String
    public var heartRate: String
    public var source: ActivitySource
  }
  public var title: String
  public var tiles: [(value: String, label: String)]
  public var restingTitle: String
  public var resting: [Int?]
  public var stepsTitle: String
  public var steps: [Int?]
  public var sleepTitle: String
  public var sleep: [Int?]
  public var activitiesTitle: String
  public var activityHeaders: [String]
  public var activities: [ActivityRow]
  public var source: String
}
public enum ReportBuilder {
  public static func sections(
    state s: AppState, doctors: Set<UUID>, from: Date, through: Date, details: Bool = true,
    calendar: Calendar = .current
  ) -> [ReportSection] {
    let l = s.language
    /// Joins non-empty parts so missing optional fields leave no stray separators.
    func join(_ parts: [String?], _ separator: String = " · ") -> String {
      parts.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        .joined(separator: separator)
    }
    func day(_ key: String) -> String { Day.date(key, calendar: calendar).map { l.date($0) } ?? key }
    let start = calendar.startOfDay(for: from)
    let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: through))!
    let observations = s.observations.filter { doctors.isEmpty || doctors.contains($0.doctorID) }
    let ids = Set(observations.map(\.id))
    let events = s.events.filter {
      $0.timestamp >= start && $0.timestamp < end && s.matches($0.observationIDs, doctors: doctors)
    }.sorted { $0.timestamp < $1.timestamp }
    let checks = s.checkIns.filter {
      $0.day >= Day.key(start, calendar: calendar) && $0.day <= Day.key(through, calendar: calendar)
        && (doctors.isEmpty || $0.observationID.map({ ids.contains($0) }) == true)
    }.sorted { $0.day < $1.day }
    var result = [
      ReportSection(
        title: "SymptoPage · " + l.text("Visit summary", "Podsumowanie wizyty"),
        body: "\(l.date(start)) — \(l.date(through))\n"
          + l.text(
            "User-recorded observations. Not a diagnosis. Missing entries do not mean no symptoms.",
            "Obserwacje użytkownika. To nie diagnoza. Brak wpisu nie oznacza braku objawów."),
        kind: .header)
    ]
    let reasons = observations.map {
      "\(s.doctor(for: $0.id)?.title(l) ?? "—"): \($0.reason) [\($0.stage.title(l))]"
    }
    result.append(
      ReportSection(
        title: l.text("Reason for consultation", "Powód konsultacji"),
        body: reasons.isEmpty ? "—" : reasons.joined(separator: "\n")))
    let groups = Dictionary(grouping: events, by: \.symptom)
    let summary = groups.keys.sorted().map { key -> String in
      let values = groups[key]!
      let scores = values.compactMap(\.intensity)
      let intensity =
        scores.isEmpty
        ? l.text("not recorded", "nie podano") : "\(scores.min()!)–\(scores.max()!)/10"
      return "\(l.symptom(key)): \(values.count) " + l.text("events", "zdarzeń") + "; "
        + l.text("intensity", "nasilenie") + ": \(intensity)"
    }
    result.append(
      ReportSection(
        title: l.text("Recorded symptoms", "Zapisane objawy"),
        body: summary.isEmpty
          ? l.text("No events recorded in this period.", "Brak zdarzeń w tym okresie.")
          : summary.joined(separator: "\n"), kind: .symptoms))
    let notes = s.notes.filter {
      $0.date >= start && $0.date < end && s.matches($0.observationIDs, doctors: doctors)
    }.sorted { $0.date < $1.date }
    result.append(
      ReportSection(
        title: l.text("Wellbeing notes", "Notatki o samopoczuciu"),
        body: notes.isEmpty
          ? l.text("No notes in this period.", "Brak notatek w tym okresie.")
          : notes.map { n in
            let meta = ([n.mood?.title(l)].compactMap { $0 } + n.tags.map { "#" + l.tag($0) })
              .joined(separator: " · ")
            return l.date(n.date, time: true) + (meta.isEmpty ? "" : " · " + meta)
              + (n.text.isEmpty ? "" : "\n" + n.text)
          }.joined(separator: "\n\n")))
    let healthDays = s.healthDays.filter {
      $0.day >= Day.key(start, calendar: calendar) && $0.day <= Day.key(through, calendar: calendar)
    }
    let activities = s.activities.filter { $0.start >= start && $0.start < end }
    if !healthDays.isEmpty || !activities.isEmpty {
      func average(_ values: [Int]) -> Int? { values.isEmpty ? nil : values.reduce(0, +) / values.count }
      let resting = healthDays.compactMap(\.restingHR)
      let lines = [
        average(resting).map {
          l.text("Resting heart rate: average ", "Tętno spoczynkowe: średnio ")
            + "\($0)/min (\(resting.min()!)–\(resting.max()!))"
        },
        average(healthDays.compactMap(\.hrv)).map { l.text("HRV: average ", "HRV: średnio ") + "\($0) ms" },
        average(healthDays.compactMap(\.steps)).map { l.text("Steps: average ", "Kroki: średnio ") + "\($0)" + l.text("/day", "/dzień") },
        average(healthDays.compactMap(\.sleepMinutes)).map { l.text("Sleep: average ", "Sen: średnio ") + l.duration($0 * 60) },
      ].compactMap { $0 }
      let workouts = activities.map { a in
        join([
          l.date(a.start, time: true), l.sport(a.sport), a.name, l.duration(a.durationSeconds),
          a.distanceMeters.map { l.distance($0) },
          a.averageHR.map { l.text("avg HR ", "śr. tętno ") + "\($0)/min" }, a.source.title,
        ])
      }
      result.append(
        ReportSection(
          title: l.text("Activity and watch data", "Aktywność i dane z zegarka"),
          body: (lines + (workouts.isEmpty ? [] : [""] + workouts)).joined(separator: "\n")
            + "\n" + l.text(
              "Imported from Apple Health and Strava as recorded. Not interpreted.",
              "Zaimportowane z Apple Health i Strava bez interpretacji."),
          kind: .health))
    }
    let wellbeing = checks.compactMap { c in c.wellbeing.map { "\(day(c.day)): \($0.title(l))" } }
    result.append(
      ReportSection(
        title: l.text("Self-reported wellbeing", "Samoocena samopoczucia"),
        body: wellbeing.isEmpty
          ? l.text("Not recorded", "Nie podano") : wellbeing.joined(separator: "\n")))
    let versions: [(plan: MedicationPlan, from: Date?, until: Date?)] = s.medications.flatMap {
      medication in
      medication.history.map { (plan: $0.plan, from: $0.from, until: Optional($0.until)) }
        + [(plan: medication.plan, from: medication.effectiveFrom, until: nil)]
    }
    let matchingVersions = versions.filter { version in
      let plan = version.plan
      return (doctors.isEmpty || plan.observationID.map({ ids.contains($0) }) == true)
        && plan.startDay <= Day.key(through, calendar: calendar)
        && (plan.endDay.map { $0 >= Day.key(start, calendar: calendar) } ?? true)
        && (version.from.map { $0 < end } ?? true)
        && (version.until.map { $0 > start } ?? true)
    }
    result.append(
      ReportSection(
        title: l.text("Recorded medication plans", "Zapisane plany leków"),
        body: matchingVersions.isEmpty
          ? "—"
          : matchingVersions.map { version in
            let p = version.plan
            let window =
              (version.from.map { l.date($0, time: true) }
                ?? l.text("Original plan", "Pierwotny plan"))
              + " — "
              + (version.until.map { l.date($0, time: true) } ?? l.text("Current", "Aktualny"))
            return join(
              [
                join([p.name, p.dosage, p.times.map(\.label).joined(separator: ", ")]),
                day(p.startDay) + " — " + (p.endDay.map(day) ?? l.text("ongoing", "bez daty końcowej")),
                window, p.instructions, p.active ? nil : l.text("Stopped", "Zatrzymano"),
              ], "\n")
          }.joined(separator: "\n\n")))
    let visits = s.visits.filter { ids.contains($0.observationID) }.sorted { $0.date < $1.date }
    let questions = visits.filter { !$0.questions.isEmpty }.map {
      "\(l.date($0.date)): \($0.questions)"
    }
    result.append(
      ReportSection(
        title: l.text("Questions for the doctor", "Pytania do lekarza"),
        body: questions.isEmpty ? "—" : questions.joined(separator: "\n")))
    if details {
      result.append(
        ReportSection(
          title: l.text("Event timeline", "Historia zdarzeń"),
          body: events.isEmpty
            ? "—"
            : events.map { e in
              join(
                [
                  join([
                    l.date(e.timestamp, time: true), l.symptom(e.symptom),
                    e.intensity.map { l.text("intensity ", "nasilenie ") + "\($0)/10" },
                    e.durationMinutes.map { "\($0) min" },
                    e.heartRate.map { l.text("heart rate ", "tętno ") + "\($0)/min" },
                    e.source == "watch" ? "Apple Watch" : nil,
                  ]),
                  e.context, e.note,
                ], "\n")
            }.joined(separator: "\n\n")))
      result.append(
        ReportSection(
          title: l.text(
            "Daily check-ins (separate from events)", "Wpisy dzienne (oddzielnie od zdarzeń)"),
          body: checks.isEmpty
            ? "—"
            : checks.map { c in
              join(
                [
                  "\(day(c.day)) · \(l.symptom(c.symptom)): \(c.frequency.title(l))"
                    + (c.wellbeing.map { " · " + $0.title(l) } ?? ""),
                  c.note,
                ], "\n")
            }.joined(separator: "\n")))
      result.append(
        ReportSection(
          title: l.text(
            "Visit notes entered by the user", "Notatki z wizyt wpisane przez użytkownika"),
          body: {
            let notes = visits.filter { $0.completed && $0.date >= start && $0.date < end }.map {
              join([l.date($0.date), $0.notes, $0.instructions, $0.tests, $0.returnAdvice], "\n")
            }
            return notes.isEmpty ? "—" : notes.joined(separator: "\n\n")
          }()))
      let doses = s.doses.filter { record in
        let plan =
          record.snapshot
          ?? s.medications.first { $0.id == record.medicationID }?.plan(at: record.plannedAt)
        return record.plannedAt >= start && record.plannedAt < end
          && (doctors.isEmpty || plan?.observationID.map({ ids.contains($0) }) == true)
      }.sorted { $0.plannedAt < $1.plannedAt }
      result.append(
        ReportSection(
          title: l.text("Medication confirmations", "Potwierdzenia przyjęcia leków"),
          body: doses.isEmpty
            ? "—"
            : doses.map { r in
              let plan =
                r.snapshot ?? s.medications.first { $0.id == r.medicationID }?.plan(at: r.plannedAt)
              return
                "\(l.date(r.plannedAt, time: true)) · \(plan?.name ?? "—") · \(plan?.dosage ?? "—") · \(r.status.title(l)) · \(l.date(r.recordedAt, time: true))"
            }.joined(separator: "\n")))
    }
    return result
  }
  public static func summary(
    state s: AppState, doctors: Set<UUID>, from: Date, through: Date, calendar: Calendar = .current,
    now: Date = .now
  ) -> ReportSummary {
    let l = s.language
    let start = calendar.startOfDay(for: from)
    let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: through))!
    let observations = s.observations.filter { doctors.isEmpty || doctors.contains($0.doctorID) }
    let ids = Set(observations.map(\.id))
    let events = s.events.filter {
      $0.timestamp >= start && $0.timestamp < end && s.matches($0.observationIDs, doctors: doctors)
    }
    let checks = s.checkIns.filter {
      $0.day >= Day.key(start, calendar: calendar) && $0.day <= Day.key(through, calendar: calendar)
        && (doctors.isEmpty || $0.observationID.map({ ids.contains($0) }) == true)
    }
    let notes = s.notes.filter {
      $0.date >= start && $0.date < end && s.matches($0.observationIDs, doctors: doctors)
    }
    let doses = s.doses.filter { r in
      let plan =
        r.snapshot ?? s.medications.first { $0.id == r.medicationID }?.plan(at: r.plannedAt)
      return r.plannedAt >= start && r.plannedAt < end
        && (doctors.isEmpty || plan?.observationID.map({ ids.contains($0) }) == true)
    }
    let groups = Dictionary(grouping: events, by: \.symptom)
    let rows = groups.map { key, values -> ReportSummary.SymptomRow in
      let scores = values.compactMap(\.intensity)
      return .init(
        label: l.symptom(key), count: values.count,
        intensity: scores.isEmpty ? "—" : "\(scores.min()!)–\(scores.max()!)/10",
        last: l.date(values.map(\.timestamp).max()!))
    }.sorted { ($1.count, $0.label) < ($0.count, $1.label) }
    // The strip shows at most the last 31 days of the period, one square per day.
    var days: [String] = []
    var cursor = calendar.startOfDay(for: through)
    while cursor >= start && days.count < 31 {
      days.insert(Day.key(cursor, calendar: calendar), at: 0)
      guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
      cursor = previous
    }
    let stripGroups = Dictionary(grouping: checks, by: \.symptom)
    let strip = stripGroups.keys.sorted { l.symptom($0) < l.symptom($1) }.map { key in
      ReportSummary.StripRow(
        label: l.symptom(key),
        values: days.map { day in
          let answers = stripGroups[key]!.filter { $0.day == day }.map(\.frequency)
          return answers.contains(.several)
            ? .several : answers.contains(.once) ? .once : answers.first
        })
    }
    let names = observations.compactMap { s.doctor(for: $0.id)?.title(l) }
    let doctorsLine = doctors.isEmpty
      ? l.text("All doctors", "Wszyscy lekarze")
      : Array(Set(names)).sorted().joined(separator: ", ")
    let name = s.profileName?.trimmingCharacters(in: .whitespacesAndNewlines)
    let health = healthBlock(s, days: days, start: start, end: end)
    return ReportSummary(
      title: l.text("Report for the doctor", "Raport dla lekarza"),
      period: "\(l.date(start)) — \(l.date(through))",
      patient: (name?.isEmpty ?? true) ? nil : name,
      doctors: doctorsLine,
      generated: l.text("Generated ", "Wygenerowano ") + l.date(now, time: true),
      disclaimer: l.text(
        "User-recorded observations. Not a diagnosis. Missing entries do not mean no symptoms.",
        "Obserwacje użytkownika. To nie diagnoza. Brak wpisu nie oznacza braku objawów."),
      tiles: [
        ("\(events.count)", l.text("symptom events", "zdarzenia objawów")),
        ("\(Set(checks.map(\.day)).count)", l.text("days with answers", "dni z odpowiedziami")),
        ("\(notes.count)", l.text("wellbeing notes", "notatki")),
        (
          "\(doses.filter { $0.status == .taken }.count)/\(doses.count)",
          l.text("doses taken / recorded", "dawki przyjęte / zapisane")
        ),
      ],
      symptoms: rows,
      symptomTitle: l.text("Recorded symptoms", "Zapisane objawy"),
      symptomHeaders: [
        l.text("Symptom", "Objaw"), l.text("Events", "Zdarzenia"),
        l.text("Intensity", "Nasilenie"), l.text("Last", "Ostatnio"),
      ],
      days: days,
      dayRange: (
        days.first.flatMap { Day.date($0, calendar: calendar) }.map { l.date($0) } ?? "",
        days.last.flatMap { Day.date($0, calendar: calendar) }.map { l.date($0) } ?? ""
      ),
      strip: strip,
      stripTitle: l.text("Daily answers", "Codzienne odpowiedzi"),
      legend: [
        (Frequency.none, Frequency.none.title(l)), (.once, Frequency.once.title(l)),
        (.several, Frequency.several.title(l)), (nil, l.text("No answer", "Brak odpowiedzi")),
      ],
      pageLabel: l.text("Page", "Strona"), health: health)
  }
  static func healthBlock(_ s: AppState, days: [String], start: Date, end: Date) -> HealthBlock? {
    let l = s.language
    let byDay = Dictionary(uniqueKeysWithValues: s.healthDays.map { ($0.day, $0) })
    let inPeriod = s.healthDays.filter { d in days.contains(d.day) }
    let activities = s.activities.filter { $0.start >= start && $0.start < end }.sorted { $0.start > $1.start }
    guard !inPeriod.isEmpty || !activities.isEmpty else { return nil }
    func average(_ values: [Int]) -> Int? { values.isEmpty ? nil : values.reduce(0, +) / values.count }
    let total = activities.reduce(0) { $0 + $1.durationSeconds }
    return HealthBlock(
      title: l.text("Activity and watch data", "Aktywność i dane z zegarka"),
      tiles: [
        (average(inPeriod.compactMap(\.restingHR)).map { "\($0)" } ?? "—", l.text("avg resting HR /min", "śr. tętno spocz. /min")),
        (average(inPeriod.compactMap(\.steps)).map { "\($0)" } ?? "—", l.text("avg steps / day", "śr. kroki / dzień")),
        (average(inPeriod.compactMap(\.sleepMinutes)).map { l.duration($0 * 60) } ?? "—", l.text("avg sleep", "śr. sen")),
        ("\(activities.count)", l.text("workouts", "treningi") + (total > 0 ? " · " + l.duration(total) : "")),
      ],
      restingTitle: l.text("Resting heart rate", "Tętno spoczynkowe"),
      resting: days.map { byDay[$0]?.restingHR },
      stepsTitle: l.text("Steps", "Kroki"),
      steps: days.map { byDay[$0]?.steps },
      sleepTitle: l.text("Sleep (hours)", "Sen (godziny)"),
      sleep: days.map { byDay[$0]?.sleepMinutes },
      activitiesTitle: l.text("Workouts", "Treningi"),
      activityHeaders: [
        l.text("Date", "Data"), l.text("Type", "Rodzaj"), l.text("Time", "Czas"), l.text("Distance", "Dystans"),
        l.text("Avg HR", "Śr. tętno"), l.text("Source", "Źródło"),
      ],
      activities: activities.map { a in
        .init(
          date: l.date(a.start), sport: l.sport(a.sport), name: a.name, duration: l.duration(a.durationSeconds),
          distance: a.distanceMeters.map { l.distance($0) } ?? "—", heartRate: a.averageHR.map { "\($0)" } ?? "—",
          source: a.source)
      },
      source: l.text(
        "Apple Health (Apple Watch) and Strava, imported as recorded.",
        "Apple Health (Apple Watch) i Strava, zaimportowane bez zmian."))
  }
}
