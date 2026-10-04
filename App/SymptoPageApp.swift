import SwiftUI

@main struct SymptoPageApp: App {
  @StateObject private var store: AppStore
  init() {
    BrandFonts.register()
    _store = StateObject(wrappedValue: AppStore())
  }
  @Environment(\.scenePhase) private var phase
  var body: some Scene {
    WindowGroup {
      RootView().environmentObject(store).environment(\.locale, store.language.locale).tint(
        Theme.teal
      ).font(.brand(.body)).preferredColorScheme(.light)
        .task {
          await store.refreshNotifications()
          await store.autoSync()
        }
        .onChange(of: phase) { _, value in
          if value == .active {
            Task {
              await store.refreshNotifications()
              await store.autoSync()
            }
          }
        }
        #if os(macOS)
          .frame(minWidth: 420, idealWidth: 480, minHeight: 740, idealHeight: 860)
        #endif
    }
    #if os(macOS)
      .defaultSize(width: 480, height: 860)
    #endif
  }
}
struct RootView: View {
  @EnvironmentObject var store: AppStore
  @State private var selectedTab = 0
  /// The welcome screen opens whenever there is no data yet; it is not persisted.
  @State private var welcomed = false
  var body: some View {
    Group {
      if store.ready && store.state.observations.isEmpty && !welcomed {
        WelcomeView { welcomed = true }
      } else if store.ready {
        #if os(macOS)
          VStack(spacing: 0) {
            NavigationStack {
              switch selectedTab {
              case 1: ReportView()
              case 2: SettingsView()
              default: TodayView()
              }
            }
            HStack(spacing: 4) {
              previewTab(0, store.t("Start", "Start"), "house.fill")
              previewTab(1, store.t("Report", "Raport"), "doc.text")
              previewTab(2, store.t("Settings", "Ustawienia"), "gearshape")
            }.padding(.horizontal, 24).padding(.top, 8).padding(.bottom, 12)
              .background(.white, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
              .shadow(color: Theme.ink.opacity(0.06), radius: 10, y: -4)
          }
        #else
          TabView {
            NavigationStack { TodayView() }.tabItem {
              Label(store.t("Start", "Start"), systemImage: "house.fill")
            }
            NavigationStack { ReportView() }.tabItem {
              Label(store.t("Report", "Raport"), systemImage: "doc.text")
            }
            NavigationStack { SettingsView() }.tabItem {
              Label(store.t("Settings", "Ustawienia"), systemImage: "gearshape")
            }
          }
        #endif
      } else {
        NavigationStack { SettingsView(recovery: true) }
      }
    }.alert(
      store.t("Please check", "Sprawdź"),
      isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
    ) {
      Button("OK") { store.error = nil }
    } message: {
      Text(store.error ?? "")
    }
  }
  #if os(macOS)
    private func previewTab(_ index: Int, _ title: String, _ icon: String) -> some View {
      Button {
        selectedTab = index
      } label: {
        VStack(spacing: 4) {
          Capsule().fill(selectedTab == index ? Theme.teal : .clear).frame(width: 40, height: 3)
          Image(systemName: icon).font(.system(size: 22, weight: .semibold))
          Text(title).font(.brand(.caption, .semibold))
        }.frame(maxWidth: .infinity).padding(.vertical, 2).foregroundStyle(
          selectedTab == index ? Theme.teal : Theme.muted
        ).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityAddTraits(selectedTab == index ? .isSelected : [])
    }
  #endif
}

#if DEBUG
  struct SymptoPageCanvas: PreviewProvider {
    @MainActor static var previews: some View {
      let _ = BrandFonts.register()
      let store = AppStore(
        url: FileManager.default.temporaryDirectory.appendingPathComponent(
          "SymptoPage-Canvas-\(UUID().uuidString)/records.json"))
      RootView().environmentObject(store).environment(\.locale, store.language.locale).tint(
        Theme.teal
      ).font(.brand(.body)).preferredColorScheme(.light)
        .previewLayout(.fixed(width: 390, height: 844)).previewDisplayName(
          "SymptoPage · iPhone layout")
    }
  }
#endif
