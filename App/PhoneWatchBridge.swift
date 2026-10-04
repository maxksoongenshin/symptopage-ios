import Foundation

#if SWIFT_PACKAGE
  import SymptoCore
#endif

#if os(iOS)
  import WatchConnectivity

  /// iPhone side of Apple Watch sync. Receives quick entries (queued `transferUserInfo`,
  /// delivered even when the phone app was closed) and publishes the current context.
  final class PhoneWatchBridge: NSObject, WCSessionDelegate {
    var onEntry: ((WatchEntry) -> Void)?
    private var pendingContext: WatchContext?

    func start() {
      guard WCSession.isSupported() else { return }
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
    func publish(_ context: WatchContext) {
      guard WCSession.isSupported() else { return }
      let session = WCSession.default
      guard session.activationState == .activated else {
        pendingContext = context
        return
      }
      guard session.isPaired, session.isWatchAppInstalled,
        let data = try? JSONEncoder().encode(context)
      else { return }
      try? session.updateApplicationContext(["context": data])
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
      if state == .activated, let context = pendingContext {
        pendingContext = nil
        DispatchQueue.main.async { self.publish(context) }
      }
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
      guard let data = userInfo["entry"] as? Data, let entry = try? WatchEntry.decode(data) else { return }
      DispatchQueue.main.async { self.onEntry?(entry) }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
  }
#else
  /// macOS preview has no Apple Watch pairing.
  final class PhoneWatchBridge {
    var onEntry: ((WatchEntry) -> Void)?
    func start() {}
    func publish(_ context: WatchContext) {}
  }
#endif
