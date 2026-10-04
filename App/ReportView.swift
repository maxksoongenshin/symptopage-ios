import CoreGraphics
import CoreText
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
  import SymptoCore
#endif
#if os(iOS)
  import UIKit
#endif

struct ExportDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json, .pdf] }
  var data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws {
    data = configuration.file.regularFileContents ?? Data()
  }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    FileWrapper(regularFileWithContents: data)
  }
}
/// Raport tab: period, filters, summary tiles, designed PDF, and the journal.
struct ReportView: View {
  enum Period: Int, CaseIterable { case week = 7, month = 30, quarter = 90, custom = 0 }
  @EnvironmentObject var store: AppStore
  @State private var period: Period = .month
  @State private var from = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
  @State private var through = Date()
  @State private var details = true
  @State private var export = false
  @State private var document = ExportDocument(data: Data())
  @State private var preview: URL?
  var body: some View {
    SoftScreen {
      VStack(alignment: .leading, spacing: 6) {
        Text(store.t("Report for the doctor", "Raport dla lekarza")).font(.brand(.largeTitle))
        Text(
          store.t(
            "Your entries as a clear PDF to take to the visit.",
            "Twoje wpisy jako przejrzysty PDF na wizytę.")
        ).font(.brand(.subheadline)).foregroundStyle(Theme.muted)
      }
      SoftCard {
        VStack(alignment: .leading, spacing: 12) {
          Text(store.t("Period", "Okres")).font(.brand(.headline))
          FlowLayout(spacing: 8) {
            ForEach(Period.allCases, id: \.self) { value in
              Pill(title: title(value), selected: period == value) { period = value }
                .accessibilityIdentifier("period-\(value.rawValue)")
            }
          }
          if period == .custom {
            DatePicker(store.t("From", "Od"), selection: $from, in: ...through, displayedComponents: .date)
            DatePicker(store.t("Through", "Do"), selection: $through, in: from..., displayedComponents: .date)
          }
          Toggle(store.t("Include detailed timeline", "Dołącz szczegółową historię"), isOn: $details)
            .font(.brand(.subheadline, .semibold))
        }
      }
      FilterButton()
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
        ForEach(Array(summary.tiles.enumerated()), id: \.offset) { _, tile in
          VStack(alignment: .leading, spacing: 4) {
            Text(tile.value).font(.brand(size: 26, .heavy)).foregroundStyle(Theme.teal)
            Text(tile.label).font(.brand(.caption, .semibold)).foregroundStyle(Theme.ink)
          }.padding(14).frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(Theme.chip, in: RoundedRectangle(cornerRadius: 18))
        }
      }
      Button {
        do {
          let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "SymptoPage-\(UUID().uuidString).pdf")
          try pdf().write(to: url, options: .atomic)
          preview = url
        } catch { store.show(error) }
      } label: {
        Label(store.t("Preview PDF", "Podgląd PDF"), systemImage: "eye")
      }.buttonStyle(PrimaryButton()).accessibilityIdentifier("previewPDF")
      HStack(spacing: 10) {
        Button {
          do {
            document = ExportDocument(data: try pdf())
            export = true
          } catch { store.show(error) }
        } label: {
          Label(store.t("Save PDF", "Zapisz PDF"), systemImage: "square.and.arrow.down")
        }.buttonStyle(SecondaryButton(fill: true)).accessibilityIdentifier("savePDF")
        #if os(iOS)
          Button {
            do {
              let controller = UIPrintInteractionController.shared
              controller.printingItem = try pdf()
              controller.present(animated: true, completionHandler: nil)
            } catch { store.show(error) }
          } label: {
            Label(store.t("Print", "Drukuj"), systemImage: "printer")
          }.buttonStyle(SecondaryButton(fill: true))
        #endif
      }
      Text(
        store.t(
          "Review the content below before sharing. Attachments are not included in this PDF.",
          "Sprawdź poniższą treść przed udostępnieniem. Załączniki nie są dołączane do tego PDF.")
      ).font(.brand(.footnote)).foregroundStyle(Theme.muted)
      NavigationLink {
        JournalView()
      } label: {
        HStack(spacing: 12) {
          Image(systemName: "list.bullet.rectangle.fill").font(.system(size: 20, weight: .semibold))
            .foregroundStyle(.white).frame(width: 42, height: 42)
            .background(Theme.teal, in: RoundedRectangle(cornerRadius: 12))
          VStack(alignment: .leading, spacing: 2) {
            Text(store.t("Journal", "Dziennik")).font(.brand(.headline))
            Text(store.t("All symptoms, answers and notes", "Wszystkie objawy, odpowiedzi i notatki"))
              .font(.brand(.caption)).foregroundStyle(Theme.muted)
          }
          Spacer()
          Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
        }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 20)).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityIdentifier("reportJournal")
      SectionHeader(title: store.t("Report content", "Zawartość raportu"))
      ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
        SoftCard {
          VStack(alignment: .leading, spacing: 10) {
            Text(section.title).font(.brand(.headline)).foregroundStyle(Theme.teal)
            Text(section.body).font(.brand(.subheadline)).textSelection(.enabled)
          }
        }
      }
    }.navigationTitle(store.t("Report", "Raport"))
      .fileExporter(
        isPresented: $export, document: document, contentType: .pdf,
        defaultFilename: "SymptoPage-report"
      ) { result in if case .failure(let error) = result { store.show(error) } }
      .quickLookPreview($preview)
  }
  private func title(_ value: Period) -> String {
    value == .custom ? store.t("Custom", "Własny") : store.t("\(value.rawValue) days", "\(value.rawValue) dni")
  }
  private var range: (from: Date, through: Date) {
    guard period != .custom else { return (from, through) }
    return (Calendar.current.date(byAdding: .day, value: -(period.rawValue - 1), to: .now)!, .now)
  }
  private var sections: [ReportSection] {
    ReportBuilder.sections(
      state: store.state, doctors: store.selectedDoctors, from: range.from, through: range.through,
      details: details)
  }
  private var summary: ReportSummary {
    ReportBuilder.summary(
      state: store.state, doctors: store.selectedDoctors, from: range.from, through: range.through)
  }
  private func pdf() throws -> Data {
    try PDFRenderer.make(
      sections, summary: summary, logo: brandPNG("BrandIconBlue"), wordmark: brandPNG("BrandLogoWhite"))
  }
}
