import AuthenticationServices
import Combine
import Foundation

#if SWIFT_PACKAGE
  import SymptoCore
#endif

@MainActor final class AppStore: ObservableObject {
  @Published private(set) var state = AppState()
  @Published var error: String?
  @Published var selectedDoctors: Set<UUID> = []
  @Published private(set) var ready = false
  @Published var notificationStatus = ""
  let url: URL
  private var repository: StateRepository?
  private let notifications = NotificationService()
  let health = HealthService()
  lazy var strava = StravaService()
  private let watch = PhoneWatchBridge()
  @Published var syncing = false
  @Published var syncStatus = ""
  private var notificationRevision = 0
  var language: Language { state.language }
  func t(_ en: String, _ pl: String) -> String { language.text(en, pl) }
  init(url: URL? = nil) {
    #if os(iOS)
      let folder = "SymptoPage-iOS"
    #else
      let folder = "SymptoPage-iOS-Preview"
    #endif
    var override: URL?
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("--uitesting") {
        override = FileManager.default.temporaryDirectory.appendingPathComponent(
          "SymptoPage-UITests"
        ).appendingPathComponent("records.json")
        if ProcessInfo.processInfo.arguments.contains("--reset-test-data"), let override {
          try? FileManager.default.removeItem(at: override.deletingLastPathComponent())
        }
      }
    #endif
    #if os(macOS)
      if let path = Bundle.main.object(forInfoDictionaryKey: "SymptoPagePreviewDataPath") as? String
      {
        override = URL(fileURLWithPath: path)
      }
    #endif
    self.url =
      url ?? override
      ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(folder).appendingPathComponent("records.json")
    reload()
    watch.onEntry = { [weak self] entry in self?.applyWatchEntry(entry) }
    watch.start()
    publishWatchContext()
  }
  func reload() {
    do {
      let repo = try StateRepository(url: url)
      repository = repo
      state = repo.state
      ready = true
    } catch {
      ready = false
      repository = nil
      show(error)
    }
  }
  func show(_ failure: Error) {
    if failure is DataError || failure is DecodingError {
      error = t(
        "The file or entered values are invalid or unsupported. Existing data was not replaced. Check required fields, dates and file size.",
        "Plik lub wprowadzone wartości są nieprawidłowe albo nieobsługiwane. Istniejące dane nie zostały zastąpione. Sprawdź wymagane pola, daty i rozmiar pliku."
      )
    } else {
      error =
        t(
          "Could not complete the operation. Your changes may not be saved. ",
          "Nie udało się wykonać operacji. Zmiany mogły nie zostać zapisane. ")
        + failure.localizedDescription
    }
  }
  @discardableResult func change(_ mutation: (inout AppState) throws -> Void) -> Bool {
    guard ready, let repository else { return false }
    var next = state
    do {
      try mutation(&next)
      try repository.commit(next)
      state = next
      Task { await refreshNotifications() }
      publishWatchContext()
      return true
    } catch {
      show(error)
      return false
    }
  }
  func refreshNotifications() async {
    notificationRevision += 1
    let revision = notificationRevision
    let language = state.language
    let status = await notifications.reconcile(state)
    guard revision == notificationRevision, language == state.language else { return }
    notificationStatus = status
  }
  /// Removes an observation with its visits, check-ins and medication courses. Symptom events and
  /// notes stay in the journal, only unlinked. The doctor goes too when nothing else refers to it.
  @discardableResult func deleteObservation(_ id: UUID) -> Bool {
    let ok = change { s in
      guard let o = s.observations.first(where: { $0.id == id }) else { return }
      s.observations.removeAll { $0.id == id }
      s.visits.removeAll { $0.observationID == id }
      s.checkIns.removeAll { $0.observationID == id }
      let meds = Set(
        s.medications.filter { m in
          m.plan.observationID == id || m.history.contains { $0.plan.observationID == id }
        }.map(\.id))
      s.medications.removeAll { meds.contains($0.id) }
      s.doses.removeAll { meds.contains($0.medicationID) }
      for i in s.events.indices { s.events[i].observationIDs.removeAll { $0 == id } }
      for i in s.notes.indices { s.notes[i].observationIDs.removeAll { $0 == id } }
      let linked = Set(s.visits.flatMap(\.attachmentIDs))
      s.attachments.removeAll { !linked.contains($0.id) }
      if !s.observations.contains(where: { $0.doctorID == o.doctorID }) {
        s.doctors.removeAll { $0.id == o.doctorID }
      }
    }
    selectedDoctors = selectedDoctors.filter { d in state.doctors.contains { $0.id == d } }
    Task { await refreshNotifications() }
    return ok
  }
  func sendTestNotification() async {
    if !state.remindersEnabled { await enableNotifications() }
    await notifications.test(state.language)
  }
  func enableNotifications() async {
    do {
      let granted = try await notifications.authorize()
      _ = change { $0.remindersEnabled = granted }
      await refreshNotifications()
    } catch { show(error) }
  }
  var observations: [Observation] {
    state.observations.filter {
      !$0.archived && (selectedDoctors.isEmpty || selectedDoctors.contains($0.doctorID))
    }
  }
  var events: [SymptomEvent] {
    state.events.filter { state.matches($0.observationIDs, doctors: selectedDoctors) }.sorted {
      $0.timestamp > $1.timestamp
    }
  }
  func label(_ o: Observation) -> String {
    "\(state.doctor(for: o.id)?.title(language) ?? "—") · \(o.reason)"
  }
  func restore(_ data: Data) -> Bool {
    do {
      let validated = try StateCodec.decode(data)
      if let repository {
        try repository.replace(with: data)
        state = repository.state
      } else {
        // Recovery also preserves the unreadable original before any replacement.
        try FileManager.default.createDirectory(
          at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
          try FileManager.default.copyItem(
            at: url,
            to: url.deletingLastPathComponent().appendingPathComponent(
              "unreadable-\(UUID().uuidString).json"))
        }
        try StateCodec.encode(validated).write(to: url, options: .atomic)
        reload()
        guard ready else { return false }
      }
      selectedDoctors = []
      Task { await refreshNotifications() }
      return true
    } catch {
      show(error)
      return false
    }
  }
  func saveEvent(_ event: SymptomEvent) -> Bool {
    guard event.timestamp <= Date().addingTimeInterval(60) else {
      error = t(
        "Choose an event time that is not in the future.",
        "Wybierz czas zdarzenia, który nie jest w przyszłości.")
      return false
    }
    return change { s in
      var e = event
      e.updatedAt = .now
      s.events.removeAll { $0.id == e.id }
      s.events.append(e)
    }
  }
  func saveCheckIn(_ value: DailyCheckIn, editingID: UUID? = nil) -> Bool {
    let target = state.checkIns.first {
      $0.observationID == value.observationID && $0.day == value.day && $0.symptom == value.symptom
    }
    if let editingID, let target, target.id != editingID {
      error = t(
        "A check-in already exists for that day, symptom and observation. Edit that entry instead.",
        "Istnieje już wpis dla tego dnia, objawu i obserwacji. Edytuj tamten wpis.")
      return false
    }
    return change { s in
      var c = value
      c.id = editingID ?? target?.id ?? UUID()
      c.updatedAt = .now
      s.checkIns.removeAll { $0.id == c.id }
      s.checkIns.append(c)
    }
  }
  var notes: [WellbeingNote] {
    state.notes.filter { state.matches($0.observationIDs, doctors: selectedDoctors) }.sorted {
      $0.date > $1.date
    }
  }
  /// Inserts or replaces a wellbeing note. Empty notes (no text and no mood) are rejected.
  func saveNote(_ note: WellbeingNote) -> Bool {
    var n = note
    n.text = n.text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard n.mood != nil || !n.text.isEmpty else {
      error = t(
        "Choose a mood or write a few words.", "Wybierz samopoczucie lub napisz kilka słów.")
      return false
    }
    guard n.date <= Date().addingTimeInterval(60) else {
      error = t(
        "Choose a time that is not in the future.", "Wybierz czas, który nie jest w przyszłości.")
      return false
    }
    return change { s in
      n.updatedAt = .now
      s.notes.removeAll { $0.id == n.id }
      s.notes.append(n)
    }
  }
  func deleteNote(_ id: UUID) -> Bool { change { $0.notes.removeAll { $0.id == id } } }
  // MARK: Apple Watch, Apple Health, Strava

