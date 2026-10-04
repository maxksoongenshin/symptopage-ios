import Foundation

/// iPhone → Watch: what the watch needs to offer one-tap entries.
public struct WatchContext: Codable, Equatable, Sendable {
  public struct Item: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var title: String
    /// Daily-question symptom key, if chosen.
    public var symptom: String?
    /// Today's answer, if any.
    public var answer: Frequency?
    public var daysLeft: Int?
    public init(id: UUID, title: String, symptom: String?, answer: Frequency?, daysLeft: Int?) {
      self.id = id
      self.title = title
      self.symptom = symptom
      self.answer = answer
      self.daysLeft = daysLeft
    }
  }
  public var language: Language
  public var name: String?
  public var observations: [Item]
  /// Symptoms offered first on the watch (daily questions, then recent, then common).
  public var quickSymptoms: [String]
  public var day: String
  public init(language: Language, name: String?, observations: [Item], quickSymptoms: [String], day: String) {
    self.language = language
    self.name = name
    self.observations = observations
    self.quickSymptoms = quickSymptoms
    self.day = day
  }

  public static func make(from s: AppState, now: Date = .now, calendar: Calendar = .current) -> WatchContext {
    let today = Day.key(now, calendar: calendar)
    let active = s.observations.filter { !$0.archived && $0.stage != .completed }
    let items = active.map { o -> Item in
      let visit = s.visits.filter { $0.observationID == o.id && !$0.completed }.min { $0.date < $1.date }
      let days = visit.map {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: $0.date)).day ?? 0
      }
      let answer = o.symptom.flatMap { symptom in
        s.checkIns.first { $0.observationID == o.id && $0.day == today && $0.symptom == symptom }?.frequency
      }
      return Item(
        id: o.id, title: s.doctor(for: o.id)?.title(s.language) ?? "—", symptom: o.symptom,
        answer: answer, daysLeft: days)
    }
    var seen = Set<String>()
    let recent = s.events.sorted { $0.timestamp > $1.timestamp }.map(\.symptom)
    let quick = (active.compactMap(\.symptom) + recent + ["palpitations", "dizziness", "headache", "pain", "fatigue", "dyspnea"])
      .filter { seen.insert($0).inserted }
    return WatchContext(
      language: s.language, name: s.profileName, observations: items, quickSymptoms: Array(quick.prefix(8)),
      day: today)
  }
}

/// Watch → iPhone: one quick entry. `id` makes delivery idempotent (retries do not duplicate).
public struct WatchEntry: Codable, Equatable, Sendable, Identifiable {
  public enum Kind: String, Codable, Sendable { case symptom, answer, mood }
  public var id: UUID
  public var kind: Kind
  public var timestamp: Date
  public var observationID: UUID?
  public var symptom: String?
  public var intensity: Int?
  public var heartRate: Int?
  public var frequency: Frequency?
  public var mood: Mood?
  public init(kind: Kind, timestamp: Date = .now) {
    id = UUID()
    self.kind = kind
    self.timestamp = timestamp
  }

  public func encoded() throws -> Data {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .secondsSince1970
    return try e.encode(self)
  }
  public static func decode(_ data: Data) throws -> WatchEntry {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .secondsSince1970
    return try d.decode(WatchEntry.self, from: data)
  }

  /// Applies the entry to the phone's state. Unknown observations become general entries;
  /// invalid values are clamped or dropped rather than rejecting the whole entry.
  public func apply(to s: inout AppState, calendar: Calendar = .current) {
    let link = observationID.flatMap { id in s.observations.contains { $0.id == id } ? id : nil }
    let time = min(timestamp, Date().addingTimeInterval(60))
    switch kind {
    case .symptom:
      guard let symptom, !symptom.trimmingCharacters(in: .whitespaces).isEmpty,
        !s.events.contains(where: { $0.id == id })
      else { return }
      var e = SymptomEvent(symptom: String(symptom.prefix(200)))
      e.id = id
      e.timestamp = time
      e.observationIDs = link.map { [$0] } ?? []
      e.intensity = intensity.map { min(max($0, 1), 10) }
      e.heartRate = heartRate.flatMap { (20...260).contains($0) ? $0 : nil }
      e.source = "watch"
      e.createdAt = time
      e.updatedAt = time
      s.events.append(e)
    case .answer:
      guard let frequency, let link, let o = s.observations.first(where: { $0.id == link }),
        let symptom = symptom ?? o.symptom
      else { return }
      let day = Day.key(time, calendar: calendar)
      if let index = s.checkIns.firstIndex(where: { $0.observationID == link && $0.day == day && $0.symptom == symptom }) {
        s.checkIns[index].frequency = frequency
        s.checkIns[index].updatedAt = .now
      } else {
        s.checkIns.append(DailyCheckIn(observationID: link, day: day, symptom: symptom, frequency: frequency))
      }
    case .mood:
      guard let mood, !s.notes.contains(where: { $0.id == id }) else { return }
      var n = WellbeingNote(text: "", mood: mood)
      n.id = id
      n.date = time
      n.observationIDs = link.map { [$0] } ?? []
      n.tags = ["watch"]
      s.notes.append(n)
    }
  }
}
