import SwiftUI

#if SWIFT_PACKAGE
  import SymptoCore
#endif

/// Design screen 1: brand hero, three promises and a single call to action.
struct WelcomeView: View {
  @EnvironmentObject var store: AppStore
  let start: () -> Void
  var body: some View {
    VStack(spacing: 0) {
      Group {
        if let logo = brandImage("BrandLogoWhite") {
          logo.resizable().scaledToFit().frame(maxWidth: 300)
        } else {
          Text("SymptoPage").font(.brand(size: 40, .heavy)).foregroundStyle(.white)
        }
      }.padding(.horizontal, 32).frame(maxWidth: .infinity).frame(minHeight: 260).padding(.top, 20)
        .accessibilityElement().accessibilityLabel("SymptoPage").accessibilityAddTraits(.isHeader)
      VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 10) {
          Text(store.t("Record symptoms.\nShow them to your doctor.", "Zapisuj objawy.\nPokaż je lekarzowi."))
            .font(.brand(size: 26, .heavy))
        }
        VStack(alignment: .leading, spacing: 14) {
          feature("heart", store.t("Daily symptom questions, in seconds", "Codzienne pytania o objawy, w kilka sekund"))
          feature("pencil", store.t("Notes about how you feel in one place", "Notatki o samopoczuciu w jednym miejscu"))
          feature("doc.text", store.t("A ready report for your visit", "Gotowy raport dla lekarza na wizytę"))
        }
        Spacer(minLength: 0)
        HStack(spacing: 8) {
          ForEach(Language.allCases, id: \.self) { language in
            Pill(title: language.name, selected: store.language == language) {
              _ = store.change { $0.language = language }
            }.accessibilityIdentifier("language-" + language.rawValue)
          }
        }.frame(maxWidth: .infinity).accessibilityElement(children: .contain)
          .accessibilityLabel(store.t("Language", "Język"))
        Button(action: start) {
          Text(store.t("Let's start", "Zaczynamy")).font(.brand(size: 17, .heavy))
            .frame(maxWidth: .infinity, minHeight: 56).foregroundStyle(.white)
            .background(Theme.teal, in: Capsule()).contentShape(Capsule())
        }.buttonStyle(.plain).accessibilityIdentifier("startOnboarding")
      }.padding(.horizontal, 24).padding(.top, 32).padding(.bottom, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
          .white, in: UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32)
        )
        .shadow(color: Theme.ink.opacity(0.08), radius: 12, y: -8)
    }
    .frame(maxWidth: 700).frame(maxWidth: .infinity)
    .background {
      GeometryReader { proxy in
        Theme.hero
        Circle().fill(.white.opacity(0.06)).frame(width: 320, height: 320)
          .offset(x: proxy.size.width - 210, y: -90)
        Circle().fill(.white.opacity(0.05)).frame(width: 260, height: 260).offset(x: -120, y: 150)
      }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
    .foregroundStyle(Theme.ink)
  }
  private func feature(_ icon: String, _ text: String) -> some View {
    HStack(spacing: 14) {
      Image(systemName: icon).font(.brand(size: 20, .semibold)).foregroundStyle(Theme.teal)
        .frame(width: 44, height: 44).background(Theme.chip, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityHidden(true)
      Text(text).font(.brand(.body, .semibold))
    }
  }
}
