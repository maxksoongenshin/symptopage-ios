import CoreText
import PDFKit
import XCTest

@testable import SymptoCore

final class CoreTests: XCTestCase {
  func testBuiltInLabelsSwitchLanguageWithoutChangingStoredValues() throws {
    for key in builtInSpecialties {
      XCTAssertNotEqual(Language.en.specialty(key), key)
      XCTAssertNotEqual(Language.pl.specialty(key), key)
      XCTAssertNotEqual(Language.en.specialty(key), Language.pl.specialty(key))
    }
    for key in builtInSymptoms {
      XCTAssertNotEqual(Language.en.symptom(key), Language.pl.symptom(key))
    }
    var s = AppState()
    var doctor = Doctor(specialty: "cardiologist"); doctor.name = "My doctor"
    s.doctors = [doctor]
    s.language = .pl
    let decoded = try StateCodec.decode(StateCodec.encode(s))
    XCTAssertEqual(decoded.doctors[0].specialty, "cardiologist")
    XCTAssertEqual(decoded.doctors[0].name, "My doctor")
    XCTAssertEqual(decoded.doctors[0].title(.pl), "My doctor · Kardiolog")
    XCTAssertEqual(decoded.doctors[0].title(.en), "My doctor · Cardiologist")
    XCTAssertEqual(Language.pl.symptom("My custom symptom"), "My custom symptom")
    XCTAssertEqual(Frequency.none.title(.pl), "Nie")
    XCTAssertEqual(Frequency.once.title(.pl), "Raz")
    XCTAssertEqual(Frequency.several.title(.pl), "Kilka")
  }
  func testDailyQuestionSymptomAndProfileNameAreOptionalAndValidated() throws {
    var s = AppState()
    let doctor = Doctor(specialty: "internist")
    var observation = Observation(doctorID: doctor.id, reason: "Visit")
    s.doctors = [doctor]
    s.observations = [observation]
    // Files written before 0.6.0 have neither key; they must still decode.
    let legacy = try StateCodec.encode(s)
    XCTAssertFalse(String(decoding: legacy, as: UTF8.self).contains("profileName"))
    XCTAssertEqual(try StateCodec.decode(legacy).observations[0].symptom, nil)
    observation.symptom = "palpitations"
    s.observations = [observation]
    s.profileName = "Kasia"
    let decoded = try StateCodec.decode(StateCodec.encode(s))
    XCTAssertEqual(decoded.observations[0].symptom, "palpitations")
    XCTAssertEqual(decoded.profileName, "Kasia")
    XCTAssertEqual(Language.pl.specialty("internist"), "Internista")
    XCTAssertEqual(suggestedSymptom(forSpecialty: "cardiologist"), "palpitations")
    XCTAssertEqual(suggestedSymptom(forSpecialty: "internist"), "fatigue")
    XCTAssertEqual(suggestedSymptom(forSpecialty: "my own specialty"), nil)
    var blank = s
    blank.observations[0].symptom = "  "
    XCTAssertThrowsError(try StateCodec.validate(blank))
    var long = s
    long.profileName = String(repeating: "a", count: 101)
    XCTAssertThrowsError(try StateCodec.validate(long))
  }
  func testCatalogIsConsistentAndKeepsLegacyKeys() {
    XCTAssertEqual(Set(builtInSymptoms).count, builtInSymptoms.count)
    XCTAssertEqual(Set(builtInSpecialties).count, builtInSpecialties.count)
    for key in ["palpitations", "dizziness", "dyspnea", "headache", "pain", "fatigue"] {
      XCTAssertTrue(builtInSymptoms.contains(key))
    }
    for key in ["gp", "cardiologist", "neurologist", "endocrinologist", "orthopedist", "internist"] {
      XCTAssertTrue(builtInSpecialties.contains(key))
    }
    for key in quickSpecialties { XCTAssertTrue(builtInSpecialties.contains(key)) }
    for category in SymptomCategory.allCases {
      XCTAssertFalse(Catalog.symptoms(in: category).isEmpty)
      XCTAssertNotEqual(category.title(.en), category.title(.pl))
    }
    for info in Catalog.symptoms { XCTAssertFalse(info.icon.isEmpty) }
    for info in Catalog.specialties {
      XCTAssertFalse(info.symptoms.isEmpty)
      for symptom in info.symptoms { XCTAssertTrue(builtInSymptoms.contains(symptom)) }
    }
    XCTAssertEqual(Set(Catalog.noteTags.map(\.key)).count, Catalog.noteTags.count)
    XCTAssertEqual(Language.pl.tag("sleep"), "Sen")
    XCTAssertEqual(Language.pl.tag("my tag"), "my tag")
  }
  func testNotesAreBackwardCompatibleAndValidated() throws {
    var s = fixture()
    // A 0.6.0 file has no "notes" key at all.
    var legacy = try JSONSerialization.jsonObject(with: StateCodec.encode(s)) as! [String: Any]
    legacy.removeValue(forKey: "notes")
    let decoded = try StateCodec.decode(JSONSerialization.data(withJSONObject: legacy))
    XCTAssertTrue(decoded.notes.isEmpty)
    var note = WellbeingNote(text: "Zażółć gęślą jaźń", mood: .good)
    note.tags = ["sleep", "own"]
    note.observationIDs = [s.observations[0].id]
    s.notes = [note]
    let restored = try StateCodec.decode(StateCodec.encode(s)).notes
    XCTAssertEqual(restored.map(\.id), [note.id])
    XCTAssertEqual(restored[0].text, note.text)
    XCTAssertEqual(restored[0].mood, .good)
    XCTAssertEqual(restored[0].tags, ["sleep", "own"])
    XCTAssertEqual(restored[0].observationIDs, note.observationIDs)
    XCTAssertTrue(abs(restored[0].date.timeIntervalSince(note.date)) < 0.002)
    var moodOnly = s
    moodOnly.notes = [WellbeingNote(text: "", mood: .bad)]
    XCTAssertEqual(try StateCodec.decode(StateCodec.encode(moodOnly)).notes[0].mood, .bad)
    var empty = s
    empty.notes = [WellbeingNote(text: "   ")]
    XCTAssertThrowsError(try StateCodec.validate(empty))
    var badLink = s
    badLink.notes[0].observationIDs = [UUID()]
    XCTAssertThrowsError(try StateCodec.validate(badLink))
    var duplicateTag = s
    duplicateTag.notes[0].tags = ["sleep", "sleep"]
    XCTAssertThrowsError(try StateCodec.validate(duplicateTag))
    var manyTags = s
    manyTags.notes[0].tags = (0..<21).map { "t\($0)" }
    XCTAssertThrowsError(try StateCodec.validate(manyTags))
    var duplicateID = s
    duplicateID.notes.append(note)
    XCTAssertThrowsError(try StateCodec.validate(duplicateID))
  }
  func testReportIncludesNotesAndSummaryRespectsFilters() throws {
    var s = fixture()
    s.language = .pl
    let other = Doctor(specialty: "neurologist")
    let otherObservation = Observation(doctorID: other.id, reason: "Other")
    s.doctors.append(other)
    s.observations.append(otherObservation)
    var mine = WellbeingNote(text: "MOJA_NOTATKA", mood: .okay)
    mine.observationIDs = [s.observations[0].id]
    mine.tags = ["stress"]
    var theirs = WellbeingNote(text: "OBCA_NOTATKA")
    theirs.observationIDs = [otherObservation.id]
    s.notes = [mine, theirs]
    var event = SymptomEvent(symptom: "palpitations")
    event.observationIDs = [s.observations[0].id]
    event.intensity = 4
    s.events = [event, event].enumerated().map { i, e in var x = e; x.id = UUID(); x.intensity = 4 + i; return x }
    let today = Day.key(.now)
    s.checkIns = [
      DailyCheckIn(observationID: s.observations[0].id, day: today, symptom: "palpitations", frequency: .several)
    ]
    let filter: Set<UUID> = [s.doctors[0].id]
    let text = ReportBuilder.sections(state: s, doctors: filter, from: .now, through: .now)
      .map { $0.title + "\n" + $0.body }.joined()
    XCTAssertTrue(text.contains("Notatki o samopoczuciu"))
    XCTAssertTrue(text.contains("MOJA_NOTATKA"))
    XCTAssertTrue(text.contains("#Stres"))
    XCTAssertFalse(text.contains("OBCA_NOTATKA"))
    let summary = ReportBuilder.summary(state: s, doctors: filter, from: .now, through: .now)
    XCTAssertEqual(summary.tiles[0].value, "2")
    XCTAssertEqual(summary.tiles[1].value, "1")
    XCTAssertEqual(summary.tiles[2].value, "1")
    XCTAssertEqual(summary.symptoms.count, 1)
    XCTAssertEqual(summary.symptoms[0].intensity, "4–5/10")
    XCTAssertEqual(summary.days, [today])
    XCTAssertEqual(summary.strip.count, 1)
    XCTAssertEqual(summary.strip[0].values, [.several])
    let long = ReportBuilder.summary(
      state: s, doctors: [], from: Date().addingTimeInterval(-86400 * 120), through: .now)
    XCTAssertEqual(long.days.count, 31)
    XCTAssertEqual(long.days.last, today)
  }
  func testDesignedPDFUsesBundledFontAndKeepsPolishText() throws {
    // check_core.py copies this file to a temporary folder and passes the project root.
    let root =
      ProcessInfo.processInfo.environment["SYMPTOPAGE_ROOT"].map { URL(fileURLWithPath: $0) }
      ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let fonts = root.appendingPathComponent("App/Resources/Fonts")
    for name in ["Regular", "SemiBold", "Bold", "ExtraBold"] {
      let url = fonts.appendingPathComponent("Manrope-\(name).ttf")
      XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
    XCTAssertEqual(CTFontCopyPostScriptName(PDFRenderer.font(10, .heavy)) as String, "Manrope-ExtraBold")
    var s = fixture()
    s.language = .pl
    s.profileName = "Kasia"
    for index in 0..<80 {
      var event = SymptomEvent(symptom: index % 2 == 0 ? "pain" : "headache")
      event.observationIDs = [s.observations[0].id]
      event.intensity = index % 10 + 1
      event.note = "Wpis \(index): Zażółć gęślą jaźń. " + String(repeating: "Notatka. ", count: 10)
      s.events.append(event)
    }
    s.notes = [WellbeingNote(text: "Łódź, ćma, źdźbło", mood: .veryGood)]
    s.checkIns = [
      DailyCheckIn(observationID: s.observations[0].id, day: Day.key(.now), symptom: "pain", frequency: .once)
    ]
    let logo = try? Data(
      contentsOf: root.appendingPathComponent(
        "App/Resources/Assets.xcassets/BrandIconBlue.imageset/SymptoPage_app_icon_blue.png"))
    let data = try PDFRenderer.make(
      ReportBuilder.sections(state: s, doctors: [], from: .now, through: .now),
      summary: ReportBuilder.summary(state: s, doctors: [], from: .now, through: .now), logo: logo)
    let pdf = PDFDocument(data: data)!
    XCTAssertTrue(pdf.pageCount > 2)
    let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
    XCTAssertTrue(text.contains("Zażółć gęślą jaźń"))
    XCTAssertTrue(text.contains("Łódź, ćma, źdźbło"))
    XCTAssertTrue(text.contains("Wpis 79"))
    XCTAssertTrue(text.contains("Raport dla lekarza"))
    XCTAssertTrue(text.contains("Kasia"))
    XCTAssertTrue(text.contains("Strona 1 / \(pdf.pageCount)"))
    XCTAssertTrue(text.contains("Strona \(pdf.pageCount) / \(pdf.pageCount)"))
    XCTAssertTrue(text.contains("Codzienne odpowiedzi"))
    // An empty report still produces one designed page.
    var blank = AppState()
    blank.language = .en
    let empty = try PDFRenderer.make(
      ReportBuilder.sections(state: blank, doctors: [], from: .now, through: .now),
      summary: ReportBuilder.summary(state: blank, doctors: [], from: .now, through: .now))
    XCTAssertTrue(PDFDocument(data: empty)!.pageCount >= 1)
  }
  // MARK: Strava, Apple Health, Apple Watch

  static let stravaActivities = """
    [{"id": 111, "name": "Poranny bieg", "sport_type": "Run", "type": "Run", "start_date": "2026-10-01T06:30:00Z",
      "moving_time": 1800, "elapsed_time": 1900, "distance": 5012.4, "average_heartrate": 142.6, "max_heartrate": 171,
      "total_elevation_gain": 35.2},
     {"id": 222, "name": "", "type": "Ride", "start_date": "2026-10-02T17:00:00Z", "elapsed_time": 3600,
      "distance": 0, "average_heartrate": 999},
     {"id": 333, "name": "Broken date", "sport_type": "Walk", "start_date": "yesterday"}]
    """
  func testStravaParsingAndOAuthHelpers() throws {
    let items = try StravaClient.parseActivities(Data(Self.stravaActivities.utf8))
    XCTAssertEqual(items.count, 2)
    XCTAssertEqual(items[0].id, "strava:111")
    XCTAssertEqual(items[0].sport, "Run")
    XCTAssertEqual(items[0].durationSeconds, 1800)
    XCTAssertEqual(items[0].averageHR, 143)
    XCTAssertEqual(items[0].maxHR, 171)
    XCTAssertTrue(items[1].distanceMeters == nil && items[1].averageHR == nil)
    XCTAssertEqual(items[1].sport, "Ride")
    XCTAssertThrowsError(try StravaClient.parseActivities(Data("{}".utf8)))
    let tokens = try StravaClient.parseTokens(
      Data(#"{"access_token":"a1","refresh_token":"r1","expires_at":1900000000,"athlete":{"firstname":"Kasia","lastname":"N"}}"#.utf8),
      previous: nil)
    XCTAssertEqual(tokens.athlete, "Kasia N")
    XCTAssertEqual(tokens.expiresAt, Date(timeIntervalSince1970: 1_900_000_000))
    XCTAssertThrowsError(try StravaClient.parseTokens(Data(#"{"message":"Bad Request"}"#.utf8), previous: nil))
    let url = StravaClient.authorizeURL(clientID: "123", mobile: true).absoluteString
    XCTAssertTrue(url.hasPrefix("https://www.strava.com/oauth/mobile/authorize"))
    XCTAssertTrue(url.contains("client_id=123"))
    XCTAssertTrue(url.contains("activity:read_all"))
    XCTAssertEqual(try StravaClient.code(from: URL(string: "symptopage://localhost/strava?state=&code=abc&scope=read,activity:read_all")!), "abc")
    XCTAssertThrowsError(try StravaClient.code(from: URL(string: "symptopage://localhost/strava?error=access_denied")!))
    XCTAssertThrowsError(try StravaClient.code(from: URL(string: "symptopage://localhost/strava?code=abc&scope=read")!))
    XCTAssertEqual(Language.pl.sport("Ride"), "Rower")
    XCTAssertEqual(Language.pl.duration(3900), "1 h 05 min")
    XCTAssertEqual(Language.pl.distance(5012.4), "5,0 km")
  }
  func testStravaClientRefreshesExpiredTokenAndPages() async throws {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockStrava.self]
    MockStrava.requests = []
    let client = StravaClient(session: URLSession(configuration: config))
    let expired = StravaClient.Tokens(accessToken: "old", refreshToken: "r0", expiresAt: Date().addingTimeInterval(-10), athlete: "Kasia")
    let credentials = StravaClient.Credentials(clientID: " 1 ", clientSecret: "s+cret ")
    XCTAssertEqual(credentials.clientID, "1")
    let fresh = try await client.valid(expired, credentials: credentials)
    XCTAssertEqual(fresh.accessToken, "new")
    XCTAssertEqual(fresh.athlete, "Kasia")
    let body = MockStrava.requests.first { $0.url?.path == "/oauth/token" }.flatMap(MockStrava.body) ?? ""
    XCTAssertTrue(body.contains("grant_type=refresh_token"))
    XCTAssertTrue(body.contains("client_secret=s%2Bcret"))
    let activities = try await client.activities(after: Date(timeIntervalSince1970: 0), tokens: fresh)
    XCTAssertEqual(activities.count, 101)
    let pages = MockStrava.requests.filter { $0.url?.path == "/api/v3/athlete/activities" }
    XCTAssertEqual(pages.count, 2)
    XCTAssertEqual(pages[0].value(forHTTPHeaderField: "Authorization"), "Bearer new")
    let still = try await client.valid(fresh, credentials: credentials)
    XCTAssertEqual(still, fresh)
    // Server mode: the token request goes to the proxy and carries no client secret.
    MockStrava.requests = []
    let proxy = StravaClient.Credentials(clientID: "1", tokenURL: URL(string: "https://proxy.example/token")!)
    XCTAssertTrue(proxy.isComplete)
    XCTAssertFalse(StravaClient.Credentials(clientID: "1").isComplete)
    _ = try await client.refresh(fresh, credentials: proxy)
    let proxied = MockStrava.requests.first { $0.url?.host == "proxy.example" }
    XCTAssertTrue(proxied != nil)
    XCTAssertFalse((proxied.flatMap(MockStrava.body) ?? "client_secret").contains("client_secret"))
    MockStrava.status = 401
    do {
      _ = try await client.activities(after: .now, tokens: fresh)
      XCTAssertTrue(false)
    } catch { XCTAssertEqual(error as? StravaError, .denied) }
    MockStrava.status = 200
  }
  func testHealthMergeDeduplicatesStravaAndAttachesHeartRate() throws {
    var s = fixture()
    var day = HealthDay(day: "2026-10-01")
    day.restingHR = 64
    day.steps = 8000
    HealthMerge.apply(days: [day], activities: [], to: &s)
    var update = HealthDay(day: "2026-10-01")
    update.sleepMinutes = 420
    HealthMerge.apply(days: [update, HealthDay(day: "2026-10-02"), HealthDay(day: "bad")], activities: [], to: &s)
    XCTAssertEqual(s.healthDays.count, 1)
    XCTAssertEqual(s.healthDays[0].restingHR, 64)
    XCTAssertEqual(s.healthDays[0].sleepMinutes, 420)
    let start = Date(timeIntervalSince1970: 1_790_000_000)
    let fromHealth = Activity(id: "health:A", source: .health, sport: "Run", name: "Strava", start: start.addingTimeInterval(60), durationSeconds: 1790)
    let other = Activity(id: "health:B", source: .health, sport: "Walk", name: "Watch", start: start.addingTimeInterval(7200), durationSeconds: 600)
    HealthMerge.apply(days: [], activities: [fromHealth, other], to: &s)
    XCTAssertEqual(s.activities.count, 2)
    let strava = Activity(id: "strava:1", source: .strava, sport: "Run", name: "Poranny bieg", start: start, durationSeconds: 1800)
    HealthMerge.apply(days: [], activities: [strava, strava], to: &s)
    XCTAssertEqual(s.activities.map(\.id), ["strava:1", "health:B"])
    var event = SymptomEvent(symptom: "palpitations")
    event.timestamp = start
    var far = SymptomEvent(symptom: "dizziness")
    far.timestamp = start.addingTimeInterval(5000)
    var known = SymptomEvent(symptom: "pain")
    known.timestamp = start
    known.heartRate = 70
    s.events = [event, far, known]
    HealthMerge.attachHeartRates([(start.addingTimeInterval(-200), 101), (start.addingTimeInterval(30), 118)], to: &s)
    XCTAssertEqual(s.events.map(\.heartRate), [118, nil, 70])
    XCTAssertNoThrow(try StateCodec.validate(s))
    var invalid = s
    invalid.healthDays[0].restingHR = 400
    XCTAssertThrowsError(try StateCodec.validate(invalid))
    invalid = s
    invalid.events[0].heartRate = 5
    XCTAssertThrowsError(try StateCodec.validate(invalid))
    invalid = s
    invalid.activities.append(s.activities[0])
    XCTAssertThrowsError(try StateCodec.validate(invalid))
  }
  func testOlderFilesOpenWithoutHealthKeys() throws {
    var s = fixture()
    s.notes = [WellbeingNote(text: "x")]
    var json = try JSONSerialization.jsonObject(with: StateCodec.encode(s)) as! [String: Any]
    for key in ["healthDays", "activities", "integrations"] { json.removeValue(forKey: key) }
    var events = json["events"] as? [[String: Any]] ?? []
    events.append(["id": UUID().uuidString, "observationIDs": [], "symptom": "pain", "timestamp": "2026-10-01T10:00:00Z",
                   "context": "", "note": "", "createdAt": "2026-10-01T10:00:00Z", "updatedAt": "2026-10-01T10:00:00Z"])
    json["events"] = events
    let decoded = try StateCodec.decode(JSONSerialization.data(withJSONObject: json))
    XCTAssertTrue(decoded.healthDays.isEmpty && decoded.activities.isEmpty)
    XCTAssertFalse(decoded.integrations.healthEnabled)
    XCTAssertEqual(decoded.events.first?.heartRate, nil)
    XCTAssertEqual(decoded.notes.count, 1)
  }
  func testWatchEntriesAreIdempotentAndClamped() throws {
    var s = fixture()
    let o = s.observations[0].id
    s.observations[0].symptom = "palpitations"
    var symptom = WatchEntry(kind: .symptom, timestamp: Date().addingTimeInterval(-60))
    symptom.symptom = "palpitations"
    symptom.intensity = 14
    symptom.heartRate = 300
    symptom.observationID = o
    let wire = try WatchEntry.decode(symptom.encoded())
    XCTAssertEqual(wire.id, symptom.id)
    XCTAssertEqual(wire.symptom, "palpitations")
    XCTAssertTrue(abs(wire.timestamp.timeIntervalSince(symptom.timestamp)) < 0.001)
    wire.apply(to: &s)
    wire.apply(to: &s)
    XCTAssertEqual(s.events.count, 1)
    XCTAssertEqual(s.events[0].intensity, 10)
    XCTAssertEqual(s.events[0].heartRate, nil)
    XCTAssertEqual(s.events[0].source, "watch")
    XCTAssertEqual(s.events[0].observationIDs, [o])
    var unknown = WatchEntry(kind: .symptom)
    unknown.symptom = "headache"
    unknown.observationID = UUID()
    unknown.heartRate = 96
    unknown.apply(to: &s)
    XCTAssertEqual(s.events[1].observationIDs, [])
    XCTAssertEqual(s.events[1].heartRate, 96)
    var answer = WatchEntry(kind: .answer)
    answer.observationID = o
    answer.frequency = .once
    answer.apply(to: &s)
    answer.frequency = .several
    answer.apply(to: &s)
    XCTAssertEqual(s.checkIns.count, 1)
    XCTAssertEqual(s.checkIns[0].frequency, .several)
    XCTAssertEqual(s.checkIns[0].symptom, "palpitations")
    var mood = WatchEntry(kind: .mood)
    mood.mood = .good
    mood.apply(to: &s)
    mood.apply(to: &s)
    XCTAssertEqual(s.notes.count, 1)
    XCTAssertEqual(s.notes[0].tags, ["watch"])
    XCTAssertNoThrow(try StateCodec.validate(s))
    var empty = WatchEntry(kind: .symptom)
    empty.symptom = "  "
    empty.apply(to: &s)
    XCTAssertEqual(s.events.count, 2)
    let context = WatchContext.make(from: s)
    XCTAssertEqual(context.observations.count, 1)
    XCTAssertEqual(context.observations[0].symptom, "palpitations")
    XCTAssertEqual(context.observations[0].answer, .several)
    XCTAssertEqual(context.quickSymptoms.first, "palpitations")
    XCTAssertTrue(context.quickSymptoms.count <= 8)
    XCTAssertEqual(Set(context.quickSymptoms).count, context.quickSymptoms.count)
  }
  func testReportAndPDFIncludeWatchAndStravaData() throws {
    let root =
      ProcessInfo.processInfo.environment["SYMPTOPAGE_ROOT"].map { URL(fileURLWithPath: $0) }
      ?? URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    var s = fixture()
    s.language = .pl
    var day = HealthDay(day: Day.key(.now))
    day.restingHR = 61
    day.steps = 9000
    day.sleepMinutes = 400
    var run = Activity(id: "strava:9", source: .strava, sport: "Run", name: "Bieg nad Wisłą", start: Date().addingTimeInterval(-3600), durationSeconds: 2700)
    run.distanceMeters = 7400
    run.averageHR = 150
    HealthMerge.apply(days: [day], activities: [run], to: &s)
    var event = SymptomEvent(symptom: "palpitations")
    event.heartRate = 131
    event.source = "watch"
    s.events = [event]
    let sections = ReportBuilder.sections(state: s, doctors: [], from: .now, through: .now)
    let text = sections.map { $0.title + "\n" + $0.body }.joined(separator: "\n")
    XCTAssertTrue(text.contains("Aktywność i dane z zegarka"))
    XCTAssertTrue(text.contains("Tętno spoczynkowe: średnio 61/min"))
    XCTAssertTrue(text.contains("Bieg nad Wisłą"))
    XCTAssertTrue(text.contains("tętno 131/min"))
    XCTAssertTrue(text.contains("Apple Watch"))
    let summary = ReportBuilder.summary(state: s, doctors: [], from: .now, through: .now)
    XCTAssertEqual(summary.health?.tiles[0].value, "61")
    XCTAssertEqual(summary.health?.activities.first?.distance, "7,4 km")
    XCTAssertEqual(summary.health?.resting, [61])
    XCTAssertNil(ReportBuilder.summary(state: fixture(), doctors: [], from: .now, through: .now).health)
    let wordmark = try? Data(contentsOf: root.appendingPathComponent("App/Resources/Assets.xcassets/BrandLogoWhite.imageset/SymptoPage_logo_white.png"))
    XCTAssertTrue(wordmark != nil)
    let pdf = PDFDocument(data: try PDFRenderer.make(sections, summary: summary, wordmark: wordmark))!
    let pdfText = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
    XCTAssertTrue(pdfText.contains("Aktywność i dane z zegarka"))
    XCTAssertTrue(pdfText.contains("Bieg · Bieg nad Wisłą"))
    XCTAssertTrue(pdfText.contains("Strava"))
    XCTAssertTrue(pdfText.contains("tętno 131/min"))
  }
  func testMedicationEditPreservesPastAndChangesOnlyFutureTimes() throws {
    let cal = calendar()
    let day = Day.date("2026-10-03", calendar: calendar())!
    let edit = cal.date(bySettingHour: 14, minute: 0, second: 0, of: day)!.addingTimeInterval(0.125)
    var s = fixture()
    let old = Medication(
      name: "Original", dosage: "Original dose", startDay: "2026-10-01",
      times: [.init(hour: 9, minute: 0), .init(hour: 20, minute: 0)])
    s.medications = [old]
    var updated = old
    updated.dosage = "Revised dose"
    updated.times = [.init(hour: 8, minute: 0), .init(hour: 21, minute: 0)]
    try MedicationHistory.save(updated, in: &s, now: edit)
    let restored = try StateCodec.decode(StateCodec.encode(s))
    let medication = restored.medications[0]
    let doses = DosePlanner.doses(medication, on: day, calendar: cal)
    XCTAssertEqual(doses.map { cal.component(.hour, from: $0.date) }, [9, 21])
    XCTAssertEqual(medication.plan(at: doses[0].date).dosage, "Original dose")
    XCTAssertEqual(medication.plan(at: doses[1].date).dosage, "Revised dose")
    XCTAssertEqual(medication.effectiveFrom, edit)
    let tomorrow = cal.date(byAdding: .day, value: 1, to: day)!
    XCTAssertEqual(
      DosePlanner.doses(medication, on: tomorrow, calendar: cal).map {
        cal.component(.hour, from: $0.date)
      }, [8, 21])
  }
  func testStopAndRestartPreserveUnconfirmedPastDoses() throws {
    let cal = calendar()
    let day = Day.date("2026-10-03", calendar: calendar())!
    let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
    var s = fixture()
    var m = Medication(
      name: "Test", dosage: "Test", startDay: "2026-10-01",
      times: [.init(hour: 9, minute: 0), .init(hour: 20, minute: 0)])
    s.medications = [m]
    m.active = false
    try MedicationHistory.save(m, in: &s, now: noon)
    XCTAssertEqual(DosePlanner.doses(s.medications[0], on: day, calendar: cal).count, 1)
    XCTAssertTrue(DosePlanner.upcoming(s, now: noon, calendar: cal).isEmpty)
    let tomorrow = cal.date(byAdding: .day, value: 1, to: noon)!
    m = s.medications[0]
    m.active = true
    try MedicationHistory.save(m, in: &s, now: tomorrow)
    XCTAssertEqual(
      DosePlanner.doses(s.medications[0], on: tomorrow, calendar: cal).map {
        cal.component(.hour, from: $0.date)
      }, [20])
    XCTAssertEqual(s.medications[0].history.count, 2)
  }
  func testUnchangedCourseDoesNotCreateHistoryAndInvalidHistoryIsRejected() throws {
    var s = fixture()
    let m = Medication(
      name: "Test", dosage: "Test", startDay: "2026-10-01", times: [.init(hour: 9, minute: 0)])
    s.medications = [m]
    try MedicationHistory.save(m, in: &s)
    XCTAssertTrue(s.medications[0].history.isEmpty)
    s.medications[0].effectiveFrom = .now
    XCTAssertThrowsError(try StateCodec.validate(s))
  }
  func testEarlyConfirmationKeepsPrescriptionSnapshotAfterEdit() throws {
    var s = fixture()
    let m = Medication(
      name: "Original", dosage: "Original dose", startDay: "2026-10-01",
      times: [.init(hour: 20, minute: 0)])
    s.medications = [m]
    let today = Day.date("2026-10-03", calendar: calendar())!
    let dose = DosePlanner.doses(m, on: today, calendar: calendar())[0]
    s.doses = [DoseRecord(id: dose.id, medicationID: m.id, plannedAt: dose.date, status: .taken)]
    var next = m
    next.name = "Changed"
    next.dosage = "Changed dose"
    try MedicationHistory.save(next, in: &s, now: today.addingTimeInterval(14 * 3600))
    XCTAssertEqual(s.doses[0].snapshot?.name, "Original")
    XCTAssertEqual(s.doses[0].snapshot?.dosage, "Original dose")
    let report = ReportBuilder.sections(
      state: s, doctors: [], from: today, through: today, calendar: calendar())
    let confirmations = report.first { $0.title == "Medication confirmations" }!.body
    XCTAssertTrue(confirmations.contains("Original dose"))
    XCTAssertFalse(confirmations.contains("Changed dose"))
  }
  func testSchemaTwoMigrationBacksUpBeforeAddingHistory() throws {
    var s = fixture()
    s.medications = [
      Medication(
        name: "Existing", dosage: "Existing", startDay: "2026-10-01",
        times: [.init(hour: 9, minute: 0)])
    ]
    var object = try JSONSerialization.jsonObject(with: StateCodec.encode(s)) as! [String: Any]
    object["schemaVersion"] = 2
    var medications = object["medications"] as! [[String: Any]]
    medications[0].removeValue(forKey: "history")
    object["medications"] = medications
    let original = try JSONSerialization.data(withJSONObject: object)
    let url = try temporary()
    try original.write(to: url)
    let repo = try StateRepository(url: url)
    XCTAssertEqual(repo.state.schemaVersion, 3)
    XCTAssertEqual(repo.state.medications[0].name, "Existing")
    XCTAssertTrue(repo.state.medications[0].history.isEmpty)
    let backup = try FileManager.default.contentsOfDirectory(
      at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil
    ).first { $0.lastPathComponent.hasPrefix("backup-") }!
    XCTAssertEqual(try Data(contentsOf: backup), original)
    XCTAssertEqual(try StateCodec.decode(Data(contentsOf: url)).schemaVersion, 3)
  }
  func testPostponeAtEndOfCourseHonorsExplicitReminder() {
    var s = fixture()
    let cal = calendar()
    let day = Day.date("2026-10-03", calendar: calendar())!
    var m = Medication(
      name: "Test", dosage: "Test", startDay: "2026-10-03", times: [.init(hour: 23, minute: 55)])
    m.endDay = "2026-10-03"
    s.medications = [m]
    let dose = DosePlanner.doses(m, on: day, calendar: cal)[0]
    var record = DoseRecord(
      id: dose.id, medicationID: m.id, plannedAt: dose.date, status: .postponed)
    record.postponedUntil = dose.date.addingTimeInterval(900)
    s.doses = [record]
    XCTAssertEqual(
      DosePlanner.upcoming(s, now: dose.date, calendar: cal).first?.date, record.postponedUntil)
  }
  func testPostponementCrossingMidnightRemainsVisibleWithoutDuplicates() {
    let cal = calendar()
    let today = Day.date("2026-10-04", calendar: calendar())!
    var state = fixture()
    let medication = Medication(
      name: "Test", dosage: "Test", startDay: "2026-10-03", times: [DoseTime(hour: 23, minute: 55)])
    state.medications = [medication]
    let yesterday = DosePlanner.doses(
      medication, on: today.addingTimeInterval(-86400), calendar: cal)[0]
    var record = DoseRecord(
      id: yesterday.id, medicationID: medication.id, plannedAt: yesterday.date, status: .postponed)
    record.postponedUntil = today.addingTimeInterval(600)
    state.doses = [record]
    XCTAssertEqual(
      DosePlanner.displayedDoses(state, medications: state.medications, on: today, calendar: cal)
        .count, 2)
    XCTAssertEqual(
      DosePlanner.displayedDoses(
        state, medications: state.medications, on: yesterday.date, calendar: cal
      ).count, 1)
  }
  func fixture() -> AppState {
    var s = AppState()
    let d = Doctor(specialty: "cardiologist")
    s.doctors = [d]
    let o = Observation(doctorID: d.id, reason: "Consultation")
    s.observations = [o]
    s.visits = [Visit(observationID: o.id, date: Date(timeIntervalSince1970: 1_800_000_000))]
    return s
  }
  func calendar(_ zone: String = "Europe/Warsaw") -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: zone)!
    return c
  }
  func temporary() throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
    return directory.appendingPathComponent("records.json")
  }
  func testEmptyFirstLaunchAndPersistence() throws {
    let url = try temporary()
    let repo = try StateRepository(url: url)
    XCTAssertTrue(repo.state.doctors.isEmpty)
    XCTAssertTrue(repo.state.events.isEmpty)
    var s = fixture()
    s.language = .pl
    try repo.commit(s)
    let reopened = try StateRepository(url: url)
    XCTAssertEqual(reopened.state.language, .pl)
    XCTAssertEqual(reopened.state.observations.first?.reason, "Consultation")
  }
  func testFailedCommitDoesNotMutateMemoryOrDisk() throws {
    let url = try temporary()
    let repo = try StateRepository(url: url)
    let s = fixture()
    try repo.commit(s)
    let original = try Data(contentsOf: url)
    var invalid = s
    invalid.observations[0].doctorID = UUID()
    XCTAssertThrowsError(try repo.commit(invalid))
    XCTAssertEqual(repo.state, s)
    XCTAssertEqual(try Data(contentsOf: url), original)
    // Filesystem failure after successful validation also preserves in-memory state.
    try FileManager.default.removeItem(at: url)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    var changed = s
    changed.language = .pl
    XCTAssertThrowsError(try repo.commit(changed))
    XCTAssertEqual(repo.state, s)
  }
  func testCorruptFileIsNotOverwritten() throws {
    let url = try temporary()
    let bytes = Data("broken".utf8)
    try bytes.write(to: url)
    XCTAssertThrowsError(try StateRepository(url: url))
    XCTAssertEqual(try Data(contentsOf: url), bytes)
  }
  func testReplaceBacksUpOriginalAndDoesNotDuplicate() throws {
    let url = try temporary()
    let repo = try StateRepository(url: url)
    try repo.commit(fixture())
    let data = try StateCodec.encode(repo.state)
    try repo.replace(with: data)
    try repo.replace(with: data)
    XCTAssertEqual(repo.state.doctors.count, 1)
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(
        at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil
      ).filter { $0.lastPathComponent.hasPrefix("backup-") }.count, 2)
  }
  func testRelationshipsAndUniqueIdentifiersValidated() throws {
    var s = fixture()
    var event = SymptomEvent(symptom: "pain")
    event.observationIDs = [UUID()]
    s.events = [event]
    XCTAssertThrowsError(try StateCodec.validate(s))
    s.events = []
    s.doctors.append(s.doctors[0])
    XCTAssertThrowsError(try StateCodec.validate(s))
  }
  func testMultiDoctorFilterDoesNotDuplicateEvents() throws {
    var s = fixture()
    let d = Doctor(specialty: "gp")
    let o = Observation(doctorID: d.id, reason: "Review")
    s.doctors.append(d)
    s.observations.append(o)
    var event = SymptomEvent(symptom: "pain")
    event.observationIDs = s.observations.map(\.id)
    s.events = [event, SymptomEvent(symptom: "fatigue")]
    try StateCodec.validate(s)
    XCTAssertEqual(
      s.events.filter { s.matches($0.observationIDs, doctors: Set(s.doctors.map(\.id))) }.count, 1)
    XCTAssertEqual(s.events.filter { s.matches($0.observationIDs, doctors: []) }.count, 2)
  }
  func testWindowsMigrationPreservesIDsDatesNotesAndLanguage() throws {
    let v = UUID()
    let e = UUID()
    let json = """
      {"version":1,"language":"pl","visit":{"id":"\(v)","specialist":"cardiologist","date":"2026-12-01","reason":"Zażółć gęślą jaźń","createdAt":"2026-10-01T10:00:00.000Z"},"events":[{"id":"\(e)","visitID":"\(v)","symptom":"palpitations","timestamp":"2026-10-02T12:34:56.000Z","note":"Notatka"}],"answers":[{"id":"legacy","visitID":"\(v)","date":"2026-10-02","symptom":"palpitations","frequency":"once","note":""}]}
      """
    let data = Data(json.utf8)
    let migrated = try StateCodec.decode(data)
    XCTAssertEqual(migrated.events[0].id, e)
    XCTAssertEqual(migrated.language, .pl)
    XCTAssertEqual(migrated.observations[0].id, v)
    XCTAssertEqual(migrated.checkIns[0].frequency, .once)
    XCTAssertEqual(
      ISO8601DateFormatter().string(from: migrated.events[0].timestamp), "2026-10-02T12:34:56Z")
    let url = try temporary()
    try data.write(to: url)
    _ = try StateRepository(url: url)
    let files = try FileManager.default.contentsOfDirectory(
      at: url.deletingLastPathComponent(), includingPropertiesForKeys: nil)
    XCTAssertEqual(
      try Data(contentsOf: files.first { $0.lastPathComponent.hasPrefix("backup-") }!), data)
    XCTAssertEqual(try StateCodec.decode(Data(contentsOf: url)).schemaVersion, 3)
  }
  func testUnknownSchemaRejected() throws {
    XCTAssertThrowsError(try StateCodec.decode(Data("{\"schemaVersion\":99}".utf8)))
  }
  func testAttachmentRoundTripAndInvalidLinks() throws {
    var s = fixture()
    let a = Attachment(name: "scan.pdf", data: Data([1, 2, 3]))
    s.attachments = [a]
    s.visits[0].attachmentIDs = [a.id]
    let decoded = try StateCodec.decode(StateCodec.encode(s))
    XCTAssertEqual(decoded.attachments[0].data, a.data)
    s.attachments = []
    XCTAssertThrowsError(try StateCodec.validate(s))
  }
  func testDuplicateDailySummaryRejected() throws {
    var s = fixture()
    let c = DailyCheckIn(
      observationID: s.observations[0].id, day: "2026-10-03", symptom: "pain", frequency: .none)
    var second = c
    second.id = UUID()
    s.checkIns = [c, second]
    XCTAssertThrowsError(try StateCodec.validate(s))
  }
  func testInvalidDatesAndSchedulesRejected() throws {
    XCTAssertFalse(Day.valid("2026-02-30"))
    XCTAssertTrue(Day.valid("2028-02-29"))
    var s = fixture()
    var m = Medication(
      name: "As prescribed", dosage: "As prescribed", startDay: "2026-10-03",
      times: [.init(hour: 9, minute: 0)])
    m.endDay = "2026-10-02"
    s.medications = [m]
    XCTAssertThrowsError(try StateCodec.validate(s))
    m.endDay = nil
    m.times = [.init(hour: 25, minute: 0)]
    s.medications = [m]
    XCTAssertThrowsError(try StateCodec.validate(s))
  }
  func testCourseEndInclusiveAndWeekdays() {
    let cal = calendar()
    var m = Medication(
      name: "Test", dosage: "Test", startDay: "2026-10-01", times: [.init(hour: 9, minute: 0)])
    m.endDay = "2026-10-03"
    XCTAssertEqual(
      DosePlanner.doses(m, on: Day.date("2026-10-03", calendar: cal)!, calendar: cal).count, 1)
    XCTAssertTrue(
      DosePlanner.doses(m, on: Day.date("2026-10-04", calendar: cal)!, calendar: cal).isEmpty)
    m.weekdays = [2]
    XCTAssertTrue(
      DosePlanner.doses(m, on: Day.date("2026-10-03", calendar: cal)!, calendar: cal).isEmpty)
  }
  func testDSTGapAndRepeatedHourProduceOneDose() {
    let cal = calendar()
    let m = Medication(
      name: "Test", dosage: "Test", startDay: "2026-01-01", times: [.init(hour: 2, minute: 30)])
    for key in ["2026-03-29", "2026-10-25"] {
      let doses = DosePlanner.doses(m, on: Day.date(key, calendar: cal)!, calendar: cal)
      XCTAssertEqual(doses.count, 1)
      XCTAssertEqual(Day.key(doses[0].date, calendar: cal), key)
    }
  }
  func testConfirmedDosesNotRescheduledAndBoundedQueue() {
    var s = fixture()
    let cal = calendar()
    let now = Day.date("2026-10-03", calendar: cal)!
    let m = Medication(
      name: "Test", dosage: "Test", startDay: "2026-10-03",
      times: [.init(hour: 9, minute: 0), .init(hour: 20, minute: 0)])
    s.medications = [m]
    let before = DosePlanner.upcoming(s, now: now, calendar: cal)
    XCTAssertEqual(before.count, 48)
    s.doses = [
      DoseRecord(id: before[0].id, medicationID: m.id, plannedAt: before[0].date, status: .taken)
    ]
    XCTAssertFalse(
      DosePlanner.upcoming(s, now: now, calendar: cal).contains { $0.id == before[0].id })
  }
  func testPostponementRetainsIdentifierAndStoppedCourseDoesNotNotify() {
    var s = fixture()
    let cal = calendar()
    let now = Day.date("2026-10-03", calendar: calendar())!
    let m = Medication(
      name: "Test", dosage: "Test", startDay: "2026-10-03", times: [.init(hour: 9, minute: 0)])
    s.medications = [m]
    let dose = DosePlanner.upcoming(s, now: now, calendar: cal)[0]
    var record = DoseRecord(
      id: dose.id, medicationID: m.id, plannedAt: dose.date, status: .postponed)
    record.postponedUntil = dose.date.addingTimeInterval(900)
    s.doses = [record]
    let after = DosePlanner.upcoming(s, now: now, calendar: cal)
    XCTAssertEqual(after.filter { $0.id == dose.id }.count, 1)
    XCTAssertEqual(after.first?.date, record.postponedUntil)
    s.medications[0].active = false
    XCTAssertTrue(DosePlanner.upcoming(s, now: now, calendar: cal).isEmpty)
  }
  func testReportSeparatesDailySummaryAndNoDataFromNoSymptoms() {
    var s = fixture()
    s.language = .en
    let sections = ReportBuilder.sections(state: s, doctors: [], from: .now, through: .now)
    XCTAssertTrue(sections.map(\.body).joined().contains("Missing entries do not mean no symptoms"))
    XCTAssertTrue(sections.contains { $0.title == "Daily check-ins (separate from events)" })
  }
  func testTimeZoneChangesWallClockButNotLogicalDoseID() {
    let m = Medication(
      name: "Test", dosage: "Test", startDay: "2026-10-03", times: [.init(hour: 9, minute: 0)])
    let a = calendar("Europe/Warsaw")
    let b = calendar("America/New_York")
    let doseA = DosePlanner.doses(m, on: Day.date("2026-10-03", calendar: a)!, calendar: a)[0]
    let doseB = DosePlanner.doses(m, on: Day.date("2026-10-03", calendar: b)!, calendar: b)[0]
    XCTAssertEqual(doseA.id, doseB.id)
    XCTAssertNotEqual(doseA.date, doseB.date)
  }
  func testPDFPaginationAndPolishTextArePreserved() throws {
    var s = fixture()
    s.language = .pl
    for index in 0..<120 {
      var event = SymptomEvent(symptom: "pain")
      event.observationIDs = [s.observations[0].id]
      event.note =
        "Wpis \(index): Zażółć gęślą jaźń. "
        + String(repeating: "Szczegółowa notatka użytkownika. ", count: 8)
      s.events.append(event)
    }
    let data = try PDFRenderer.make(
      ReportBuilder.sections(state: s, doctors: [], from: .now, through: .now))
    let pdf = PDFDocument(data: data)!
    XCTAssertTrue(pdf.pageCount > 5)
    let text = (0..<pdf.pageCount).compactMap { pdf.page(at: $0)?.string }.joined(separator: "\n")
    XCTAssertTrue(text.contains("Zażółć gęślą jaźń"))
    XCTAssertTrue(text.contains("Wpis 119"))
    XCTAssertTrue(text.contains("Podsumowanie wizyty"))
  }
  func testReportDateAndDoctorFilters() throws {
    var s = fixture()
    let d = Doctor(specialty: "gp")
    let o = Observation(doctorID: d.id, reason: "Second doctor")
    s.doctors.append(d)
    s.observations.append(o)
    var included = SymptomEvent(symptom: "pain")
    included.observationIDs = [s.observations[0].id]
    included.note = "INCLUDED"
    var excluded = SymptomEvent(symptom: "fatigue")
    excluded.observationIDs = [o.id]
    excluded.note = "EXCLUDED"
    var old = included
    old.id = UUID()
    old.timestamp = Date().addingTimeInterval(-86400 * 5)
    old.note = "OLD_ENTRY"
    s.events = [included, excluded, old]
    let text = ReportBuilder.sections(
      state: s, doctors: [s.doctors[0].id], from: .now, through: .now
    ).map(\.body).joined()
    XCTAssertTrue(text.contains("INCLUDED"))
    XCTAssertFalse(text.contains("EXCLUDED"))
    XCTAssertFalse(text.contains("OLD_ENTRY"))
  }
  func testLargeAttachmentRejectedBeforeCommit() throws {
    var s = fixture()
    s.attachments = [
      Attachment(name: "large.pdf", data: Data(repeating: 0, count: 8 * 1024 * 1024 + 1))
    ]
    XCTAssertThrowsError(try StateCodec.validate(s))
  }
}

