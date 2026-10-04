import CoreText
import SwiftUI

#if os(watchOS)
  import WatchKit
#endif

/// Watch palette (same tokens as the phone design).
enum WTheme {
  static let teal = Color(red: 0.086, green: 0.451, blue: 0.455)
  static let mint = Color(red: 0.494, green: 0.812, blue: 0.784)
  static let red = Color(red: 0.827, green: 0.184, blue: 0.184)
  static let card = Color(white: 0.13)
  static func mood(_ m: Mood) -> Color {
    switch m {
    case .veryBad: return Color(red: 0.83, green: 0.18, blue: 0.18)
    case .bad: return Color(red: 0.94, green: 0.49, blue: 0.34)
    case .okay: return Color(red: 0.95, green: 0.71, blue: 0.27)
    case .good: return Color(red: 0.21, green: 0.65, blue: 0.63)
    case .veryGood: return Color(red: 0.49, green: 0.81, blue: 0.78)
    }
  }
  static func moodIcon(_ m: Mood) -> String {
    ["cloud.bolt.rain.fill", "cloud.rain.fill", "cloud.sun.fill", "sun.max.fill", "sparkles"][m.rawValue - 1]
  }
  static func intensity(_ v: Int) -> Color { v <= 3 ? mint : v <= 6 ? Color(red: 0.95, green: 0.71, blue: 0.27) : red }
}
enum WFont {
  static func register() {
    for name in ["Regular", "SemiBold", "Bold", "ExtraBold"] {
      if let url = Bundle.main.url(forResource: "Manrope-" + name, withExtension: "ttf") {
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
      }
    }
  }
  static func f(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
    let name = weight == .heavy ? "Manrope-ExtraBold" : weight == .bold ? "Manrope-Bold" : weight == .semibold ? "Manrope-SemiBold" : "Manrope-Regular"
    return .custom(name, size: size, relativeTo: .body)
  }
}

struct WatchRootView: View {
  @EnvironmentObject var store: WatchStore
  var body: some View {
    NavigationStack {
      TabView {
        WatchNowPage()
        ForEach(store.context?.observations.filter { $0.symptom != nil } ?? []) { item in
          WatchQuestionPage(item: item)
        }
        WatchMoodPage()
      }
      #if os(watchOS)
        .tabViewStyle(.verticalPage)
      #endif
    }
    .task { await store.refreshHeartRate() }
  }
}

/// Page 1: one big red button — "Now!".
struct WatchNowPage: View {
  @EnvironmentObject var store: WatchStore
  var body: some View {
    VStack(spacing: 6) {
      HStack {
        Text(store.context?.name.map { store.t("Hi ", "Cześć ") + $0 } ?? "SymptoPage")
          .font(WFont.f(14, .bold)).foregroundStyle(WTheme.mint).lineLimit(1)
        Spacer()
        if let hr = store.heartRate {
          Label("\(hr)", systemImage: "heart.fill").font(WFont.f(13, .bold)).foregroundStyle(WTheme.red)
            .labelStyle(.titleAndIcon)
        }
      }
      NavigationLink {
        WatchSymptomList()
      } label: {
        ZStack {
          Circle().fill(RadialGradient(colors: [Color(red: 0.93, green: 0.30, blue: 0.28), WTheme.red], center: .topLeading, startRadius: 4, endRadius: 120))
          Circle().stroke(.white.opacity(0.18), lineWidth: 4).padding(6)
          VStack(spacing: 0) {
            Text("!!!").font(WFont.f(20, .heavy))
            Text(store.t("Now!", "Teraz!")).font(WFont.f(24, .heavy))
          }.foregroundStyle(.white)
        }.frame(width: 128, height: 128).shadow(color: WTheme.red.opacity(0.5), radius: 10)
      }.buttonStyle(.plain).accessibilityIdentifier("watchNow")
      Text(
        store.savedToday > 0
          ? store.t("Saved today: ", "Zapisano dziś: ") + "\(store.savedToday)"
          : store.t("Tap when it happens", "Stuknij, gdy coś się dzieje")
      ).font(WFont.f(11, .semibold)).foregroundStyle(.secondary)
    }.padding(.horizontal, 4)
  }
}

/// Step 2: which symptom (daily questions first, then recent).
struct WatchSymptomList: View {
  @EnvironmentObject var store: WatchStore
  var body: some View {
    ScrollView {
      VStack(spacing: 6) {
        ForEach(symptoms, id: \.self) { key in
          NavigationLink {
            WatchIntensityView(symptom: key)
          } label: {
            HStack(spacing: 10) {
              Image(systemName: Catalog.symptom(key)?.icon ?? "waveform.path.ecg").font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white).frame(width: 30, height: 30).background(WTheme.red, in: Circle())
              Text(store.label(key)).font(WFont.f(15, .bold)).foregroundStyle(.white).lineLimit(2)
                .multilineTextAlignment(.leading)
              Spacer(minLength: 0)
            }.padding(.horizontal, 10).frame(minHeight: 46).background(WTheme.card, in: RoundedRectangle(cornerRadius: 16))
          }.buttonStyle(.plain)
        }
      }
    }.navigationTitle(store.t("What?", "Co?"))
  }
  private var symptoms: [String] {
    let quick = store.context?.quickSymptoms ?? []
    return quick.isEmpty ? ["palpitations", "dizziness", "headache", "pain", "fatigue", "dyspnea"] : quick
  }
}

