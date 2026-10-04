import Foundation

@main struct StoreChecks {
    @MainActor static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("SymptoPage-StoreCheck-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("records.json")
        let store = AppStore(url: url)
        precondition(store.ready && store.state.events.isEmpty)
        let doctor = Doctor(specialty: "gp"), observation = Observation(doctorID: UUID(), reason: "Temporary test")
        var linked = observation; linked.doctorID = doctor.id
        precondition(store.change { $0.doctors = [doctor]; $0.observations = [linked] })
        var event = SymptomEvent(symptom: "pain"); event.observationIDs = [linked.id]
        precondition(store.saveEvent(event)); event.note = "Edited"; precondition(store.saveEvent(event))
        precondition(store.state.events.count == 1 && store.state.events[0].timestamp == event.timestamp)
        var future = event; future.timestamp = Date().addingTimeInterval(86400)
        precondition(!store.saveEvent(future)); precondition(store.state.events[0].note == "Edited")
        var check = DailyCheckIn(observationID: linked.id, day: Day.key(.now), symptom: "pain", frequency: .once)
        precondition(store.saveCheckIn(check)); let id = store.state.checkIns[0].id; check.frequency = .several; precondition(store.saveCheckIn(check))
        precondition(store.state.checkIns.count == 1 && store.state.checkIns[0].id == id && store.state.checkIns[0].frequency == .several)
        var moved = store.state.checkIns[0]; moved.day = Day.key(Date().addingTimeInterval(-86400))
        precondition(store.saveCheckIn(moved, editingID: id))
        precondition(store.state.checkIns.count == 1 && store.state.checkIns[0].day == moved.day)
        precondition(store.saveCheckIn(check))
        precondition(!store.saveCheckIn(check, editingID: id))
        precondition(store.state.checkIns.count == 2)
        let medication = Medication(name: "Test only", dosage: "As prescribed", startDay: Day.key(.now), times: [DoseTime(hour: 9, minute: 0)])
        precondition(store.change { $0.medications = [medication]; $0.language = .pl })
        let dose = DosePlanner.doses(medication, on: .now)[0]
        store.mark(dose, status: .postponed); store.mark(dose, status: .taken)
        precondition(store.state.doses.count == 1 && store.state.doses[0].status == .taken && store.state.doses[0].postponedUntil == nil)
        let reopened = AppStore(url: url)
        precondition(reopened.state.events[0].note == "Edited" && reopened.language == .pl)
        precondition(!reopened.restore(Data("broken".utf8)))
        precondition(reopened.state.events.count == 1)
        precondition(reopened.change { $0.profileName = "Kasia"; $0.observations[0].symptom = "pain" })
        precondition(AppStore(url: url).state.profileName == "Kasia" && AppStore(url: url).state.observations[0].symptom == "pain")
        var note = WellbeingNote(text: "  Spacer pomógł  ", mood: .good); note.tags = ["activity"]
        precondition(reopened.saveNote(note) && reopened.state.notes.count == 1 && reopened.state.notes[0].text == "Spacer pomógł")
        note.text = "Edytowano"; precondition(reopened.saveNote(note) && reopened.state.notes.count == 1)
        precondition(!reopened.saveNote(WellbeingNote(text: "   ")) && reopened.state.notes.count == 1)
        var futureNote = WellbeingNote(text: "Future"); futureNote.date = Date().addingTimeInterval(86400)
        precondition(!reopened.saveNote(futureNote))
        precondition(AppStore(url: url).state.notes[0].text == "Edytowano")
        precondition(reopened.deleteNote(note.id) && AppStore(url: url).state.notes.isEmpty)
        print("PASS AppStore event editing, future-date rejection, daily upsert, dose status replacement, language/name/daily-question persistence, wellbeing notes and invalid import")
    }
}
