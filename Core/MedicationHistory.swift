import Foundation

/// A prescription as entered by the user, without computed clinical interpretation.
public struct MedicationPlan: Codable, Equatable, Sendable {
  public var observationID: UUID?
  public var name: String
  public var dosage: String
  public var instructions: String
  public var startDay: String
  public var endDay: String?
  public var times: [DoseTime]
  public var weekdays: [Int]
  public var active: Bool
}
public struct MedicationRevision: Codable, Equatable, Sendable {
  public var plan: MedicationPlan
  public var from: Date?
  public var until: Date
}
extension Medication {
  public var plan: MedicationPlan {
    MedicationPlan(
      observationID: observationID, name: name, dosage: dosage,
      instructions: instructions, startDay: startDay, endDay: endDay, times: times,
      weekdays: weekdays, active: active)
  }
  public func plan(at date: Date) -> MedicationPlan {
    history.first { ($0.from.map { date >= $0 } ?? true) && date < $0.until }?.plan ?? plan
  }
}
public enum MedicationHistory {
  /// Changes take effect at save time. Existing scheduled times before that instant retain their plan.
  public static func save(_ draft: Medication, in state: inout AppState, now: Date = .now) throws {
    var next = draft
    if let old = state.medications.first(where: { $0.id == draft.id }) {
      guard old.effectiveFrom.map({ now >= $0 }) ?? true else { throw DataError.invalid }
      next.createdAt = old.createdAt
      next.history = old.history
      next.effectiveFrom = old.effectiveFrom
      if old.plan != draft.plan {
        next.history.append(MedicationRevision(plan: old.plan, from: old.effectiveFrom, until: now))
        next.effectiveFrom = now
        // Also retain details for early confirmations whose planned time is after the edit.
        for index in state.doses.indices
        where state.doses[index].medicationID == old.id && state.doses[index].snapshot == nil {
          state.doses[index].snapshot = old.plan(at: state.doses[index].plannedAt)
        }
      }
    } else {
      next.history = []
      next.effectiveFrom = nil
    }
    next.updatedAt = now
    state.medications.removeAll { $0.id == next.id }
    state.medications.append(next)
  }
}
