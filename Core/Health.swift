import Foundation

/// Daily aggregates imported from Apple Health (recorded by Apple Watch or iPhone).
/// Values are copied as recorded; the app does not interpret them medically.
public struct HealthDay: Codable, Equatable, Sendable {
  public var day: String
  public var restingHR: Int?
  public var averageHR: Int?
  public var maxHR: Int?
  /// Heart rate variability (SDNN), milliseconds.
  public var hrv: Int?
  public var steps: Int?
  public var sleepMinutes: Int?
  public var activeKcal: Int?
  public init(day: String) { self.day = day }
  public var isEmpty: Bool {
    restingHR == nil && averageHR == nil && maxHR == nil && hrv == nil && steps == nil
      && sleepMinutes == nil && activeKcal == nil
  }
}
public enum ActivitySource: String, Codable, CaseIterable, Sendable {
  case strava, health
  public var title: String { self == .strava ? "Strava" : "Apple Health" }
}
/// A workout from Strava or Apple Health. `id` is prefixed by source ("strava:123").
public struct Activity: Codable, Identifiable, Equatable, Sendable {
  public var id: String
  public var source: ActivitySource
  /// Strava `sport_type` or a HealthKit activity name, e.g. "Run", "Ride", "Walk".
  public var sport: String
  public var name: String
  public var start: Date
  public var durationSeconds: Int
  public var distanceMeters: Double?
  public var averageHR: Int?
  public var maxHR: Int?
  public var elevationMeters: Double?
  public var kcal: Int?
  public init(id: String, source: ActivitySource, sport: String, name: String, start: Date, durationSeconds: Int) {
    self.id = id
    self.source = source
    self.sport = sport
    self.name = name
    self.start = start
    self.durationSeconds = durationSeconds
  }
}
/// Connection state for automatic imports. Secrets are never stored here (Keychain only).
public struct Integrations: Codable, Equatable, Sendable {
  public var healthEnabled = false
  public var lastHealthSync: Date?
  public var stravaAthlete: String?
  public var lastStravaSync: Date?
  public init() {}
}

extension Language {
  public func sport(_ value: String) -> String {
    switch value.lowercased() {
    case "run", "running", "trailrun", "virtualrun": return text("Run", "Bieg")
    case "ride", "cycling", "virtualride", "ebikeride", "mountainbikeride", "gravelride":
      return text("Ride", "Rower")
    case "walk", "walking": return text("Walk", "Spacer")
    case "hike", "hiking": return text("Hike", "Wędrówka")
    case "swim", "swimming": return text("Swim", "Pływanie")
    case "weighttraining", "traditionalstrengthtraining", "functionalstrengthtraining":
      return text("Strength training", "Trening siłowy")
    case "yoga": return text("Yoga", "Joga")
    case "rowing": return text("Rowing", "Wioślarstwo")
    case "elliptical": return text("Elliptical", "Orbitrek")
    case "highintensityintervaltraining", "hiit": return text("Interval training", "Trening interwałowy")
    default: return text("Workout", "Trening")
    }
  }
  /// "1 h 05 min" / "42 min".
  public func duration(_ seconds: Int) -> String {
    let minutes = max(seconds, 0) / 60
    return minutes >= 60 ? "\(minutes / 60) h \(String(format: "%02d", minutes % 60)) min" : "\(minutes) min"
  }
  public func distance(_ meters: Double) -> String {
    let km = meters / 1000
    let value = km >= 10 ? String(format: "%.0f", km) : String(format: "%.1f", km)
    return (self == .pl ? value.replacingOccurrences(of: ".", with: ",") : value) + " km"
  }
}

public enum HealthMerge {
  /// Upserts days (non-nil fields win) and activities. A Health workout that duplicates a
  /// Strava activity (same start within 3 minutes, similar duration) is dropped:
  /// Strava can write its activities into Apple Health, and the Strava copy has the name.
  public static func apply(days: [HealthDay], activities: [Activity], to s: inout AppState) {
    for day in days where Day.valid(day.day) {
      var merged = s.healthDays.first { $0.day == day.day } ?? HealthDay(day: day.day)
      merged.restingHR = day.restingHR ?? merged.restingHR
      merged.averageHR = day.averageHR ?? merged.averageHR
      merged.maxHR = day.maxHR ?? merged.maxHR
      merged.hrv = day.hrv ?? merged.hrv
      merged.steps = day.steps ?? merged.steps
      merged.sleepMinutes = day.sleepMinutes ?? merged.sleepMinutes
      merged.activeKcal = day.activeKcal ?? merged.activeKcal
      s.healthDays.removeAll { $0.day == day.day }
      if !merged.isEmpty { s.healthDays.append(merged) }
    }
    s.healthDays.sort { $0.day < $1.day }
    for activity in activities {
      s.activities.removeAll { $0.id == activity.id }
      s.activities.append(activity)
    }
    let strava = s.activities.filter { $0.source == .strava }
    s.activities.removeAll { a in
      a.source == .health
        && strava.contains {
          abs($0.start.timeIntervalSince(a.start)) <= 180
            && abs($0.durationSeconds - a.durationSeconds) <= max(300, a.durationSeconds / 5)
        }
    }
    s.activities.sort { $0.start < $1.start }
  }
  /// Fills `heartRate` of events that have none with the nearest sample within 10 minutes.
  public static func attachHeartRates(_ samples: [(date: Date, bpm: Int)], to s: inout AppState) {
    guard !samples.isEmpty else { return }
    for index in s.events.indices where s.events[index].heartRate == nil {
      let time = s.events[index].timestamp
      if let nearest = samples.min(by: {
        abs($0.date.timeIntervalSince(time)) < abs($1.date.timeIntervalSince(time))
      }), abs(nearest.date.timeIntervalSince(time)) <= 600 {
        s.events[index].heartRate = nearest.bpm
      }
    }
  }
}
