import SwiftUI

#if SWIFT_PACKAGE
  import SymptoCore
#endif

struct EventForm: View {
  @EnvironmentObject var store: AppStore
  @State var event: SymptomEvent
  @State private var custom = ""
  @State private var intensityEnabled: Bool
  @State private var durationEnabled: Bool
  @State private var intensity = 5
  @State private var duration = 10
  init(event: SymptomEvent = SymptomEvent(symptom: "")) {
    _event = State(initialValue: event)
    _intensityEnabled = State(initialValue: event.intensity != nil)
    _durationEnabled = State(initialValue: event.durationMinutes != nil)
    _intensity = State(initialValue: event.intensity ?? 5)
    _duration = State(initialValue: event.durationMinutes ?? 10)
    if !event.symptom.isEmpty && !builtInSymptoms.contains(event.symptom) {
      _custom = State(initialValue: event.symptom)
      var draft = event
      draft.symptom = "custom"
      _event = State(initialValue: draft)
    }
  }
  var body: some View {
    FormShell(
      title: store.t("Record a symptom", "Zapisz objaw"),
      valid: !event.symptom.isEmpty
        && (event.symptom != "custom"
          || !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty),
      save: save
    ) {
      Section(store.t("What happened?", "Co się wydarzyło?")) {
        SymptomPicker(selection: $event.symptom)
        if event.symptom == "custom" {
          TextField(store.t("Symptom name", "Nazwa objawu"), text: $custom)
        }
        DatePicker(store.t("When", "Kiedy"), selection: $event.timestamp, in: ...Date())
        TextField(
          store.t("Note (optional)", "Notatka (opcjonalnie)"), text: $event.note, axis: .vertical
        ).lineLimit(3...6).accessibilityIdentifier("eventNote")
      }
      Section(store.t("More detail (optional)", "Szczegóły (opcjonalnie)")) {
        Toggle(store.t("Record intensity", "Zapisz nasilenie"), isOn: $intensityEnabled)
        if intensityEnabled {
          Stepper(
            store.t("Intensity", "Nasilenie") + ": \(intensity)/10", value: $intensity, in: 1...10)
          Text(
            store.t(
              "1 = mild, 10 = strongest you can imagine",
              "1 = łagodne, 10 = najsilniejsze, jakie możesz sobie wyobrazić")
          ).font(.brand(.caption))
        }
        Toggle(store.t("Record duration", "Zapisz czas trwania"), isOn: $durationEnabled)
        if durationEnabled {
          TextField(
            store.t("Duration in minutes", "Czas w minutach"), value: $duration, format: .number)
        }
        TextField(
          store.t("Context or possible trigger", "Okoliczności lub możliwy czynnik"),
          text: $event.context, axis: .vertical)
      }
      ObservationMultiPicker(selected: $event.observationIDs)
    }
  }
  private func save() -> Bool {
    var next = event
    if next.symptom == "custom" {
      next.symptom = custom.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    next.intensity = intensityEnabled ? intensity : nil
    next.durationMinutes = durationEnabled ? duration : nil
    return store.saveEvent(next)
  }
}
struct CheckInForm: View {
  private let editingID: UUID?
  @EnvironmentObject var store: AppStore
  @State private var observationID: UUID?
  @State private var date = Date()
  @State private var symptom = ""
  @State private var frequency: Frequency?
  @State private var wellbeing: Wellbeing?
  @State private var note = ""
  @State private var loaded = false
  private struct Draft {
    var frequency: Frequency?
    var wellbeing: Wellbeing?
    var note: String
  }
  @State private var drafts: [String: Draft] = [:]
  @State private var currentKey = ""
  init(existing: DailyCheckIn? = nil, observationID: UUID? = nil, symptom: String = "") {
    editingID = existing?.id
    _observationID = State(initialValue: existing?.observationID ?? observationID)
    _symptom = State(initialValue: existing?.symptom ?? symptom)
    if let existing { _date = State(initialValue: Day.date(existing.day) ?? .now) }
  }
  var body: some View {
    FormShell(
      title: store.t("Daily check-in", "Codzienny wpis"),
      valid: !symptom.isEmpty && frequency != nil, save: save
    ) {
      Section {
        ObservationPicker(selected: $observationID)
        DatePicker(
          store.t("Day", "Dzień"), selection: $date, in: ...Date(), displayedComponents: .date)
        Text(store.t("Choose a symptom", "Wybierz objaw")).font(.brand(.headline))
        SymptomPicker(selection: $symptom, allowCustom: false)
      }
      Section(store.t("How often today?", "Jak często dzisiaj?")) {
        if symptom.isEmpty {
          Text(
            store.t(
              "Choose a symptom above, then answer the question.",
              "Wybierz objaw powyżej, a następnie odpowiedz na pytanie."))
        } else {
          Text(store.t("Did you experience this symptom today?", "Czy ten objaw wystąpił dzisiaj?"))
            .font(.brand(.title3))
          Text(store.language.symptom(symptom)).font(.brand(.headline)).foregroundStyle(Theme.teal)
        }
        ChoiceGrid(
          title: store.t("Frequency", "Częstotliwość"),
          options: Frequency.allCases.map { Optional($0) }, selection: $frequency
        ) { $0?.title(store.language) ?? "" }
        .disabled(symptom.isEmpty)
        ChoiceGrid(
          title: store.t(
            "Compared with before (optional)", "W porównaniu z poprzednim stanem (opcjonalnie)"),
          options: [nil] + Wellbeing.allCases.map { Optional($0) }, selection: $wellbeing
        ) {
          $0?.title(store.language) ?? store.t("Not specified", "Nie podano")
        }.disabled(symptom.isEmpty)
        TextField(store.t("Note", "Notatka"), text: $note, axis: .vertical)
        Text(
          store.t(
            "Saving updates the check-in for this day, symptom and observation. It does not create an individual symptom event.",
            "Zapis aktualizuje wpis dla tego dnia, objawu i obserwacji. Nie tworzy pojedynczego zdarzenia objawu."
          )
        ).font(.brand(.footnote))
      }
    }.onAppear {
      if !loaded {
        load()
        loaded = true
      }
    }
    .onChange(of: observationID) { _, _ in load() }.onChange(of: date) { _, _ in load() }.onChange(
      of: symptom
    ) { _, _ in load() }
  }
  private func load() {
    if loaded { drafts[currentKey] = Draft(frequency: frequency, wellbeing: wellbeing, note: note) }
    currentKey = "\(observationID?.uuidString ?? "general")/\(Day.key(date))/\(symptom)"
    if let draft = drafts[currentKey] {
      frequency = draft.frequency
      wellbeing = draft.wellbeing
      note = draft.note
      return
    }
    let old = store.state.checkIns.first {
      $0.observationID == observationID && $0.day == Day.key(date) && $0.symptom == symptom
    }
    frequency = old?.frequency
    wellbeing = old?.wellbeing
    note = old?.note ?? ""
  }
  private func save() -> Bool {
    guard let frequency else { return false }
    var c = DailyCheckIn(
      observationID: observationID, day: Day.key(date), symptom: symptom, frequency: frequency)
    c.wellbeing = wellbeing
    c.note = note
    return store.saveCheckIn(c, editingID: editingID)
  }
}

/// Catalog symptoms grouped by category, recent custom symptoms first, then "custom".
struct SymptomPicker: View {
  @EnvironmentObject var store: AppStore
  @Binding var selection: String
  var allowCustom = true
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      if !recent.isEmpty {
        group(store.t("Recently used", "Ostatnio używane"), recent, id: "recent-")
      }
      ForEach(SymptomCategory.allCases, id: \.self) { category in
        group(category.title(store.language), Catalog.symptoms(in: category).map(\.key))
      }
      if allowCustom { group(store.t("Not on the list?", "Nie ma na liście?"), ["custom"]) }
    }.padding(.vertical, 4)
  }
  /// Up to six most recent symptoms, including the user's own names.
  private var recent: [String] {
    var seen = Set<String>()
    let used =
      store.state.events.sorted { $0.timestamp > $1.timestamp }.map(\.symptom)
      + store.state.checkIns.sorted { $0.day > $1.day }.map(\.symptom)
    return used.filter { seen.insert($0).inserted }.prefix(6).map { $0 }
  }
  private func group(_ title: String, _ keys: [String], id prefix: String = "") -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.brand(.caption, .bold)).foregroundStyle(Theme.muted)
      FlowLayout(spacing: 8) {
        ForEach(keys, id: \.self) { key in
          let selected = selection == key
          Button {
            selection = key
          } label: {
            Label(
              key == "custom" ? store.t("Custom symptom", "Własny objaw") : store.language.symptom(key),
              systemImage: key == "custom" ? "plus" : Catalog.symptom(key)?.icon ?? "waveform.path.ecg"
            ).font(.brand(.subheadline, .bold)).padding(.horizontal, 14).frame(minHeight: 40)
              .foregroundStyle(selected ? .white : Theme.chipText)
              .background(selected ? Theme.teal : Theme.chip, in: Capsule()).contentShape(Capsule())
          }.buttonStyle(.plain).accessibilityIdentifier(prefix + "symptom-" + key)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
      }
    }
  }
}