/// Step 3: intensity with the Digital Crown, then save.
struct WatchIntensityView: View {
  @EnvironmentObject var store: WatchStore
  @Environment(\.dismiss) private var dismiss
  let symptom: String
  @State private var value = 5.0
  @State private var saved = false
  var body: some View {
    if saved {
      WatchSavedView(symptom: symptom, intensity: Int(value))
    } else {
      VStack(spacing: 6) {
        Text(store.label(symptom)).font(WFont.f(13, .bold)).foregroundStyle(WTheme.mint).lineLimit(1)
        ZStack {
          Circle().stroke(Color(white: 0.2), lineWidth: 9)
          Circle().trim(from: 0, to: value / 10).stroke(WTheme.intensity(Int(value)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            .rotationEffect(.degrees(-90))
          VStack(spacing: -4) {
            Text("\(Int(value))").font(WFont.f(40, .heavy)).foregroundStyle(.white).contentTransition(.numericText())
            Text("/10").font(WFont.f(11, .bold)).foregroundStyle(.secondary)
          }
        }.frame(width: 96, height: 96)
          .focusable()
        #if os(watchOS)
          .digitalCrownRotation($value, from: 1, through: 10, by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        #endif
        HStack(spacing: 6) {
          Button(store.t("Skip", "Bez")) { save(nil) }.buttonStyle(WatchButton(fill: WTheme.card))
          Button(store.t("Save", "Zapisz")) { save(Int(value)) }.buttonStyle(WatchButton(fill: WTheme.teal))
            .accessibilityIdentifier("watchSave")
        }
      }
    }
  }
  private func save(_ intensity: Int?) {
    store.recordSymptom(symptom, intensity: intensity)
    withAnimation(.spring) { saved = true }
    Task {
      try? await Task.sleep(nanoseconds: 1_600_000_000)
      dismiss()
    }
  }
}

struct WatchSavedView: View {
  @EnvironmentObject var store: WatchStore
  let symptom: String
  let intensity: Int?
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "checkmark").font(.system(size: 34, weight: .heavy)).foregroundStyle(.white)
        .frame(width: 74, height: 74).background(WTheme.teal, in: Circle())
        .shadow(color: WTheme.mint.opacity(0.5), radius: 10)
      Text(store.t("Saved", "Zapisano")).font(WFont.f(18, .heavy))
      Text(
        [store.label(symptom), intensity.map { "\($0)/10" }, store.heartRate.map { "♥ \($0)" }].compactMap { $0 }
          .joined(separator: " · ")
      ).font(WFont.f(12, .semibold)).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }
  }
}

/// One page per observation: today's question with three big answers.
struct WatchQuestionPage: View {
  @EnvironmentObject var store: WatchStore
  let item: WatchContext.Item
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(item.title).font(WFont.f(12, .bold)).foregroundStyle(WTheme.mint).lineLimit(1)
        Spacer()
        if let days = item.daysLeft, days >= 0 {
          Text(store.language == .pl ? "\(days) dni" : "\(days) d").font(WFont.f(12, .heavy)).foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 2).background(WTheme.teal, in: Capsule())
        }
      }
      Text(store.t("Today: ", "Dziś: ") + store.label(item.symptom ?? "") + "?").font(WFont.f(16, .heavy))
        .lineLimit(2).minimumScaleFactor(0.8)
      HStack(spacing: 5) {
        ForEach(Frequency.allCases, id: \.self) { f in
          let selected = item.answer == f
          Button(f.title(store.language)) { store.answer(item, f) }
            .buttonStyle(WatchButton(fill: selected ? WTheme.teal : WTheme.card, height: 44))
            .accessibilityIdentifier("watchAnswer-" + f.rawValue)
        }
      }
      if item.answer != nil {
        Label(store.t("Answered", "Odpowiedziano"), systemImage: "checkmark.circle.fill").font(WFont.f(11, .bold))
          .foregroundStyle(WTheme.mint)
      }
    }.padding(.horizontal, 4)
  }
}

/// Mood in one tap.
struct WatchMoodPage: View {
  @EnvironmentObject var store: WatchStore
  @State private var chosen: Mood?
  var body: some View {
    VStack(spacing: 8) {
      Text(chosen == nil ? store.t("How do you feel?", "Jak się czujesz?") : chosen!.title(store.language))
        .font(WFont.f(15, .heavy)).foregroundStyle(chosen.map(WTheme.mood) ?? .white)
      let rows: [[Mood]] = [[.veryBad, .bad, .okay], [.good, .veryGood]]
      ForEach(rows, id: \.self) { row in
        HStack(spacing: 8) {
          ForEach(row, id: \.self) { m in
            Button {
              chosen = m
              store.mood(m)
            } label: {
              Image(systemName: WTheme.moodIcon(m)).font(.system(size: 20, weight: .bold))
                .foregroundStyle(chosen == m ? .black : WTheme.mood(m)).frame(width: 50, height: 50)
                .background(chosen == m ? WTheme.mood(m) : WTheme.mood(m).opacity(0.18), in: Circle())
            }.buttonStyle(.plain).accessibilityLabel(m.title(store.language))
          }
        }
      }
    }
  }
}

struct WatchButton: ButtonStyle {
  var fill: Color
  var height: CGFloat = 40
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.font(WFont.f(14, .heavy)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
      .frame(maxWidth: .infinity, minHeight: height).background(fill, in: Capsule())
      .opacity(configuration.isPressed ? 0.7 : 1)
  }
}
