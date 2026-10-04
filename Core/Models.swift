import Foundation

public enum Language: String, Codable, CaseIterable, Sendable {
  case en, pl
  public var name: String { self == .en ? "English" : "Polski" }
  public var locale: Locale { Locale(identifier: self == .en ? "en_GB" : "pl_PL") }
  public func text(_ en: String, _ pl: String) -> String { self == .en ? en : pl }
  public func date(_ date: Date, time: Bool = false) -> String {
    let f = DateFormatter()
    f.locale = locale
    f.dateStyle = .medium
    f.timeStyle = time ? .short : .none
    return f.string(from: date)
  }
  public func symptom(_ value: String) -> String {
    Catalog.symptom(value).map { text($0.en, $0.pl) } ?? value
  }
  public func specialty(_ value: String) -> String {
    Catalog.specialty(value).map { text($0.en, $0.pl) } ?? value
  }
  public func tag(_ value: String) -> String {
    Catalog.noteTags.first { $0.key == value }.map { text($0.en, $0.pl) } ?? value
  }
}
public enum Stage: String, Codable, CaseIterable, Sendable {
  case waiting, visited, treatment, review, completed
  public func title(_ l: Language) -> String {
    switch self {
    case .waiting: return l.text("Waiting for a visit", "Oczekiwanie na wizytę")
    case .visited: return l.text("Visit completed", "Po wizycie")
    case .treatment: return l.text("Following the plan", "Realizacja zaleceń")
    case .review: return l.text("Review progress", "Ocena samopoczucia")
    case .completed: return l.text("Observation completed", "Obserwacja zakończona")
    }
  }
}
public enum Frequency: String, Codable, CaseIterable, Sendable {
  case none, once, several
  public func title(_ l: Language) -> String {
    self == .none
      ? l.text("None", "Nie") : self == .once ? l.text("Once", "Raz") : l.text("Several", "Kilka")
  }
}
public enum Wellbeing: String, Codable, CaseIterable, Sendable {
  case better, same, worse
  public func title(_ l: Language) -> String {
    self == .better
      ? l.text("Better", "Lepiej")
      : self == .same ? l.text("Unchanged", "Bez zmian") : l.text("Worse", "Gorzej")
  }
}
public struct Doctor: Codable, Identifiable, Equatable, Sendable {
  public var id = UUID()
  public var specialty: String
  public var name = ""
  public var clinic = ""
  public var archived = false
  public var createdAt = Date()
  public var updatedAt = Date()
  public init(specialty: String) { self.specialty = specialty }
  public func title(_ l: Language) -> String {
    name.isEmpty ? l.specialty(specialty) : "\(name) · \(l.specialty(specialty))"
  }
}
public struct Observation: Codable, Identifiable, Equatable, Sendable {
  public var id = UUID()
  public var doctorID: UUID
  public var reason: String
  /// Symptom asked about in the daily question. Optional for backward compatibility.
  public var symptom: String?
  public var stage: Stage = .waiting
  public var archived = false
  public var createdAt = Date()
  public var updatedAt = Date()
  public init(doctorID: UUID, reason: String) {
    self.doctorID = doctorID
    self.reason = reason
  }
}
public struct Visit: Codable, Identifiable, Equatable, Sendable {
  public var id = UUID()
  public var observationID: UUID
  public var date: Date
  public var completed = false
  public var notes = ""
  public var instructions = ""
  public var tests = ""
  public var questions = ""
  public var returnAdvice = ""
  public var attachmentIDs: [UUID] = []
  public var createdAt = Date()
  public var updatedAt = Date()
  public init(observationID: UUID, date: Date) {
    self.observationID = observationID
    self.date = date
  }
}
public struct SymptomEvent: Codable, Identifiable, Equatable, Sendable {
  public var id = UUID()
  public var observationIDs: [UUID] = []
  public var symptom: String
  public var timestamp = Date()
  public var intensity: Int?
  public var durationMinutes: Int?
  public var context = ""
  public var note = ""
  /// Heart rate at the time of the event (Apple Watch / Apple Health), beats per minute.
  public var heartRate: Int?
  /// "watch" when recorded on Apple Watch; nil for iPhone entries.
  public var source: String?
  public var createdAt = Date()
  public var updatedAt = Date()
  public init(symptom: String) { self.symptom = symptom }
}
public struct DailyCheckIn: Codable, Identifiable, Equatable, Sendable {
  public var id = UUID()
  public var observationID: UUID?
  public var day: String
  public var timeZoneID: String
  public var symptom: String
  public var frequency: Frequency
  public var wellbeing: Wellbeing?
  public var note = ""
  public var updatedAt = Date()
  public init(
    observationID: UUID?, day: String, symptom: String, frequency: Frequency,
    timeZoneID: String = TimeZone.current.identifier
  ) {
    self.observationID = observationID
    self.day = day
    self.symptom = symptom
    self.frequency = frequency
    self.timeZoneID = timeZoneID
  }
}
public struct DoseTime: Codable, Hashable, Sendable {
  public var hour: Int
  public var minute: Int
  public init(hour: Int, minute: Int) {
    self.hour = hour
    self.minute = minute
  }
  public var label: String { String(format: "%02d:%02d", hour, minute) }
}
public struct Medication: Codable, Identifiable, Equatable, Sendable {
  public var history: [MedicationRevision] = []
  public var effectiveFrom: Date?
  public var id = UUID()
  public var observationID: UUID?
  public var name: String
  public var dosage: String
  public var instructions = ""
  public var startDay: String
  public var endDay: String?
  public var times: [DoseTime]
  public var weekdays = [1, 2, 3, 4, 5, 6, 7]
  public var active = true
  public var createdAt = Date()
  public var updatedAt = Date()
  public init(name: String, dosage: String, startDay: String, times: [DoseTime]) {
    self.name = name
    self.dosage = dosage
    self.startDay = startDay
    self.times = times
  }
}
public enum DoseStatus: String, Codable, CaseIterable, Sendable {
  case taken, skipped, postponed
  public func title(_ l: Language) -> String {
    self == .taken
      ? l.text("Taken", "Przyjęto")
      : self == .skipped ? l.text("Skipped", "Pominięto") : l.text("Postponed", "Odłożono")
  }
}
public struct DoseRecord: Codable, Identifiable, Equatable, Sendable {
  public var snapshot: MedicationPlan?
  public var id: String
  public var medicationID: UUID
  public var plannedAt: Date
  public var status: DoseStatus
  public var recordedAt = Date()
  public var postponedUntil: Date?
  public init(id: String, medicationID: UUID, plannedAt: Date, status: DoseStatus) {
    self.id = id
    self.medicationID = medicationID
    self.plannedAt = plannedAt
    self.status = status
  }
}
public struct Attachment: Codable, Identifiable, Equatable, Sendable {
  public var id = UUID()
  public var name: String
  public var data: Data
  public init(name: String, data: Data) {
    self.name = name
    self.data = data
  }
}
public struct AppState: Codable, Equatable, Sendable {
  public var schemaVersion = 3
  public var language: Language = .en
  public var remindersEnabled = false
  /// Optional first name for the greeting. Stored only on this device.
  public var profileName: String?
  public var doctors: [Doctor] = []
  public var observations: [Observation] = []
  public var visits: [Visit] = []
  public var events: [SymptomEvent] = []
  public var checkIns: [DailyCheckIn] = []
  public var medications: [Medication] = []
  public var doses: [DoseRecord] = []
  public var attachments: [Attachment] = []
  /// Added in 0.7.0. Older files have no key; StateCodec.decode fills it with [].
  public var notes: [WellbeingNote] = []
  /// Added in 0.8.0; filled with defaults when missing in older files.
  public var healthDays: [HealthDay] = []
  public var activities: [Activity] = []
  public var integrations = Integrations()
  public init() {}
  public func matches(_ ids: [UUID], doctors selected: Set<UUID>) -> Bool {
    selected.isEmpty
      || observations.contains { ids.contains($0.id) && selected.contains($0.doctorID) }
  }
  public func doctor(for observationID: UUID) -> Doctor? {
    guard let o = observations.first(where: { $0.id == observationID }) else { return nil }
    return doctors.first { $0.id == o.doctorID }
  }
}
