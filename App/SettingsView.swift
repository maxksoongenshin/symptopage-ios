import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
  import UIKit
#endif
#if SWIFT_PACKAGE
  import SymptoCore
#endif

struct SettingsView: View {
  @EnvironmentObject var store: AppStore
  var recovery = false
  @State private var importing = false
  @State private var exporting = false
  @State private var document = ExportDocument(data: Data())
  @State private var importData: Data?
  @State private var importSummary = ""
  @State private var confirmImport = false
  @State private var name = ""
  private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
  var body: some View {
    Form {
      if recovery {
        Section(store.t("Data recovery", "Odzyskiwanie danych")) {
          Text(
            store.t(
              "The existing file could not be opened. It has not been reset or overwritten. Export the original or restore a validated backup.",
              "Nie można otworzyć istniejącego pliku. Nie został wyzerowany ani nadpisany. Wyeksportuj oryginał lub przywróć poprawną kopię zapasową."
            ))
          Button(store.t("Export unreadable original", "Eksportuj nieczytelny oryginał")) {
            do {
              document = ExportDocument(data: try Data(contentsOf: store.url))
              exporting = true
            } catch { store.show(error) }
          }
          Button(store.t("Retry", "Spróbuj ponownie")) { store.reload() }
        }
      } else {
        Section {
          Brand()
          ChoiceGrid(
            title: store.t("Language", "Język"), options: Language.allCases,
            selection: Binding(
              get: { store.language }, set: { value in _ = store.change { $0.language = value } })
          ) { $0.name }
          TextField(store.t("Your first name (optional)", "Twoje imię (opcjonalnie)"), text: $name)
            .onSubmit(saveName).accessibilityIdentifier("profileName")
          Button(store.t("Save name", "Zapisz imię"), action: saveName)
            .disabled(trimmedName == (store.state.profileName ?? "") || trimmedName.count > 100)
          Text(
            store.t(
              "Used only for the greeting on the start screen.",
              "Używane tylko do powitania na ekranie startowym.")
          ).font(.brand(.footnote))
        }
        Section(store.t("Apple Watch, Apple Health & Strava", "Apple Watch, Apple Health i Strava")) {
          NavigationLink {
            IntegrationsView()
          } label: {
            Label(store.t("Connections", "Integracje"), systemImage: "applewatch")
          }.accessibilityIdentifier("openIntegrations")
          Text(connectionSummary).font(.brand(.footnote))
        }
        Section(store.t("Reminders", "Przypomnienia")) {
          Toggle(
            store.t("Medication and visit reminders", "Przypomnienia o lekach i wizytach"),
            isOn: Binding(
              get: { store.state.remindersEnabled },
              set: { on in
                if on {
                  Task { await store.enableNotifications() }
                } else {
                  _ = store.change { $0.remindersEnabled = false }
                }
              }))
          Text(store.notificationStatus).font(.brand(.footnote))
          Button(store.t("Refresh schedule", "Odśwież harmonogram")) {
            Task { await store.refreshNotifications() }
          }
          #if os(iOS)
            Link(
              store.t(
                "Open system notification settings", "Otwórz systemowe ustawienia powiadomień"),
              destination: URL(string: UIApplication.openSettingsURLString)!)
          #endif
          Text(
            store.t(
              "Notifications hide medication names. Delivery depends on system settings; opening the app extends the scheduled queue. No guarantee when the device is off.",
              "Powiadomienia ukrywają nazwy leków. Dostarczenie zależy od ustawień systemu; otwarcie aplikacji przedłuża kolejkę. Brak gwarancji przy wyłączonym urządzeniu."
            )
          ).font(.brand(.footnote))
        }
      }
      Section(store.t("Backup and transfer", "Kopia zapasowa i przenoszenie")) {
        if !recovery {
          Button(store.t("Export full backup", "Eksportuj pełną kopię")) {
            do {
              document = ExportDocument(data: try StateCodec.encode(store.state))
              exporting = true
            } catch { store.show(error) }
          }
        }
        Button(store.t("Import backup / Windows 0.4.0", "Importuj kopię / Windows 0.4.0")) {
          importing = true
        }
        Text(
          store.t(
            "A backup contains sensitive records and attachments and is not password-encrypted. Choose a private destination. Import replaces current records after validation and saves the previous file locally.",
            "Kopia zawiera wrażliwe wpisy i załączniki; nie jest szyfrowana hasłem. Wybierz prywatne miejsce. Import zastępuje dane po sprawdzeniu i zachowuje poprzedni plik lokalnie."
          )
        ).font(.brand(.footnote))
      }
      if !recovery {
        Section(store.t("Getting help", "Uzyskanie pomocy")) {
          Text(
            store.t(
              "Do not wait for the planned appointment if you think you need urgent medical help. This app does not assess urgency and no clinician monitors your entries.",
              "Nie czekaj na zaplanowaną wizytę, jeśli uważasz, że potrzebujesz pilnej pomocy medycznej. Aplikacja nie ocenia pilności, a lekarz nie monitoruje wpisów."
            ))
          Text(
            store.t(
              "In Poland and the EU, the emergency number is 112. Outside the EU, use the local emergency number.",
              "W Polsce i UE numer alarmowy to 112. Poza UE użyj lokalnego numeru alarmowego."))
          #if os(iOS)
            Link(
              store.t("Call 112 (Poland / EU)", "Zadzwoń pod 112 (Polska / UE)"),
              destination: URL(string: "tel:112")!)
          #endif
        }
        Section(store.t("About your data", "O Twoich danych")) {
          Text(
            store.t(
              "Local storage. No account, analytics or automatic sync. Data can be transferred by backup. Device backups may follow your Apple settings.",
              "Dane lokalne. Bez konta, analityki i automatycznej synchronizacji. Dane można przenieść przez kopię zapasową. Kopie urządzenia zależą od ustawień Apple."
            ))
          Text("SymptoPage 0.6.0 · iOS").font(.brand(.caption))
        }
      }
    }.formStyle(.grouped).scrollContentBackground(.hidden).background(Color(hex: 0xF4FAF9))
    .navigationTitle(
      recovery ? store.t("Recovery", "Odzyskiwanie") : store.t("Settings", "Ustawienia")
    )
    .fileExporter(
      isPresented: $exporting, document: document, contentType: .json,
      defaultFilename: recovery ? "SymptoPage-original" : "SymptoPage-backup"
    ) { result in if case .failure(let error) = result { store.show(error) } }
    .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
      do {
        let url = try result.get()
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= StateCodec.maxBytes else { throw DataError.tooLarge }
        let data = try Data(contentsOf: url)
        let candidate = try StateCodec.decode(data)
        importData = data
        importSummary =
          store.t("Doctors: ", "Lekarze: ") + "\(candidate.doctors.count), "
          + store.t("events: ", "zdarzenia: ") + "\(candidate.events.count), "
          + store.t("courses: ", "kuracje: ") + "\(candidate.medications.count). "
          + store.t(
            "This replaces all current records. A local copy of the previous file will be kept.",
            "To zastąpi wszystkie obecne dane. Lokalna kopia poprzedniego pliku zostanie zachowana."
          )
        confirmImport = true
      } catch { store.show(error) }
    }
    .confirmationDialog(
      store.t("Replace current data?", "Zastąpić obecne dane?"), isPresented: $confirmImport,
      titleVisibility: .visible
    ) {
      Button(store.t("Replace with this backup", "Zastąp tą kopią"), role: .destructive) {
        if let importData { _ = store.restore(importData) }
        importData = nil
      }
      Button(store.t("Cancel", "Anuluj"), role: .cancel) { importData = nil }
    } message: {
      Text(importSummary)
    }
    .onAppear { name = store.state.profileName ?? "" }
    .onChange(of: store.state.profileName) { _, value in name = value ?? "" }
  }
  private var connectionSummary: String {
    let parts = [
      store.state.integrations.healthEnabled ? "Apple Health ✓" : nil,
      store.state.integrations.stravaAthlete.map { "Strava ✓ " + $0 },
    ].compactMap { $0 }
    return parts.isEmpty ? store.t("Not connected", "Nie połączono") : parts.joined(separator: " · ")
  }
  private func saveName() {
    guard trimmedName.count <= 100 else { return }
    _ = store.change { $0.profileName = trimmedName.isEmpty ? nil : trimmedName }
  }
}
