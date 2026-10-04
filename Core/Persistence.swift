import Foundation

public enum DataError: Error, Equatable { case invalid, unsupportedVersion, tooLarge }
public enum StateCodec {
  public static let maxBytes = 50 * 1024 * 1024
  public static func encode(_ state: AppState) throws -> Data {
    try validate(state)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .custom { date, encoder in
      var container = encoder.singleValueContainer()
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      try container.encode(formatter.string(from: date))
    }
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(state)
    guard data.count <= maxBytes else { throw DataError.tooLarge }
    return data
  }
  public static func decode(_ data: Data) throws -> AppState {
    guard data.count <= maxBytes else { throw DataError.tooLarge }
    guard let header = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw DataError.invalid
    }
    if let version = header["schemaVersion"] as? Int, version == 2 || version == 3 {
      var migrated = header
      if version == 2 {
        guard let medications = header["medications"] as? [[String: Any]] else {
          throw DataError.invalid
        }
        migrated["schemaVersion"] = 3
        migrated["medications"] = medications.map { item in
          var m = item
          m["history"] = []
          return m
        }
      }
      // Collections added after schema 3 was introduced are optional in older files.
      if migrated["notes"] == nil { migrated["notes"] = [] }
      if migrated["healthDays"] == nil { migrated["healthDays"] = [] }
      if migrated["activities"] == nil { migrated["activities"] = [] }
      if migrated["integrations"] == nil { migrated["integrations"] = ["healthEnabled": false] }
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .custom { decoder in
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: value) else { throw DataError.invalid }
        return date
      }
      let state = try decoder.decode(
        AppState.self, from: JSONSerialization.data(withJSONObject: migrated))
      try validate(state)
      return state
    }
    if header["version"] as? Int == 1 { return try WindowsMigration.convert(data) }
    throw DataError.unsupportedVersion
  }
  public static func validate(_ s: AppState) throws {
    guard s.schemaVersion == 3 else { throw DataError.unsupportedVersion }
    func unique<T: Hashable>(_ values: [T]) throws {
      guard Set(values).count == values.count else { throw DataError.invalid }
    }
    func text(_ value: String, required: Bool = false, max: Int = 10000) throws {
      guard value.count <= max,
        !required || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else { throw DataError.invalid }
    }
    func dates(_ values: Date...) throws {
      guard
        values.allSatisfy({
          $0.timeIntervalSince1970.isFinite
            && (0...4_102_444_800).contains($0.timeIntervalSince1970)
        })
      else { throw DataError.invalid }
    }
    try text(s.profileName ?? "", max: 100)
    try unique(s.doctors.map(\.id))
    try unique(s.observations.map(\.id))
    try unique(s.visits.map(\.id))
    try unique(s.events.map(\.id))
    try unique(s.checkIns.map(\.id))
    try unique(s.medications.map(\.id))
    try unique(s.doses.map(\.id))
    try unique(s.attachments.map(\.id))
    try unique(s.notes.map(\.id))
    try unique(s.healthDays.map(\.day))
    try unique(s.activities.map(\.id))
    guard s.healthDays.count <= 20000, s.activities.count <= 50000 else { throw DataError.tooLarge }
    func within(_ value: Int?, _ range: ClosedRange<Int>) -> Bool { value.map { range.contains($0) } ?? true }
    for d in s.healthDays {
      guard Day.valid(d.day), within(d.restingHR, 20...260), within(d.averageHR, 20...260),
        within(d.maxHR, 20...260), within(d.hrv, 0...500), within(d.steps, 0...200_000),
        within(d.sleepMinutes, 0...1440), within(d.activeKcal, 0...20_000)
      else { throw DataError.invalid }
    }
    for a in s.activities {
      guard (0...604_800).contains(a.durationSeconds), within(a.averageHR, 20...260),
        within(a.maxHR, 20...260), within(a.kcal, 0...50_000),
        a.distanceMeters.map({ $0.isFinite && (0...2_000_000).contains($0) }) ?? true,
        a.elevationMeters.map({ $0.isFinite && abs($0) <= 20_000 }) ?? true
      else { throw DataError.invalid }
      try text(a.id, required: true, max: 100)
      try text(a.name, max: 300)
      try text(a.sport, required: true, max: 100)
      try dates(a.start)
    }
    try text(s.integrations.stravaAthlete ?? "", max: 200)
    let doctorIDs = Set(s.doctors.map(\.id))
    let observationIDs = Set(s.observations.map(\.id))
    let medicationIDs = Set(s.medications.map(\.id))
    let attachmentIDs = Set(s.attachments.map(\.id))
    guard s.notes.count <= 100000, s.events.count <= 100000, s.checkIns.count <= 100000, s.doses.count <= 100000,
      s.doctors.count <= 1000, s.medications.count <= 1000, s.visits.count <= 10000
    else { throw DataError.tooLarge }
    for d in s.doctors {
      try text(d.specialty, required: true, max: 200)
      try text(d.name, max: 200)
      try text(d.clinic, max: 500)
      try dates(d.createdAt, d.updatedAt)
    }
    for o in s.observations {
      guard doctorIDs.contains(o.doctorID) else { throw DataError.invalid }
      try text(o.reason, required: true)
      if let symptom = o.symptom { try text(symptom, required: true, max: 200) }
      try dates(o.createdAt, o.updatedAt)
    }
    for v in s.visits {
      guard observationIDs.contains(v.observationID),
        Set(v.attachmentIDs).isSubset(of: attachmentIDs)
      else { throw DataError.invalid }
      try unique(v.attachmentIDs)
      try dates(v.date, v.createdAt, v.updatedAt)
      for value in [v.notes, v.instructions, v.tests, v.questions, v.returnAdvice] {
        try text(value)
      }
    }
    for e in s.events {
      guard Set(e.observationIDs).isSubset(of: observationIDs),
        e.intensity.map({ (1...10).contains($0) }) ?? true,
        e.durationMinutes.map({ (1...43200).contains($0) }) ?? true,
        e.heartRate.map({ (20...260).contains($0) }) ?? true
      else { throw DataError.invalid }
      try unique(e.observationIDs)
      try text(e.symptom, required: true, max: 200)
      try text(e.note)
      try text(e.context)
      try dates(e.timestamp, e.createdAt, e.updatedAt)
    }
    for n in s.notes {
      guard Set(n.observationIDs).isSubset(of: observationIDs), n.tags.count <= 20,
        n.mood != nil || !n.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else { throw DataError.invalid }
      try unique(n.observationIDs)
      try unique(n.tags)
      try text(n.text)
      for tag in n.tags { try text(tag, required: true, max: 50) }
      try dates(n.date, n.createdAt, n.updatedAt)
    }
    var checkInKeys = Set<String>()
    for c in s.checkIns {
      let key = "\(c.observationID?.uuidString ?? "general")/\(c.day)/\(c.symptom)"
      guard c.observationID.map({ observationIDs.contains($0) }) ?? true, Day.valid(c.day),
        TimeZone(identifier: c.timeZoneID) != nil, checkInKeys.insert(key).inserted
      else { throw DataError.invalid }
      try text(c.symptom, required: true, max: 200)
      try text(c.note)
      try dates(c.updatedAt)
    }
    func validatePlan(_ m: MedicationPlan) throws {
      guard m.observationID.map({ observationIDs.contains($0) }) ?? true, Day.valid(m.startDay),
        m.endDay.map({ Day.valid($0) && $0 >= m.startDay }) ?? true,
        !m.times.isEmpty, m.times.count <= 8,
        m.times.allSatisfy({ (0...23).contains($0.hour) && (0...59).contains($0.minute) }),
        !m.weekdays.isEmpty, m.weekdays.allSatisfy({ (1...7).contains($0) })
      else { throw DataError.invalid }
      try unique(m.times)
      try unique(m.weekdays)
      try text(m.name, required: true, max: 200)
      try text(m.dosage, required: true, max: 500)
      try text(m.instructions)
    }
    for m in s.medications {
      try validatePlan(m.plan)
      try dates(m.createdAt, m.updatedAt)
      guard m.history.count <= 1000 else { throw DataError.tooLarge }
      var last: Date?
      for revision in m.history {
        try validatePlan(revision.plan)
        try dates(revision.until)
        guard revision.from == last, revision.from.map({ $0 <= revision.until }) ?? true else {
          throw DataError.invalid
        }
        if let from = revision.from { try dates(from) }
        last = revision.until
      }
      guard m.effectiveFrom == last else { throw DataError.invalid }
      if let from = m.effectiveFrom { try dates(from) }
    }
    for r in s.doses {
      guard medicationIDs.contains(r.medicationID), r.id.hasPrefix(r.medicationID.uuidString + "/"),
        r.status != .postponed || r.postponedUntil != nil
      else { throw DataError.invalid }
      try dates(r.plannedAt, r.recordedAt)
      if let date = r.postponedUntil { try dates(date) }
      if let snapshot = r.snapshot { try validatePlan(snapshot) }
    }
    var totalBytes = 0
    for a in s.attachments {
      try text(a.name, required: true, max: 300)
      guard a.data.count <= 8 * 1024 * 1024 else { throw DataError.tooLarge }
      totalBytes += a.data.count
    }
    guard totalBytes <= 30 * 1024 * 1024 else { throw DataError.tooLarge }
  }
}

