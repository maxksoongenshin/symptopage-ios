import SwiftUI

#if SWIFT_PACKAGE
  import SymptoCore
#endif

/// Start tab. Layout follows design screens 2–4: empty state with a quick visit form,
/// then a carousel of active observations with the daily question and the Now button.
struct TodayView: View {
  @EnvironmentObject var store: AppStore
  @State private var addVisit = false
  @State private var capture = false
  @State private var showDoses = false
  @State private var addNote = false
  @State private var openJournal = false
  @State private var openCare = false
  @State private var page: String?
  @State private var deleting: Observation?
  var body: some View {
    ZStack(alignment: .bottomTrailing) {
      if active.isEmpty { emptyLayout } else { activeLayout }
      if !store.state.observations.isEmpty {
        Button {
          capture = true
        } label: {
          Text(store.t("!!! Now!", "!!! Teraz!")).font(.brand(size: 18, .heavy))
            .padding(.horizontal, 26).frame(height: 52).foregroundStyle(.white)
            .background(Theme.alert, in: Capsule())
            .shadow(color: Theme.alert.opacity(0.35), radius: 9, y: 8).contentShape(Capsule())
        }.buttonStyle(.plain).padding(20).accessibilityIdentifier("recordSymptom")
          .accessibilityLabel(store.t("Record a symptom now", "Zapisz objaw teraz"))
      }
    }
    .navigationTitle(store.t("Start", "Start"))
    #if os(iOS)
      .toolbar(.hidden, for: .navigationBar)
    #endif
    .sheet(isPresented: $addVisit) { NewObservationForm() }
    .sheet(isPresented: $capture) { EventForm() }
    .sheet(isPresented: $showDoses) { DosePlanSheet() }
    .sheet(isPresented: $addNote) { NoteForm() }
    .navigationDestination(isPresented: $openJournal) { JournalView() }
    .navigationDestination(isPresented: $openCare) { CareView() }
    .confirmationDialog(
      store.t("Delete this doctor?", "Usunąć tego lekarza?"),
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
      titleVisibility: .visible, presenting: deleting
    ) { o in
      Button(store.t("Delete", "Usuń"), role: .destructive) { store.deleteObservation(o.id) }
      Button(store.t("Cancel", "Anuluj"), role: .cancel) {}
    } message: { _ in
      Text(
        store.t(
          "Visits and medication for this doctor will be removed. Symptoms stay in the journal.",
          "Wizyty i leki tego lekarza zostaną usunięte. Objawy zostaną w dzienniku."))
    }
  }