  func publishWatchContext() {
    guard ready else { return }
    watch.publish(WatchContext.make(from: state))
  }
  /// Entries from the watch are idempotent: a retried delivery does not duplicate.
  func applyWatchEntry(_ entry: WatchEntry) {
    _ = change { entry.apply(to: &$0) }
  }
  var latestRestingHR: Int? {
    let recent = Day.key(Date().addingTimeInterval(-3 * 86400))
    return state.healthDays.last { $0.day >= recent && $0.restingHR != nil }?.restingHR
  }
  func connectHealth() async {
    guard health.isAvailable else {
      error = t(
        "Apple Health is available on iPhone. On Mac the preview cannot read it.",
        "Apple Health jest dostępne na iPhonie. Podgląd na Macu nie może go odczytać.")
      return
    }
    do {
      try await health.requestAccess()
      _ = change { $0.integrations.healthEnabled = true }
      await autoSync(force: true)
    } catch { show(error) }
  }
  func connectStrava(_ credentials: StravaClient.Credentials) async {
    strava.credentials = credentials
    do {
      let athlete = try await strava.connect()
      _ = change { $0.integrations.stravaAthlete = athlete ?? "Strava" }
      await autoSync(force: true)
    } catch { showStrava(error) }
  }
  func disconnectStrava(removeActivities: Bool) async {
    await strava.disconnect()
    _ = change { s in
      s.integrations.stravaAthlete = nil
      s.integrations.lastStravaSync = nil
      if removeActivities { s.activities.removeAll { $0.source == .strava } }
    }
  }
  func disconnectHealth(removeData: Bool) {
    _ = change { s in
      s.integrations.healthEnabled = false
      s.integrations.lastHealthSync = nil
      if removeData {
        s.healthDays = []
        s.activities.removeAll { $0.source == .health }
      }
    }
  }
  /// Imports automatically (on launch and when the app becomes active) at most once an hour,
  /// so a lazy user never has to press anything.
  func autoSync(force: Bool = false) async {
    guard ready, !syncing else { return }
    let hourAgo = Date().addingTimeInterval(-3600)
    let healthDue = state.integrations.healthEnabled && health.isAvailable
      && (force || (state.integrations.lastHealthSync ?? .distantPast) < hourAgo)
    let stravaDue = state.integrations.stravaAthlete != nil
      && (force || (state.integrations.lastStravaSync ?? .distantPast) < hourAgo)
    guard healthDue || stravaDue else { return }
    syncing = true
    defer { syncing = false }
    var messages: [String] = []
    if healthDue {
      do {
        let days = state.integrations.lastHealthSync == nil ? 90 : 30
        let since = Date().addingTimeInterval(-Double(days) * 86400)
        let times = state.events.filter { $0.heartRate == nil && $0.timestamp > since }.map(\.timestamp)
        let result = try await health.importData(days: days, eventTimes: times)
        _ = change { s in
          HealthMerge.apply(days: result.days, activities: result.activities, to: &s)
          HealthMerge.attachHeartRates(result.heartRates, to: &s)
          s.integrations.lastHealthSync = .now
        }
        messages.append("Apple Health ✓")
      } catch { messages.append("Apple Health: " + error.localizedDescription) }
    }
    if stravaDue {
      do {
        let after = (state.integrations.lastStravaSync?.addingTimeInterval(-2 * 86400))
          ?? Date().addingTimeInterval(-90 * 86400)
        let activities = try await strava.activities(after: after)
        _ = change { s in
          HealthMerge.apply(days: [], activities: activities, to: &s)
          s.integrations.lastStravaSync = .now
        }
        messages.append("Strava ✓ \(activities.count)")
      } catch {
        messages.append("Strava: " + stravaMessage(error))
      }
    }
    syncStatus = messages.joined(separator: " · ")
  }
  private func stravaMessage(_ failure: Error) -> String {
    switch failure as? StravaError {
    case .notConfigured: return t("enter Client ID and Secret", "wpisz Client ID i Secret")
    case .denied: return t("access denied — connect again", "brak dostępu — połącz ponownie")
    case .rateLimited: return t("limit reached, try later", "limit zapytań, spróbuj później")
    case .http(let code): return "HTTP \(code)"
    default: return failure.localizedDescription
    }
  }
  private func showStrava(_ failure: Error) {
    if (failure as? ASWebAuthenticationSessionError)?.code == .canceledLogin { return }
    error = "Strava: " + stravaMessage(failure)
  }

  func mark(_ dose: ScheduledDose, status: DoseStatus) {
    _ = change { s in
      var record = DoseRecord(
        id: dose.id, medicationID: dose.medicationID, plannedAt: dose.date, status: status)
      if let existing = s.doses.first(where: { $0.id == dose.id }) {
        record.plannedAt = existing.plannedAt
        record.snapshot = existing.snapshot
      }
      if record.snapshot == nil,
        let medication = s.medications.first(where: { $0.id == dose.medicationID })
      {
        record.snapshot = medication.plan(at: record.plannedAt)
      }
      if status == .postponed { record.postponedUntil = Date().addingTimeInterval(15 * 60) }
      s.doses.removeAll { $0.id == dose.id }
      s.doses.append(record)
    }
  }
}
