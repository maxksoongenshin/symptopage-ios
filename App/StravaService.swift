import AuthenticationServices
import Foundation
import Security

#if SWIFT_PACKAGE
  import SymptoCore
#endif

/// Generic-password Keychain storage for Strava credentials and tokens.
enum Keychain {
  static let service = "app.symptopage.strava"
  static func set(_ data: Data?, for account: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(query as CFDictionary)
    guard let data else { return }
    var add = query
    add[kSecValueData as String] = data
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    SecItemAdd(add as CFDictionary, nil)
  }
  static func get(_ account: String) -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
      kSecAttrAccount as String: account, kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    return SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess ? item as? Data : nil
  }
  static func codable<T: Codable>(_ account: String) -> T? {
    get(account).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
  }
  static func setCodable<T: Codable>(_ value: T?, _ account: String) {
    set(value.flatMap { try? JSONEncoder().encode($0) }, for: account)
  }
}

@MainActor final class StravaService: NSObject, ASWebAuthenticationPresentationContextProviding {
  private let client = StravaClient()
  private var session: ASWebAuthenticationSession?

  /// Client ID + token proxy baked into the build (server mode); no secret in the app.
  static var builtIn: StravaClient.Credentials? {
    let info = Bundle.main.infoDictionary ?? [:]
    guard let id = info["SymptoPageStravaClientID"] as? String, !id.isEmpty, !id.hasPrefix("$("),
      let raw = info["SymptoPageStravaTokenURL"] as? String, let url = URL(string: raw), url.scheme == "https"
    else { return nil }
    return StravaClient.Credentials(clientID: id, tokenURL: url)
  }
  var credentials: StravaClient.Credentials? {
    get { Self.builtIn ?? Keychain.codable("credentials") }
    set { if Self.builtIn == nil { Keychain.setCodable(newValue, "credentials") } }
  }
  var tokens: StravaClient.Tokens? {
    get { Keychain.codable("tokens") }
    set { Keychain.setCodable(newValue, "tokens") }
  }
  var isConnected: Bool { tokens != nil }

  /// Opens Strava's consent page and stores tokens. Returns the athlete's name.
  func connect() async throws -> String? {
    guard let credentials, credentials.isComplete else { throw StravaError.notConfigured }
    #if os(iOS)
      let mobile = true
    #else
      let mobile = false
    #endif
    let url = StravaClient.authorizeURL(clientID: credentials.clientID, mobile: mobile)
    let callback: URL = try await withCheckedThrowingContinuation { continuation in
      let session = ASWebAuthenticationSession(url: url, callbackURLScheme: StravaClient.callbackScheme) { url, error in
        if let url { continuation.resume(returning: url) } else { continuation.resume(throwing: error ?? StravaError.denied) }
      }
      session.presentationContextProvider = self
      session.prefersEphemeralWebBrowserSession = false
      self.session = session
      if !session.start() { continuation.resume(throwing: StravaError.invalidResponse) }
    }
    let code = try StravaClient.code(from: callback)
    let tokens = try await client.exchange(code: code, credentials: credentials)
    self.tokens = tokens
    return tokens.athlete
  }
  func disconnect() async {
    if let tokens { await client.deauthorize(tokens) }
    tokens = nil
  }
  /// Activities since `after`; refreshes and stores tokens when needed.
  func activities(after: Date) async throws -> [Activity] {
    guard let credentials, credentials.isComplete, let current = tokens else { throw StravaError.notConfigured }
    let valid = try await client.valid(current, credentials: credentials)
    if valid != current { tokens = valid }
    return try await client.activities(after: after, tokens: valid)
  }

  nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    MainActor.assumeIsolated {
      #if os(iOS)
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
          .first { $0.isKeyWindow } ?? ASPresentationAnchor()
      #else
        NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first ?? ASPresentationAnchor()
      #endif
    }
  }
}

#if os(iOS)
  import UIKit
#else
  import AppKit
#endif