  /// Shortcuts that replace the former Care and Journal tabs (design has three tabs).
  private var actions: some View {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
      if !store.state.observations.isEmpty {
        ActionTile(title: store.t("Record a symptom", "Zapisz objaw"), icon: "waveform.path.ecg", tint: Theme.alert) {
          capture = true
        }.accessibilityIdentifier("tileSymptom")
      }
      ActionTile(title: store.t("Wellbeing note", "Notatka o samopoczuciu"), icon: "square.and.pencil", tint: Theme.accent) {
        addNote = true
      }.accessibilityIdentifier("addNote")
      ActionTile(title: store.t("Journal", "Dziennik"), icon: "list.bullet.rectangle.fill") {
        openJournal = true
      }.accessibilityIdentifier("openJournal")
      ActionTile(title: store.t("Doctors & medication", "Lekarze i leki"), icon: "stethoscope", tint: Color(hex: 0x5AA9D6)) {
        openCare = true
      }.accessibilityIdentifier("openCare")
    }
  }

  /// Watch / Strava data once something is connected or imported; otherwise a one-tap invitation.
  @ViewBuilder private var healthCard: some View {
    let s = store.state
    if !s.healthDays.isEmpty || s.integrations.healthEnabled {
      HealthSummaryCard()
    }
  }

  private var recent: some View {
    let notes = store.notes.prefix(3).map { (date: $0.date, view: AnyView(NoteCard(note: $0))) }
    let events = store.events.prefix(3).map { (date: $0.timestamp, view: AnyView(EventCard(event: $0))) }
    let items = (notes + events).sorted { $0.date > $1.date }.prefix(3)
    return VStack(alignment: .leading, spacing: 12) {
      if !items.isEmpty {
        SectionHeader(
          title: store.t("Recent entries", "Ostatnie wpisy"),
          action: (store.t("See all", "Zobacz wszystko"), { openJournal = true }))
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in item.view }
      }
    }
  }

  // MARK: Layouts

  private var emptyLayout: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        header(onGradient: false)
        if !store.selectedDoctors.isEmpty { FilterButton() }
        QuickVisitCard(more: { addVisit = true })
        actions
        healthCard
        recent
      }.padding(20).padding(.bottom, 80).frame(maxWidth: 700).frame(maxWidth: .infinity)
    }.background(Color(hex: 0xF7FBFA)).foregroundStyle(Theme.ink)
  }

  private var activeLayout: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        header(onGradient: true).padding(.horizontal, 22)
        if store.state.doctors.count > 1 { FilterButton().padding(.horizontal, 20) }
        carousel
        dots
        actions.padding(.horizontal, 20)
        SymptomTrendCard().padding(.horizontal, 20)
        healthCard.padding(.horizontal, 20)
        if !todayDoses.isEmpty {
          MedicationPlanCard(doses: todayDoses).padding(.horizontal, 20)
        }
        recent.padding(.horizontal, 20)
      }.padding(.top, 20).padding(.bottom, 96).frame(maxWidth: 700).frame(maxWidth: .infinity)
    }
    .background {
      GeometryReader { proxy in
        Theme.background
        Circle().fill(.white.opacity(0.28)).frame(width: 260, height: 260)
          .offset(x: proxy.size.width - 170, y: 230)
        Circle().fill(Color(hex: 0x5AA9D6).opacity(0.55)).frame(width: 240, height: 240)
          .offset(x: proxy.size.width - 170, y: 560)
        Circle().fill(.white.opacity(0.3)).frame(width: 240, height: 240).offset(x: -110, y: 470)
      }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }.foregroundStyle(Theme.ink)
  }

  private var carousel: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(alignment: .top, spacing: 12) {
        ForEach(active) { observation in
          ObservationCard(observation: observation, visit: nextVisit(observation.id))
            .contextMenu {
              Button(store.t("Delete doctor", "Usuń lekarza"), systemImage: "trash", role: .destructive) {
                deleting = observation
              }
            }
            .containerRelativeFrame(.horizontal) { width, _ in min(width - 64, 420) }
            .id(observation.id.uuidString)
        }
        AddVisitCard { addVisit = true }
          .containerRelativeFrame(.horizontal) { width, _ in min(width - 64, 420) }
          .id("add")
      }.scrollTargetLayout()
    }
    .contentMargins(.horizontal, 32, for: .scrollContent)
    .scrollTargetBehavior(.viewAligned)
    .scrollPosition(id: $page)
  }

  private var dots: some View {
    let ids = active.map(\.id.uuidString) + ["add"]
    let current = page ?? ids[0]
    return HStack(spacing: 8) {
      ForEach(ids, id: \.self) { id in
        Button {
          withAnimation { page = id }
        } label: {
          Capsule().fill(id == current ? Theme.teal : Theme.chipText.opacity(0.35))
            .frame(width: id == current ? 22 : 8, height: 8).padding(.vertical, 8)
            .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityHidden(true)
      }
    }.frame(maxWidth: .infinity)
  }

  private func header(onGradient: Bool) -> some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text(greeting).font(.brand(size: 28, .heavy)).accessibilityAddTraits(.isHeader)
        if let resting = store.latestRestingHR {
          Label(store.t("Resting HR: ", "Tętno spocz.: ") + "\(resting)", systemImage: "heart.fill")
            .font(.brand(.footnote, .bold)).accessibilityIdentifier("restingHR")
        }
        TimelineView(.everyMinute) { context in
          Text(stamp(context.date)).font(.brand(.footnote, .bold))
        }
      }
      Spacer()
      Button {
        showDoses = true
      } label: {
        Image(systemName: "bell").font(.brand(.title2, .regular)).frame(width: 44, height: 44)
          .overlay(alignment: .topTrailing) {
            if hasDueDose {
              Circle().fill(Theme.heart).frame(width: 10, height: 10)
                .overlay(Circle().stroke(onGradient ? Theme.accent : .white, lineWidth: 2))
                .offset(x: -8, y: 8)
            }
          }.contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityIdentifier("dosePlan")
        .accessibilityLabel(
          store.t("Today's medication plan", "Dzisiejszy plan leków")
            + (hasDueDose ? store.t(", doses waiting", ", dawki oczekują") : ""))
    }.foregroundStyle(onGradient ? .white : Theme.ink)
  }


  // MARK: Data

  private var greeting: String {
    let name = store.state.profileName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return name.isEmpty
      ? store.t("Hello!", "Witaj!") : store.t("Hello \(name)!", "Witaj \(name)!")
  }
  private func stamp(_ date: Date) -> String {
    let day = DateFormatter()
    day.locale = store.language.locale
    day.setLocalizedDateFormatFromTemplate("dMMM")
    let time = DateFormatter()
    time.locale = store.language.locale
    time.timeStyle = .short
    return day.string(from: date) + ", " + time.string(from: date)
  }
  private var active: [Observation] {
    store.observations.filter { $0.stage != .completed }.sorted {
      (nextVisit($0.id)?.date ?? .distantFuture, $0.createdAt)
        < (nextVisit($1.id)?.date ?? .distantFuture, $1.createdAt)
    }
  }
  private func nextVisit(_ observationID: UUID) -> Visit? {
    store.state.visits.filter { $0.observationID == observationID && !$0.completed }
      .min { $0.date < $1.date }
  }
  private var todayDoses: [ScheduledDose] {
    let medications = store.state.medications.filter { m in
      store.selectedDoctors.isEmpty
        || m.observationID.map { store.state.matches([$0], doctors: store.selectedDoctors) } == true
    }
    return DosePlanner.displayedDoses(store.state, medications: medications, on: .now)
  }
  private var hasDueDose: Bool {
    let recorded = Set(store.state.doses.map(\.id))
    return todayDoses.contains { $0.date <= .now && !recorded.contains($0.id) }
  }
}

