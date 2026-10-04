import SwiftUI

#if SWIFT_PACKAGE
  import SymptoCore
#endif

extension Mood {
  var color: Color {
    switch self {
    case .veryBad: return Color(hex: 0xD32F2F)
    case .bad: return Color(hex: 0xEF7D57)
    case .okay: return Color(hex: 0xF2B544)
    case .good: return Color(hex: 0x35A5A0)
    case .veryGood: return Color(hex: 0x167374)
    }
  }
  var icon: String {
    switch self {
    case .veryBad: return "cloud.bolt.rain.fill"
    case .bad: return "cloud.rain.fill"
    case .okay: return "cloud.sun.fill"
    case .good: return "sun.max.fill"
    case .veryGood: return "sparkles"
    }
  }
}

/// "Notatki o samopoczuciu": mood, free text, tags and optional observation links.
struct NoteForm: View {
  @EnvironmentObject var store: AppStore
  @State var note: WellbeingNote
  @State private var customTag = ""
  init(note: WellbeingNote = WellbeingNote(text: "")) { _note = State(initialValue: note) }
  var body: some View {
    FormShell(
      title: store.t("Wellbeing note", "Notatka o samopoczuciu"),
      valid: note.mood != nil || !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      save: { store.saveNote(note) }
    ) {
      Section(store.t("How do you feel?", "Jak się czujesz?")) {
        HStack(spacing: 6) {
          ForEach(Mood.allCases, id: \.self) { mood in
            let selected = note.mood == mood
            Button {
              note.mood = selected ? nil : mood
            } label: {
              VStack(spacing: 6) {
                Image(systemName: mood.icon).font(.system(size: 22, weight: .semibold))
                Text(mood.title(store.language)).font(.brand(.caption2, .bold))
                  .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.8)
              }.frame(maxWidth: .infinity, minHeight: 74)
                .foregroundStyle(selected ? .white : mood.color)
                .background(
                  selected ? mood.color : mood.color.opacity(0.12),
                  in: RoundedRectangle(cornerRadius: 16)
                ).contentShape(RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(.plain).accessibilityIdentifier("mood-\(mood.rawValue)")
              .accessibilityLabel(mood.title(store.language))
              .accessibilityAddTraits(selected ? .isSelected : [])
          }
        }.padding(.vertical, 4)
      }
      Section(store.t("Note", "Notatka")) {
        TextField(
          store.t("What happened, what helped, what worried you…", "Co się działo, co pomogło, co niepokoiło…"),
          text: $note.text, axis: .vertical
        ).lineLimit(4...10).accessibilityIdentifier("noteText")
        DatePicker(store.t("When", "Kiedy"), selection: $note.date, in: ...Date())
      }
      Section(store.t("Tags (optional)", "Tagi (opcjonalnie)")) {
        FlowLayout(spacing: 8) {
          ForEach(tagOptions, id: \.self) { tag in
            Pill(title: "#" + store.language.tag(tag), selected: note.tags.contains(tag)) {
              if note.tags.contains(tag) { note.tags.removeAll { $0 == tag } } else { note.tags.append(tag) }
            }
          }
        }.padding(.vertical, 4)
        HStack {
          TextField(store.t("Own tag", "Własny tag"), text: $customTag).onSubmit(addTag)
          Button(store.t("Add", "Dodaj"), action: addTag).buttonStyle(SecondaryButton())
            .disabled(trimmedTag.isEmpty || trimmedTag.count > 50 || note.tags.count >= 20)
        }
      }
      ObservationMultiPicker(selected: $note.observationIDs)
    }
  }
  private var trimmedTag: String { customTag.trimmingCharacters(in: .whitespacesAndNewlines) }
  private var tagOptions: [String] {
    Catalog.noteTags.map(\.key) + note.tags.filter { t in !Catalog.noteTags.contains { $0.key == t } }
  }
  private func addTag() {
    let tag = trimmedTag.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
    guard !tag.isEmpty, tag.count <= 50, note.tags.count < 20 else { return }
    if !note.tags.contains(tag) { note.tags.append(tag) }
    customTag = ""
  }
}

/// Card used in the journal and on the start screen.
struct NoteCard: View {
  @EnvironmentObject var store: AppStore
  let note: WellbeingNote
  var onEdit: (() -> Void)?
  var onDelete: (() -> Void)?
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      RoundedRectangle(cornerRadius: 3).fill(note.mood?.color ?? Theme.chip).frame(width: 6)
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Label(
            note.mood?.title(store.language) ?? store.t("Note", "Notatka"),
            systemImage: note.mood?.icon ?? "note.text"
          ).font(.brand(.subheadline, .bold)).foregroundStyle(note.mood?.color ?? Theme.teal)
          Spacer()
          Text(store.language.date(note.date, time: true)).font(.brand(.caption)).foregroundStyle(Theme.muted)
        }
        if !note.text.isEmpty { Text(note.text).font(.brand(.body)).textSelection(.enabled) }
        if !note.tags.isEmpty {
          FlowLayout(spacing: 6) { ForEach(note.tags, id: \.self) { TagChip(text: "#" + store.language.tag($0)) } }
        }
        let doctors = note.observationIDs.compactMap { store.state.doctor(for: $0)?.title(store.language) }
        if !doctors.isEmpty {
          Label(doctors.joined(separator: ", "), systemImage: "stethoscope").font(.brand(.caption))
            .foregroundStyle(Theme.muted)
        }
        if onEdit != nil || onDelete != nil {
          HStack {
            if let onEdit { Button(store.t("Edit", "Edytuj"), action: onEdit).buttonStyle(SecondaryButton()) }
            if let onDelete {
              Button(store.t("Delete", "Usuń"), role: .destructive, action: onDelete).buttonStyle(SecondaryButton())
            }
          }.padding(.top, 2)
        }
      }
    }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
      .background(.white, in: RoundedRectangle(cornerRadius: 22))
      .shadow(color: Theme.ink.opacity(0.07), radius: 10, y: 5)
      .foregroundStyle(Theme.ink)
  }
}
