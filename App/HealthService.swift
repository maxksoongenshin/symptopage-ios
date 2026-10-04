import Foundation

#if SWIFT_PACKAGE
  import SymptoCore
#endif

/// Result of one Apple Health import.
struct HealthImport {
  var days: [HealthDay] = []
  var activities: [Activity] = []
  var heartRates: [(date: Date, bpm: Int)] = []
}

// HEALTHKIT_TYPECHECK lets the iOS code path be compiled against the macOS SDK in CI.
#if os(iOS) || HEALTHKIT_TYPECHECK
  import HealthKit

  /// Reads (never writes) Apple Health data recorded by Apple Watch, iPhone or apps such as Strava.
  final class HealthService: @unchecked Sendable {
    private let store = HKHealthStore()
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
      var types: Set<HKObjectType> = [HKObjectType.workoutType()]
      for id in [
        HKQuantityTypeIdentifier.heartRate, .restingHeartRate, .heartRateVariabilitySDNN, .stepCount,
        .activeEnergyBurned,
      ] {
        types.insert(HKQuantityType(id))
      }
      types.insert(HKCategoryType(.sleepAnalysis))
      return types
    }

    func requestAccess() async throws {
      try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Daily values for `days` days back, workouts in the same window, and heart-rate samples
    /// around the given event times (for "heart rate at the moment of the symptom").
    func importData(days: Int, eventTimes: [Date], calendar: Calendar = .current) async throws -> HealthImport {
      let end = Date()
      let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -(days - 1), to: end)!)
      var result = HealthImport()
      var byDay: [String: HealthDay] = [:]
      func update(_ date: Date, _ change: (inout HealthDay) -> Void) {
        let key = Day.key(date, calendar: calendar)
        var day = byDay[key] ?? HealthDay(day: key)
        change(&day)
        byDay[key] = day
      }
      let bpm = HKUnit.count().unitDivided(by: .minute())
      for (id, option, unit, apply) in [
        (HKQuantityTypeIdentifier.restingHeartRate, HKStatisticsOptions.discreteAverage, bpm,
         { (d: inout HealthDay, v: Double) in d.restingHR = Int(v.rounded()) }),
        (.heartRate, .discreteAverage, bpm, { (d: inout HealthDay, v: Double) in d.averageHR = Int(v.rounded()) }),
        (.heartRate, .discreteMax, bpm, { (d: inout HealthDay, v: Double) in d.maxHR = Int(v.rounded()) }),
        (.heartRateVariabilitySDNN, .discreteAverage, HKUnit.secondUnit(with: .milli),
         { (d: inout HealthDay, v: Double) in d.hrv = Int(v.rounded()) }),
        (.stepCount, .cumulativeSum, HKUnit.count(), { (d: inout HealthDay, v: Double) in d.steps = Int(v.rounded()) }),
        (.activeEnergyBurned, .cumulativeSum, HKUnit.kilocalorie(),
         { (d: inout HealthDay, v: Double) in d.activeKcal = Int(v.rounded()) }),
      ] as [(HKQuantityTypeIdentifier, HKStatisticsOptions, HKUnit, (inout HealthDay, Double) -> Void)] {
        let descriptor = HKStatisticsCollectionQueryDescriptor(
          predicate: HKSamplePredicate.quantitySample(
            type: HKQuantityType(id), predicate: HKQuery.predicateForSamples(withStart: start, end: end)),
          options: option, anchorDate: start, intervalComponents: DateComponents(day: 1))
        let collection = try await descriptor.result(for: store)
        collection.enumerateStatistics(from: start, to: end) { statistics, _ in
          let quantity =
            option == .cumulativeSum
            ? statistics.sumQuantity() : option == .discreteMax ? statistics.maximumQuantity() : statistics.averageQuantity()
          if let value = quantity?.doubleValue(for: unit) { update(statistics.startDate) { apply(&$0, value) } }
        }
      }
      // Sleep: asleep stages, attributed to the day the sleep ended.
      let sleep = HKSampleQueryDescriptor(
        predicates: [.categorySample(type: HKCategoryType(.sleepAnalysis), predicate: HKQuery.predicateForSamples(withStart: start.addingTimeInterval(-43_200), end: end))],
        sortDescriptors: [])
      var sleepByDay: [String: Double] = [:]
      for sample in try await sleep.result(for: store) {
        let asleep = HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue)
        guard asleep.contains(sample.value) else { continue }
        sleepByDay[Day.key(sample.endDate, calendar: calendar), default: 0] += sample.endDate.timeIntervalSince(sample.startDate)
      }
      for (key, seconds) in sleepByDay where key >= Day.key(start, calendar: calendar) {
        var day = byDay[key] ?? HealthDay(day: key)
        day.sleepMinutes = min(Int(seconds / 60), 1440)
        byDay[key] = day
      }
      result.days = byDay.values.filter { !$0.isEmpty }.sorted { $0.day < $1.day }
      // Workouts (Apple Watch, iPhone, Strava and other apps that write to Health).
      let workouts = HKSampleQueryDescriptor(
        predicates: [.workout(HKQuery.predicateForSamples(withStart: start, end: end))], sortDescriptors: [])
      for w in try await workouts.result(for: store) {
        var a = Activity(
          id: "health:" + w.uuid.uuidString, source: .health, sport: Self.sport(w.workoutActivityType),
          name: w.sourceRevision.source.name, start: w.startDate, durationSeconds: Int(w.duration))
        a.distanceMeters = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?.sumQuantity()?.doubleValue(for: .meter())
          ?? w.statistics(for: HKQuantityType(.distanceCycling))?.sumQuantity()?.doubleValue(for: .meter())
        let hr = w.statistics(for: HKQuantityType(.heartRate))
        a.averageHR = hr?.averageQuantity().map { Int($0.doubleValue(for: bpm).rounded()) }
        a.maxHR = hr?.maximumQuantity().map { Int($0.doubleValue(for: bpm).rounded()) }
        a.kcal = w.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity().map { Int($0.doubleValue(for: .kilocalorie())) }
        result.activities.append(a)
      }
      // Heart rate around symptom events without a value.
      if let first = eventTimes.min(), let last = eventTimes.max() {
        let samples = HKSampleQueryDescriptor(
          predicates: [.quantitySample(type: HKQuantityType(.heartRate), predicate: HKQuery.predicateForSamples(withStart: first.addingTimeInterval(-600), end: last.addingTimeInterval(600)))],
          sortDescriptors: [], limit: 20_000)
        result.heartRates = try await samples.result(for: store).map {
          ($0.startDate, Int($0.quantity.doubleValue(for: bpm).rounded()))
        }.filter { (20...260).contains($0.1) }
      }
      return result
    }

    static func sport(_ type: HKWorkoutActivityType) -> String {
      switch type {
      case .running: return "Run"
      case .cycling: return "Ride"
      case .walking: return "Walk"
      case .hiking: return "Hike"
      case .swimming: return "Swim"
      case .traditionalStrengthTraining, .functionalStrengthTraining: return "WeightTraining"
      case .yoga: return "Yoga"
      case .rowing: return "Rowing"
      case .elliptical: return "Elliptical"
      case .highIntensityIntervalTraining: return "HIIT"
      default: return "Workout"
      }
    }
  }
#else
  /// macOS preview: Apple Health is not available on Mac.
  final class HealthService: @unchecked Sendable {
    var isAvailable: Bool { false }
    func requestAccess() async throws {}
    func importData(days: Int, eventTimes: [Date], calendar: Calendar = .current) async throws -> HealthImport {
      HealthImport()
    }
  }
#endif
