import SwiftUI

#if SWIFT_PACKAGE
  import SymptoCore
#endif

/// One timeline mixing symptom events, daily answers and wellbeing notes, grouped by day.
struct JournalView: View {
  enum Kind: String, CaseIterable { case all, events, daily, notes }
  private enum Entry: Identifiable {
    case event(SymptomEvent), daily(DailyCheckIn), note(WellbeingNote)
    var id: String {
      switch self {
      case .event(let e): return "e" + e.id.uuidString
      case .daily(let c): return "d" + c.id.uuidString
      case .note(let n): return "n" + n.id.uuidString
      }
    }
    var day: String {
      switch self {
      case .event(let e): return Day.key(e.timestamp)
      case .daily(let c): return c.day
      case .note(let n): return Day.key(n.date)
      }
    }
    var sortDate: Date {
      switch self {
      case .event(let e): return e.timestamp
      case .daily(let c): return (Day.date(c.day) ?? c.updatedAt).addingTimeInterval(86399)
      case .note(let n): return n.date
      }
    }
  }
  @EnvironmentObject var store: AppStore
  @State private var kind: Kind = .all
  @State private var search = ""
  @State private var from = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
  @State private var through = Date()
  @State private var allDates = true
  @State private var editing: SymptomEvent?
  @State private var deleting: SymptomEvent?
  @State private var adding = false
  @State private var addingNote = false
  @State private var editingNote: WellbeingNote?
  @State private var deletingNote: WellbeingNote?
  @State private var checkIn = false
  @State private var editingCheckIn: DailyCheckIn?
  @State private var deletingCheckIn: DailyCheckIn?
  var body: some View {
    SoftScreen {
      HStack(spacing: 10) {
        Button {
          adding = true
        } label: {
          Label(store.t("Symptom", "Objaw"), systemImage: "plus")
        }.buttonStyle(PrimaryButton(coral: true)).accessibilityIdentifier("journalAddEvent")
        Button {
          addingNote = true
        } label: {
          Label(store.t("Note", "Notatka"), systemImage: "square.and.pencil")
        }.buttonStyle(PrimaryButton()).accessibilityIdentifier("journalAddNote")
      }
      FilterButton()
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(Kind.allCases, id: \.self) { value in
            Pill(title: title(value), selected: kind == value) { kind = value }
              .accessibilityIdentifier("journalKind-" + value.rawValue)
          }
        }
      }
      HStack {
        Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
        TextField(store.t("Search symptoms and notes", "Szukaj objawów i notatek"), text: $search)
          .textFieldStyle(.plain)
      }.padding(12).background(.white, in: Capsule())
      Toggle(store.t("All dates", "Wszystkie daty"), isOn: $allDates).font(.brand(.subheadline, .semibold))
      if !allDates {
        DatePicker(store.t("From", "Od"), selection: $from, in: ...through, displayedComponents: .date)
        DatePicker(store.t("Through", "Do"), selection: $through, in: from..., displayedComponents: .date)
      }
      if entries.isEmpty {
        EmptyCard(
          icon: "text.book.closed",
          title: store.t("No matching events", "Brak pasujących wpisów"),
          message: store.t(
            "Record a symptom or change your filters. Missing entries do not mean no symptoms.",
            "Zapisz objaw lub zmień filtry. Brak wpisów nie oznacza braku objawów."))
      }
      ForEach(groups, id: \.day) { group in
        Text(dayTitle(group.day)).font(.brand(.headline, .heavy)).foregroundStyle(Theme.teal)
          .padding(.top, 6)
        ForEach(group.items) { entry in row(entry) }
      }
      Button(store.t("Add / update daily check-in", "Dodaj / zmień codzienny wpis")) {
        checkIn = true
      }.buttonStyle(SecondaryButton(fill: true))
    }.navigationTitle(store.t("Journal", "Dziennik"))
      .sheet(isPresented: $adding) { EventForm() }.sheet(item: $editing) { EventForm(event: $0) }
      .sheet(isPresented: $addingNote) { NoteForm() }.sheet(item: $editingNote) { NoteForm(note: $0) }
      .sheet(isPresented: $checkIn) { CheckInForm() }
      .sheet(item: $editingCheckIn) { CheckInForm(existing: $0) }
      .confirmationDialog(
        store.t("Delete this daily check-in?", "Usunąć ten codzienny wpis?"),
        isPresented: Binding(get: { deletingCheckIn != nil }, set: { if !$0 { deletingCheckIn = nil } }),
        titleVisibility: .visible
      ) {
        Button(store.t("Delete", "Usuń"), role: .destructive) {
          if let deletingCheckIn { _ = store.change { $0.checkIns.removeAll { $0.id == deletingCheckIn.id } } }
          deletingCheckIn = nil
        }
      }
      .confirmationDialog(
        store.t("Delete this note?", "Usunąć tę notatkę?"),
        isPresented: Binding(get: { deletingNote != nil }, set: { if !$0 { deletingNote = nil } }),
        titleVisibility: .visible
      ) {
        Button(store.t("Delete note", "Usuń notatkę"), role: .destructive) {
          if let deletingNote { _ = store.deleteNote(deletingNote.id) }
          deletingNote = nil
        }
      }
      .confirmationDialog(
        store.t(
          "Delete this event? It will be removed from every linked observation.",
          "Usunąć to zdarzenie? Zniknie ze wszystkich powiązanych obserwacji."),
        isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
        titleVisibility: .visible
      ) {
        Button(store.t("Delete event", "Usuń zdarzenie"), role: .destructive) {
          if let deleting { _ = store.change { $0.events.removeAll { $0.id == deleting.id } } }
          deleting = nil
        }
      }
  }

  @ViewBuilder private func row(_ entry: Entry) -> some View {
    switch entry {
    case .event(let e): EventCard(event: e, onEdit: { editing = e }, onDelete: { deleting = e })
    case .note(let n): NoteCard(note: n, onEdit: { editingNote = n }, onDelete: { deletingNote = n })
    case .daily(let c):
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "checklist").font(.system(size: 18, weight: .semibold)).foregroundStyle(Theme.teal)
          .frame(width: 38, height: 38).background(Theme.chip, in: RoundedRectangle(cornerRadius: 12))
        VStack(alignment: .leading, spacing: 6) {
          Text(store.t("Daily answer", "Codzienna odpowiedź")).font(.brand(.caption, .semibold))
            .foregroundStyle(Theme.muted)
          Text("\(store.language.symptom(c.symptom)): \(c.frequency.title(store.language))")
            .font(.brand(.headline))
          if let wellbeing = c.wellbeing {
            Text(wellbeing.title(store.language)).font(.brand(.subheadline, .semibold)).foregroundStyle(Theme.teal)
          }
          if !c.note.isEmpty { Text(c.note) }
          HStack {
            Button(store.t("Edit", "Edytuj")) { editingCheckIn = c }.buttonStyle(SecondaryButton())
            Button(store.t("Delete", "Usuń"), role: .destructive) { deletingCheckIn = c }
              .buttonStyle(SecondaryButton())
          }
        }
        Spacer(minLength: 0)
      }.padding(16).background(.white, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: Theme.ink.opacity(0.07), radius: 10, y: 5)
    }
  }
  private func title(_ kind: Kind) -> String {
    switch kind {
    case .all: return store.t("All", "Wszystko")
    case .events: return store.t("Symptoms", "Objawy")
    case .daily: return store.t("Daily answers", "Codzienne")
    case .notes: return store.t("Notes", "Notatki")
    }
  }
  private func dayTitle(_ day: String) -> String {
    if day == Day.key(.now) { return store.t("Today", "Dzisiaj") }
    if let y = Calendar.current.date(byAdding: .day, value: -1, to: .now), day == Day.key(y) {
      return store.t("Yesterday", "Wczoraj")
    }
    return Day.date(day).map { store.language.date($0) } ?? day
  }
  private func inRange(_ day: String) -> Bool {
    allDates || (day >= Day.key(from) && day <= Day.key(through))
  }
  private func matches(_ text: String) -> Bool {
    search.isEmpty || text.localizedCaseInsensitiveContains(search)
  }
  private var entries: [Entry] {
    var result: [Entry] = []
    if kind == .all || kind == .events {
      result += store.events.filter {
        inRange(Day.key($0.timestamp))
          && matches("\(store.language.symptom($0.symptom)) \($0.note) \($0.context)")
      }.map(Entry.event)
    }
    if kind == .all || kind == .daily {
      result += store.state.checkIns.filter { c in
        (store.selectedDoctors.isEmpty
          || c.observationID.map { store.state.matches([$0], doctors: store.selectedDoctors) } == true)
          && inRange(c.day) && matches("\(store.language.symptom(c.symptom)) \(c.note)")
      }.map(Entry.daily)
    }
    if kind == .all || kind == .notes {
      result += store.notes.filter {
        inRange(Day.key($0.date))
          && matches(
            "\($0.text) \($0.mood?.title(store.language) ?? "") "
              + $0.tags.map { store.language.tag($0) }.joined(separator: " "))
      }.map(Entry.note)
    }
    return result.sorted { $0.sortDate > $1.sortDate }
  }
  private var groups: [(day: String, items: [Entry])] {
    var order: [String] = []
    var map: [String: [Entry]] = [:]
    for entry in entries {
      if map[entry.day] == nil { order.append(entry.day) }
      map[entry.day, default: []].append(entry)
    }
    return order.map { ($0, map[$0]!) }
  }
}

