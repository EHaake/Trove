# Spec 004 — Light mode

**Status**: Draft — authored 2026-09-08, awaiting the person's approval. No plan or tasks yet.
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

1. [ ] With Appearance set to **Dark**, every screen looks exactly as it
   does today — the dark palette is unchanged.
2. [ ] With Appearance set to **Light**, every screen is legible and
   on-brand: text meets contrast, surfaces and dividers are
   distinguishable, and no element disappears or clashes.
3. [ ] With Appearance set to **System**, the app matches the device's
   light/dark setting and switches live when the device switches, with
   no relaunch.
4. [ ] Changing the Appearance choice in Settings changes the whole app
   immediately — including system chrome (keyboard, pickers, selection)
   — with no relaunch.
5. [ ] The choice persists across a relaunch, and is stored locally: a
   choice made on one device does not change another.
6. [ ] An existing install updating to this version opens in Dark
   without the person choosing, and a fresh install opens in Dark.
7. [ ] In light, the desire dial's levels are each perceptually distinct
   from their neighbours and from the brass price figure — the dark
   ramp's guarantee, re-verified against the light tokens.
8. [ ] In light, the `DesireGauge` segments and the trend arrows keep
   their meaning and stay legible on the light ground.
9. [ ] Every light token is pinned by a test, as the dark tokens are,
   and `NoHardcodedColorsTests` still passes — no view acquired a
   literal or system colour while light mode was added.
10. [ ] The exported PDF is unaffected by the appearance choice.

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