/// Fake Strava API for client tests: refresh returns "new" tokens; activities return 100 + 1 items.
final class MockStrava: URLProtocol {
  nonisolated(unsafe) static var requests: [URLRequest] = []
  nonisolated(unsafe) static var status = 200
  static func body(_ r: URLRequest) -> String? {
    if let data = r.httpBody { return String(decoding: data, as: UTF8.self) }
    guard let stream = r.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
      let n = stream.read(&buffer, maxLength: buffer.count)
      if n <= 0 { break }
      data.append(buffer, count: n)
    }
    return String(decoding: data, as: UTF8.self)
  }
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    var r = request
    if r.httpBody == nil, let body = Self.body(request) { r.httpBody = Data(body.utf8) }
    Self.requests.append(r)
    let json: String
    if request.url?.path == "/oauth/token" || request.url?.host == "proxy.example" {
      json = #"{"access_token":"new","refresh_token":"r1","expires_at":4000000000}"#
    } else {
      let page = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "page" }?.value
      let count = page == "1" ? 100 : 1
      let offset = page == "1" ? 0 : 100
      json = "[" + (0..<count).map {
        #"{"id": \#($0 + offset), "name": "A", "sport_type": "Run", "start_date": "2026-10-01T06:30:00Z", "moving_time": 600}"#
      }.joined(separator: ",") + "]"
    }
    let response = HTTPURLResponse(url: request.url!, statusCode: Self.status, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: Data(json.utf8))
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}
}
