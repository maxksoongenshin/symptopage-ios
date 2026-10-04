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
        }
        Section {
          NavigationLink {
            IntegrationsView()
          } label: {
            HStack {
              Label("Apple Health", systemImage: "heart.text.square")
              Spacer()
              Text(connectionSummary).font(.brand(.footnote)).foregroundStyle(Theme.muted)
            }
          }.accessibilityIdentifier("openIntegrations")
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
          Button(store.t("Send a test notification", "Wyślij testowe powiadomienie")) {
            Task { await store.sendTestNotification() }
          }.accessibilityIdentifier("testNotification")
          #if os(iOS)
            Link(
              store.t("System notification settings", "Systemowe ustawienia powiadomień"),
              destination: URL(string: UIApplication.openSettingsURLString)!)
          #endif
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
      }
      if !recovery {
        Section(store.t("Urgent help", "Pilna pomoc")) {
          Text(
            store.t(
              "Feeling much worse? Don't wait for the visit.",
              "Czujesz się dużo gorzej? Nie czekaj na wizytę."))
          #if os(iOS)
            Link(
              store.t("Call 112 (Poland / EU)", "Zadzwoń pod 112 (Polska / UE)"),
              destination: URL(string: "tel:112")!)
          #endif
        }
        Section {
          Text(
            store.t(
              "Data stays on this device. No account, no analytics.",
              "Dane zostają na tym urządzeniu. Bez konta i analityki."))
          Text("SymptoPage 0.9.0").font(.brand(.caption))
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
      store.state.integrations.healthEnabled ? store.t("Connected", "Połączono") : nil
    ].compactMap { $0 }
    return parts.first ?? store.t("Off", "Wył.")
  }
  private func saveName() {
    guard trimmedName.count <= 100 else { return }
    _ = store.change { $0.profileName = trimmedName.isEmpty ? nil : trimmedName }
  }
}
