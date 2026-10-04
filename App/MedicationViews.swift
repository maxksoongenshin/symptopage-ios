import SwiftUI

#if SWIFT_PACKAGE
  import SymptoCore
#endif

struct MedicationPlanView: View {
  @EnvironmentObject var store: AppStore
  @State private var adding = false
  @State private var editing: Medication?
  @State private var day = Date()
  var body: some View {
    SoftScreen {
      FilterButton()
      DatePicker(
        store.t("Plan for day", "Plan na dzień"), selection: $day, displayedComponents: .date)
      Text(store.t("Dose confirmations", "Potwierdzenia dawek")).font(.brand(.title2))
      ForEach(doses) { DoseRow(dose: $0) }
      if doses.isEmpty {
        Text(store.t("No scheduled doses for this day.", "Brak zaplanowanych dawek na ten dzień."))
          .foregroundStyle(Theme.muted)
      }
      Text(store.t("Courses", "Kuracje")).font(.brand(.title2))
      ForEach(medications) { m in
        SoftCard {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text(m.name).font(.brand(.headline))
              Spacer()
              if !m.active { Text(store.t("Stopped", "Zatrzymano")).font(.brand(.caption)) }
            }
            Text(m.dosage)
            Text(m.times.map(\.label).joined(separator: " · ")).font(.brand(.headline)).foregroundStyle(
              Theme.teal)
            Text("\(m.startDay) — \(m.endDay ?? store.t("No end date", "Bez daty końcowej"))").font(
              .caption)
            if !m.instructions.isEmpty { Text(m.instructions) }
            Button(store.t("Edit course", "Edytuj kurację")) { editing = m }.buttonStyle(SecondaryButton())
            if !m.history.isEmpty {
              DisclosureGroup(store.t("Previous plans", "Poprzednie plany")) {
                ForEach(Array(m.history.enumerated().reversed()), id: \.offset) { _, revision in
                  VStack(alignment: .leading, spacing: 4) {
                    Text(revision.plan.name + " · " + revision.plan.dosage).font(
                      .subheadline.bold())
                    Text(revision.plan.times.map(\.label).joined(separator: " · "))
                    Text(store.t("Until ", "Do ") + store.language.date(revision.until, time: true))
                      .font(.brand(.caption))
                    if !revision.plan.active {
                      Text(store.t("Stopped", "Zatrzymano")).font(.brand(.caption))
                    }
                  }.padding(.vertical, 6)
                }
              }
            }
          }
        }
      }
      Button(store.t("Add prescribed medication", "Dodaj przepisany lek")) { adding = true }
        .buttonStyle(PrimaryButton())
      Text(store.notificationStatus).font(.brand(.footnote)).foregroundStyle(Theme.muted)
      Text(
        store.t(
          "Follow the prescribed plan. The end of a course does not confirm recovery. Changes apply from the moment you save; earlier schedules and confirmations remain in your history.",
          "Postępuj zgodnie z zaleceniami. Koniec kuracji nie potwierdza wyzdrowienia. Zmiany obowiązują od zapisania; wcześniejsze harmonogramy i potwierdzenia pozostają w historii."
        )
      ).font(.brand(.footnote)).foregroundStyle(Theme.muted)
    }.navigationTitle(store.t("Medication plan", "Plan leków"))
      .sheet(isPresented: $adding) { MedicationForm() }
      .sheet(item: $editing) { MedicationForm(medication: $0) }
  }
  private var medications: [Medication] {
    store.state.medications.filter { m in
      store.selectedDoctors.isEmpty
        || m.observationID.map { store.state.matches([$0], doctors: store.selectedDoctors) } == true
    }
  }
  private var doses: [ScheduledDose] {
    DosePlanner.displayedDoses(store.state, medications: medications, on: day)
  }
}
struct MedicationForm: View {
  @EnvironmentObject var store: AppStore
  @State private var medication: Medication
  @State private var start: Date
  @State private var end: Date
  @State private var hasEnd: Bool
  @State private var confirmed = false
  private struct TimeRow: Identifiable {
    let id = UUID()
    var date: Date
  }
  @State private var timeRows: [TimeRow]
  private var selectedTimes: [DoseTime] {
    timeRows.map {
      DoseTime(
        hour: Calendar.current.component(.hour, from: $0.date),
        minute: Calendar.current.component(.minute, from: $0.date))
    }
  }
  init(medication: Medication? = nil, observationID: UUID? = nil) {
    var m =
      medication
      ?? Medication(
        name: "", dosage: "", startDay: Day.key(.now), times: [DoseTime(hour: 9, minute: 0)])
    if medication == nil { m.observationID = observationID }
    _medication = State(initialValue: m)
    _timeRows = State(
      initialValue: m.times.map { time in
        TimeRow(
          date: Calendar.current.date(
            bySettingHour: time.hour, minute: time.minute, second: 0, of: .now) ?? .now)
      })
    _start = State(initialValue: Day.date(m.startDay) ?? .now)
    _end = State(
      initialValue: m.endDay.flatMap { Day.date($0) } ?? Date().addingTimeInterval(6 * 86400))
    _hasEnd = State(initialValue: medication == nil || m.endDay != nil)
  }
  var body: some View {
    FormShell(
      title: store.t("Prescribed course", "Przepisana kuracja"),
      valid: !medication.name.isEmpty && !medication.dosage.isEmpty && confirmed
        && !timeRows.isEmpty && Set(selectedTimes).count == timeRows.count
        && !medication.weekdays.isEmpty
        && (!hasEnd || Day.key(end) >= Day.key(start)), save: save
    ) {
      Section(store.t("Copy from your prescription", "Przepisz z zaleceń")) {
        TextField(store.t("Medication name", "Nazwa leku"), text: $medication.name)
        TextField(
          store.t("Dose and units as prescribed", "Dawka i jednostki zgodnie z zaleceniem"),
          text: $medication.dosage)
        TextField(
          store.t("Instructions", "Sposób przyjmowania"), text: $medication.instructions,
          axis: .vertical)
        ObservationPicker(selected: $medication.observationID)
      }
      Section(store.t("Course dates", "Daty kuracji")) {
        DatePicker(store.t("Start", "Początek"), selection: $start, displayedComponents: .date)
        Toggle(store.t("Has an end date", "Ma datę końcową"), isOn: $hasEnd)
        if hasEnd {
          DatePicker(
            store.t("Last day (inclusive)", "Ostatni dzień (włącznie)"), selection: $end,
            in: start..., displayedComponents: .date)
        }
        Toggle(store.t("Course active", "Kuracja aktywna"), isOn: $medication.active)
      }
      Section(store.t("Local times", "Godziny lokalne")) {
        ForEach($timeRows) { $row in
          HStack {
            DatePicker(
              store.t("Dose time", "Godzina dawki"), selection: $row.date,
              displayedComponents: .hourAndMinute)
            Button(role: .destructive) {
              timeRows.removeAll { $0.id == row.id }
            } label: {
              Image(systemName: "minus.circle").accessibilityLabel(
                store.t("Remove time", "Usuń godzinę"))
            }.buttonStyle(.borderless)
          }
        }
        Button(store.t("Add time", "Dodaj godzinę")) {
          let used = Set(selectedTimes.map(\.hour))
          let hour = (0..<24).map { (9 + $0) % 24 }.first { !used.contains($0) } ?? 9
          timeRows.append(
            TimeRow(
              date: Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now)
                ?? .now))
        }.disabled(timeRows.count >= 8)
        if Set(selectedTimes).count != timeRows.count {
          Text(store.t("Each dose time must be different.", "Każda godzina dawki musi być inna."))
            .foregroundStyle(.red)
        }
        Text(
          store.t(
            "Times follow the device's local timezone. Reopen the app after changing timezone. Confirm travel schedules with your clinician.",
            "Godziny odpowiadają lokalnej strefie urządzenia. Otwórz aplikację po zmianie strefy. Harmonogram podczas podróży uzgodnij z lekarzem."
          )
        ).font(.brand(.footnote))
      }
      Section(store.t("Days of week", "Dni tygodnia")) {
        ForEach(1...7, id: \.self) { weekday in
          Toggle(
            weekdayName(weekday),
            isOn: Binding(
              get: { medication.weekdays.contains(weekday) },
              set: { on in
                if on {
                  medication.weekdays.append(weekday)
                } else {
                  medication.weekdays.removeAll { $0 == weekday }
                }
              }))
        }
      }
      Section {
        if store.state.medications.contains(where: { $0.id == medication.id }) {
          Text(
            store.t(
              "Changes apply from saving. Earlier doses keep the previous plan.",
              "Zmiany obowiązują od zapisania. Wcześniejsze dawki zachowają poprzedni plan.")
          ).font(.brand(.footnote))
        }
        Toggle(
          store.t("I checked this against the prescription", "Sprawdzono zgodność z zaleceniem"),
          isOn: $confirmed)
        Text(
          store.t(
            "Saving a course does not enable notifications automatically. Enable reminders in Settings.",
            "Zapisanie kuracji nie włącza automatycznie powiadomień. Włącz przypomnienia w Ustawieniach."
          )
        ).font(.brand(.footnote))
      }
    }
  }
  private func weekdayName(_ value: Int) -> String {
    let f = DateFormatter()
    f.locale = store.language.locale
    return f.weekdaySymbols[value - 1]
  }
  private func save() -> Bool {
    var m = medication
    m.times = selectedTimes
    m.startDay = Day.key(start)
    m.endDay = hasEnd ? Day.key(end) : nil
    m.updatedAt = .now
    return store.change { s in
      try MedicationHistory.save(m, in: &s)
      if let id = m.observationID,
        let index = s.observations.firstIndex(where: { $0.id == id && $0.stage == .visited })
      {
        s.observations[index].stage = .treatment
        s.observations[index].updatedAt = .now
      }
    }
  }
}
