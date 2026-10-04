import Charts
import SwiftUI

#if SWIFT_PACKAGE
  import SymptoCore
#endif

extension ActivitySource {
  var color: Color { self == .strava ? Color(hex: 0xFC4C02) : Color(hex: 0xFF2D55) }
  var icon: String { self == .strava ? "figure.run" : "applewatch" }
}
struct SourceBadge: View {
  let source: ActivitySource
  var body: some View {
    Text(source.title).font(.brand(.caption2, .bold)).foregroundStyle(.white)
      .padding(.horizontal, 8).padding(.vertical, 3).background(source.color, in: Capsule())
  }
}

/// Start-screen summary: what the watch and Strava collected, at a glance.
struct HealthSummaryCard: View {
  @EnvironmentObject var store: AppStore
  var body: some View {
    let today = store.state.healthDays.last
    let lastNight = store.state.healthDays.last { $0.sleepMinutes != nil }
    let last = store.state.activities.last
    NavigationLink {
      HealthView()
    } label: {
      VStack(alignment: .leading, spacing: 14) {
        HStack {
          Label(store.t("From your watch & Strava", "Z zegarka i Strava"), systemImage: "applewatch")
            .font(.brand(.headline))
          Spacer()
          if store.syncing { ProgressView().controlSize(.small) }
          Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
        }
        HStack(spacing: 10) {
          metric(store.latestRestingHR.map { "\($0)" } ?? "—", store.t("resting HR", "tętno spocz."), "heart.fill", Theme.heart)
          metric(today?.steps.map { $0.formatted(.number.locale(store.language.locale)) } ?? "—", store.t("steps", "kroki"), "figure.walk", Theme.teal)
          metric(lastNight?.sleepMinutes.map { store.language.duration($0 * 60) } ?? "—", store.t("sleep", "sen"), "moon.zzz.fill", Color(hex: 0x5AA9D6))
        }
        if let last {
          HStack(spacing: 10) {
            Image(systemName: last.source.icon).foregroundStyle(.white).frame(width: 30, height: 30)
              .background(last.source.color, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
              Text(last.name.isEmpty ? store.language.sport(last.sport) : last.name).font(.brand(.subheadline, .bold)).lineLimit(1)
              Text(
                [store.language.date(last.start), store.language.duration(last.durationSeconds),
                 last.distanceMeters.map { store.language.distance($0) }].compactMap { $0 }.joined(separator: " · ")
              ).font(.brand(.caption)).foregroundStyle(Theme.muted)
            }
            Spacer()
            SourceBadge(source: last.source)
          }
        }
      }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: Theme.ink.opacity(0.08), radius: 12, y: 6).foregroundStyle(Theme.ink)
        .contentShape(RoundedRectangle(cornerRadius: 24))
    }.buttonStyle(.plain).accessibilityIdentifier("healthSummary")
  }
  private func metric(_ value: String, _ label: String, _ icon: String, _ color: Color) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
      Text(value).font(.brand(size: 20, .heavy)).lineLimit(1).minimumScaleFactor(0.6)
      Text(label).font(.brand(.caption2, .semibold)).foregroundStyle(Theme.muted)
    }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
      .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
  }
}

