import Foundation

public enum Day {
  public static func key(_ date: Date, calendar: Calendar = .current) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = calendar.timeZone
    let c = cal.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
  }
  public static func date(_ key: String, calendar: Calendar = .current) -> Date? {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.calendar = Calendar(identifier: .gregorian)
    f.timeZone = calendar.timeZone
    f.dateFormat = "yyyy-MM-dd"
    f.isLenient = false
    guard let d = f.date(from: key), f.string(from: d) == key else { return nil }
    return d
  }
  public static func valid(_ key: String) -> Bool { date(key) != nil }
}
public struct ScheduledDose: Identifiable, Equatable, Sendable {
  public var id: String
  public var medicationID: UUID
  public var date: Date
  public init(id: String, medicationID: UUID, date: Date) {
    self.id = id
    self.medicationID = medicationID
    self.date = date
  }
}
public enum DosePlanner {
  public static func displayedDoses(
    _ state: AppState, medications: [Medication], on day: Date, calendar: Calendar = .current
  ) -> [ScheduledDose] {
    var result = medications.flatMap { doses($0, on: day, calendar: calendar) }
    let ids = Set(result.map(\.id))
    let medicationIDs = Set(medications.map(\.id))
    result += state.doses.filter { record in
      medicationIDs.contains(record.medicationID) && !ids.contains(record.id)
        && (calendar.isDate(record.plannedAt, inSameDayAs: day)
          || (record.status == .postponed
            && record.postponedUntil.map { calendar.isDate($0, inSameDayAs: day) } == true))
    }.map { ScheduledDose(id: $0.id, medicationID: $0.medicationID, date: $0.plannedAt) }
    return result.sorted { $0.date < $1.date }
  }
  /// Local wall-clock schedule. On DST gaps use next valid time; repeated hours fire once.
  public static func doses(_ m: Medication, on day: Date, calendar: Calendar = .current)
    -> [ScheduledDose]
  {
    var result: [ScheduledDose] = []
    for revision in m.history {
      result += doses(m.id, plan: revision.plan, on: day, calendar: calendar).filter { dose in
        (revision.from.map { dose.date >= $0 } ?? true) && dose.date < revision.until
      }
    }
    result += doses(m.id, plan: m.plan, on: day, calendar: calendar).filter { dose in
      m.effectiveFrom.map { dose.date >= $0 } ?? true
    }
    return result.sorted { $0.date < $1.date }
  }
  private static func doses(
    _ medicationID: UUID, plan m: MedicationPlan, on day: Date, calendar: Calendar
  ) -> [ScheduledDose] {
    let key = Day.key(day, calendar: calendar)
    guard m.active, key >= m.startDay, m.endDay.map({ key <= $0 }) ?? true,
      m.weekdays.contains(calendar.component(.weekday, from: day))
    else { return [] }
    let start = calendar.startOfDay(for: day)
    return m.times.compactMap { time in
      guard
        let date = calendar.date(
          bySettingHour: time.hour, minute: time.minute, second: 0, of: start,
          matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward),
        calendar.isDate(date, inSameDayAs: day)
      else { return nil }
      return ScheduledDose(
        id: "\(medicationID.uuidString)/\(key)/\(time.label)", medicationID: medicationID,
        date: date)
    }.sorted { $0.date < $1.date }
  }
  public static func upcoming(
    _ state: AppState, now: Date = .now, days: Int = 30, limit: Int = 48,
    calendar: Calendar = .current
  ) -> [ScheduledDose] {
    var result: [ScheduledDose] = []
    let records = Dictionary(uniqueKeysWithValues: state.doses.map { ($0.id, $0) })
    for offset in 0..<max(0, days) {
      guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
      for m in state.medications {
        for dose in doses(m, on: day, calendar: calendar)
        where dose.date > now && records[dose.id] == nil { result.append(dose) }
      }
    }
    for r in state.doses where r.status == .postponed {
      guard let date = r.postponedUntil, date > now,
        let m = state.medications.first(where: { $0.id == r.medicationID }), m.active
      else { continue }
      result.append(ScheduledDose(id: r.id, medicationID: r.medicationID, date: date))
    }
    return Array(
      result.sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }.prefix(max(0, limit))
    )
  }
}
