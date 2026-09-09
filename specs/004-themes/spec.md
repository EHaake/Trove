# Spec 004 — Light mode

**Status**: Approved by the person 2026-09-09 (Draft authored 2026-09-08). Implementation complete 2026-09-09 — all ten acceptance criteria verified with a per-criterion citation below (the T006 device pass signed off criteria 1–4 and 8's visual halves); pre-merge sweep pending.
**Depends on**: `001-core-inventory` (the `Theme` abstraction injected at the root, and `NoHardcodedColorsTests`, which together make a second palette a config change rather than a sweep), `013-settings-menu` (the Settings screen the choice lives in — theme selection was deferred here from `013`)
**Authored**: 2026-09-08, in the Claude Code spec session at the person's direction. Every substantive call below is the person's. The session ran at the implementation tier (`opus`), not the top tier, under the model policy's Fallback clause — the top tier's budget was spent; recorded here so the tier log has the reason.

## What and why

Trove has been dark-only since `001`, and deliberately so: the root
pins `.preferredColorScheme(.dark)` so that system chrome — keyboards,
pickers, selection — matches the near-black palette instead of fighting
it. But `001` also built for this day. Every colour lives in
`ThemeColors` as a semantic token, injected once at the root as
`.environment(\.theme, .dark)`, and `NoHardcodedColorsTests` fails the
build if any view reaches past that for a literal or a system colour.
The abstraction's whole purpose was that a second palette would be
"inject a different instance," not a redesign.

This spec spends that groundwork on **light mode**: a light-ground
variant of the app's existing brass/moss/rust identity, plus a
**System / Light / Dark** choice in Settings. The look is the same
Trove — the same accents, the same meanings — shown on paper-light
instead of near-black. It is not a set of new colour themes; picking
new hues is a real design decision the roadmap holds for its own spec
(the reasoning that kept `008` and `009` for deliberate Design passes),
and it stays deferred here.

## Core behaviour

### The appearance choice

- Settings gains an **Appearance** choice offering three options:
  **System**, **Light**, **Dark**.
- **System** follows the device's own light/dark setting and switches
  **live** when the device switches — no relaunch.
- **Light** and **Dark** are explicit overrides that hold regardless of
  what the device is set to.
- **The default is Dark, for everyone** (Decision 3). An existing
  install updating to this version opens in Dark — exactly the look it
  has today, nothing changed without the person asking. A fresh install
  also opens in Dark. System and Light are discoverable opt-ins, never
  imposed on update.
- Changing the choice takes effect **immediately** — the whole app, and
  the system chrome with it, changes without a relaunch. The pinned
  `.preferredColorScheme(.dark)` is replaced by one the choice drives.
- The choice is stored **locally on the device** and **does not sync**
  (Decision 4). Like the market figures that stay on the device that
  fetched them, and like iOS's own appearance setting, each device
  carries its own choice; setting Light on the phone leaves the iPad as
  it was.
- The choice persists across launches: reopening the app shows the last
  appearance chosen.

### The light palette

- A second `ThemeColors` instance (a light counterpart to `.dark`)
  carries the **same semantic tokens** — `background`, `surface`,
  `textPrimary`, `accentBrass`, `accentMoss`, `accentRust`, the dial
  ramp, and the rest — with values chosen for a light ground while
  keeping the brass/moss/rust identity.
- Every value is **derived and measured by the same Oklab method that
  produced the dark palette** (Decision 5), and **pinned by a test** the
  way the dark tokens are in `ThemeTests`. No colour is picked by eye.
- **Contrast holds on the light ground.** The dark palette already
  carries text-safe lifts (`accentMossText`, `accentRustText`) because
  the raw accents fail contrast as text; the light palette needs its own
  equivalents so text and accents clear the same bar on a light surface.
- **The perceptual guarantees are re-earned, not inherited.** The
  desire-dial ramp and the `DesireGauge` were tuned against the dark
  palette so that adjacent levels are not visually confusable, and no
  level is confusable with the brass price figure. The same guarantees
  must hold for the light tokens, verified by the same kind of
  perceptual test run against the light values.
- The trend arrows keep their meaning in light: rising in the moss tone,
  falling in the rust tone, each legible on the light ground.

### What does not change

- **The exported PDF is unaffected** (Decision 6). Its `PrintPalette`
  is already paper-fixed — white ground, brass darkened to clear 4.5:1
  on white — and independent of the app's theme. A Light or Dark choice
  changes nothing about any export.
- **The dark palette itself is untouched.** Light mode is additive; the
  dark tokens keep their exact values, so Dark looks identical to today.
- **No data changes.** Themes are pure presentation: no schema, no
  market data, no sync, no `Item`/`WishlistItem` change. Photos and
  user content are unaffected.

## Design requirements

- **No separate Claude Design pass** (Decision 5). The identity is fixed
  and the derivation method already exists, so the implementer produces
  the light tokens and the person attests visually at the phase pause —
  unlike `008`/`009`, which invent new palettes and are held for Design
  passes precisely because that is a genuine design decision.
- **Every screen must read as legible and on-brand in light** — surfaces
  and dividers distinguishable, text meeting contrast, no element
  disappearing or clashing — confirmed screen by screen on the running
  app at the phase pause.
- The **exact Appearance control** (segmented picker, a row into a
  sub-screen, etc.) is left to the plan; this spec requires only that it
  offers the three choices and lives in Settings, consistent with
  `013`'s "bespoke inside the page, system in the bars" rule.

## Decisions record

1. **Light mode of the existing palette only.** Alternate-hue colour
   themes are a later spec. Light mode of a fixed identity is a
   constrained translation; inventing new palettes is a real design
   decision, held for its own Design pass by the same reasoning that
   kept `008` and `009` out of earlier specs.
2. **System / Light / Dark.** The standard iOS three-way. System follows
   the device and switches live; Light and Dark are explicit overrides.
3. **Default Dark, for everyone.** Chosen over defaulting to System.
   Zero-surprise upgrade: existing users keep exactly today's look, a
   fresh install opens dark, and System/Light are opt-in. Dark is
   Trove's designed identity and every design reference is dark-first —
   flipping an existing user to a brand-new light look on update, only
   because their phone happens to be in light mode, was the outcome to
   avoid.
4. **Per-device, not synced.** The choice lives in local storage, the
   same treatment the market figures already get and the same as iOS's
   own per-device appearance setting. Syncing a preference most people
   set once was judged not worth a synced store.
5. **Light tokens derived and Oklab-measured by the implementer; no
   formal Design pass.** The identity is fixed — only a light ground and
   its contrast-safe lifts are being found — and the method that
   produced the dark ramp is on record. The person attests to the result
   visually at the phase pause rather than approving colour values up
   front.
6. **The PDF export is unaffected.** Its `PrintPalette` is already
   paper-fixed and independent of the app theme, so no export changes
   with the appearance choice.

## Acceptance criteria

Each is something a person can check on the built app, or a test can
check. The plan will cite what verifies each.

1. [x] With Appearance set to **Dark**, every screen looks exactly as it
   does today — the dark palette is unchanged.
   *Verified: the dark suites (`ThemeColorTokenTests`, `DesireDialColorTests`, `DesireGaugeColorTests`, `TrendArrowRenderTests`) untouched and green — light mode is additive (plan §8) — and the person's T006 device pass ("Dark = today's look", every screen).*
2. [x] With Appearance set to **Light**, every screen is legible and
   on-brand: text meets contrast, surfaces and dividers are
   distinguishable, and no element disappears or clashes.
   *Verified: `LightPaletteContrastTests` (text tokens clear WCAG on the light `background`/`surface`; the dial numeral ≥ 3:1) and the T006 device pass — Overview, Items list, item detail, Wishlist, Settings and the add-item form all walked in Light, signed off.*
3. [x] With Appearance set to **System**, the app matches the device's
   light/dark setting and switches live when the device switches, with
   no relaunch.
   *Verified: `AppearanceChoiceTests.systemFollowsTheSystemScheme` (`resolvedTheme` returns the light theme under `.light` and the dark theme under `.dark` for `.system`, while explicit cases ignore the system scheme) and the live no-relaunch switch attested at T006 (device flipped dark↔light, app followed both directions); `ThemeWiringTests` pins that `ThemedRoot` drives the theme through `resolvedTheme(systemColorScheme:)` — the resolver that first test covers — rather than proving the `@Environment(\.colorScheme)` read itself.*
4. [x] Changing the Appearance choice in Settings changes the whole app
   immediately — including system chrome (keyboard, pickers, selection)
   — with no relaunch.
   *Verified: `ThemeWiringTests` (`TroveApp` drops the hardcoded `.preferredColorScheme(.dark)`/`.environment(\.theme, .dark)`; `ThemedRoot` drives both modifiers from the `@Observable` `AppearanceStore.choice`), plus `AppearanceChoiceTests.sheetColorScheme(device:)` for the Settings sheet's own chrome (T009); the immediate whole-app + status-bar-chrome change attested at T006, and the **within-sheet** switch (segmented labels + nav title, all three choices incl. →System, in both modes) re-attested on the simulator at T009 after the sheet-propagation fix — so "system chrome (keyboard, pickers, selection)" now holds inside the Settings sheet, not only on the main window.*
5. [x] The choice persists across a relaunch, and is stored locally: a
   choice made on one device does not change another.
   *Verified: `AppearanceStoreTests.theChoicePersistsIntoASecondStore` — a value written and read back through a **second** store over the same suite (real persistence, not a same-instance refetch); the per-device half by G13 (`theStoreNamesNoUbiquitousOrCloudKitSymbol`, that `AppearanceStore.swift` names no `NSUbiquitousKeyValueStore`/CloudKit symbol) together with the store reading only local `UserDefaults` — so a choice on one device cannot propagate to another (does-not-sync, spec Decision 4).*
6. [x] An existing install updating to this version opens in Dark
   without the person choosing, and a fresh install opens in Dark.
   *Verified: `AppearanceStoreTests` (a fresh suite, and an unrecognised stored string, both read `.dark`) and `TroveUITests.testAppearanceControlDefaultsToDarkAndOffersThreeChoices` (UI launches with Dark selected); confirmed on the T006 device pass.*
7. [x] In light, the desire dial's levels are each perceptually distinct
   from their neighbours and from the brass price figure — the dark
   ramp's guarantee, re-verified against the light tokens.
   *Verified: `LightDesireDialColorTests` (adjacent stops Oklab ΔE > 0.06; no stop closer to `accentBrass` than its nearest neighbour gap) and `LightPaletteContrastTests` (each numeral clears 3:1 on the light `surface`).*
8. [x] In light, the `DesireGauge` segments and the trend arrows keep
   their meaning and stay legible on the light ground.
   *Verified: `LightDesireGaugeColorTests` (filled tones distinguishable from an empty track and from each other at row size, sampled off a light render) and `LightTrendArrowRenderTests` (up = light `accentMossText`, down = light `accentRustText`, each legible on the ground); the visual half attested at T006.*
9. [x] Every light token is pinned by a test, as the dark tokens are,
   and `NoHardcodedColorsTests` still passes — no view acquired a
   literal or system colour while light mode was added.
   *Verified: `LightThemeColorTokenTests` pins every `ThemeColors.light` token as independent channel literals transcribed from `design/tokens.md` (not copied from the source), and `NoHardcodedColorsTests` is green.*
10. [x] The exported PDF is unaffected by the appearance choice.
    *Verified: `ThemeWiringTests`' PDF guard (`PDFComposer.swift` references no `ThemeColors`/`Theme.`/`\.theme`/`AppearanceChoice`/`AppearanceStore`, mutation-tested with a compiling reference so the scan itself fires), reinforced by actor isolation (plan §6); the existing `PrintPalette`/renderer tests untouched and green.*

## Non-goals (explicit)

- **Alternate colour palettes / new hues** — Decision 1; a later spec
  needing its own Design pass.
- **Dynamic Type** — every font in the app is fixed-size (`001`'s
  recorded limitation, `003` Decision 11); its own spec, unrelated to
  colour.
- **Per-screen or per-element theme overrides** — one app-wide choice,
  nothing local.
- **A custom or user-defined palette** (colour pickers, hex entry) —
  curated only, and here only the one light palette.
- **Syncing the appearance choice across devices** — Decision 4.
- **Theming the exported PDF or any print output** — Decision 6.
- **Changing the dark palette's values** — light is additive; dark is
  untouched.