/// Shown until something is connected: one tap to the integrations screen.
struct ConnectPromoCard: View {
  @EnvironmentObject var store: AppStore
  var body: some View {
    NavigationLink {
      IntegrationsView()
    } label: {
      HStack(spacing: 14) {
        ZStack {
          Circle().fill(Color(hex: 0xFF2D55)).frame(width: 40, height: 40)
          Image(systemName: "applewatch").foregroundStyle(.white).font(.system(size: 18, weight: .bold))
        }
        VStack(alignment: .leading, spacing: 3) {
          Text(store.t("Connect Apple Watch & Strava", "Połącz Apple Watch i Strava")).font(.brand(.headline))
          Text(
            store.t(
              "Heart rate, sleep, steps and workouts go into your report automatically.",
              "Tętno, sen, kroki i treningi trafią do raportu automatycznie.")
          ).font(.brand(.caption)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
      }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: Theme.ink.opacity(0.07), radius: 10, y: 5).foregroundStyle(Theme.ink)
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }.buttonStyle(.plain).accessibilityIdentifier("connectPromo")
  }
}

/// Trends from Apple Health and the workout list from Strava / Health.
struct HealthView: View {
  @EnvironmentObject var store: AppStore
  @State private var range = 30
  var body: some View {
    SoftScreen {
      VStack(alignment: .leading, spacing: 4) {
        Text(store.t("Body & activity", "Ciało i aktywność")).font(.brand(.largeTitle))
        Text(syncLine).font(.brand(.footnote)).foregroundStyle(Theme.muted)
      }
      HStack(spacing: 8) {
        Pill(title: store.t("7 days", "7 dni"), selected: range == 7) { range = 7 }
        Pill(title: store.t("30 days", "30 dni"), selected: range == 30) { range = 30 }
        Spacer()
        Button {
          Task { await store.autoSync(force: true) }
        } label: {
          Label(store.t("Sync", "Synchronizuj"), systemImage: "arrow.triangle.2.circlepath")
        }.buttonStyle(SecondaryButton()).disabled(store.syncing).accessibilityIdentifier("syncNow")
      }
      chart(store.t("Resting heart rate", "Tętno spoczynkowe"), "/min", \.restingHR, Theme.heart, line: true)
      chart(store.t("Heart rate variability", "Zmienność rytmu (HRV)"), "ms", \.hrv, Color(hex: 0x8E6CEF), line: true)
      chart(store.t("Steps", "Kroki"), "", \.steps, Theme.teal, line: false)
      chart(store.t("Sleep", "Sen"), "h", \.sleepMinutes, Color(hex: 0x5AA9D6), line: false, scale: 1 / 60)
      SectionHeader(title: store.t("Workouts", "Treningi"))
      if activities.isEmpty {
        EmptyCard(
          icon: "figure.run", title: store.t("No workouts", "Brak treningów"),
          message: store.t("Connect Strava or record a workout on Apple Watch.", "Połącz Strava lub zapisz trening na Apple Watch."))
      }
      ForEach(activities) { a in ActivityCard(activity: a) }
      NavigationLink {
        IntegrationsView()
      } label: {
        Label(store.t("Connections", "Integracje"), systemImage: "link")
      }.buttonStyle(SecondaryButton(fill: true))
      Text(
        store.t(
          "Values are shown as recorded by your devices. The app does not interpret them.",
          "Wartości są pokazane tak, jak zapisały je urządzenia. Aplikacja ich nie interpretuje.")
      ).font(.brand(.footnote)).foregroundStyle(Theme.muted)
    }.navigationTitle(store.t("Watch & Strava", "Zegarek i Strava"))
  }
  private var days: [HealthDay] {
    let from = Day.key(Date().addingTimeInterval(-Double(range - 1) * 86400))
    return store.state.healthDays.filter { $0.day >= from }
  }
  private var activities: [Activity] {
    let from = Date().addingTimeInterval(-Double(range) * 86400)
    return store.state.activities.filter { $0.start >= from }.reversed()
  }
  private var syncLine: String {
    let dates = [store.state.integrations.lastHealthSync, store.state.integrations.lastStravaSync].compactMap { $0 }
    guard let last = dates.max() else { return store.t("Not synced yet", "Jeszcze nie zsynchronizowano") }
    return store.t("Updated ", "Zaktualizowano ") + store.language.date(last, time: true)
      + (store.syncStatus.isEmpty ? "" : " · " + store.syncStatus)
  }
  private func number(_ value: Double, decimals: Int) -> String {
    value.formatted(.number.precision(.fractionLength(decimals)).locale(store.language.locale))
  }
  @ViewBuilder private func chart(
    _ title: String, _ unit: String, _ key: KeyPath<HealthDay, Int?>, _ color: Color, line: Bool, scale: Double = 1
  ) -> some View {
    let points = days.compactMap { d in d[keyPath: key].flatMap { v in Day.date(d.day).map { ($0, Double(v) * scale) } } }
    SoftCard {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .firstTextBaseline) {
          Text(title).font(.brand(.headline))
          Spacer()
          if let last = points.last {
            Text(number(last.1, decimals: scale == 1 ? 0 : 1) + (unit.isEmpty ? "" : " " + unit))
              .font(.brand(.title3, .heavy)).foregroundStyle(color)
          }
        }
        if points.isEmpty {
          Text(store.t("No data in this period", "Brak danych w tym okresie")).font(.brand(.subheadline)).foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity, minHeight: 90)
        } else {
          Chart(points, id: \.0) { point in
            if line {
              LineMark(x: .value("Day", point.0, unit: .day), y: .value(title, point.1))
                .interpolationMethod(.catmullRom).foregroundStyle(color).lineStyle(StrokeStyle(lineWidth: 2.5))
              PointMark(x: .value("Day", point.0, unit: .day), y: .value(title, point.1)).foregroundStyle(color).symbolSize(18)
            } else {
              BarMark(x: .value("Day", point.0, unit: .day), y: .value(title, point.1))
                .foregroundStyle(color.gradient).cornerRadius(3)
            }
          }
          .chartYScale(domain: .automatic(includesZero: !line))
          .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) { _ in AxisValueLabel(format: .dateTime.day().month(.abbreviated).locale(store.language.locale)) } }
          .frame(height: 120)
        }
      }
    }
  }
}

