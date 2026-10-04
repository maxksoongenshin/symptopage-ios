import QuickLook
import SwiftUI
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
  import SymptoCore
#endif

struct CareView: View {
  @EnvironmentObject var store: AppStore
  @State private var adding = false
  @State private var showArchived = false
  var body: some View {
    SoftScreen {
      Text(store.t("Your care, connected.", "Twoja opieka w jednym miejscu.")).font(
        .largeTitle.bold())
      FilterButton()
      NavigationLink {
        MedicationPlanView()
      } label: {
        SoftCard {
          Label(
            store.t("Medication plan & confirmations", "Plan leków i potwierdzenia"),
            systemImage: "pills.fill"
          ).font(.brand(.headline)).foregroundStyle(Theme.teal)
        }
      }.buttonStyle(.plain)
      Toggle(
        store.t("Show archived observations", "Pokaż archiwalne obserwacje"), isOn: $showArchived)
      if store.state.observations.isEmpty {
        EmptyCard(
          icon: "person.crop.rectangle.badge.plus",
          title: store.t("Add your first doctor", "Dodaj pierwszego lekarza"),
          message: store.t(
            "Keep separate plans for different concerns.",
            "Prowadź oddzielne plany dla różnych problemów."))
      }
      if !store.state.observations.isEmpty && visibleObservations.isEmpty {
        EmptyCard(
          icon: "line.3.horizontal.decrease.circle",
          title: store.t("No matching observations", "Brak pasujących obserwacji"),
          message: store.t(
            "Choose All doctors or show archived observations.",
            "Wybierz wszystkich lekarzy lub pokaż archiwalne obserwacje."))
      }
      ForEach(visibleObservations) { o in
        NavigationLink {
          ObservationDetail(observationID: o.id)
        } label: {
          SoftCard {
            VStack(alignment: .leading, spacing: 10) {
              Text(store.state.doctor(for: o.id)?.title(store.language) ?? "—").font(.brand(.headline))
              Text(o.reason).font(.brand(.title3, .regular))
              Text(o.archived ? store.t("Archived", "Archiwum") : o.stage.title(store.language))
                .font(.brand(.subheadline)).foregroundStyle(Theme.teal)
              Label(
                store.t("Visits: ", "Wizyty: ")
                  + String(store.state.visits.filter { $0.observationID == o.id }.count),
                systemImage: "calendar"
              ).font(.brand(.caption))
            }
          }
        }.buttonStyle(.plain)
      }
      Button(store.t("Add doctor / observation", "Dodaj lekarza / obserwację")) { adding = true }
        .buttonStyle(PrimaryButton())
    }.navigationTitle(store.t("Care", "Opieka")).sheet(isPresented: $adding) {
      NewObservationForm()
    }
  }
  private var visibleObservations: [Observation] {
    store.state.observations.filter {
      (showArchived || !$0.archived)
        && (store.selectedDoctors.isEmpty || store.selectedDoctors.contains($0.doctorID))
    }
  }

}
struct NewObservationForm: View {
  @EnvironmentObject var store: AppStore
  @State private var doctorID: UUID?
  @State private var specialty = "gp"
  @State private var customSpecialty = ""
  @State private var name = ""
  @State private var clinic = ""
  @State private var reason = ""
  @State private var date = Date().addingTimeInterval(86400)
  var body: some View {
    FormShell(
      title: store.t("Plan a visit", "Zaplanuj wizytę"),
      valid: !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && (doctorID != nil || specialty != "custom" || !customSpecialty.isEmpty), save: save
    ) {
      Section(store.t("Doctor", "Lekarz")) {
        ChoiceGrid(
          title: store.t("Choose doctor", "Wybierz lekarza"),
          options: [nil] + store.state.doctors.map { Optional($0.id) }, selection: $doctorID
        ) { id in
          guard let id, let doctor = store.state.doctors.first(where: { $0.id == id }) else {
            return store.t("New doctor", "Nowy lekarz")
          }
          return doctor.title(store.language)
        }
        if store.state.doctors.isEmpty {
          Text(
            store.t(
              "Saved doctors will appear here after you add your first visit.",
              "Zapisani lekarze pojawią się tutaj po dodaniu pierwszej wizyty.")
          ).font(.brand(.footnote))
        }
        if doctorID == nil {
          ChoiceGrid(
            title: store.t("Specialist", "Specjalista"), options: builtInSpecialties + ["custom"],
            selection: $specialty
          ) {
            $0 == "custom" ? store.t("Other", "Inny") : store.language.specialty($0)
          }
          if specialty == "custom" {
            TextField(store.t("Specialty", "Specjalizacja"), text: $customSpecialty)
          }
          TextField(
            store.t("Doctor's name (optional)", "Imię i nazwisko lekarza (opcjonalnie)"),
            text: $name)
          TextField(store.t("Clinic (optional)", "Placówka (opcjonalnie)"), text: $clinic)
        }
      }
      Section(store.t("First visit", "Pierwsza wizyta")) {
        DatePicker(store.t("Visit date", "Data wizyty"), selection: $date)
        TextField(
          store.t("Main reason for visit", "Główny powód wizyty"), text: $reason, axis: .vertical
        ).lineLimit(3...6).accessibilityIdentifier("visitReason")
      }
    }
  }
  private func save() -> Bool {
    store.change { s in
      var doctor = Doctor(specialty: specialty == "custom" ? customSpecialty : specialty)
      doctor.name = name
      doctor.clinic = clinic
      if doctorID == nil { s.doctors.append(doctor) }
      let observation = Observation(doctorID: doctorID ?? doctor.id, reason: reason)
      s.observations.append(observation)
      s.visits.append(Visit(observationID: observation.id, date: date))
    }
  }
}
struct ObservationDetail: View {
  @EnvironmentObject var store: AppStore
  let observationID: UUID
  @State private var addVisit = false
  @State private var edit = false
  @State private var medication = false
  @State private var confirmDelete = false
  @Environment(\.dismiss) private var dismiss
  var body: some View {
    if let o = store.state.observations.first(where: { $0.id == observationID }) {
      SoftScreen {
        SoftCard {
          VStack(alignment: .leading, spacing: 16) {
            Text(store.state.doctor(for: o.id)?.title(store.language) ?? "—").font(.brand(.title2))
            Text(o.reason)
            Picker(
              store.t("Stage", "Etap"),
              selection: Binding(
                get: { o.stage },
                set: { stage in
                  _ = store.change { s in
                    if let index = s.observations.firstIndex(where: { $0.id == o.id }) {
                      s.observations[index].stage = stage
                      s.observations[index].updatedAt = .now
                    }
                  }
                })
            ) {
              ForEach(Stage.allCases, id: \.self) { Text($0.title(store.language)).tag($0) }
            }
            Button(store.t("Edit doctor and reason", "Edytuj lekarza i powód")) { edit = true }
              .buttonStyle(SecondaryButton())
          }
        }
        ForEach(store.state.visits.filter { $0.observationID == o.id }.sorted { $0.date < $1.date })
        { v in
          NavigationLink {
            VisitDetail(visitID: v.id)
          } label: {
            SoftCard {
              VStack(alignment: .leading, spacing: 8) {
                Label(
                  store.language.date(v.date, time: true),
                  systemImage: v.completed ? "checkmark.circle" : "calendar"
                ).font(.brand(.headline))
                Text(
                  v.completed
                    ? store.t("Visit notes and instructions", "Notatki i zalecenia z wizyty")
                    : store.t(
                      "Prepare questions or record the outcome",
                      "Przygotuj pytania lub zapisz wynik wizyty"))
              }
            }
          }.buttonStyle(.plain)
        }
        Button(store.t("Add follow-up visit", "Dodaj wizytę kontrolną")) { addVisit = true }
          .buttonStyle(PrimaryButton())
        Button(store.t("Add prescribed medication", "Dodaj przepisany lek")) { medication = true }
          .buttonStyle(SecondaryButton())
        Button(
          o.archived
            ? store.t("Restore observation", "Przywróć obserwację")
            : store.t("Archive observation", "Archiwizuj obserwację")
        ) {
          _ = store.change { s in
            if let index = s.observations.firstIndex(where: { $0.id == o.id }) {
              s.observations[index].archived.toggle()
              s.observations[index].updatedAt = .now
            }
          }
        }.buttonStyle(SecondaryButton())
        Button(store.t("Delete doctor", "Usuń lekarza"), role: .destructive) { confirmDelete = true }
          .buttonStyle(SecondaryButton(fill: true)).accessibilityIdentifier("deleteObservation")
      }.navigationTitle(store.t("Observation", "Obserwacja"))
        .confirmationDialog(
          store.t("Delete this doctor?", "Usunąć tego lekarza?"), isPresented: $confirmDelete,
          titleVisibility: .visible
        ) {
          Button(store.t("Delete", "Usuń"), role: .destructive) {
            if store.deleteObservation(o.id) { dismiss() }
          }
          Button(store.t("Cancel", "Anuluj"), role: .cancel) {}
        } message: {
          Text(
            store.t(
              "Visits and medication for this doctor will be removed. Symptoms stay in the journal.",
              "Wizyty i leki tego lekarza zostaną usunięte. Objawy zostaną w dzienniku."))
        }
        .sheet(isPresented: $addVisit) { VisitForm(visit: Visit(observationID: o.id, date: .now)) }
        .sheet(isPresented: $edit) {
          ObservationEditForm(observation: o, doctor: store.state.doctor(for: o.id)!)
        }
        .sheet(isPresented: $medication) { MedicationForm(observationID: o.id) }
    }
  }
}
struct ObservationEditForm: View {
  @EnvironmentObject var store: AppStore
  @State var observation: Observation
  @State var doctor: Doctor
  var body: some View {
    FormShell(
      title: store.t("Edit observation", "Edytuj obserwację"),
      valid: !observation.reason.isEmpty && !doctor.specialty.isEmpty,
      save: {
        store.change { s in
          doctor.updatedAt = .now
          observation.updatedAt = .now
          s.doctors.removeAll { $0.id == doctor.id }
          s.doctors.append(doctor)
          s.observations.removeAll { $0.id == observation.id }
          s.observations.append(observation)
        }
      }
    ) {
      Section(store.t("Doctor", "Lekarz")) {
        TextField(store.t("Name", "Imię i nazwisko"), text: $doctor.name)
        ChoiceGrid(
          title: store.t("Specialty", "Specjalizacja"),
          options: builtInSpecialties
            + (builtInSpecialties.contains(doctor.specialty) ? [] : [doctor.specialty]),
          selection: $doctor.specialty
        ) { store.language.specialty($0) }
        if !builtInSpecialties.contains(doctor.specialty) {
          TextField(store.t("Custom specialty", "Własna specjalizacja"), text: $doctor.specialty)
        }
        TextField(store.t("Clinic", "Placówka"), text: $doctor.clinic)
        Text(
          store.t(
            "Doctor details change in all linked observations.",
            "Dane lekarza zmienią się we wszystkich powiązanych obserwacjach.")
        ).font(.brand(.footnote))
      }
      Section { TextField(store.t("Reason", "Powód"), text: $observation.reason, axis: .vertical) }
    }
  }
}
struct VisitDetail: View {
  @EnvironmentObject var store: AppStore
  let visitID: UUID
  @State private var edit = false
  @State private var preview: URL?
  var body: some View {
    if let visit = store.state.visits.first(where: { $0.id == visitID }) {
      SoftScreen {
        Text(store.language.date(visit.date, time: true)).font(.brand(.title))
        Text(store.state.doctor(for: visit.observationID)?.title(store.language) ?? "—").font(
          .headline)
        Text(
          visit.completed
            ? store.t("Visit completed", "Wizyta zakończona")
            : store.t("Planned visit", "Zaplanowana wizyta")
        ).foregroundStyle(Theme.teal)
        detail(store.t("Questions for the doctor", "Pytania do lekarza"), visit.questions)
        detail(store.t("Visit notes", "Notatki z wizyty"), visit.notes)
        detail(store.t("Doctor's instructions", "Zalecenia lekarza"), visit.instructions)
        detail(store.t("Tests and deadlines", "Badania i terminy"), visit.tests)
        detail(
          store.t("When to contact the doctor again", "Kiedy ponownie skontaktować się z lekarzem"),
          visit.returnAdvice)
        ForEach(store.state.attachments.filter { visit.attachmentIDs.contains($0.id) }) {
          attachment in
          Button {
            do {
              let url = FileManager.default.temporaryDirectory.appendingPathComponent(
                attachment.id.uuidString + "-"
                  + URL(fileURLWithPath: attachment.name).lastPathComponent)
              try attachment.data.write(to: url, options: .atomic)
              preview = url
            } catch { store.show(error) }
          } label: {
            Label(attachment.name, systemImage: "paperclip")
          }.buttonStyle(SecondaryButton())
        }
        Button(store.t("Edit visit / record outcome", "Edytuj wizytę / zapisz wynik")) {
          edit = true
        }.buttonStyle(PrimaryButton())
        Text(
          store.t(
            "These details were entered by you. Verify them against the doctor's original instructions.",
            "Te informacje zostały wpisane przez Ciebie. Porównaj je z oryginalnymi zaleceniami lekarza."
          )
        ).font(.brand(.footnote))
      }.navigationTitle(store.t("Visit", "Wizyta")).sheet(isPresented: $edit) {
        VisitForm(visit: visit)
      }.quickLookPreview($preview)
        .onDisappear {
          if let preview { try? FileManager.default.removeItem(at: preview) }
          preview = nil
        }
    }
  }
  private func detail(_ title: String, _ text: String) -> some View {
    SoftCard {
      VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.brand(.headline))
        Text(text.isEmpty ? store.t("Not recorded", "Nie podano") : text).foregroundStyle(
          text.isEmpty ? Theme.muted : Theme.ink)
      }
    }
  }
}
struct VisitForm: View {
  @EnvironmentObject var store: AppStore
  @State var visit: Visit
  @State private var imported: [Attachment] = []
  @State private var importFile = false
  var body: some View {
    FormShell(title: store.t("Visit details", "Szczegóły wizyty"), save: save) {
      Section {
        DatePicker(store.t("Date", "Data"), selection: $visit.date)
        Toggle(
          store.t("The visit has taken place", "Wizyta już się odbyła"), isOn: $visit.completed)
        TextField(
          store.t("Questions for the doctor", "Pytania do lekarza"), text: $visit.questions,
          axis: .vertical
        ).lineLimit(2...5)
      }
      Section(store.t("After the visit · entered by you", "Po wizycie · wpisane przez Ciebie")) {
        TextField(store.t("Notes", "Notatki"), text: $visit.notes, axis: .vertical)
        TextField(
          store.t("Doctor's instructions", "Zalecenia lekarza"), text: $visit.instructions,
          axis: .vertical)
        TextField(
          store.t("Tests and deadlines", "Badania i terminy"), text: $visit.tests, axis: .vertical)
        TextField(
          store.t("Advice about returning earlier", "Zalecenia dotyczące wcześniejszego kontaktu"),
          text: $visit.returnAdvice, axis: .vertical)
      }
      Section(
        store.t(
          "Documents (PDF or images, up to 8 MB each)", "Dokumenty (PDF lub obrazy, do 8 MB każdy)")
      ) {
        ForEach((store.state.attachments + imported).filter { visit.attachmentIDs.contains($0.id) })
        { a in
          HStack {
            Text(a.name)
            Spacer()
            Button(role: .destructive) {
              visit.attachmentIDs.removeAll { $0 == a.id }
              imported.removeAll { $0.id == a.id }
            } label: {
              Image(systemName: "minus.circle").accessibilityLabel(
                store.t("Remove attachment", "Usuń załącznik"))
            }
          }
        }
        Button(store.t("Attach document", "Dołącz dokument")) { importFile = true }
      }
    }.fileImporter(isPresented: $importFile, allowedContentTypes: [.pdf, .image]) { result in
      do {
        let url = try result.get()
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 8 * 1024 * 1024 else { throw DataError.tooLarge }
        let data = try Data(contentsOf: url)
        guard data.count <= 8 * 1024 * 1024 else { throw DataError.tooLarge }
        let attachment = Attachment(name: url.lastPathComponent, data: data)
        imported.append(attachment)
        visit.attachmentIDs.append(attachment.id)
      } catch { store.show(error) }
    }
  }
  private func save() -> Bool {
    store.change { s in
      let wasCompleted = s.visits.first { $0.id == visit.id }?.completed ?? false
      visit.updatedAt = .now
      s.visits.removeAll { $0.id == visit.id }
      s.visits.append(visit)
      s.attachments.append(contentsOf: imported)
      let linked = Set(s.visits.flatMap(\.attachmentIDs))
      s.attachments.removeAll { !linked.contains($0.id) }
      if visit.completed && !wasCompleted,
        let index = s.observations.firstIndex(where: {
          $0.id == visit.observationID && $0.stage == .waiting
        })
      {
        s.observations[index].stage = .visited
        s.observations[index].updatedAt = .now
      }
    }
  }
}