// MARK: - Empty state

/// Design screen 2: choose a specialist and a date, then add the visit in one tap.
struct QuickVisitCard: View {
  @EnvironmentObject var store: AppStore
  let more: () -> Void
  @State private var specialty: String?
  @State private var showAll = false
  @State private var custom = ""
  @State private var date = QuickVisitCard.defaultDate
  private static var defaultDate: Date {
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
    return Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? tomorrow
  }
  private var resolved: String? {
    specialty == "custom"
      ? (custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ? nil : custom.trimmingCharacters(in: .whitespacesAndNewlines))
      : specialty
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(store.t("No active observation", "Brak aktywnej obserwacji")).font(
        .caption.weight(.bold)
      ).foregroundStyle(Color(hex: 0x9E1C1C)).padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color(hex: 0xFBE3E3), in: Capsule())
      Text(store.t("Add a doctor's visit", "Dodaj wizytę u lekarza")).font(.brand(size: 22, .heavy))
      Text(
        store.t(
          "Enter the specialist and date. Until the visit we collect your symptoms and notes in one place.",
          "Podaj specjalistę i termin. Do wizyty zbieramy Twoje objawy i notatki w jednym miejscu.")
      ).font(.brand(.subheadline)).foregroundStyle(Theme.muted)
      Text(store.t("Specialist", "Specjalista")).font(.brand(.subheadline, .bold)).padding(.top, 4)
      FlowLayout(spacing: 8) {
        ForEach(quickSpecialties, id: \.self) { value in
          Pill(title: store.language.specialty(value), selected: specialty == value) { specialty = value }
            .accessibilityIdentifier("specialty-" + value)
        }
        Pill(title: store.t("Other", "Inny"), selected: showAll) { showAll.toggle() }
          .accessibilityIdentifier("specialty-other")
      }
      if showAll {
        Text(store.t("Other specialists", "Pozostali specjaliści")).font(.brand(.caption, .bold))
          .foregroundStyle(Theme.muted)
        FlowLayout(spacing: 8) {
          ForEach(builtInSpecialties.filter { !quickSpecialties.contains($0) }, id: \.self) { value in
            Pill(title: store.language.specialty(value), selected: specialty == value) { specialty = value }
              .accessibilityIdentifier("specialty-" + value)
          }
          Pill(title: store.t("Type it", "Wpisz własną"), selected: specialty == "custom") { specialty = "custom" }
            .accessibilityIdentifier("specialty-custom")
        }
      }
      if specialty == "custom" {
        TextField(store.t("Specialty", "Specjalizacja"), text: $custom).textFieldStyle(.roundedBorder)
          .accessibilityIdentifier("customSpecialty")
      }
      Text(store.t("Visit date", "Data wizyty")).font(.brand(.subheadline, .bold)).padding(.top, 4)
      DatePicker(store.t("Visit date", "Data wizyty"), selection: $date, in: Date()...)
        .labelsHidden()
      Button {
        add()
      } label: {
        Label(store.t("Add visit", "Dodaj wizytę"), systemImage: "plus")
      }.buttonStyle(PrimaryButton()).disabled(resolved == nil).accessibilityIdentifier(
        "quickAddVisit")
      Button(store.t("More details: doctor, reason", "Więcej szczegółów: lekarz, powód")) {
        more()
      }.buttonStyle(.plain).font(.brand(.subheadline, .semibold)).foregroundStyle(Theme.teal)
        .frame(maxWidth: .infinity, minHeight: 44).accessibilityIdentifier("firstVisit")
    }.padding(18).frame(maxWidth: .infinity, alignment: .leading).foregroundStyle(Theme.ink)
      .background(.white, in: RoundedRectangle(cornerRadius: 24))
      .shadow(color: Theme.ink.opacity(0.08), radius: 12, y: 6)
  }
  private func add() {
    guard let value = resolved else { return }
    let reason = store.t("Preparing for the visit", "Przygotowanie do wizyty")
    let saved = store.change { s in
      // Reuse an unnamed doctor of the same specialty instead of creating duplicates.
      let doctorID: UUID
      if let existing = s.doctors.first(where: {
        !$0.archived && $0.name.isEmpty && $0.specialty == value
      }) {
        doctorID = existing.id
      } else {
        let doctor = Doctor(specialty: value)
        s.doctors.append(doctor)
        doctorID = doctor.id
      }
      var observation = Observation(doctorID: doctorID, reason: reason)
      observation.symptom = suggestedSymptom(forSpecialty: value)
      s.observations.append(observation)
      s.visits.append(Visit(observationID: observation.id, date: date))
    }
    if saved {
      specialty = nil
      showAll = false
      custom = ""
    }
  }
}

