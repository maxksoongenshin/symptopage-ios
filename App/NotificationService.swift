import Foundation
import UserNotifications

#if SWIFT_PACKAGE
  import SymptoCore
#endif

@MainActor final class NotificationService {
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
