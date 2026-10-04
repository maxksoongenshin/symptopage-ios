import Combine
import Foundation

#if os(watchOS)
  import HealthKit
  import WatchConnectivity
  import WatchKit
#endif

/// Watch-side state: the context sent by the iPhone, and delivery of quick entries.
/// `transferUserInfo` is queued by the system and delivered even if the iPhone app is closed.
@MainActor final class WatchStore: NSObject, ObservableObject {
  @Published private(set) var context: WatchContext?
  @Published private(set) var heartRate: Int?
  @Published private(set) var lastSaved: WatchEntry?
  @Published private(set) var savedToday = 0
  private let defaults: UserDefaults
  #if os(watchOS)
    private let health = HKHealthStore()
  #endif

  init(defaults: UserDefaults = .standard, preview: WatchContext? = nil) {
    self.defaults = defaults
    super.init()
    context = preview ?? defaults.data(forKey: "context").flatMap { try? JSONDecoder().decode(WatchContext.self, from: $0) }
    #if os(watchOS)
      if preview == nil, WCSession.isSupported() {
        WCSession.default.delegate = self
        WCSession.default.activate()
      }
    #endif
  }

  var language: Language { context?.language ?? (Locale.current.language.languageCode?.identifier == "pl" ? .pl : .en) }
  func t(_ en: String, _ pl: String) -> String { language.text(en, pl) }

  func label(_ symptom: String) -> String { language.symptom(symptom) }

  func recordSymptom(_ symptom: String, intensity: Int?) {
    var entry = WatchEntry(kind: .symptom)
    entry.symptom = symptom
    entry.intensity = intensity
    entry.heartRate = heartRate
    entry.observationID = context?.observations.first { $0.symptom == symptom }?.id ?? context?.observations.first?.id
    send(entry)
  }
  func answer(_ item: WatchContext.Item, _ frequency: Frequency) {
    var entry = WatchEntry(kind: .answer)
    entry.observationID = item.id
    entry.symptom = item.symptom
    entry.frequency = frequency
    send(entry)
    // Optimistic: show the answer immediately; the phone confirms with the next context.
    if var c = context, let index = c.observations.firstIndex(where: { $0.id == item.id }) {
      c.observations[index].answer = frequency
      context = c
    }
  }
  func mood(_ mood: Mood) {
    var entry = WatchEntry(kind: .mood)
    entry.mood = mood
    send(entry)
  }

  private func send(_ entry: WatchEntry) {
    lastSaved = entry
    savedToday += 1
    #if os(watchOS)
      WKInterfaceDevice.current().play(.success)
      if let data = try? entry.encoded(), WCSession.isSupported() {
        WCSession.default.transferUserInfo(["entry": data])
      }
    #endif
  }

  /// Most recent heart rate from the last 10 minutes, attached to the next symptom entry.
  func refreshHeartRate() async {
    #if os(watchOS)
      guard HKHealthStore.isHealthDataAvailable() else { return }
      let type = HKQuantityType(.heartRate)
      try? await health.requestAuthorization(toShare: [], read: [type])
      let query = HKSampleQueryDescriptor(
        predicates: [.quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-600), end: nil))],
        sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)], limit: 1)
      if let sample = try? await query.result(for: health).first {
        heartRate = Int(sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())).rounded())
      }
    #endif
  }

  fileprivate func receive(_ data: Data) {
    guard let c = try? JSONDecoder().decode(WatchContext.self, from: data) else { return }
    context = c
    defaults.set(data, forKey: "context")
  }
  /// For previews and the render check.
  func setPreviewHeartRate(_ value: Int?) { heartRate = value }
}

#if os(watchOS)
  extension WatchStore: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
      if let data = session.receivedApplicationContext["context"] as? Data {
        Task { @MainActor in self.receive(data) }
      }
    }
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
      if let data = applicationContext["context"] as? Data {
        Task { @MainActor in self.receive(data) }
      }
    }
  }
#endif
