import SwiftUI

#if os(watchOS)
  @main struct SymptoPageWatchApp: App {
    @StateObject private var store: WatchStore
    init() {
      WFont.register()
      _store = StateObject(wrappedValue: WatchStore())
    }
    var body: some Scene {
      WindowGroup {
        WatchRootView().environmentObject(store).tint(WTheme.mint)
      }
    }
  }
#endif