struct ActivityCard: View {
  @EnvironmentObject var store: AppStore
  let activity: Activity
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: activity.source.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
        .frame(width: 38, height: 38).background(activity.source.color, in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(activity.name.isEmpty ? store.language.sport(activity.sport) : activity.name).font(.brand(.headline)).lineLimit(1)
          Spacer()
          SourceBadge(source: activity.source)
        }
        Text(store.language.sport(activity.sport) + " · " + store.language.date(activity.start, time: true))
          .font(.brand(.caption)).foregroundStyle(Theme.muted)
        HStack(spacing: 6) {
          TagChip(text: store.language.duration(activity.durationSeconds))
          if let d = activity.distanceMeters { TagChip(text: store.language.distance(d)) }
          if let hr = activity.averageHR { TagChip(text: "♥ \(hr)") }
        }
      }
    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
      .background(.white, in: RoundedRectangle(cornerRadius: 22))
      .shadow(color: Theme.ink.opacity(0.07), radius: 10, y: 5).foregroundStyle(Theme.ink)
  }
}

/// Connect Apple Health and Strava. Secrets go to the Keychain, never into backups.
struct IntegrationsView: View {
  @EnvironmentObject var store: AppStore
  @State private var clientID = ""
  @State private var secret = ""
  @State private var confirmStrava = false
  @State private var confirmHealth = false
  var body: some View {
    SoftScreen {
      Text(store.t("Connections", "Integracje")).font(.brand(.largeTitle))
      Text(
        store.t(
          "Connect once — the app then imports data by itself every time you open it.",
          "Połącz raz — potem aplikacja sama pobiera dane przy każdym otwarciu.")
      ).font(.brand(.subheadline)).foregroundStyle(Theme.muted)
      card(icon: "heart.text.square.fill", color: Color(hex: 0xFF2D55), title: "Apple Health · Apple Watch") {
        Text(
          store.t(
            "Reads resting heart rate, heart rate, HRV, steps, sleep and workouts. Heart rate at the time of each symptom is added automatically. Nothing is written to Health.",
            "Odczytuje tętno spoczynkowe, tętno, HRV, kroki, sen i treningi. Tętno w chwili objawu dodaje się automatycznie. Nic nie jest zapisywane w Zdrowiu.")
        ).font(.brand(.subheadline))
        if store.state.integrations.healthEnabled {
          status(store.t("Connected", "Połączono"), store.state.integrations.lastHealthSync)
          Button(store.t("Disconnect", "Odłącz"), role: .destructive) { confirmHealth = true }.buttonStyle(SecondaryButton())
        } else {
          Button {
            Task { await store.connectHealth() }
          } label: {
            Label(store.t("Connect Apple Health", "Połącz Apple Health"), systemImage: "heart.fill")
          }.buttonStyle(PrimaryButton()).accessibilityIdentifier("connectHealth")
          if !store.health.isAvailable {
            Text(store.t("Available on iPhone (not in the Mac preview).", "Dostępne na iPhonie (nie w podglądzie na Macu)."))
              .font(.brand(.caption)).foregroundStyle(Theme.muted)
          }
        }
      }
      card(icon: "figure.run", color: Color(hex: 0xFC4C02), title: "Strava") {
        if let athlete = store.state.integrations.stravaAthlete {
          status(store.t("Connected: ", "Połączono: ") + athlete, store.state.integrations.lastStravaSync)
          HStack {
            Button(store.t("Sync now", "Synchronizuj")) { Task { await store.autoSync(force: true) } }
              .buttonStyle(SecondaryButton())
            Button(store.t("Disconnect", "Odłącz"), role: .destructive) { confirmStrava = true }.buttonStyle(SecondaryButton())
          }
        } else if let builtIn = StravaService.builtIn {
          Text(
            store.t(
              "Your workouts with time, distance and heart rate will appear in the report automatically.",
              "Treningi z czasem, dystansem i tętnem będą automatycznie trafiać do raportu.")
          ).font(.brand(.subheadline))
          Button {
            Task { await store.connectStrava(builtIn) }
          } label: {
            Label(store.t("Connect Strava", "Połącz Strava"), systemImage: "link")
          }.buttonStyle(PrimaryButton(coral: true)).accessibilityIdentifier("connectStrava")
        } else {
          Text(
            store.t(
              "1. On strava.com/settings/api create an app; set Authorization Callback Domain to \"localhost\".\n2. Paste its Client ID and Client Secret below.\n3. Tap Connect and allow access to activities.",
              "1. Na strava.com/settings/api utwórz aplikację; w polu Authorization Callback Domain wpisz \"localhost\".\n2. Wklej poniżej Client ID i Client Secret.\n3. Stuknij Połącz i zezwól na dostęp do aktywności.")
          ).font(.brand(.subheadline)).fixedSize(horizontal: false, vertical: true)
          TextField("Client ID", text: $clientID).textFieldStyle(.roundedBorder).accessibilityIdentifier("stravaClientID")
          SecureField("Client Secret", text: $secret).textFieldStyle(.roundedBorder).accessibilityIdentifier("stravaSecret")
          Button {
            Task { await store.connectStrava(.init(clientID: clientID, clientSecret: secret)) }
          } label: {
            Label(store.t("Connect Strava", "Połącz Strava"), systemImage: "link")
          }.buttonStyle(PrimaryButton(coral: true))
            .disabled(clientID.trimmingCharacters(in: .whitespaces).isEmpty || secret.trimmingCharacters(in: .whitespaces).isEmpty)
            .accessibilityIdentifier("connectStrava")
        }
        Text(
          store.t(
            "Client Secret and tokens are kept in the Keychain on this device only and are not included in backups.",
            "Client Secret i tokeny są przechowywane tylko w pęku kluczy tego urządzenia i nie trafiają do kopii zapasowych.")
        ).font(.brand(.caption)).foregroundStyle(Theme.muted)
      }
      card(icon: "applewatch.watchface", color: Theme.teal, title: "Apple Watch") {
        Text(
          store.t(
            "Install SymptoPage on your watch: record a symptom with one tap (\"Now!\"), answer today's question and mark your mood. Entries reach the iPhone even if it is closed.",
            "Zainstaluj SymptoPage na zegarku: zapisz objaw jednym dotknięciem („Teraz!”), odpowiedz na pytanie dnia i zaznacz samopoczucie. Wpisy trafią na iPhone'a, nawet gdy aplikacja jest zamknięta.")
        ).font(.brand(.subheadline))
      }
    }.navigationTitle(store.t("Connections", "Integracje"))
      .onAppear {
        clientID = store.strava.credentials?.clientID ?? ""
        secret = store.strava.credentials?.clientSecret ?? ""
      }
      .confirmationDialog(store.t("Disconnect Strava?", "Odłączyć Strava?"), isPresented: $confirmStrava, titleVisibility: .visible) {
        Button(store.t("Disconnect, keep workouts", "Odłącz, zachowaj treningi")) { Task { await store.disconnectStrava(removeActivities: false) } }
        Button(store.t("Disconnect and remove workouts", "Odłącz i usuń treningi"), role: .destructive) {
          Task { await store.disconnectStrava(removeActivities: true) }
        }
      }
      .confirmationDialog(store.t("Disconnect Apple Health?", "Odłączyć Apple Health?"), isPresented: $confirmHealth, titleVisibility: .visible) {
        Button(store.t("Disconnect, keep data", "Odłącz, zachowaj dane")) { store.disconnectHealth(removeData: false) }
        Button(store.t("Disconnect and remove imported data", "Odłącz i usuń zaimportowane dane"), role: .destructive) {
          store.disconnectHealth(removeData: true)
        }
      }
  }
  private func status(_ text: String, _ date: Date?) -> some View {
    Label(
      text + (date.map { " · " + store.language.date($0, time: true) } ?? ""), systemImage: "checkmark.circle.fill"
    ).font(.brand(.subheadline, .bold)).foregroundStyle(Theme.teal)
  }
  private func card<Content: View>(icon: String, color: Color, title: String, @ViewBuilder content: () -> Content) -> some View {
    SoftCard {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          Image(systemName: icon).font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            .frame(width: 42, height: 42).background(color, in: RoundedRectangle(cornerRadius: 13))
          Text(title).font(.brand(.title3, .heavy))
        }
        content()
      }
    }
  }
}
