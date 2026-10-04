import Charts
import SwiftUI

#if SWIFT_PACKAGE
  import SymptoCore
#endif

/// Start screen chart: symptom events per day, stacked by the most frequent symptoms,
/// with the change against the previous period of the same length.
struct SymptomTrendCard: View {
  @EnvironmentObject var store: AppStore
  @State private var range = 14
  private struct Key: Hashable {
    let day: Date
    let symptom: String
  }
  private struct Bar: Identifiable {
    let day: Date
    let symptom: String
    let count: Int
    var id: String { "\(day.timeIntervalSince1970)-\(symptom)" }
  }
  var body: some View {
    let cal = Calendar.current
    let today = cal.startOfDay(for: .now)
    let start = cal.date(byAdding: .day, value: -(range - 1), to: today)!
    let previousStart = cal.date(byAdding: .day, value: -range, to: start)!
    let events = store.events
    let current = events.filter { $0.timestamp >= start }
    let previous = events.filter { $0.timestamp >= previousStart && $0.timestamp < start }
    let top = Dictionary(grouping: current, by: \.symptom).sorted { $0.value.count > $1.value.count }
      .prefix(3).map(\.key)
    let other = store.t("Other", "Inne")
    let bars = Dictionary(grouping: current) { e in
      Key(day: cal.startOfDay(for: e.timestamp), symptom: top.contains(e.symptom) ? store.language.symptom(e.symptom) : other)
    }.map { Bar(day: $0.key.day, symptom: $0.key.symptom, count: $0.value.count) }
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label(store.t("Symptom trend", "Trend objawów"), systemImage: "chart.bar.xaxis")
          .font(.brand(.headline))
        Spacer()
        ForEach([7, 14, 30], id: \.self) { days in
          Button("\(days)" + store.t("d", "d")) { withAnimation { range = days } }
            .buttonStyle(.plain).font(.brand(.caption, .bold)).padding(.horizontal, 10).frame(height: 28)
            .foregroundStyle(range == days ? .white : Theme.chipText)
            .background(range == days ? Theme.teal : Theme.chip, in: Capsule())
        }
      }
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text("\(current.count)").font(.brand(size: 28, .heavy))
        Text(store.t("events", "zdarzeń")).font(.brand(.subheadline)).foregroundStyle(Theme.muted)
        Spacer()
        change(current.count, previous.count)
      }
      if current.isEmpty {
        Text(store.t("No symptoms in this period", "Brak objawów w tym okresie"))
          .font(.brand(.subheadline)).foregroundStyle(Theme.muted).frame(maxWidth: .infinity, minHeight: 120)
      } else {
        Chart(bars) { bar in
          BarMark(x: .value("Day", bar.day, unit: .day), y: .value("Count", bar.count))
            .foregroundStyle(by: .value("Symptom", bar.symptom)).cornerRadius(3)
        }
        .chartForegroundStyleScale(range: [Theme.alert, Theme.teal, Color(hex: 0x5AA9D6), Color(hex: 0xB8C7C9)])
        .chartXScale(domain: start...cal.date(byAdding: .day, value: 1, to: today)!)
        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
        .chartXAxis {
          AxisMarks(values: .stride(by: .day, count: range > 14 ? 7 : range > 7 ? 3 : 1)) { _ in
            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
          }
        }
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 170)
      }
    }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
      .background(.white, in: RoundedRectangle(cornerRadius: 24))
      .shadow(color: Theme.ink.opacity(0.08), radius: 12, y: 6).foregroundStyle(Theme.ink)
      .accessibilityIdentifier("symptomTrend")
  }
  /// Fewer symptoms than in the previous period is shown as an improvement.
  @ViewBuilder private func change(_ now: Int, _ before: Int) -> some View {
    if before > 0 || now > 0 {
      let diff = now - before
      let better = diff < 0
      Label(
        (diff > 0 ? "+" : "") + "\(diff) " + store.t("vs previous", "vs poprzednio"),
        systemImage: diff == 0 ? "equal" : better ? "arrow.down.right" : "arrow.up.right"
      ).font(.brand(.caption, .bold)).padding(.horizontal, 10).frame(height: 26)
        .foregroundStyle(diff == 0 ? Theme.muted : better ? Theme.teal : Theme.alert)
        .background((diff == 0 ? Theme.muted : better ? Theme.teal : Theme.alert).opacity(0.1), in: Capsule())
    }
  }
}
