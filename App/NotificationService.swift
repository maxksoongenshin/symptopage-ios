import Foundation
import UserNotifications

#if SWIFT_PACKAGE
  import SymptoCore
#endif

@MainActor final class NotificationService {
  #if os(iOS)
    /// Shows banners while the app is open too (otherwise iOS hides them in the foreground).
    final class Presenter: NSObject, UNUserNotificationCenterDelegate {
      func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void
      ) { done([.banner, .list, .sound]) }
    }
    private let presenter = Presenter()
    init() { UNUserNotificationCenter.current().delegate = presenter }
  #endif
  func test(_ l: Language) async {
    #if os(iOS)
      let content = UNMutableNotificationContent()
      content.title = "SymptoPage"
      content.body = l.text(
        "How are you feeling? Tap \"Now!\" if a symptom appears.",
        "Jak się czujesz? Stuknij „Teraz!”, jeśli pojawi się objaw.")
      content.sound = .default
      try? await UNUserNotificationCenter.current().add(
        UNNotificationRequest(
          identifier: "symptopage.test." + UUID().uuidString, content: content,
          trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    #endif
  }
  private var pendingTask: Task<String, Never>?
  func authorize() async throws -> Bool {
    #if os(iOS)
      return try await UNUserNotificationCenter.current().requestAuthorization(options: [
        .alert, .sound,
      ])
    #else
      return false
    #endif
  }
  func reconcile(_ s: AppState) async -> String {
    let previous = pendingTask
    let task = Task { @MainActor in
      if let previous { _ = await previous.value }
      return await self.apply(s)
    }
    pendingTask = task
    return await task.value
  }
  private func apply(_ s: AppState) async -> String {
    let l = s.language
    #if os(iOS)
      let center = UNUserNotificationCenter.current()
      let settings = await center.notificationSettings()
      let pending = await center.pendingNotificationRequests()
      let existing = pending.filter { $0.identifier.hasPrefix("symptopage.") }
      guard s.remindersEnabled,
        settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
      else {
        center.removePendingNotificationRequests(withIdentifiers: existing.map(\.identifier))
        return l.text(
          "Reminders are off. Enable notifications in Settings.",
          "Przypomnienia są wyłączone. Włącz powiadomienia w Ustawieniach.")
      }
      let doses = DosePlanner.upcoming(s)
      let visits = s.visits.filter { visit in
        !visit.completed && visit.date.addingTimeInterval(-86400) > Date()
          && s.observations.contains(where: { $0.id == visit.observationID && !$0.archived })
      }.sorted { $0.date < $1.date }.prefix(8)
      var requests: [UNNotificationRequest] = []
      func request(id: String, date: Date, visit: Bool) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "SymptoPage"
        content.body =
          visit
          ? l.text(
            "An appointment is coming up. Open your plan.", "Zbliża się wizyta. Otwórz swój plan.")
          : l.text(
            "You have a scheduled reminder. Open your plan.",
            "Masz zaplanowane przypomnienie. Otwórz swój plan.")
        content.sound = .default
        var components = Calendar.current.dateComponents(
          [.year, .month, .day, .hour, .minute, .second], from: date)
        components.timeZone = Calendar.current.timeZone
        return UNNotificationRequest(
          identifier: "symptopage." + id, content: content,
          trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
      }
      for d in doses { requests.append(request(id: d.id, date: d.date, visit: false)) }
      // Morning of the visit, 8:00.
      for v in visits {
        let morning = Calendar.current.date(
          bySettingHour: 8, minute: 0, second: 0, of: v.date) ?? v.date
        if morning > Date() && morning < v.date {
          let content = UNMutableNotificationContent()
          content.title = "SymptoPage"
          content.body = l.text(
            "Visit today. Your report is ready in the Report tab.",
            "Wizyta dzisiaj. Raport czeka w zakładce Raport.")
          content.sound = .default
          var c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: morning)
          c.timeZone = Calendar.current.timeZone
          requests.append(
            UNNotificationRequest(
              identifier: "symptopage.visitday." + v.id.uuidString, content: content,
              trigger: UNCalendarNotificationTrigger(dateMatching: c, repeats: false)))
        }
      }
      // Daily question at 20:00 while any observation is active.
      if s.observations.contains(where: { !$0.archived && $0.stage != .completed }) {
        let content = UNMutableNotificationContent()
        content.title = "SymptoPage"
        content.body = l.text(
          "Daily question: did your symptoms appear today?",
          "Pytanie dnia: czy objawy pojawiły się dzisiaj?")
        content.sound = .default
        requests.append(
          UNNotificationRequest(
            identifier: "symptopage.daily", content: content,
            trigger: UNCalendarNotificationTrigger(
              dateMatching: DateComponents(hour: 20, minute: 0), repeats: true)))
      }
      for v in visits {
        requests.append(
          request(
            id: "visit." + v.id.uuidString, date: v.date.addingTimeInterval(-86400), visit: true))
      }
      let wanted = Set(requests.map(\.identifier))
      center.removePendingNotificationRequests(
        withIdentifiers: existing.map(\.identifier).filter { !wanted.contains($0) })
      do {
        for r in requests {
          try await center.add(r)
        }
        let horizon = doses.last.map { l.date($0.date, time: true) } ?? "—"
        return l.text(
          "Medication reminders scheduled through: ", "Przypomnienia o lekach zaplanowane do: ")
          + horizon + ". "
          + l.text(
            "Open the app regularly to extend the schedule. Up to 48 medication reminders and 8 visits are queued.",
            "Otwieraj aplikację regularnie, aby przedłużać harmonogram. Kolejka obejmuje do 48 przypomnień o lekach i 8 wizyt."
          )
      } catch {
        return l.text(
          "Some reminders could not be scheduled. Open the app and try again.",
          "Nie udało się zaplanować części przypomnień. Otwórz aplikację i spróbuj ponownie.")
      }
    #else
      return l.text(
        "Notifications must be tested on iPhone.", "Powiadomienia wymagają testu na iPhonie.")
    #endif
  }
}