// MARK: - Active observation

/// Design screen 3: countdown card with the daily question overlapping it.
struct ObservationCard: View {
  @EnvironmentObject var store: AppStore
  let observation: Observation
  let visit: Visit?
  var body: some View {
    VStack(spacing: 0) {
      NavigationLink {
        if let visit { VisitDetail(visitID: visit.id) } else {
          ObservationDetail(observationID: observation.id)
        }
      } label: {
        VStack(alignment: .leading, spacing: 6) {
          Text(store.t("Active observation", "Aktywna obserwacja")).font(.brand(size: 20, .heavy))
          HStack(spacing: 8) {
            Image(systemName: "heart.fill").foregroundStyle(Theme.heart).accessibilityHidden(true)
            Text(
              store.t("Visit: ", "Wizyta: ")
                + (store.state.doctor(for: observation.id)?.title(store.language) ?? "—")
            ).lineLimit(1)
          }.font(.brand(.subheadline, .semibold)).foregroundStyle(Color(hex: 0x2E4448))
          Text(observation.reason).font(.brand(.caption)).foregroundStyle(Theme.muted).lineLimit(1)
          VStack(spacing: 2) {
            Text(countdown).font(.brand(size: 44, .heavy)).minimumScaleFactor(0.6)
              .lineLimit(1)
            Text(subtitle).font(.brand(.subheadline, .semibold)).foregroundStyle(
              Color(hex: 0x2E4448))
          }.frame(maxWidth: .infinity).padding(.top, 4)
        }.padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 74)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 28))
          .shadow(color: Theme.ink.opacity(0.10), radius: 12, y: 8)
          .contentShape(RoundedRectangle(cornerRadius: 28))
      }.buttonStyle(.plain)
      DailyQuestionCard(observation: observation).padding(.top, -56)
    }.foregroundStyle(Theme.ink)
  }
  private var countdown: String {
    guard let visit else { return observation.stage.title(store.language) }
    let calendar = Calendar.current
    let days =
      calendar.dateComponents(
        [.day], from: calendar.startOfDay(for: .now), to: calendar.startOfDay(for: visit.date)
      ).day ?? 0
    if days < 0 { return store.t("Visit date passed", "Termin minął") }
    if days == 0 { return store.t("Today", "Dzisiaj") }
    if store.language == .en { return "\(days) " + (days == 1 ? "day" : "days") }
    return "\(days) " + (days == 1 ? "dzień" : "dni")
  }
  private var subtitle: String {
    guard let visit else {
      return store.t("No visit scheduled", "Brak zaplanowanej wizyty")
    }
    let f = DateFormatter()
    f.locale = store.language.locale
    f.dateFormat = "dd.MM.yyyy"
    return store.t("until ", "do ") + f.string(from: visit.date)
  }
}

