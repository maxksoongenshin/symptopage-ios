import Foundation

/// Built-in symptom and specialty catalog. Stored records keep only the stable `key`,
/// so labels can change language without rewriting user data.
public enum SymptomCategory: String, CaseIterable, Sendable {
  case heart, breathing, head, digestion, movement, general, mood, skin
  public func title(_ l: Language) -> String {
    switch self {
    case .heart: return l.text("Heart and circulation", "Serce i krążenie")
    case .breathing: return l.text("Breathing", "Oddychanie")
    case .head: return l.text("Head and nerves", "Głowa i układ nerwowy")
    case .digestion: return l.text("Digestion", "Trawienie")
    case .movement: return l.text("Muscles and joints", "Mięśnie i stawy")
    case .general: return l.text("General", "Ogólne")
    case .mood: return l.text("Mood", "Samopoczucie psychiczne")
    case .skin: return l.text("Skin", "Skóra")
    }
  }
}
public struct SymptomInfo: Sendable {
  public let key: String
  public let category: SymptomCategory
  public let en: String
  public let pl: String
  /// SF Symbol name used by the app; Core does not render it.
  public let icon: String
}
public struct SpecialtyInfo: Sendable {
  public let key: String
  public let en: String
  public let pl: String
  /// Typical symptoms, most relevant first. The first one is the default daily question.
  public let symptoms: [String]
}
public enum Catalog {
  public static let symptoms: [SymptomInfo] = [
    .init(key: "palpitations", category: .heart, en: "Heart palpitations", pl: "Kołatanie serca", icon: "heart.fill"),
    .init(key: "chest_pain", category: .heart, en: "Chest pain", pl: "Ból w klatce piersiowej", icon: "heart.text.square.fill"),
    .init(key: "swelling", category: .heart, en: "Leg swelling", pl: "Obrzęki nóg", icon: "drop.fill"),
    .init(key: "fainting", category: .heart, en: "Fainting or near-fainting", pl: "Omdlenie lub zasłabnięcie", icon: "figure.fall"),
    .init(key: "dyspnea", category: .breathing, en: "Shortness of breath", pl: "Duszność", icon: "lungs.fill"),
    .init(key: "cough", category: .breathing, en: "Cough", pl: "Kaszel", icon: "wind"),
    .init(key: "wheezing", category: .breathing, en: "Wheezing", pl: "Świszczący oddech", icon: "lungs"),
    .init(key: "headache", category: .head, en: "Headache", pl: "Ból głowy", icon: "brain.head.profile"),
    .init(key: "dizziness", category: .head, en: "Dizziness", pl: "Zawroty głowy", icon: "tornado"),
    .init(key: "numbness", category: .head, en: "Numbness or tingling", pl: "Drętwienie lub mrowienie", icon: "hand.raised.fill"),
    .init(key: "vision", category: .head, en: "Vision problems", pl: "Zaburzenia widzenia", icon: "eye.fill"),
    .init(key: "memory", category: .head, en: "Concentration problems", pl: "Problemy z koncentracją", icon: "brain"),
    .init(key: "nausea", category: .digestion, en: "Nausea", pl: "Nudności", icon: "fork.knife"),
    .init(key: "abdominal_pain", category: .digestion, en: "Abdominal pain", pl: "Ból brzucha", icon: "cross.case.fill"),
    .init(key: "heartburn", category: .digestion, en: "Heartburn", pl: "Zgaga", icon: "flame.fill"),
    .init(key: "bowel", category: .digestion, en: "Bowel changes", pl: "Zmiany rytmu wypróżnień", icon: "arrow.triangle.2.circlepath"),
    .init(key: "pain", category: .movement, en: "Pain", pl: "Ból", icon: "bolt.heart.fill"),
    .init(key: "joint_pain", category: .movement, en: "Joint pain", pl: "Ból stawów", icon: "figure.walk"),
    .init(key: "back_pain", category: .movement, en: "Back pain", pl: "Ból pleców", icon: "figure.stand"),
    .init(key: "stiffness", category: .movement, en: "Morning stiffness", pl: "Sztywność poranna", icon: "figure.cooldown"),
    .init(key: "fatigue", category: .general, en: "Fatigue", pl: "Zmęczenie", icon: "battery.25"),
    .init(key: "fever", category: .general, en: "Fever", pl: "Gorączka", icon: "thermometer.medium"),
    .init(key: "sleep", category: .general, en: "Sleep problems", pl: "Problemy ze snem", icon: "moon.zzz.fill"),
    .init(key: "sweating", category: .general, en: "Night sweats", pl: "Nocne poty", icon: "drop.triangle.fill"),
    .init(key: "appetite", category: .general, en: "Appetite changes", pl: "Zmiany apetytu", icon: "fork.knife.circle"),
    .init(key: "anxiety", category: .mood, en: "Anxiety", pl: "Niepokój", icon: "cloud.bolt.fill"),
    .init(key: "low_mood", category: .mood, en: "Low mood", pl: "Obniżony nastrój", icon: "cloud.rain.fill"),
    .init(key: "irritability", category: .mood, en: "Irritability", pl: "Drażliwość", icon: "exclamationmark.bubble.fill"),
    .init(key: "rash", category: .skin, en: "Rash", pl: "Wysypka", icon: "allergens"),
    .init(key: "itching", category: .skin, en: "Itching", pl: "Swędzenie", icon: "hand.point.up.left.fill"),
  ]
  public static let specialties: [SpecialtyInfo] = [
    .init(key: "gp", en: "Family doctor", pl: "Lekarz rodzinny", symptoms: ["fatigue", "fever", "cough", "pain"]),
    .init(key: "cardiologist", en: "Cardiologist", pl: "Kardiolog", symptoms: ["palpitations", "chest_pain", "dyspnea", "swelling", "dizziness"]),
    .init(key: "neurologist", en: "Neurologist", pl: "Neurolog", symptoms: ["headache", "dizziness", "numbness", "memory", "vision"]),
    .init(key: "internist", en: "Internist", pl: "Internista", symptoms: ["fatigue", "fever", "abdominal_pain", "appetite"]),
    .init(key: "endocrinologist", en: "Endocrinologist", pl: "Endokrynolog", symptoms: ["fatigue", "sweating", "appetite", "palpitations"]),
    .init(key: "orthopedist", en: "Orthopaedist", pl: "Ortopeda", symptoms: ["joint_pain", "back_pain", "stiffness", "pain"]),
    .init(key: "gastroenterologist", en: "Gastroenterologist", pl: "Gastroenterolog", symptoms: ["abdominal_pain", "nausea", "heartburn", "bowel"]),
    .init(key: "pulmonologist", en: "Pulmonologist", pl: "Pulmonolog", symptoms: ["dyspnea", "cough", "wheezing", "fatigue"]),
    .init(key: "rheumatologist", en: "Rheumatologist", pl: "Reumatolog", symptoms: ["joint_pain", "stiffness", "fatigue", "fever"]),
    .init(key: "dermatologist", en: "Dermatologist", pl: "Dermatolog", symptoms: ["rash", "itching"]),
    .init(key: "allergist", en: "Allergist", pl: "Alergolog", symptoms: ["rash", "itching", "wheezing", "cough"]),
    .init(key: "psychiatrist", en: "Psychiatrist", pl: "Psychiatra", symptoms: ["anxiety", "low_mood", "sleep", "irritability"]),
    .init(key: "gynecologist", en: "Gynaecologist", pl: "Ginekolog", symptoms: ["abdominal_pain", "pain", "fatigue"]),
    .init(key: "ent", en: "ENT specialist", pl: "Laryngolog", symptoms: ["dizziness", "cough", "headache"]),
    .init(key: "ophthalmologist", en: "Ophthalmologist", pl: "Okulista", symptoms: ["vision", "headache"]),
    .init(key: "urologist", en: "Urologist", pl: "Urolog", symptoms: ["pain", "abdominal_pain"]),
  ]
  public static let noteTags: [(key: String, en: String, pl: String)] = [
    ("sleep", "Sleep", "Sen"), ("stress", "Stress", "Stres"), ("food", "Food", "Jedzenie"),
    ("activity", "Activity", "Aktywność"), ("medication", "Medication", "Leki"),
    ("work", "Work", "Praca"), ("weather", "Weather", "Pogoda"), ("family", "Family", "Rodzina"),
    ("watch", "Apple Watch", "Apple Watch"),
  ]
  public static func symptom(_ key: String) -> SymptomInfo? { symptoms.first { $0.key == key } }
  public static func specialty(_ key: String) -> SpecialtyInfo? { specialties.first { $0.key == key } }
  public static func symptoms(in category: SymptomCategory) -> [SymptomInfo] {
    symptoms.filter { $0.category == category }
  }
}
public let builtInSymptoms = Catalog.symptoms.map(\.key)
public let builtInSpecialties = Catalog.specialties.map(\.key)
/// Specialists offered as quick choices on the start screen, in design order.
public let quickSpecialties = ["cardiologist", "neurologist", "internist"]
/// Suggested daily question for a new observation. Nil means the user chooses it.
public func suggestedSymptom(forSpecialty specialty: String) -> String? {
  Catalog.specialty(specialty)?.symptoms.first
}

/// Self-reported mood for a wellbeing note. Not a clinical scale.
public enum Mood: Int, Codable, CaseIterable, Sendable {
  case veryBad = 1, bad, okay, good, veryGood
  public func title(_ l: Language) -> String {
    switch self {
    case .veryBad: return l.text("Very bad", "Bardzo źle")
    case .bad: return l.text("Bad", "Źle")
    case .okay: return l.text("So-so", "Średnio")
    case .good: return l.text("Good", "Dobrze")
    case .veryGood: return l.text("Very good", "Bardzo dobrze")
    }
  }
}
/// Free-form note about how the user feels ("Notatki o samopoczuciu").
public struct WellbeingNote: Codable, Identifiable, Equatable, Sendable {
  public var id = UUID()
  public var date = Date()
  public var mood: Mood?
  public var text: String
  public var tags: [String] = []
  public var observationIDs: [UUID] = []
  public var createdAt = Date()
  public var updatedAt = Date()
  public init(text: String, mood: Mood? = nil) {
    self.text = text
    self.mood = mood
  }
}
