import Foundation

#if SWIFT_PACKAGE
  import SymptoCore
#endif

/// Demo mode for presentations: fills the app with three weeks of realistic sample records.
/// Replaces current data; "Clear all data" returns to a clean first launch.
extension AppStore {
  @discardableResult func loadDemo() -> Bool {
    let ok = change { s in
      let pl = s.language == .pl
      let cal = Calendar.current
      let now = Date()
      func ago(_ days: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        let day = cal.date(byAdding: .day, value: -days, to: now)!
        return cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
      }
      let keep = (language: s.language, reminders: s.remindersEnabled)
      s = AppState()
      s.language = keep.language
      s.remindersEnabled = keep.reminders
      s.profileName = pl ? "Kasia" : "Kate"

      var cardio = Doctor(specialty: "cardiologist")
      cardio.name = pl ? "dr Anna Nowak" : "Dr Anna Nowak"
      var neuro = Doctor(specialty: "neurologist")
      neuro.name = pl ? "dr Piotr Wiśniewski" : "Dr Peter White"
      s.doctors = [cardio, neuro]

      var heart = Observation(
        doctorID: cardio.id, reason: pl ? "Kołatanie serca wieczorem" : "Palpitations in the evening")
      heart.symptom = "palpitations"
      var head = Observation(
        doctorID: neuro.id, reason: pl ? "Bóle głowy rano" : "Morning headaches")
      head.symptom = "headache"
      s.observations = [heart, head]

      var v1 = Visit(observationID: heart.id, date: cal.date(byAdding: .day, value: 9, to: ago(0, 10, 30))!)
      v1.questions = pl ? "Czy mogę pić kawę? Czy potrzebne jest EKG Holter?" : "Can I drink coffee? Do I need a Holter ECG?"
      let v2 = Visit(observationID: head.id, date: cal.date(byAdding: .day, value: 16, to: ago(0, 14))!)
      s.visits = [v1, v2]

      // Three weeks of symptoms, more frequent in the first week, easing after medication started.
      let plan: [(Int, Int, Int, String, UUID, Int, String)] = [
        (20, 21, 10, "palpitations", heart.id, 6, pl ? "Po dwóch kawach" : "After two coffees"),
        (19, 7, 40, "headache", head.id, 5, ""),
        (18, 22, 5, "palpitations", heart.id, 7, ""),
        (18, 8, 15, "headache", head.id, 6, pl ? "Źle spałam" : "Slept badly"),
        (17, 20, 30, "palpitations", heart.id, 5, ""),
        (16, 21, 45, "dizziness", heart.id, 4, pl ? "Przy wstawaniu" : "When standing up"),
        (15, 7, 30, "headache", head.id, 7, ""),
        (14, 22, 0, "palpitations", heart.id, 6, ""),
        (13, 19, 20, "palpitations", heart.id, 5, pl ? "Po treningu" : "After a workout"),
        (12, 8, 0, "headache", head.id, 4, ""),
        (11, 21, 15, "palpitations", heart.id, 4, ""),
        (10, 16, 40, "fatigue", head.id, 5, ""),
        (9, 7, 50, "headache", head.id, 5, ""),
        (8, 21, 30, "palpitations", heart.id, 3, ""),
        (6, 8, 10, "headache", head.id, 3, ""),
        (5, 22, 20, "palpitations", heart.id, 3, ""),
        (3, 7, 45, "headache", head.id, 2, pl ? "Lżej niż zwykle" : "Milder than usual"),
        (2, 21, 0, "palpitations", heart.id, 3, ""),
        (0, 9, 5, "dizziness", heart.id, 2, ""),
      ]
      let rates = [112, 0, 121, 0, 108, 96, 0, 115, 124, 0, 104, 0, 0, 99, 0, 98, 0, 101, 88]
      for (i, p) in plan.enumerated() {
        var e = SymptomEvent(symptom: p.3)
        e.timestamp = ago(p.0, p.1, p.2)
        e.observationIDs = [p.4]
        e.intensity = p.5
        e.note = p.6
        if rates[i] > 0 { e.heartRate = rates[i] }
        if p.3 == "palpitations" { e.durationMinutes = [5, 10, 15, 20][i % 4] }
        s.events.append(e)
      }

      // Daily answers for both doctors over the last two weeks.
      for d in 0..<14 {
        let day = Day.key(ago(d, 12))
        let h: Frequency = d > 9 ? .several : d > 4 ? .once : (d % 2 == 0 ? .none : .once)
        let n: Frequency = d > 10 ? .once : (d % 3 == 0 ? .once : .none)
        s.checkIns.append(DailyCheckIn(observationID: heart.id, day: day, symptom: "palpitations", frequency: h))
        s.checkIns.append(DailyCheckIn(observationID: head.id, day: day, symptom: "headache", frequency: n))
      }

      var n1 = WellbeingNote(text: pl ? "Spałam 5 godzin, po spacerze lepiej." : "Slept 5 hours, better after a walk.", mood: .okay)
      n1.date = ago(1, 20)
      n1.tags = pl ? ["sen", "ruch"] : ["sleep", "activity"]
      var n2 = WellbeingNote(text: pl ? "Bez kawy od tygodnia — mniej kołatań." : "No coffee for a week — fewer palpitations.", mood: .good)
      n2.date = ago(4, 19)
      n2.observationIDs = [heart.id]
      n2.tags = pl ? ["kawa"] : ["coffee"]
      var n3 = WellbeingNote(text: pl ? "Stresujący tydzień w pracy." : "Stressful week at work.", mood: .bad)
      n3.date = ago(15, 21)
      s.notes = [n1, n2, n3]

      var m = Medication(
        name: "Bisoprolol", dosage: "2,5 mg", startDay: Day.key(ago(10, 8)),
        times: [DoseTime(hour: 8, minute: 0)])
      m.observationID = heart.id
      m.instructions = pl ? "Rano, po śniadaniu" : "In the morning, after breakfast"
      s.medications = [m]

      for i in 0..<30 {
        var d = HealthDay(day: Day.key(ago(i, 12)))
        d.restingHR = (i > 10 ? 68 : 62) + (i * 7) % 5
        d.hrv = (i > 10 ? 34 : 42) + (i * 5) % 9
        d.steps = 4200 + (i * 1733) % 7800
        d.sleepMinutes = 330 + (i * 37) % 150
        s.healthDays.append(d)
      }
      s.healthDays.sort { $0.day < $1.day }
    }
    selectedDoctors = []
    Task { await refreshNotifications() }
    return ok
  }

  @discardableResult func clearAll() -> Bool {
    let ok = change { s in
      let language = s.language
      s = AppState()
      s.language = language
    }
    selectedDoctors = []
    Task { await refreshNotifications() }
    return ok
  }
}
