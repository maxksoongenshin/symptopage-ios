import CoreText
import SwiftUI

#if SWIFT_PACKAGE
  import SymptoCore
#endif
#if os(iOS)
  import UIKit
#else
  import AppKit
#endif

/// Tokens follow the supplied SymptoPad screens (work/design-reference/ekrany).
enum Theme {
  static let ink = Color(hex: 0x0F2A2E)
  static let muted = Color(hex: 0x4A5F62)
  static let teal = Color(hex: 0x167374)
  static let accent = Color(hex: 0x35A5A0)
  static let chip = Color(hex: 0xCDEDE9)
  static let chipText = Color(hex: 0x0F3B3D)
  static let alert = Color(hex: 0xD32F2F)
  static let heart = Color(hex: 0xE8423F)
  static let surface = Color(red: 0.96, green: 0.99, blue: 0.98)
  static let soft = Color(hex: 0xDDF3F0)
  static let background = LinearGradient(
    stops: [
      .init(color: Color(hex: 0x35A5A0), location: 0), .init(color: Color(hex: 0x7FCFC8), location: 0.3),
      .init(color: Color(hex: 0xBFE9E4), location: 0.68), .init(color: Color(hex: 0xD8F1EF), location: 1),
    ], startPoint: .top, endPoint: .bottom)
}
extension Color {
  init(hex: UInt32) {
    self.init(
      red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255)
  }
}
struct SoftCard<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content.frame(maxWidth: .infinity, alignment: .leading).padding(20)
      .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24))
      .overlay(
        RoundedRectangle(cornerRadius: 24).stroke(.white, lineWidth: 1).allowsHitTesting(false)
      )
      .contentShape(RoundedRectangle(cornerRadius: 24))
      .shadow(color: Theme.teal.opacity(0.10), radius: 14, x: 5, y: 8)
  }
}
struct SoftScreen<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) { content }.padding(20).frame(maxWidth: 700).frame(
        maxWidth: .infinity)
    }
    .background {
      GeometryReader { proxy in
        Theme.background
        Circle().fill(.white.opacity(0.24)).frame(width: 270, height: 270).offset(
          x: proxy.size.width - 170, y: 200)
        Circle().fill(Color(hex: 0x5AA9D6).opacity(0.45)).frame(width: 250, height: 250).offset(
          x: proxy.size.width - 150, y: 540)
      }.clipped().allowsHitTesting(false).accessibilityHidden(true)
    }.foregroundStyle(Theme.ink)
  }
}
/// Registers bundled Manrope (from the supplied design) once per process.
/// Runtime registration needs no Info.plist entry and also serves the PDF renderer.
enum BrandFonts {
  private static var done = false
  static func register() {
    guard !done else { return }
    done = true
    let urls =
      (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
      + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
    for url in urls where url.lastPathComponent.hasPrefix("Manrope-") {
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
  }
}
extension Font {
  /// Manrope scaled with Dynamic Type; falls back to the system font if not registered.
  static func brand(_ style: Font.TextStyle, _ weight: Font.Weight? = nil) -> Font {
    let (size, base): (CGFloat, Font.Weight) =
      switch style {
      case .largeTitle: (34, .heavy)
      case .title: (28, .heavy)
      case .title2: (22, .heavy)
      case .title3: (20, .bold)
      case .headline: (17, .bold)
      case .subheadline: (15, .regular)
      case .callout: (16, .regular)
      case .footnote: (13, .regular)
      case .caption: (12, .regular)
      case .caption2: (11, .regular)
      default: (17, .regular)
      }
    return .custom(manropeName(weight ?? base), size: size, relativeTo: style)
  }
  static func brand(size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    .custom(manropeName(weight), size: size, relativeTo: .body)
  }
  private static func manropeName(_ weight: Font.Weight) -> String {
    switch weight {
    case .heavy, .black: return "Manrope-ExtraBold"
    case .bold: return "Manrope-Bold"
    case .semibold, .medium: return "Manrope-SemiBold"
    default: return "Manrope-Regular"
    }
  }
}
/// Main call to action: solid capsule from the design ("Zaczynamy", "Dodaj wizytę").
struct PrimaryButton: ButtonStyle {
  var coral = false
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(.brand(.headline, .heavy)).frame(maxWidth: .infinity, minHeight: 54)
      .padding(.horizontal, 18).foregroundStyle(.white)
      .background(coral ? Theme.alert : Theme.teal, in: Capsule())
      .shadow(color: (coral ? Theme.alert : Theme.teal).opacity(enabled ? 0.22 : 0), radius: 8, y: 5)
      .contentShape(Capsule())
      .scaleEffect(configuration.isPressed ? 0.98 : 1)
      .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
/// Secondary action: tinted capsule. Destructive roles turn red automatically.
struct SecondaryButton: ButtonStyle {
  var fill = false
  @Environment(\.isEnabled) private var enabled
  func makeBody(configuration: Configuration) -> some View {
    let destructive = configuration.role == .destructive
    configuration.label.font(.brand(.subheadline, .bold)).padding(.horizontal, 16)
      .frame(maxWidth: fill ? .infinity : nil, minHeight: 40)
      .foregroundStyle(destructive ? Theme.alert : Theme.chipText)
      .background(destructive ? Color(hex: 0xFBE3E3) : Theme.chip, in: Capsule())
      .contentShape(Capsule())
      .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
  }
}
/// Square shortcut tile used on the start screen.
struct ActionTile: View {
  let title: String
  let icon: String
  var tint: Color = Theme.teal
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 10) {
        Image(systemName: icon).font(.brand(size: 20, .semibold)).foregroundStyle(.white)
          .frame(width: 40, height: 40).background(tint, in: RoundedRectangle(cornerRadius: 12))
        Text(title).font(.brand(.subheadline, .bold)).foregroundStyle(Theme.ink)
          .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }.padding(14).frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: Theme.ink.opacity(0.08), radius: 10, y: 6)
        .contentShape(RoundedRectangle(cornerRadius: 22))
    }.buttonStyle(.plain)
  }
}
/// Small capsule label, e.g. note tags.
struct TagChip: View {
  let text: String
  var body: some View {
    Text(text).font(.brand(.caption, .semibold)).padding(.horizontal, 10).padding(.vertical, 4)
      .foregroundStyle(Theme.chipText).background(Theme.chip, in: Capsule())
  }
}
/// Section heading with an optional trailing action, used across tabs.
struct SectionHeader: View {
  let title: String
  var action: (title: String, run: () -> Void)?
  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title).font(.brand(.title3, .heavy)).accessibilityAddTraits(.isHeader)
      Spacer()
      if let action {
        Button(action.title, action: action.run).buttonStyle(.plain)
          .font(.brand(.subheadline, .bold)).foregroundStyle(Theme.teal)
      }
    }
  }
}
/// Loads an owner-supplied brand image from the asset catalog (iOS) or the preview bundle (macOS).
func brandImage(_ name: String) -> Image? {
  #if os(iOS)
    return UIImage(named: name).map { Image(uiImage: $0) }
  #else
    guard let url = Bundle.main.url(forResource: name, withExtension: "png"),
      let image = NSImage(contentsOf: url)
    else { return nil }
    return Image(nsImage: image)
  #endif
}
/// PNG bytes of a brand image, for embedding into the PDF.
func brandPNG(_ name: String) -> Data? {
  #if os(iOS)
    return UIImage(named: name)?.pngData()
  #else
    return Bundle.main.url(forResource: name, withExtension: "png").flatMap { try? Data(contentsOf: $0) }
  #endif
}
struct Brand: View {
  var body: some View {
    Group {
      if let logo = brandImage("BrandLogo") {
        logo.resizable().scaledToFit()
      } else {
        Text("SymptoPage").font(.brand(.title2))
      }
    }.frame(maxWidth: 275, maxHeight: 70, alignment: .leading).accessibilityLabel("SymptoPage")
  }
}
struct EmptyCard: View {
  let icon: String
  let title: String
  let message: String
  var body: some View {
    SoftCard {
      VStack(alignment: .leading, spacing: 12) {
        Image(systemName: icon).font(.largeTitle).foregroundStyle(Theme.teal)
        Text(title).font(.brand(.title3))
        Text(message).foregroundStyle(Theme.muted)
      }
    }
  }
}
struct FormShell<Content: View>: View {
  @EnvironmentObject var store: AppStore
  @Environment(\.dismiss) private var dismiss
  let title: String
  var valid = true
  let save: () -> Bool
  @ViewBuilder var content: Content
  var body: some View {
    NavigationStack {
      Form { content }.formStyle(.grouped).scrollContentBackground(.hidden)
        .background(Color(hex: 0xF4FAF9)).navigationTitle(title)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button(store.t("Cancel", "Anuluj")) { dismiss() }
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(store.t("Save", "Zapisz")) { if save() { dismiss() } }.disabled(!valid)
          }
        }
    }.tint(Theme.teal).frame(minWidth: 300, minHeight: 560)
      .alert(
        store.t("Could not save", "Nie udało się zapisać"),
        isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })
      ) {
        Button("OK") { store.error = nil }
      } message: {
        Text(store.error ?? "")
      }
  }
}
struct ObservationPicker: View {
  @EnvironmentObject var store: AppStore
  @Binding var selected: UUID?
  var body: some View {
    ChoiceGrid(
      title: store.t("Observation", "Obserwacja"),
      options: [nil] + store.state.observations.map { Optional($0.id) }, selection: $selected
    ) { id in
      guard let id, let o = store.state.observations.first(where: { $0.id == id }) else {
        return store.t("General / no link", "Ogólne / bez powiązania")
      }
      return store.label(o)
    }

  }
}
struct ObservationMultiPicker: View {
  @EnvironmentObject var store: AppStore
  @Binding var selected: [UUID]
  var body: some View {
    Section(store.t("Link to observations (optional)", "Powiąż z obserwacjami (opcjonalnie)")) {
      ForEach(store.state.observations) { o in
        Toggle(
          store.label(o),
          isOn: Binding(
            get: { selected.contains(o.id) },
            set: { on in if on { selected.append(o.id) } else { selected.removeAll { $0 == o.id } }
            }))
      }
      if store.state.observations.isEmpty {
        Text(store.t("You can add a doctor later.", "Możesz dodać lekarza później."))
      }
    }
  }
}
/// Visible choices avoid platform menu hit-testing and make selected answers explicit.
struct ChoiceGrid<Value: Hashable>: View {
  let title: String
  let options: [Value]
  @Binding var selection: Value
  let label: (Value) -> String
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).font(.brand(.headline))
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 135))], spacing: 8) {
        ForEach(options, id: \.self) { value in
          ChoiceButton(title: label(value), selected: selection == value) { selection = value }
        }
      }
    }.padding(.vertical, 4)
  }
}
struct ChoiceButton: View {
  let title: String
  let selected: Bool
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
        Text(title).fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }.font(.brand(.subheadline, .semibold)).padding(12).frame(maxWidth: .infinity, minHeight: 48)
        .foregroundStyle(selected ? .white : Theme.ink)
        .background(
          selected ? Theme.teal : Color(red: 0.80, green: 0.93, blue: 0.91),
          in: RoundedRectangle(cornerRadius: 18)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18))
    }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
  }
}
struct DoctorFilter: View {
  @EnvironmentObject var store: AppStore
  @Environment(\.dismiss) private var dismiss
  @State private var selection: Set<UUID> = []
  @State private var adding = false
  var body: some View {
    NavigationStack {
      SoftScreen {
        Text(store.t("Choose doctors", "Wybierz lekarzy")).font(.brand(.title2))
        Text(
          store.t(
            "Show all records or choose several doctors.",
            "Pokaż wszystkie wpisy lub wybierz kilku lekarzy."))
        ChoiceButton(title: store.t("All doctors", "Wszyscy lekarze"), selected: selection.isEmpty)
        {
          selection = []
        }.accessibilityIdentifier("filterAllDoctors")
        ForEach(store.state.doctors) { doctor in
          ChoiceButton(title: doctor.title(store.language), selected: selection.contains(doctor.id))
          {
            if selection.contains(doctor.id) {
              selection.remove(doctor.id)
            } else {
              selection.insert(doctor.id)
            }
          }.accessibilityIdentifier("filterDoctor-" + doctor.id.uuidString)
        }
        if store.state.doctors.isEmpty {
          EmptyCard(
            icon: "person.crop.circle.badge.plus",
            title: store.t("No doctors yet", "Nie dodano jeszcze lekarzy"),
            message: store.t(
              "Add a visit to create your first doctor and observation.",
              "Dodaj wizytę, aby utworzyć pierwszego lekarza i obserwację."))
          Button(store.t("Add doctor", "Dodaj lekarza")) { adding = true }.buttonStyle(
            PrimaryButton())
        }
        Text(
          selection.isEmpty
            ? store.t(
              "All doctors and general entries are included.",
              "Uwzględniono wszystkich lekarzy i wpisy ogólne.")
            : store.t("Selected doctors: ", "Wybrani lekarze: ") + String(selection.count)
        )
        .font(.brand(.headline)).accessibilityIdentifier("filterSummary")
        Text(
          store.t(
            "Selecting doctors excludes unlinked entries. Your records are not changed.",
            "Wybór lekarzy wyklucza wpisy bez powiązania. Twoje dane nie są zmieniane.")
        ).font(.brand(.footnote))
        Button(store.t("Apply filter", "Zastosuj filtr")) {
          store.selectedDoctors = selection
          dismiss()
        }.buttonStyle(PrimaryButton()).accessibilityIdentifier("applyDoctorFilter")
      }.toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(store.t("Cancel", "Anuluj")) { dismiss() }
        }
      }
    }.onAppear { selection = store.selectedDoctors }
      .sheet(isPresented: $adding) { NewObservationForm() }
      #if os(macOS)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 560, idealHeight: 700)
      #endif
  }
}
struct FilterButton: View {
  @EnvironmentObject var store: AppStore
  @State private var open = false
  var body: some View {
    Button {
      open = true
    } label: {
      HStack {
        Image(systemName: "line.3.horizontal.decrease.circle")
        Text(
          store.selectedDoctors.isEmpty
            ? store.t("All doctors", "Wszyscy lekarze")
            : store.t("Selected doctors: ", "Wybrani lekarze: ")
              + String(store.selectedDoctors.count))
        Spacer()
        Image(systemName: "chevron.down")
      }.font(.brand(.headline)).padding(16).frame(maxWidth: .infinity, minHeight: 48)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }.buttonStyle(.plain).accessibilityIdentifier("doctorFilter")
      .sheet(isPresented: $open) {
        DoctorFilter().environmentObject(store).environment(\.locale, store.language.locale)
      }
  }
}
/// Capsule choice from the design's specialist chips.
struct Pill: View {
  let title: String
  let selected: Bool
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Text(title).font(.brand(.subheadline, .bold)).padding(.horizontal, 16).frame(minHeight: 40)
        .foregroundStyle(selected ? .white : Theme.chipText)
        .background(selected ? Theme.teal : Theme.chip, in: Capsule()).contentShape(Capsule())
    }.buttonStyle(.plain).accessibilityAddTraits(selected ? .isSelected : [])
  }
}
/// Wraps children onto new lines like inline chips.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = arrange(proposal.width ?? .infinity, subviews)
    return CGSize(
      width: rows.map(\.width).max() ?? 0,
      height: rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0)))
  }
  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var y = bounds.minY
    for row in arrange(bounds.width, subviews) {
      var x = bounds.minX
      for index in row.indices {
        let size = subviews[index].sizeThatFits(.unspecified)
        subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
        x += size.width + spacing
      }
      y += row.height + spacing
    }
  }
  private struct Row {
    var indices: [Int] = []
    var width: CGFloat = 0
    var height: CGFloat = 0
  }
  private func arrange(_ maxWidth: CGFloat, _ subviews: Subviews) -> [Row] {
    var rows = [Row()]
    for index in subviews.indices {
      let size = subviews[index].sizeThatFits(.unspecified)
      if !rows[rows.count - 1].indices.isEmpty
        && rows[rows.count - 1].width + spacing + size.width > maxWidth
      {
        rows.append(Row())
      }
      var row = rows[rows.count - 1]
      row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
      row.height = max(row.height, size.height)
      row.indices.append(index)
      rows[rows.count - 1] = row
    }
    return rows
  }
}
