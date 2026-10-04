import Foundation

public enum StravaError: Error, Equatable {
  case notConfigured, denied, invalidResponse, rateLimited
  case http(Int)
}

/// Strava API v3 client (OAuth 2 + athlete activities). Uses the owner's own Strava API
/// application: client ID and secret are entered in Settings and kept in the Keychain.
public final class StravaClient: @unchecked Sendable {
  /// Either personal mode (owner's own client secret on the device) or server mode:
  /// `tokenURL` points to a small proxy (see server/strava-token-worker) that adds the secret,
  /// so a distributed app never contains it.
  public struct Credentials: Codable, Equatable, Sendable {
    public var clientID: String
    public var clientSecret: String
    public var tokenURL: URL?
    public init(clientID: String, clientSecret: String = "", tokenURL: URL? = nil) {
      self.clientID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
      self.clientSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
      self.tokenURL = tokenURL
    }
    public var isComplete: Bool { !clientID.isEmpty && (!clientSecret.isEmpty || tokenURL != nil) }
  }
  public struct Tokens: Codable, Equatable, Sendable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date
    public var athlete: String?
  }
  /// Register "localhost" as the Authorization Callback Domain of the Strava API app.
  public static let callbackScheme = "symptopage"
  public static let redirectURI = "symptopage://localhost/strava"
  public static let scope = "read,activity:read_all"

  let session: URLSession
  let base: URL
  public init(session: URLSession = .shared, base: URL = URL(string: "https://www.strava.com")!) {
    self.session = session
    self.base = base
  }

  public static func authorizeURL(clientID: String, mobile: Bool) -> URL {
    var c = URLComponents(string: mobile ? "https://www.strava.com/oauth/mobile/authorize" : "https://www.strava.com/oauth/authorize")!
    c.queryItems = [
      .init(name: "client_id", value: clientID), .init(name: "redirect_uri", value: redirectURI),
      .init(name: "response_type", value: "code"), .init(name: "approval_prompt", value: "auto"),
      .init(name: "scope", value: scope),
    ]
    return c.url!
  }
  /// Reads `code` from the OAuth callback; a denied consent or missing activity scope throws.
  public static func code(from callback: URL) throws -> String {
    let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
    func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
    if value("error") != nil { throw StravaError.denied }
    guard let code = value("code"), !code.isEmpty else { throw StravaError.invalidResponse }
    if let scope = value("scope"), !scope.contains("activity:read") { throw StravaError.denied }
    return code
  }

  public func exchange(code: String, credentials: Credentials) async throws -> Tokens {
    try Self.parseTokens(
      try await token(
        ["client_id": credentials.clientID, "code": code, "grant_type": "authorization_code"], credentials),
      previous: nil)
  }
  public func refresh(_ tokens: Tokens, credentials: Credentials) async throws -> Tokens {
    try Self.parseTokens(
      try await token(
        ["client_id": credentials.clientID, "refresh_token": tokens.refreshToken, "grant_type": "refresh_token"],
        credentials), previous: tokens)
  }
  /// Returns usable tokens, refreshing them when they expire within 5 minutes.
  public func valid(_ tokens: Tokens, credentials: Credentials, now: Date = .now) async throws -> Tokens {
    tokens.expiresAt.timeIntervalSince(now) > 300 ? tokens : try await refresh(tokens, credentials: credentials)
  }
  /// Activities started after `after`, newest pages first, at most `maxPages` × 100.
  public func activities(after: Date, tokens: Tokens, maxPages: Int = 5) async throws -> [Activity] {
    var result: [Activity] = []
    for page in 1...maxPages {
      var c = URLComponents(url: base.appendingPathComponent("api/v3/athlete/activities"), resolvingAgainstBaseURL: false)!
      c.queryItems = [
        .init(name: "after", value: String(Int(after.timeIntervalSince1970))),
        .init(name: "per_page", value: "100"), .init(name: "page", value: String(page)),
      ]
      var request = URLRequest(url: c.url!)
      request.setValue("Bearer " + tokens.accessToken, forHTTPHeaderField: "Authorization")
      let items = try Self.parseActivities(try await send(request))
      result += items
      if items.count < 100 { break }
    }
    return result
  }
  public func deauthorize(_ tokens: Tokens) async {
    var request = URLRequest(url: base.appendingPathComponent("oauth/deauthorize"))
    request.httpMethod = "POST"
    request.setValue("Bearer " + tokens.accessToken, forHTTPHeaderField: "Authorization")
    _ = try? await send(request)
  }

  private func token(_ fields: [String: String], _ credentials: Credentials) async throws -> Data {
    var fields = fields
    if credentials.tokenURL == nil { fields["client_secret"] = credentials.clientSecret }
    var request = URLRequest(url: credentials.tokenURL ?? base.appendingPathComponent("oauth/token"))
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    var c = URLComponents()
    c.queryItems = fields.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
    request.httpBody = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
    return try await send(request)
  }
  private func send(_ request: URLRequest) async throws -> Data {
    var request = request
    request.timeoutInterval = 30
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw StravaError.invalidResponse }
    switch http.statusCode {
    case 200..<300: return data
    case 401, 403: throw StravaError.denied
    case 429: throw StravaError.rateLimited
    default: throw StravaError.http(http.statusCode)
    }
  }

  public static func parseTokens(_ data: Data, previous: Tokens?) throws -> Tokens {
    struct Response: Decodable {
      struct Athlete: Decodable { var firstname: String?; var lastname: String? }
      var access_token: String
      var refresh_token: String
      var expires_at: TimeInterval
      var athlete: Athlete?
    }
    guard let r = try? JSONDecoder().decode(Response.self, from: data), !r.access_token.isEmpty else {
      throw StravaError.invalidResponse
    }
    let name = [r.athlete?.firstname, r.athlete?.lastname].compactMap { $0 }.joined(separator: " ")
    return Tokens(
      accessToken: r.access_token, refreshToken: r.refresh_token,
      expiresAt: Date(timeIntervalSince1970: r.expires_at),
      athlete: name.isEmpty ? previous?.athlete : name)
  }
  public static func parseActivities(_ data: Data) throws -> [Activity] {
    struct Item: Decodable {
      var id: Int64
      var name: String?
      var sport_type: String?
      var type: String?
      var start_date: String
      var moving_time: Int?
      var elapsed_time: Int?
      var distance: Double?
      var average_heartrate: Double?
      var max_heartrate: Double?
      var total_elevation_gain: Double?
      var calories: Double?
    }
    guard let items = try? JSONDecoder().decode([Item].self, from: data) else {
      throw StravaError.invalidResponse
    }
    let iso = ISO8601DateFormatter()
    return items.compactMap { i in
      guard let start = iso.date(from: i.start_date) else { return nil }
      var a = Activity(
        id: "strava:\(i.id)", source: .strava, sport: i.sport_type ?? i.type ?? "Workout",
        name: String((i.name ?? "").prefix(300)), start: start,
        durationSeconds: min(max(i.moving_time ?? i.elapsed_time ?? 0, 0), 604_800))
      a.distanceMeters = i.distance.flatMap { $0 > 0 && $0.isFinite ? min($0, 2_000_000) : nil }
      a.averageHR = i.average_heartrate.map { Int($0.rounded()) }.flatMap { (20...260).contains($0) ? $0 : nil }
      a.maxHR = i.max_heartrate.map { Int($0.rounded()) }.flatMap { (20...260).contains($0) ? $0 : nil }
      a.elevationMeters = i.total_elevation_gain.flatMap { $0.isFinite && abs($0) <= 20_000 ? $0 : nil }
      a.kcal = i.calories.map { Int($0.rounded()) }.flatMap { (0...50_000).contains($0) ? $0 : nil }
      return a
    }
  }
}