struct DailyQuestionCard: View {
  @EnvironmentObject var store: AppStore
  let observation: Observation
  @State private var note = false
  @State private var choose = false
  private var today: DailyCheckIn? {
    guard let symptom = observation.symptom else { return nil }
    let day = Day.key(.now)
    return store.state.checkIns.first {
      $0.observationID == observation.id && $0.day == day && $0.symptom == symptom
    }
  }
  var body: some View {
    VStack(spacing: 14) {
      if let symptom = observation.symptom {
        Text(question(symptom)).font(.brand(size: 20, .heavy)).multilineTextAlignment(
          .center
        ).frame(maxWidth: .infinity).accessibilityIdentifier("dailyQuestion")
        HStack(spacing: 8) {
          ForEach(Frequency.allCases, id: \.self) { value in
            let selected = today?.frequency == value
            Button {
              answer(symptom, value)
            } label: {
              Text(value.title(store.language)).font(.brand(.subheadline, .bold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(selected ? .white : Theme.chipText)
                .background(selected ? Theme.teal : Theme.chip, in: Capsule())
                .contentShape(Capsule())
            }.buttonStyle(.plain).accessibilityIdentifier("answer-" + value.rawValue)
              .accessibilityAddTraits(selected ? .isSelected : [])
          }
        }
        Divider()
        HStack {
          Button {
            note = true
          } label: {
            Label {
              Text(
                today?.note.isEmpty == false
                  ? today!.note : store.t("Add a note...", "Dodaj notatkę...")
              ).lineLimit(1)
            } icon: {
              Image(systemName: today?.note.isEmpty == false ? "square.and.pencil" : "plus")
            }.font(.brand(.subheadline, .semibold)).foregroundStyle(Theme.muted)
              .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
              .contentShape(Rectangle())
          }.buttonStyle(.plain).accessibilityIdentifier("dailyNote")
          Button(store.t("Change", "Zmień")) { choose = true }.buttonStyle(.plain)
            .font(.brand(.caption, .semibold))
            .foregroundStyle(Theme.teal).accessibilityLabel(
              store.t("Change the daily question", "Zmień codzienne pytanie"))
        }
      } else {
        Text(
          store.t("Which symptom should we ask about daily?", "O jaki objaw pytać codziennie?")
        ).font(.brand(size: 18, .heavy)).multilineTextAlignment(.center)
        Button(store.t("Choose a symptom", "Wybierz objaw")) { choose = true }.buttonStyle(
          PrimaryButton()
        ).accessibilityIdentifier("chooseDailySymptom")
      }
    }.padding(18).frame(maxWidth: .infinity).foregroundStyle(Theme.ink)
      .background(.white, in: RoundedRectangle(cornerRadius: 26))
      .shadow(color: Theme.ink.opacity(0.16), radius: 14, y: 10)
      .padding(.horizontal, 0)
      .sheet(isPresented: $note) {
        CheckInForm(
          existing: today, observationID: observation.id, symptom: observation.symptom ?? "")
      }
      .sheet(isPresented: $choose) { DailySymptomForm(observation: observation) }
  }
  private func question(_ symptom: String) -> String {
    let label = store.language.symptom(symptom)
    let name = builtInSymptoms.contains(symptom) ? label.lowercased() : label
    return store.t("Did you feel\n\(name) today?", "Czy dziś pojawiło się\n\(name)?")
  }
  private func answer(_ symptom: String, _ value: Frequency) {
    var c = DailyCheckIn(
      observationID: observation.id, day: Day.key(.now), symptom: symptom, frequency: value)
    c.wellbeing = today?.wellbeing
    c.note = today?.note ?? ""
    _ = store.saveCheckIn(c)
  }
}

/// Chooses which symptom the daily question asks about for one observation.
struct DailySymptomForm: View {
  @EnvironmentObject var store: AppStore
  let observation: Observation
  @State private var selection = ""
  @State private var custom = ""
  var body: some View {
    FormShell(
      title: store.t("Daily question", "Codzienne pytanie"),
      valid: selection == "custom"
        ? !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty : !selection.isEmpty,
      save: save
    ) {
      Section {
        Text(store.t("Ask me every day about", "Pytaj mnie codziennie o")).font(.brand(.headline))
        SymptomPicker(selection: $selection)
        if selection == "custom" {
          TextField(store.t("Symptom name", "Nazwa objawu"), text: $custom)
        }
      }
    }.onAppear { selection = observation.symptom ?? "" }
  }
  private func save() -> Bool {
    let value =
      selection == "custom" ? custom.trimmingCharacters(in: .whitespacesAndNewlines) : selection
    return store.change { s in
      guard let i = s.observations.firstIndex(where: { $0.id == observation.id }) else { return }
      s.observations[i].symptom = value
      s.observations[i].updatedAt = .now
    }
  }
}

/// Design screen 4: the last carousel page invites another doctor.
struct AddVisitCard: View {
  @EnvironmentObject var store: AppStore
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      VStack(spacing: 12) {
        Image(systemName: "plus.circle.fill").font(.system(size: 44)).foregroundStyle(Theme.teal)
        Text(store.t("Add visit", "Dodaj wizytę")).font(.brand(size: 20, .heavy))
        Text(store.t("Choose another doctor", "Wybierz kolejnego lekarza")).font(
          .subheadline.weight(.semibold))
      }.padding(24).frame(maxWidth: .infinity, minHeight: 380).foregroundStyle(Theme.ink)
        .background(.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 28))
        .overlay(
          RoundedRectangle(cornerRadius: 28).strokeBorder(
            .white.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [7]))
        ).contentShape(RoundedRectangle(cornerRadius: 28))
    }.buttonStyle(.plain).accessibilityIdentifier("addAnotherVisit")
  }
}

