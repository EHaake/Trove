# Plan 004 — Light mode

**Status**: Draft — pending sign-off
**Implements**: spec.md in this directory (approved by the person 2026-09-09)
**Drafted**: 2026-09-09 by the `sdd-planner`, against the approved `spec.md` and the code on `main` at the point spec 004 branches, from a planning bundle carrying the spec, `003-trend-aware-sell-plan`'s plan and tasks as the pattern, and the file listing. Read beyond the bundle, recorded for the next bundle: `ContentView.swift`, `Color+Hex.swift`, `TestSupport.swift`, `SettingsViewModel.swift`, `WishlistView.swift`, `MenuPolicyTests.swift`, and `specs/013-settings-menu/plan.md`. **This dispatch ran at the implementation tier (`opus`) at high effort under the model policy's Fallback clause — the top tier's (`fable`) budget is spent** (spec.md line 5 records the same for the spec session); logged in the tier log below.

## Context

What exists, read from the code rather than remembered:

- `Theme` (`Trove/Views/Shared/Theme/Theme.swift`) is a `Sendable` struct of `colors: ThemeColors`, `typography: ThemeTypography`, `metrics: ThemeMetrics`, with one instance `Theme.dark`. `EnvironmentValues.theme` is an `@Entry` defaulting to `.dark`. Views read every colour, font and metric off `@Environment(\.theme)`; `NoHardcodedColorsTests` fails the build if a view under `Trove/Views/` (except `/Views/Shared/Theme/`) constructs a `Color(` or names a system colour. The abstraction's stated purpose (Theme.swift's own doc comment, ThemeColors.swift lines 6–10) is that a second palette is "inject a different instance," not a sweep.
- `ThemeColors` carries ~30 semantic tokens and one instance, `.dark`. Text tokens are one ivory (`#F2EDE4`) at eight descending opacities. `accentMoss`/`accentRust` are "strokes, borders and fills only — fail contrast on `surface` as text"; `accentMossText`/`accentRustText` are the contrast-safe lifts for when the accent must be text. The dial ramp (`accentRust` → `dialMidpoint` → `accentMoss`) and the gauge tones (`accentBrassDim`/`accentBrassMid`/`accentBrass`) were tuned by an Oklab search recorded in `design/tokens.md`.
- `ThemeTypography` sizes every font `fixedSize:` (no Dynamic Type — the 001 limitation, `003` Decision 11) and has one instance `.standard`. `ThemeMetrics` likewise has one instance `.standard`. Neither varies by appearance today, and this spec keeps them shared (spec "The look is the same Trove… colour-only"): light mode changes `colors` alone.
- `TroveApp.swift` (lines 66–87) injects `.environment(\.theme, .dark)` and pins `.preferredColorScheme(.dark)` on `ContentView`, with the comment (lines 81–84) that the pin keeps system chrome matching the dark palette. `ContentView` reads `@Environment(\.theme)` for its `.tint(theme.colors.accentBrass)` and injects nothing itself. There is **no** `AppStorage`/`UserDefaults` anywhere in the app: the appearance choice is the first stored preference.
- `SyncMonitor` is the app's precedent for app-level `@Observable` state: created in `TroveApp.init`, put in the environment, read by `ContentView` (`@Environment(SyncMonitor.self)`) and **constructor-injected** into each screen's view model — `013` overturned reading it from the environment inside the Settings sheet (013 plan, "Overturned or reshaped"), so every screen threads it in. `SettingsView` takes `modelContext`, `syncMonitor`, `storageMode`, `storageFallbackReason`; the three hosts that open Settings — `ItemListView`, `WishlistView`, `DashboardView` — read those from the environment and thread them in (`SettingsWiringTests.settingsHosts`).
- `SettingsView` is bespoke (013): `DetailSection`-headed rows inside a `ScrollView`, not a system `List`. `MenuPolicyTests` enforces "bespoke inside the page, system in the bars" — no `Menu {`/`Menu(`, `.pickerStyle(.menu)` or `.contextMenu` in any view except `DetailOverflowMenu`. A segmented `Picker` (`.pickerStyle(.segmented)`) is **not** a menu and is not forbidden by that scan.
- `ThemeTests.swift` holds `ThemeColorTokenTests` (channel-literal pins of every `.dark` token, written independently of the source so a fat-fingered digit is caught) and `NoHardcodedColorsTests`. `DesireDialTests.swift`/`DesireGaugeTests.swift` hold the perceptual guarantees, all keyed on `ThemeColors.dark`: dial adjacent-stop ΔE > 0.06, no stop closer to brass than to its neighbours, numeral lifts clear 3:1 on `surface` while the raw accents fail; gauge tones distinguishable from empty track and from each other **sampled off a rendered view** (`renderBitmap`, which hardcodes `.environment(\.theme, .dark)`). `TrendArrow`'s render tests sample the moss/rust lift ink the arrow draws.
- `PrintPalette` (`Trove/Export/PDFComposer.swift`, lines 20–35) is a `nonisolated enum` of fixed CGColors — paper white, ink, brass darkened to clear 4.5:1 on white — reading nothing from `Theme`. The PDF is already appearance-independent by construction (spec Decision 6).