/// Symptom event card with its catalog icon.
struct EventCard: View {
  @EnvironmentObject var store: AppStore
  let event: SymptomEvent
  var onEdit: (() -> Void)?
  var onDelete: (() -> Void)?
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: Catalog.symptom(event.symptom)?.icon ?? "waveform.path.ecg")
        .font(.system(size: 18, weight: .semibold)).foregroundStyle(.white)
        .frame(width: 38, height: 38).background(Theme.alert, in: RoundedRectangle(cornerRadius: 12))
      VStack(alignment: .leading, spacing: 6) {
        HStack(alignment: .firstTextBaseline) {
          Text(store.language.symptom(event.symptom)).font(.brand(.headline))
          Spacer()
          Text(event.timestamp, style: .time).font(.brand(.caption, .semibold)).foregroundStyle(Theme.muted)
        }
        if event.intensity != nil || event.durationMinutes != nil || event.heartRate != nil || event.source != nil {
          HStack(spacing: 6) {
            if let intensity = event.intensity {
              TagChip(text: store.t("Intensity ", "Nasilenie ") + "\(intensity)/10")
            }
            if let duration = event.durationMinutes { TagChip(text: "\(duration) min") }
            if let hr = event.heartRate { TagChip(text: "♥ \(hr)/min") }
            if event.source == "watch" {
              Image(systemName: "applewatch").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.muted)
                .accessibilityLabel("Apple Watch")
            }
          }
        }
        if !event.note.isEmpty { Text(event.note) }
        if !event.context.isEmpty {
          Text(event.context).font(.brand(.subheadline)).foregroundStyle(Theme.muted)
        }
        if event.observationIDs.isEmpty {
          Text(store.t("General entry", "Wpis ogólny")).font(.brand(.caption)).foregroundStyle(Theme.muted)
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