// MARK: - Medication

struct MedicationPlanCard: View {
  @EnvironmentObject var store: AppStore
  let doses: [ScheduledDose]
  var body: some View {
    SoftCard {
      VStack(alignment: .leading, spacing: 12) {
        Label(store.t("Today's medication plan", "Dzisiejszy plan leków"), systemImage: "pills")
          .font(.brand(.headline))
        if doses.isEmpty {
          Text(store.t("No doses scheduled today.", "Brak zaplanowanych dawek na dziś."))
            .foregroundStyle(Theme.muted)
        }
        ForEach(doses) { dose in DoseRow(dose: dose) }
      }
    }
  }
}
struct DosePlanSheet: View {
  @EnvironmentObject var store: AppStore
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    NavigationStack {
      SoftScreen {
        MedicationPlanCard(
          doses: DosePlanner.displayedDoses(
            store.state, medications: store.state.medications, on: .now))
        Text(store.notificationStatus).font(.brand(.footnote)).foregroundStyle(Theme.muted)
      }.navigationTitle(store.t("Medication plan", "Plan leków"))
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Done", "Gotowe")) { dismiss() }
          }
        }
    }
    #if os(macOS)
      .frame(minWidth: 420, idealWidth: 480, minHeight: 520, idealHeight: 640)
    #endif
  }
}
struct DoseRow: View {
  @EnvironmentObject var store: AppStore
  let dose: ScheduledDose
  private func statusButton(_ title: String, _ icon: String, _ status: DoseStatus, _ current: DoseStatus?)
    -> some View
  {
    let selected = current == status
    return Button {
      store.mark(dose, status: status)
    } label: {
      Label(title, systemImage: icon).font(.brand(.caption, .bold)).lineLimit(1).minimumScaleFactor(0.8)
        .frame(maxWidth: .infinity, minHeight: 38)
        .foregroundStyle(selected ? .white : Theme.chipText)
        .background(selected ? (status == .taken ? Theme.teal : status == .skipped ? Theme.alert : Color(hex: 0xF2B544)) : Theme.chip, in: Capsule())
        .contentShape(Capsule())
    }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
      .accessibilityIdentifier("dose-\(status.rawValue)")
  }
  var body: some View {
    if let medication = store.state.medications.first(where: { $0.id == dose.medicationID }) {
      let plan =
        store.state.doses.first(where: { $0.id == dose.id })?.snapshot
        ?? medication.plan(at: dose.date)
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top) {
          Text(dose.date, style: .time).font(.brand(.headline)).monospacedDigit()
          VStack(alignment: .leading) {
            Text(plan.name).font(.brand(.headline))
            Text(plan.dosage).font(.brand(.subheadline))
          }
          Spacer()
        }
        if !Calendar.current.isDateInToday(dose.date) {
          Text(store.language.date(dose.date)).font(.brand(.caption))
        }
        if !plan.instructions.isEmpty { Text(plan.instructions).font(.brand(.footnote)) }
        if let record = store.state.doses.first(where: { $0.id == dose.id }) {
          Label(
            record.status.title(store.language),
            systemImage: record.status == .taken ? "checkmark.circle.fill" : "clock"
          ).foregroundStyle(Theme.teal)
          if let until = record.postponedUntil, record.status == .postponed {
            Text(store.t("Reminder: ", "Przypomnienie: ") + store.language.date(until, time: true))
              .font(.brand(.caption))
          }
        }
        let record = store.state.doses.first(where: { $0.id == dose.id })
        HStack(spacing: 8) {
          statusButton(store.t("Taken", "Przyjęto"), "checkmark", .taken, record?.status)
          statusButton(store.t("Skipped", "Pominięto"), "xmark", .skipped, record?.status)
          statusButton(store.t("+15 min", "+15 min"), "clock.arrow.circlepath", .postponed, record?.status)
        }
        if record != nil {
          Button(store.t("Clear confirmation", "Usuń potwierdzenie")) {
            _ = store.change { $0.doses.removeAll { $0.id == dose.id } }
          }.buttonStyle(.plain).font(.brand(.caption, .semibold)).foregroundStyle(Theme.muted)
        }
        Divider()
      }.padding(.vertical, 4)
    }
  }
}