## Proposed at planning (Q1–Q9) — approved on sign-off unless overturned

- **Q1. The appearance choice is a plain enum; the SwiftUI mapping is a separate extension.** `AppearanceChoice: String, CaseIterable, Sendable` in `Trove/Models/AppearanceChoice.swift` — `case system, light, dark` — with `displayName` ("System"/"Light"/"Dark") the only copy, and **no SwiftUI import** (a model, per the constitution). Its `preferredColorScheme` (`.system` → `nil`, `.light` → `.light`, `.dark` → `.dark`) and `resolvedTheme(systemColorScheme:)` (`.light` → `.light`, `.dark` → `.dark`, `.system` → `systemColorScheme == .dark ? .dark : .light`) live in `Trove/Views/Shared/Theme/AppearanceChoice+Theme.swift`, which may import SwiftUI. **The resolver never consults `colorScheme` for an explicit choice** — so the theme it returns for Light/Dark does not depend on `.preferredColorScheme` feeding back into the same view's `@Environment(\.colorScheme)`, a SwiftUI behaviour this plan does not want to rely on. Only `.system` reads `colorScheme`, which is exactly the live signal it should follow.
- **Q2. The choice is stored in `UserDefaults`, behind a small app-level `@Observable`, mirroring `SyncMonitor`.** `AppearanceStore` (`@Observable final class`, `Trove/App/AppearanceStore.swift`): `var choice: AppearanceChoice { didSet { persist } }`, `init(defaults: UserDefaults = .standard)` that reads the stored raw value **synchronously at init** (so the choice is known before the first frame) and defaults to `.dark` when the key is absent or unrecognised (spec Decision 3, criterion 6). Persistence to `UserDefaults` is per-device and never mirrored to CloudKit (spec Decision 4). `UserDefaults` is chosen over a SwiftData row precisely because it is local-only and readable before the store is built. `AppStorage` is deliberately **not** the source of truth: one concrete `@Observable` instance shared by the root and Settings gives live propagation by observation (criterion 4) without depending on whether an external `UserDefaults` write refreshes an `@AppStorage`-bound view — a claim this plan would otherwise have to verify.
- **Q3. Light tokens are derived and Oklab-measured by the implementer, recorded in `design/tokens.md`, and pinned by an independent channel-literal test** (spec Decision 5; the `001` method). No value is picked by eye; the person attests visually at the phase pause. The derivation is one loop with the perceptual re-earning (§3): the dial ramp and gauge tones are searched against the Oklab model the same way the dark ramp was, so §2 and §3 land in one task (T001), and its token pins are written from the tokens.md light column, not copied from `ThemeColors.light` (a copy could not detect a wrong source value — the pin must be a genuine second transcription).
- **Q4. Typography and metrics stay shared.** `Theme.light = Theme(colors: .light, typography: .standard, metrics: .standard)`. `ThemeMetrics` and `ThemeTypography` gain `Equatable` (all members are already `Equatable` — `CGFloat`, `CGSize`, `Font`), and a test asserts `Theme.light.metrics == Theme.dark.metrics` and `Theme.light.typography == Theme.dark.typography`, so "light mode is colour-only" is a checked claim, not a comment (mutation: give `.light` a different metric → red).
- **Q5. The root's two hardcoded modifiers become choice-driven, in a thin wrapper view.** `ThemedRoot` (`Trove/Views/Shared/Theme/ThemedRoot.swift`) takes the `AppearanceStore`, reads `@Environment(\.colorScheme)`, and applies `.environment(\.theme, store.choice.resolvedTheme(systemColorScheme:))` and `.preferredColorScheme(store.choice.preferredColorScheme)` to its content. `TroveApp` creates one `AppearanceStore`, wraps `ContentView` in `ThemedRoot`, and injects `.environment(appearanceStore)` for the hosts to thread onward. `ContentView` is **untouched** — it still reads `@Environment(\.theme)`, now supplied by `ThemedRoot` instead of `TroveApp`. Because `AppearanceStore` is `@Observable`, a `choice` change re-renders `ThemedRoot` with no relaunch (criterion 4); because `ThemedRoot` reads `colorScheme`, a device flip re-renders it under `.system` (criterion 3).
- **Q6. The Appearance control is a segmented `Picker`, first in Settings, threaded like `syncMonitor`.** A new `appearanceSection` (a `DetailSection(title: "Appearance")`) holds `Picker` over `AppearanceChoice.allCases` with `.pickerStyle(.segmented)`, bound to `$appearanceStore.choice`. `SettingsView` gains `appearanceStore: AppearanceStore` as a constructor-injected `@Bindable`, threaded from the three hosts, which read it from `@Environment(AppearanceStore.self)`. The picker binds the store directly rather than routing through `SettingsViewModel`: it is a settable binding to an app-level `@Observable`, exactly how the app already treats such state, and there is no derivation to place in the view model (`SettingsViewModel` is untouched, its tests unchanged). `.segmented` is not a menu, so `MenuPolicyTests` stays green — verified as its own claim (mutation: `.pickerStyle(.menu)` → `MenuPolicyTests` red).
- **Q7. The PDF's independence is pinned by a cheap source scan.** `PDFComposer.swift`'s production code references no `Theme`, `ThemeColors`, `AppearanceChoice`, `AppearanceStore` or `\.theme` (mutation: make it read `ThemeColors.light.background` → red). This is the whole of criterion 10's automated half; the existing PDF tests are untouched and green.
- **Q8. The UI test starts from an isolated appearance and confirms the control and its default.** Under `-uiTesting`, `AppearanceStore` is built over a **volatile, isolated `UserDefaults` suite**, gated structurally on the built store being `.ephemeral` (the `003` UITestSeed pattern — on the store's mode, not on a second read of the launch flag), so every UI-test launch starts from Dark regardless of what a previous run left, and a persistent-store launch can never pick up the volatile suite. Criterion 5's *persistence across relaunch* is verified by `AppearanceStoreTests` (write, rebuild the store over the same suite, read back) rather than a UI relaunch, which would reintroduce the ambient-state flakiness the constitution warns against.
- **Q9. No Design pass** (spec Decision 5, delegated); no schema change (no SwiftData model touched — the choice is `UserDefaults`, so `CloudKitSchemaTests` and the local-store schema tests are untouched); no CSV, import, PDF or `PRIVACY.md` change (nothing new is sent, and the one new stored value never leaves the device — the close-out says so in "As built"). `design/tokens.md` gains the light column on the spec branch; README gains one sentence; `specs/ROADMAP.md` is updated on this branch (the `004` entry and status row), the `003` mechanism.

## Layout and files

| File | Change |
|---|---|
| `Trove/Models/AppearanceChoice.swift` | new: the enum + `displayName` (no SwiftUI) |
| `Trove/Views/Shared/Theme/AppearanceChoice+Theme.swift` | new: `preferredColorScheme`, `resolvedTheme(systemColorScheme:)` |
| `Trove/App/AppearanceStore.swift` | new: `@Observable` store over `UserDefaults`, default `.dark` |
| `Trove/Views/Shared/Theme/ThemeColors.swift` | `.light` instance (all tokens) |
| `Trove/Views/Shared/Theme/Theme.swift` | `Theme.light`; `EnvironmentValues.theme` default stays `.dark` |
| `Trove/Views/Shared/Theme/ThemeTypography.swift`, `ThemeMetrics.swift` | `Equatable` conformance (additive) |
| `Trove/Views/Shared/Theme/ThemedRoot.swift` | new: the root wrapper |
| `Trove/App/TroveApp.swift` | build `AppearanceStore`; wrap in `ThemedRoot`; inject the store; the two hardcoded modifiers gone |
| `Trove/Views/Settings/SettingsView.swift` | `appearanceStore` param; `appearanceSection` first |
| `Trove/Views/Items/ItemListView.swift`, `Trove/Views/Wishlist/WishlistView.swift`, `Trove/Views/Dashboard/DashboardView.swift` | read `@Environment(AppearanceStore.self)`, thread into `SettingsView` |
| `TroveTests/AppearanceChoiceTests.swift` | new: resolver, `preferredColorScheme`, `displayName` |
| `TroveTests/AppearanceStoreTests.swift` | new: default `.dark`, round-trip persistence, isolation |
| `TroveTests/ThemeTests.swift` | light token pins; the shared-typography/metrics guard |
| `TroveTests/DesireDialTests.swift`, `DesireGaugeTests.swift` | light perceptual/contrast suites |
| `TroveTests/TrendArrowRenderTests.swift` | a light render suite |
| `TroveTests/TestSupport.swift` | `renderBitmap(_:theme:)` gains a defaulted `theme:` |
| `TroveTests/ThemeWiringTests.swift` | new: `TroveApp`/`ThemedRoot`/Settings/hosts source scans; the PDF guard |
| `TroveTests/SettingsWiringTests.swift` | the hosts thread `appearanceStore`; the section |
| `TroveUITests/TroveUITests.swift` | one appearance test |
| `design/tokens.md`, `README.md` | the light column; one sentence |

New files land through the synchronized root groups — no `.pbxproj` edit.

## 1. The appearance choice, store and resolver

```swift
enum AppearanceChoice: String, CaseIterable, Sendable {   // Trove/Models/AppearanceChoice.swift — no SwiftUI
    case system, light, dark
    var displayName: String { … }   // "System" / "Light" / "Dark"
}

// Trove/Views/Shared/Theme/AppearanceChoice+Theme.swift — SwiftUI
extension AppearanceChoice {
    var preferredColorScheme: ColorScheme? { … }   // system nil, light .light, dark .dark
    func resolvedTheme(systemColorScheme: ColorScheme) -> Theme { … }   // §Q1
}

@Observable final class AppearanceStore {   // Trove/App/AppearanceStore.swift
    var choice: AppearanceChoice { didSet { persist() } }
    init(defaults: UserDefaults = .standard)   // reads the stored raw value now; default .dark
}
```

Tests (`AppearanceChoiceTests`): `preferredColorScheme` for all three; `resolvedTheme` — `.light` → `Theme.light`, `.dark` → `Theme.dark` at both `colorScheme`s (an explicit choice ignores the system scheme; mutation: make `.light` consult `colorScheme` → red), `.system` → `.light` under `.light` and `.dark` under `.dark` (mutation: invert the branch → red); `displayName` whole for each case. `Theme` equality is by its `colors`/`typography`/`metrics` — assert `resolvedTheme(...).colors` is the light or dark instance via a token that differs between the two palettes (e.g. `background`), since `Theme` need not be `Equatable`.

Tests (`AppearanceStoreTests`, over an isolated `UserDefaults(suiteName:)` cleared in the test — a legitimate persistence/infrastructure check, not a view-model test, so the "no disk I/O" rule does not reach it): a fresh suite reads `.dark` (criterion 6; mutation: default to `.system` → red); setting `.light` then building a **second** `AppearanceStore` over the same suite reads back `.light` (criterion 5; mutation: drop the `persist()` in `didSet` → red); an unrecognised stored string reads `.dark` (a forward-compat guard). The second-store read is the persistence check for the reason `TestSupport`'s `makeInMemoryContainer` note gives — a same-instance read would pass whether or not the value was written. A source scan (added at sign-off) also confirms `AppearanceStore.swift` names no `NSUbiquitousKeyValueStore` or CloudKit symbol — criterion 5's does-not-sync half made a checked claim rather than an architectural assertion (mutation: reference the ubiquitous store → red).

## 2. The light palette and its pins

`ThemeColors.light` carries every token `ThemeColors.dark` does, derived for a light ground while keeping the brass/moss/rust identity (spec "The light palette"). The derivation is the implementer's, by the Oklab method in `design/tokens.md`, recorded there as a light column before the pins are written. Tokens needing genuine care, called out so they are not translated mechanically: the **text-safe lifts** (`accentMossText`/`accentRustText`) move in the opposite contrast direction on a light ground — the lift that darkens a moss to read on near-black must instead darken it enough to read on near-white; the **dial ramp** and **gauge tones** must re-earn §3's ΔE floors on the light surface; the **plate alphas** (`plateHighlight` from an ivory alpha, `plateEdgeShadow`/`plateCastShadow` from black) and `gaugeTrack` are alphas over the light `surface`, whose read flips. The text tokens keep the dark palette's structure — one ink at descending opacities — with a dark ink over the light ground.

`Theme.light`, and `ThemeMetrics`/`ThemeTypography` gain `Equatable` (Q4).

Tests (`ThemeTests`, a new `LightThemeColorTokenTests` mirroring `ThemeColorTokenTests`, dark suite untouched): every light token pinned to its tokens.md value as **independently-written channel literals** (mutation: flip a digit in either `ThemeColors.light` or the pin → red); the light text tokens are one ink at descending opacity (the dark suite's shape); `accentMossText != accentMoss` and `accentRustText != accentRust` on light. A `ThemeCompositionTests` (or a case in `ThemeTests`): `Theme.light.metrics == Theme.dark.metrics`, `Theme.light.typography == Theme.dark.typography` (Q4; mutation: `Theme.light` given non-`.standard` metrics → red); `Theme.dark` and its dark pins unchanged and green is criterion 1's automated half.

## 3. Re-earning the perceptual and contrast guarantees

`renderBitmap(_ view:, theme: Theme = .dark)` gains a defaulted `theme:` — the one change to shared test support. Every existing render caller (`TrendArrowRenderTests`, `SellPlanMarketLinesTests`, `DesireGaugeColorTests`) keeps its behaviour by the default; the light suites pass `theme: .light`. (Mutation of the change itself is covered by the light gauge suite going red if the default silently rendered the wrong theme.)

New light suites, each mirroring its dark counterpart against `ThemeColors.light`/`Theme.light`, added rather than folded into the dark suites so the dark guarantees stay pristine and each light suite is independently falsifiable:

- **`LightDesireDialColorTests`** (palette-token ΔE, no render): adjacent dial stops ΔE > 0.06 (criterion 7; mutation: set two light stops equal → red); no stop closer to brass than the smallest neighbour gap (criterion 7's price-figure half; mutation: pull a light stop toward `accentBrass` → red); every level a distinct colour; the midpoint at the middle; the numeral lifts at both ends.
- **`LightPaletteContrastTests`** (WCAG ratio, the dark suite's formula): the dial numeral clears 3:1 on the light `surface` at every level (criterion 2, criterion 7's legibility) **and** the raw `accentMoss`/`accentRust` stay below 3:1 as text on the light surface — the split that makes the lift non-vacuous, the same discriminator the dark suite uses (mutation: set a light lift equal to its shape colour → the ≥3:1 side red); `textPrimary`/`textBody` clear their WCAG bars on the light `background` and `surface`; the formula sanity pair (`surface` on `surface` == 1.0). **Derivation constraint** this states: the light shape accents must remain shape-only (below 3:1 as text) so the lift split is real on light as it is on dark — a technical consequence of the spec's "clear the same bar," not a new product call.
- **`LightDesireGaugeColorTests`** (sampled off a light render): every filled segment distinguishable from an empty track, adjacent filled tones from each other, the three readings tellable apart, and the sampling landing on fill — all at row size, rendered with `theme: .light` over `ThemeColors.light.surface`, ΔE floor 0.06 (criterion 8; mutation: collapse two light gauge tones → red).
- **`LightTrendArrowRenderTests`**: the up arrow draws light `accentMossText` ink and the down arrow light `accentRustText`, each distinguishable from the light ground, rendered `theme: .light` (criterion 8; mutation: draw the arrow in the raw accent → the distinguishability/ink assertion red).

## 4. Root wiring

```swift
struct ThemedRoot<Content: View>: View {   // Trove/Views/Shared/Theme/ThemedRoot.swift
    @Bindable var appearanceStore: AppearanceStore
    @Environment(\.colorScheme) private var systemColorScheme
    let content: Content
    var body: some View {
        content
            .environment(\.theme, appearanceStore.choice.resolvedTheme(systemColorScheme: systemColorScheme))
            .preferredColorScheme(appearanceStore.choice.preferredColorScheme)
    }
}
```

`TroveApp`: build `appearanceStore` in `init` (isolated defaults under the ephemeral store — §7), wrap `ContentView()` in `ThemedRoot(appearanceStore:)`, keep the existing `storageMode`/`storageFallbackReason`/`syncMonitor` environment injections, add `.environment(appearanceStore)`, and remove the hardcoded `.environment(\.theme, .dark)` and `.preferredColorScheme(.dark)`.

Tested by source scan (`ThemeWiringTests`, the `SettingsWiringTests` discipline): `TroveApp.swift` wraps `ContentView` in `ThemedRoot(`, injects `.environment(appearanceStore)`, and contains **no** `.preferredColorScheme(.dark)` and no `.environment(\.theme, .dark)` (mutation: leave the pin in → red); `ThemedRoot.swift` applies `.environment(\.theme,` with `resolvedTheme(systemColorScheme:` and `.preferredColorScheme(appearanceStore.choice.preferredColorScheme` (mutation: hardcode `.dark`/`.environment(\.theme, .dark)` → red). The *live/no-relaunch* behaviour (criteria 3, 4) rests on SwiftUI's `@Observable` re-render and `@Environment(\.colorScheme)` — long-standing platform capabilities (the `T056` "suspect the newest code, not the platform" instinct) — and is attested by the person at the phase pause, named as such in the conformance summary; the wiring scan and the resolver test are what make that attestation about *this* code and not the framework.

## 5. The Settings Appearance control

`SettingsView` gains `@Bindable var appearanceStore: AppearanceStore`, constructor-injected. A new `appearanceSection` — a `DetailSection(title: "Appearance")` holding `Picker("Appearance", selection: $appearanceStore.choice) { ForEach(AppearanceChoice.allCases…) { Text($0.displayName).tag($0) } }.pickerStyle(.segmented)` — is composed **first** in the body's section stack. The three hosts read `@Environment(AppearanceStore.self)` and pass `appearanceStore:` into `SettingsView`.

Tested by source scan (`SettingsWiringTests`, extended): each host in `settingsHosts` passes `appearanceStore: appearanceStore` to `SettingsView` (mutation: drop the arg → red), and reads it from the environment; `SettingsView` composes `appearanceSection` first in the section stack (the section-order scan's shape — checked at composition, not declaration), the picker is `.pickerStyle(.segmented)` bound to `$appearanceStore.choice` over `AppearanceChoice.allCases`, and its labels read `displayName` (no typed "System"/"Light"/"Dark" literal in the view — the copy lives on the model). `MenuPolicyTests` stays green and is the guard that `.segmented` did not become `.menu` (mutation: `.pickerStyle(.menu)` → `MenuPolicyTests` red). `SettingsViewModel` and its tests are untouched.

## 6. The PDF guard

`ThemeWiringTests`: `SourceScan.production("Trove/Export/PDFComposer.swift")` contains none of `ThemeColors`, `Theme.`, `\.theme`, `AppearanceChoice`, `AppearanceStore` (criterion 10; mutation: add `ThemeColors.light.background` to the module → red). The existing PDF tests (`PrintPalette` values, the renderer) are untouched and green — the second half of criterion 10.

## 7. The UI test and its isolation

`AppearanceStore` under `-uiTesting` uses a volatile, isolated `UserDefaults` suite so each launch starts from Dark: `TroveApp.init` passes an isolated suite when the built store's mode is `.ephemeral` (structural, on `store.mode`, the `003` UITestSeed gating — never on a second read of the flag), else `.standard`. `AppearanceStoreTests` covers the isolation shape (a store over a named suite does not see `.standard`'s value).

`TroveUITests.testAppearanceControlDefaultsToDarkAndOffersThreeChoices`: launch with `-uiTesting`; open Settings from a list (`openSettings`); the Appearance segmented control shows three segments labelled System / Light / Dark, with **Dark** selected (criterion 6's UI half; criterion 2's presence half); tapping **Light** leaves Light selected (the control is wired and settable). It asserts selection state, not rendered pixels — the visual correctness of the light palette is the person's device pass and the perceptual suites, not a fragile screenshot. Every other UI test keeps launching with `-uiTesting` alone and starts Dark (mutation: default the store to `.system`/`.light` → this test's "Dark selected" red). Run twice back to back (the launch path gained a branch).

## 8. Guards that can fail (each with the mutation that turns it red)

| # | Test | Red when |
|---|---|---|
| G1 | `resolvedTheme` for `.light`/`.dark` ignores the system scheme; `.system` follows it | an explicit case reads `colorScheme`; the `.system` branch inverted |
| G2 | `AppearanceStore` defaults `.dark`; round-trips through a second store | default changed; `persist()` dropped from `didSet` |
| G3 | light token pins (independent channel literals) | a digit flipped in `ThemeColors.light` or the pin |
| G4 | `Theme.light` shares dark's metrics and typography | `.light` given non-`.standard` metrics/typography |
| G5 | light dial adjacent-stop ΔE > 0.06; no stop nearer brass than its neighbours | two light stops equalised; a stop pulled toward brass |
| G6 | light numeral clears 3:1 on light surface; raw accents stay below | a light lift set equal to its shape colour |
| G7 | light gauge tones distinguishable at row size | two light gauge tones collapsed |
| G8 | light trend arrows draw the lifts and stay legible | the arrow drawn in the raw accent |
| G9 | `TroveApp` drops `.preferredColorScheme(.dark)`; `ThemedRoot` drives both modifiers from the choice | the pin left in; `ThemedRoot` hardcodes `.dark` |
| G10 | hosts thread `appearanceStore`; Settings composes the segmented picker first, bound to the store | the arg dropped; the section absent; `.pickerStyle(.menu)` (→ `MenuPolicyTests`) |
| G11 | `PDFComposer.swift` references nothing theme/appearance | the module reads a `ThemeColors` token |
| G12 | the UI control defaults Dark and offers three choices | the store's default changed |
| G13 | `AppearanceStore.swift` references no ubiquitous/CloudKit symbol — criterion 5's does-not-sync half (added at sign-off) | the store wired to `NSUbiquitousKeyValueStore`/CloudKit |

Plus every mutation named in §§1–7. The dark suites (`ThemeColorTokenTests`, `DesireDialColorTests`, `DesireGaugeColorTests`, `TrendArrowRenderTests`) stay untouched and green — criterion 1's automated half, by construction.

## 9. Tasks — the shape (drafted after sign-off in tasks.md)

**Phase 1 — foundations (foundational: per-task review)**: T001 the light palette, its pins, the shared-composition guard, and the re-earned perceptual/contrast suites + the `renderBitmap` `theme:` param (§§2, 3, Q3–Q4) → T002 `AppearanceChoice`, the resolver, `AppearanceStore` and their tests (§1, Q1–Q2). T001 is marked `review: per-task` explicitly for emphasis; both Phase-1 tasks get a per-task review.
**Phase 2 — wiring and the control (mechanical: one per-phase review)**: T003 root wiring — `ThemedRoot`, `TroveApp`, the isolation gate (§§4, 7), **marked `review: per-task`** (a root-wiring mistake the whole app inherits) → T004 the Settings section and the hosts + the PDF guard (§§5, 6) → T005 the UI test, twice (§7).
**Phase 3 — close-out**: T006 the device pass **[person]** (criteria 1–4 and 8's visual halves, every screen in light) → T007 close-out: criteria 1–10 cited, tokens.md light column, README, plan "As built", the tier log totalled, `ROADMAP.md`, the pre-merge sweep.

## 10. Verification

`scripts/verify.sh` per task (the unit suite; the orchestrator re-runs it for `review: per-task` tasks — T001, T002, T003 — takes the implementer's verbatim output otherwise); `scripts/verify.sh ui` at the Phase 1 pause (T003's isolation branch touches the launch path every UI test goes through — run at the pause once T003 has landed, i.e. at the Phase 2 boundary) and at T005 and T007 twice back to back. Every guard's red run recorded in its task's Done note. No test opens a network connection; nothing in this spec touches the live API.

## Not in this plan

Alternate-hue palettes / new colour themes, a custom/user-defined palette, Dynamic Type, per-screen or per-element overrides, syncing the choice, theming the PDF, and any change to the dark palette's values (all spec non-goals). One observation for the person, not changed here: the app now stores its first `UserDefaults` preference — noted in "As built" so a future preference has the precedent to point at.

## As built

To be filled at close-out (T007): any deviation, the tier totals, the light token values as recorded in `design/tokens.md`, and the sentence Q9 promised — nothing new is sent and the one stored value never leaves the device, so `PRIVACY.md` is unchanged.

## Skeptical-review record (sign-off)

Reviewed 2026-09-09 by the `skeptical-reviewer` at the implementation
tier (`opus`, high effort) under the model policy's Fallback clause
(`fable`'s budget spent). Verdict: the design is sound and honestly
scoped, and its guard tests survive the falsifiability scrutiny this
project's scars demand; every symbol the plan cites was verified to
exist in the tree. One blocking finding, fixed and re-reviewed:

- **B1 — Phase 2 review scope contradiction (`tasks.md`).** The task
  list's Phase 2 review line (review restricted to T004, before T005)
  disagreed with its own handoff note (review T004–T005 as the phase);
  the operative wording left T005 — the UI test riding T003's launch-path
  branch — outside any skeptical review and dropped criterion 6, against
  `CLAUDE.md`'s "per-phase everywhere." **Fixed**: the single Phase 2
  review now runs after T005 over the T004–T005 diff, criteria 2, 3, 4,
  6, 10, with T003 already reviewed per-task.

Second-look items (non-blocking), routed to task bundles rather than
implemented by the orchestrator (model policy):
- **The "does not sync" claim (criterion 5's per-device half) had no
  guard.** A source scan that `AppearanceStore.swift` names no
  `NSUbiquitousKeyValueStore`/CloudKit symbol hardens it — added to
  T002 (G13), the doctrine of writing the test that catches the claim
  being false.
- **The light contrast split may be unsatisfiable** if a mid-tone accent
  naturally clears 3:1 on the near-white ground; T001 now says to
  escalate rather than lower the floor.
- **The independent channel-literal pin is a process instruction, not a
  structural guarantee** (a source-copied pin catches only later drift);
  the T001 per-task reviewer confirms the light pins were transcribed
  from `tokens.md`, not copied from `ThemeColors.light`.

Confirmed sound by the reviewer: every cited existing symbol
(`SourceScan.production`, `settingsHosts`, `theSectionsAppearInSpecOrder`,
`theScreenAttaches…`, `DesireGaugeColorTests`/`DesireDialColorTests`,
`UITestSeed.shouldSeed(mode:arguments:)`, the dark channel-literal pins);
`renderBitmap(_:theme:)` backward-compatible; `.pickerStyle(.segmented)`
clears `MenuPolicyTests`; the PDF guard falsifiable and green today; the
ΔE (>0.06) and contrast (<3:1 / ≥3:1) discriminators real; `Equatable`
synthesis compiles; criterion 1 guarded by the untouched dark pins; the
persistence/isolation tests avoid the refetch/ambient-state scars; the
live/no-relaunch attestation (criteria 3, 4) honest and sufficient;
every non-goal respected; every criterion 1–10 mapped to a task and
every task traced to a plan section.