/// Copy-on-write state: disk errors never update the committed state.
public final class StateRepository {
  public private(set) var state: AppState
  public let url: URL
  public init(url: URL) throws {
    self.url = url
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    if FileManager.default.fileExists(atPath: url.path) {
      let original = try Data(contentsOf: url)
      state = try StateCodec.decode(original)
      if let header = try JSONSerialization.jsonObject(with: original) as? [String: Any],
        header["version"] as? Int == 1 || header["schemaVersion"] as? Int == 2
      {
        try original.write(to: backupURL(), options: .atomic)
        try write(state)
      }
    } else {
      state = AppState()
    }
  }
  public func commit(_ next: AppState) throws {
    try write(next)
    state = next
  }
  public func replace(with data: Data) throws {
    let next = try StateCodec.decode(data)
    if FileManager.default.fileExists(atPath: url.path) {
      try Data(contentsOf: url).write(to: backupURL(), options: .atomic)
    }
    try commit(next)
  }
  public func backupURL() -> URL {
    url.deletingLastPathComponent().appendingPathComponent("backup-\(UUID().uuidString).json")
  }
  private func write(_ next: AppState) throws {
    let data = try StateCodec.encode(next)
    #if os(iOS)
      try data.write(
        to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    #else
      try data.write(to: url, options: .atomic)
    #endif
  }
}

private enum WindowsMigration {
  struct Legacy: Decodable {
    struct Visit: Decodable {
      var id: UUID
      var specialist: String
      var date: String
      var reason: String
      var createdAt: String
    }
    struct Event: Decodable {
      var id: UUID
      var visitID: UUID
      var symptom: String
      var timestamp: String
      var note: String
    }
    struct Answer: Decodable {
      var id: String
      var visitID: UUID
      var date: String
      var symptom: String
      var frequency: Frequency
      var note: String
    }
    var version: Int
    var language: Language
    var visit: Visit?
    var events: [Event]
    var answers: [Answer]
  }
  static func timestamp(_ value: String) throws -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: value) { return d }
    f.formatOptions = [.withInternetDateTime]
    guard let d = f.date(from: value) else { throw DataError.invalid }
    return d
  }
  static func convert(_ data: Data) throws -> AppState {
    let old = try JSONDecoder().decode(Legacy.self, from: data)
    var s = AppState()
    s.language = old.language
    guard let v = old.visit else {
      guard old.events.isEmpty && old.answers.isEmpty else { throw DataError.invalid }
      return s
    }
    guard Day.valid(v.date) else { throw DataError.invalid }
    var doctor = Doctor(specialty: v.specialist)
    doctor.id = v.id
    doctor.createdAt = try timestamp(v.createdAt)
    doctor.updatedAt = doctor.createdAt
    var observation = Observation(doctorID: doctor.id, reason: v.reason)
    observation.id = v.id
    observation.createdAt = doctor.createdAt
    observation.updatedAt = doctor.updatedAt
    var visit = Visit(observationID: observation.id, date: Day.date(v.date)!)
    visit.id = v.id
    visit.createdAt = doctor.createdAt
    visit.updatedAt = doctor.updatedAt
    s.doctors = [doctor]
    s.observations = [observation]
    s.visits = [visit]
    s.events = try old.events.map { e in
      guard e.visitID == v.id else { throw DataError.invalid }
      var event = SymptomEvent(symptom: e.symptom)
      event.id = e.id
      event.observationIDs = [observation.id]
      event.timestamp = try timestamp(e.timestamp)
      event.createdAt = event.timestamp
      event.updatedAt = event.timestamp
      event.note = e.note
      return event
    }
    s.checkIns = try old.answers.map { a in
      guard a.visitID == v.id else { throw DataError.invalid }
      var c = DailyCheckIn(
        observationID: observation.id, day: a.date, symptom: a.symptom, frequency: a.frequency)
      c.note = a.note
      return c
    }
    try StateCodec.validate(s)
    return s
  }
}
