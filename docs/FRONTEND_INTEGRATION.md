# Frontend and brand integration

The colleague supplied four static HTML screens (welcome, empty start, active observation, add visit) in `work/design-reference/ekrany`. Version 0.6.0 reimplements them natively: tokens are in `Theme` (App/Design.swift), screens in App/WelcomeView.swift and App/TodayView.swift. The HTML itself is not embedded. Deviations: owner brand "SymptoPage" instead of "SymptoPad", no resting heart rate (HealthKit out of scope), gender-neutral Polish daily question ("Czy dziś pojawiło się …?").

View contract: read AppStore.state, language, observations, events and selectedDoctors. Mutations go through change(), saveEvent(), saveCheckIn(), mark(), restore(). Return true only after persistence succeeds; forms dismiss only on true. No view writes records.json directly. Long-lived edits use local drafts. Do not trigger persistence on every keystroke.

Brand resources received from the owner:
- BrandLogo: full transparent wordmark, original 545×132.
- BrandIconBlue: original blue icon, 132×130.
- BrandIconWhite: original white icon, 132×130, retained for future appearance options.
- AppIcon: blue original fitted onto a 1024×1024 opaque canvas by scripts/prepare_app_icon.swift. No new graphic was invented. Source resolution limits final sharpness.

Replace files and Contents.json in App/Resources/Assets.xcassets with higher-resolution originals when available. Brand view reads BrandLogo. The macOS preview packager copies the same logo into its bundle. Keep assets free of medical records or other private data.

All product strings use paired EN/PL text. User-entered content is preserved verbatim and not automatically translated. Dynamic Type uses semantic fonts; interactive icons have labels. Validate accessibility with VoiceOver and large text on iPhone before release.

Fonts: `App/Resources/Fonts/Manrope-{Regular,SemiBold,Bold,ExtraBold}.ttf` are static instances of the variable Manrope supplied in `ekrany.zip` (latin + latin-ext subsets merged so Polish letters work). `BrandFonts.register()` registers them at launch; use `Font.brand(.headline)` etc. in views. `PDFRenderer.font` uses the same files and falls back to Helvetica.
