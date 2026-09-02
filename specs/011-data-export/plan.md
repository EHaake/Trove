# 011 — Data Export: Technical Plan

Status: **Approved** (2026-08-30)

First plan authored under the constitution's 2026-08-30 authorship
amendment: drafted by Claude Code in-session against the approved spec,
in Plan Mode, with the `skeptical-reviewer` subagent applied to the
foundational calls. Three product-level questions surfaced during
planning were escalated and decided by the person steering the project
(2026-08-30); they're marked **[escalated → decided]** below and applied
to `spec.md` in the same commit as this draft.

## Approach in one paragraph

Both list view models grow export intent methods behind an injected
`ExportService` protocol. On tap, the view model snapshots the visible
items — the already-filtered, already-sorted `items` array, which is the
only correct source of "what the user is looking at" — into `Sendable`
value records, then hands them to the service, whose generation runs
entirely off the main actor. CSV is a hand-rolled RFC 4180 writer over a
pinned schema; PDF is composed with CoreGraphics + CoreText + ImageIO —
no UIKit anywhere in the export module. Delivery is the system share
sheet via a `UIViewControllerRepresentable`-wrapped
`UIActivityViewController`, this spec's single flagged UIKit exception.
Temp files live in one dedicated directory purged before every export
and at launch.

## Skeptical review record

The reviewer was run on four foundational calls before this draft was
written. It **overturned two initial picks**, both adopted here:

1. **PDF renderer.** The initial pick was `UIGraphicsPDFRenderer` as a
   flagged UIKit exception. Rejected on review: the argument against
   pure CoreText rested on a false premise (`CTFramesetter` *is* a
   multi-page flow engine — see "PDF generation" below), calling a
   rendering subsystem a "narrow bridge" would stretch the
   constitution's exception wording beyond honesty, and the repo's own
   precedent (`RowThumbnailTests`' fixture builder) already chose
   CoreGraphics + ImageIO over `UIImage` for exactly this reason.
2. **Delivery.** The initial pick was `ShareLink` with a lazy
   `Transferable` (async `FileRepresentation`). Rejected on review: it
   moves "which items, in which order, generate this file" into a
   view-layer closure with no testable intent method (a collision with
   the constitution's MVVM and view-model-testing rules, not just an
   ergonomic loss), its loading behavior for multi-second generations is
   unverified, and a throw inside the exporting closure surfaces as a
   silent provider failure — no error path at all.

The reviewer also contributed the downsampling requirement (the single
highest-leverage catch — see "Photos"), the off-main instrumentation
test shape, the `ModelContext` retention strategy, and most of the CSV
edge-case decisions recorded below.

## The canonical CSV schema

**This section is the contract `012-data-import` parses against.**
Derived field-by-field from the actual detail screens per the spec's
"if the detail screen shows it" rule — `ItemDetailView` shows category,
name, worth now, paid, the desire dial, condition, condition notes,
bought, bought from, serial number, and notes; `WishlistDetailView`
shows category, name, estimated cost, the desire gauge, added date, and
notes. Photos are the one exception (PDF only, per spec).

### Items — `Trove-Items-YYYY-MM-DD.csv`, 12 columns, this order

| # | Header | Source | Serialization |
|---|--------|--------|---------------|
| 1 | `Name` | `Item.name` | text |
| 2 | `Category` | `Item.categoryPath` | full slash path, exactly as stored |
| 3 | `Purchase Price` | `Item.purchasePriceCents` | decimal, always two places, dot separator (`1250.00`) |
| 4 | `Currency` | `Item.currencyCode` | ISO 4217 (`USD`) |
| 5 | `Purchase Date` | `Item.purchaseDate` | `yyyy-MM-dd`, device-local calendar day — the day the screen shows |
| 6 | `Purchase Location` | `Item.purchaseLocation` | text; empty when nil (screen label: "Bought from") |
| 7 | `Current Value` | `Item.currentValueCents` | decimal as above; **empty cell when nil** — unvalued is not worthless, same distinction the model and dashboard draw |
| 8 | `Desire to Keep` | `Item.desireToKeep` | integer 1–5 |
| 9 | `Condition` | `Item.conditionRawValue` | raw lowercase (`excellent`) — import-stable; criterion 6 is met case-insensitively against the screen's capitalized rendering |
| 10 | `Condition Notes` | `Item.conditionNotes` | text; empty when nil |
| 11 | `Serial Number` | `Item.serialNumber` | text; empty when nil |
| 12 | `Notes` | `Item.notes` | text; may contain newlines (quoted) |

### Wishlist — `Trove-Wishlist-YYYY-MM-DD.csv`, 7 columns

| # | Header | Source | Serialization |
|---|--------|--------|---------------|
| 1 | `Name` | `WishlistItem.name` | text |
| 2 | `Category` | `WishlistItem.categoryPath` | full slash path |
| 3 | `Estimated Cost` | `WishlistItem.estimatedCostCents` | decimal, two places |
| 4 | `Currency` | `WishlistItem.currencyCode` | ISO 4217 |
| 5 | `Desire to Own` | `WishlistItem.desireToOwn` | integer 1–3 |
| 6 | `Added` | `WishlistItem.createdAt` | `yyyy-MM-dd`, local day (shown on the detail screen) |
| 7 | `Notes` | `WishlistItem.notes` | text |

### Format rules (part of the schema)

- UTF-8 **with BOM**. Excel on Windows misreads BOM-less UTF-8 and
  criterion 5 names Excel; `012`'s parser must skip the BOM.
- CRLF row endings, **including a trailing CRLF after the last row** —
  RFC 4180 leaves the final one optional; this schema pins it present
  (recorded at T019/S3) so `012`'s parser knows a naive split yields
  one empty trailing fragment to drop.
- RFC 4180 minimal quoting: a field is quoted iff it contains a comma,
  quote, CR, or LF; embedded quotes are doubled.
- Header row present, matched byte-for-byte by `012`. The headers and
  column order live in one shared `nonisolated` type (`ExportSchema`),
  never a string array inside the writer, so export and the future
  import read the same constant.

### Recorded schema decisions

- **`Currency` is included** though the screen shows it only as the "$"
  symbol: money without a currency is ambiguous in a canonical schema,
  and the field exists on both models precisely so multi-currency stays
  additive (001's Money groundwork).
- **Visible order is positional** — row order in the file is screen
  order, and there is no `sortOrder` column. `012` must treat row order
  as load-bearing; a Custom arrangement is reproducible no other way.
- **Items carry no `Added` column** — `createdAt` isn't on the item
  detail screen (the wishlist's is). Deliberate asymmetry, stated so it
  can't read as an oversight. It also means item-list sort tie-breaks
  (`createdAt` at the deepest floor) can't be re-derived after a round
  trip.
- **No `id` column** — not user-visible, and `012`'s template-first
  design creates new items rather than matching existing ones.
- **No formula-injection escaping.** A note starting with `=`, `+`, or
  `@` exports verbatim; prefixing `'` would corrupt the round trip, and
  this is the user's own data opened by the user. Recorded, not silent.
- **Excel serial-number caveat**, recorded against criterion 5: Excel's
  default file-open coerces long digit strings (scientific notation,
  stripped leading zeros). Numbers and Excel's text-import path with
  text-typed columns are fine; the criterion's own wording ("via a
  standard CSV import") is what the check exercises.
- **The schema will grow — append-only** *(recorded 2026-08-31 at
  T018)*: when new user-visible per-item data ships — trending/market
  values are the known case — the detail screens gain fields and this
  schema gains columns. That is a canonical-schema change: made here,
  in `ExportSchema`, and against `012`'s parser together, never by an
  edit to the writer alone. New columns append after the existing
  ones, so files written against this version keep parsing
  positionally.
- **[escalated → decided] Dates are the device-local calendar day**,
  serialized from `Calendar` components — exactly what the detail
  screen shows, which is what criterion 6 measures. The caveat this
  buys: `purchaseDate` is stored as a raw instant (the form keeps
  time-of-day), so the calendar day genuinely differs across timezones
  and a CSV round trip is timezone-stable only within one timezone.
  That instability is a pre-existing storage property export exposes
  rather than creates; normalizing storage (e.g. noon UTC) would be a
  data migration and was explicitly deferred. `012` inherits this
  caveat knowingly via this section.

### Money and date serialization

Pure integer arithmetic for money — `cents / 100` and a `%02d`
remainder — so **no locale API exists in the money path**; this
deliberately routes around `Int+Currency.swift`, whose formatters pin
`en_US` and emit symbols for *display*. Dates serialize through a
calendar that is **always proleptic Gregorian, built inside the
serializer over an injectable `TimeZone`** (the device's by default).
*(Corrected 2026-08-31 at T019/B1: the draft claimed "no locale API
anywhere" and the first implementation defaulted to `Calendar.current`
— which follows the user's preferred-calendar setting, not just the
time zone, so a device set to the Buddhist calendar would have written
year 2569 into the canonical file and its filenames. The API now takes
only a `TimeZone`, making calendar-identifier independence structural,
the same way integer math makes the money path locale-free.)* Two money formatters
(display vs. data) is a deliberate split, not duplication: they answer
different questions and must be allowed to diverge. The invariant `012`
depends on is the cent-exact round trip:
`Money.cents(from: Decimal(string: field)) == originalCents`.
*(Corrected 2026-08-31, during `012` planning: this line originally
named `Money.cents(from: Decimal(string:))` as `012`'s parse path
itself. `012` parses with its own strict integer parser instead —
`Decimal(string:)` is lenient in ways `012`'s spec forbids, stopping
silently at a thousands separator rather than rejecting the field —
and preserves this invariant as a test-side equivalence on canonical
forms. The codebase deliberately carries three money implementations
at three different boundaries: `Money.cents` for what a user types
into a form, `ExportSchema.money` writing the canonical format,
`ImportSchema`'s parser reading only the canonical format — each pair
tied together by a round-trip test rather than by shared code that
would blur what each boundary accepts. See `012`'s plan.md, "Money
and date parsing".)*

## CSV generation

`CSVWriter.write(headers:rows:) -> String` — a hand-rolled RFC 4180
writer, roughly forty lines, no dependencies (constitution: no
third-party packages, and CSV is small enough that a package would be
all liability). `ExportSchema` owns the per-entity record → `[String]`
row mapping and the money/date serializers above.

## PDF generation: CoreGraphics + CoreText + ImageIO

**Decision: `CGContext(consumer:mediaBox:)` PDF context, `CTFramesetter`
text layout, ImageIO photo decoding. No UIKit in the rendering module,
so no constitution exception is spent on it.** (One `import SwiftUI`
exists in `PDFComposer.swift`, for `Font.Weight` alone — the parameter
type of `FontFamily.postScriptName(for:)`, the single source of face
names — flagged at the import site. The framework claim here is about
UIKit; noted at T019 so it can't read as an overclaim.)

The alternatives, weighed honestly (the reviewer corrected the first
pass of this comparison):

- **SwiftUI `ImageRenderer`** — rejected. It is `@MainActor`-isolated
  (criterion 11 forbids main-actor generation for hundreds of items
  with photos; `TestSupport.renderBitmap` already carries the
  `@MainActor` annotation for exactly this reason), and it has no
  multi-page text flow — pagination of variable-height entries with
  unbounded notes would mean hand-measuring SwiftUI views. A hybrid
  (ImageRenderer for the fixed cover page only) buys a second rendering
  stack for one page; dismissed.
- **`UIGraphicsPDFRenderer`** — rejected, reversing the initial pick.
  The familiar-API advantage was real but the case for it rested on
  CoreText lacking pagination, which is false: `CTFramesetterCreateFrame`
  performs line breaking into a given rect, `CTFrameGetVisibleStringRange`
  hands back the resume point for the next page — that *is* multi-page
  flow — and `CTFramesetterSuggestFrameSizeWithConstraints` is the
  measurement primitive. With that premise gone, what remains on the
  UIKit side is a full rendering subsystem (`UIGraphicsPDFRenderer`,
  `NSAttributedString` drawing, `UIFont`, `UIImage`) that the
  constitution's "narrow bridge/decode utility" exception does not
  honestly cover — taking it would require amending the constitution
  first. Meanwhile ImageIO is needed regardless (downsampling, below)
  and yields `CGImage`, which draws into a `CGContext` directly;
  `UIImage` would add a conversion. `RowThumbnailTests` already set the
  in-repo precedent of choosing CG + ImageIO over `UIImage` to avoid a
  quiet UIKit dependency — for a test fixture; production deserves at
  least that standard.

Text attributes use `CTFont` (created from the same PostScript names
`FontFamily.postScriptName(for:)` serves — fonts registered via
`UIAppFonts` are process-wide, so `FontRegistrationTests`' guarantee
keeps covering the PDF) and `CTParagraphStyle`. Colors are `CGColor`.
The PDF context's bottom-left origin is CoreText's native space — no
coordinate flip needed for text; image rects use the same math.

An early **walking-skeleton task** proves the off-main CG/CT pipeline
compiles clean under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and
runs off the main thread (instrumented, per the test plan) before any
layout work builds on it — per the constitution's "prefer the test that
would catch the claim being false."

### Photos: downsample at decode

`PhotoPickerField` stores whatever `PhotosPicker` returns — the
full-resolution original, 2–5 MB and ~12 MP per photo, and nothing in
the app resizes anything. Drawing those into PDF pages would embed
full-resolution images: a 300-item export in the hundreds of MB, useless
as the insurance document the spec exists for, and each
`UIImage`-style decode would materialize a ~48 MB bitmap. So:
`CGImageSourceCreateThumbnailAtIndex` with
`kCGImageSourceThumbnailMaxPixelSize` set to twice the drawn box size —
ImageIO decodes straight to target size without ever materializing the
full bitmap. This is load-bearing for criterion 11 and gets its own
mutation-verified size-bound test.

**First photo** means `PhotoSelection.inDisplayOrder(photos).first` —
the single existing definition of photo display order (the same one
`RowThumbnail` documents; SwiftData relationship order is meaningless).
The selection happens **at snapshot time on the main actor**, where the
`[Photo]` array is in hand; only the chosen photo's
`PersistentIdentifier` crosses to the background.

## The PDF document

Judgment call, stated rather than implied: a typographically restrained
print document derived from `tokens.md`'s type roles is plannable
without a dedicated Claude Design pass. The rendered artifact is
reviewed by eye at the manual device task, which is the bounce point if
it reads wrong.

- **Page**: US Letter, 612×792 pt (v1 is US/USD-only), 54 pt margins.
- **Print palette** — a print-only token table added to `tokens.md`
  (the dark-UI palette is for screens; this is a document for paper):
  paper `#FFFFFF`, ink `#1C1A17`, secondary `#6A645C`, hairline
  `#D8D3CA`, print brass `#8F6E3E` (the UI's `accentBrass #C79A56`
  fails contrast on white; the darkened variant clears 4.5:1).
- **Type scale** — the same three faces via their PostScript names, at
  a print-specific scale recorded here deliberately (`ThemeTypography`
  holds opaque screen-sized `Font` values, so sizes can't be shared;
  nobody should later "unify" them): wordmark Archivo 600 @ 26 · cover
  title Archivo @ 20 · entry name Archivo @ 14 · eyebrows/labels IBM
  Plex Mono @ 7.5, tracked caps · field values IBM Plex Sans @ 10.5 ·
  notes IBM Plex Sans @ 10 · money IBM Plex Mono @ 10.5 · cover
  totals IBM Plex Mono 500 @ 15 · cover floor note IBM Plex Sans
  @ 9.5.
- **Cover page**: "TROVE" wordmark, hairline rule, document title
  ("Owned Items" / "Wishlist"), generated date, coverage line built
  from the active filter using the same label strings the chips show
  ("All items", "Category: Guitars"), item count, and the totals block
  — items: total current value and total paid for the exported set,
  with the unvalued count stated so the value figure stays an honest
  floor (mirroring the list header's summary line); wishlist: total
  estimated cost. All figures computed by the view model with its
  existing arithmetic (`totalCurrentValueCents`,
  `totalEstimatedCostCents`), which is what criterion 8 measures.
- **Per-item entry**: hairline rule; photo top-right in a 132×99 pt
  aspect-fit box (no-photo entries let text span the full width — no
  reserved gap); category eyebrow; name; a two-column label/value grid
  carrying the same field set as the CSV; notes as a flowed paragraph.
- **Pagination**: an entry that fits the remaining page space is kept
  together; one that doesn't starts a new page; an entry taller than a
  full page splits mid-notes via `CTFrameGetVisibleStringRange`
  continuation frames.

## Entry point

Ground truth first: both list screens hide the navigation bar
(`.toolbarVisibility(.hidden, for: .navigationBar)`) — the spec's "sort
picker" is the custom `SortBadge` inside each screen's hand-built header
`HStack`. So the "…" is a new header control, not a `ToolbarItem`:

- **`ExportBadge`** — an ellipsis glyph in a brass hairline-bordered
  badge matching `SortBadge`'s height — placed after `sortControl` in
  both headers, so the sort badge shifts left exactly as the spec
  describes.
- It opens a **system `Menu`** with two `Button`s. The T029c history is
  addressed rather than skipped: the system `Menu` was evicted from
  this header because UIKit animated its *variable-width label's*
  bounds outside SwiftUI's reach. This label is a constant-size glyph —
  the exact shape `DetailOverflowMenu` already runs safely in
  production. A `SortDropdown`-style custom menu would add a second
  overlay-and-catcher state machine to each screen for no design gain;
  if the badge's border ever tears the way T029c's did, that custom
  dropdown is the known fallback.
- **[escalated → decided] Visibility**: the badge appears exactly when
  the sort badge does (`totalCount > 0`) — on an entirely empty
  collection the whole control row is hidden and the empty state owns
  the screen, and a lone disabled "…" floating above it served nobody.
  Criteria 1–2 are amended in place. When a filter or search matches
  nothing, the badge stays visible with **both menu items
  `.disabled`** — criterion 2's disabled state lives there.
- While an export is generating, the badge shows a compact
  `ProgressView` in place of the glyph and is disabled — the progress
  affordance of criterion 11, shown for the whole generation (a brief
  flash on instant exports is accepted).

Menu strings, exactly: **Export as CSV…**, **Export as PDF…**.

## Architecture (MVVM placement)

- **Snapshot records** — `nonisolated`, `Sendable` value structs:
  `ItemExportRecord` and `WishlistExportRecord` (strings, ints, dates
  only; `@Model` objects are non-`Sendable` and never cross the
  boundary), each optionally carrying the chosen first photo's
  `PersistentIdentifier`; and `CoverSummary` (title, coverage label,
  count, totals). Snapshotting **on the main actor from the `items`
  array as-is** is correctness, not convenience: visible order is
  computed by `isOrderedBefore` over live filter/sort/search state and
  is not reproducible from any `FetchDescriptor` — a background refetch
  would silently export a different set (criteria 3–4).
- **`ExportService`** — the protocol injected into both list view
  models (constructor parameter with a live default, the same shape as
  `syncMonitor:`):
  `exportCSV(_ table: CSVTable, filename: String) async throws -> URL`
  and
  `exportPDF(_ document: PDFDocumentModel, filename: String) async throws -> URL`.
  The live implementation owns the temp-file store and the generators;
  it takes the `ModelContainer` for background photo fetches.
- **View-model intents** on both list VMs: `func exportCSV() async` and
  `func exportPDF() async` — set `isExporting`, build records from
  `items` in order, call the service, then set
  `stagedExport: StagedExport?` (a Foundation-only Identifiable struct:
  id, URL, filename) or `exportFailureMessage` on throw; always clear
  `isExporting`. Plus `var canExport: Bool { !items.isEmpty }`. View
  models keep importing no SwiftUI.
- **Views**: menu buttons fire `Task { await viewModel.exportCSV() }`;
  `.sheet(item:)` on `stagedExport` presents the share sheet; the
  failure message drives a plain alert.
- **[escalated → decided] Failure surface**: a plain alert — "Couldn't
  export" with a one-line body stating nothing was saved and to try
  again — held as view-model state the way `loadFailureMessage` already
  is. The spec gains a one-line criterion for it.

## Concurrency (criterion 11)

- The export module (schema, writer, composer, live service) is
  **explicitly `nonisolated`** — the project-wide `MainActor` default
  would otherwise capture every one of these types.
- The service entry points are **`@concurrent` async functions**.
  *(Corrected 2026-08-30 at T005 — the draft said `nonisolated async`
  sufficed per SE-0338. The walking skeleton disproved it on this
  toolchain: the project builds with `SWIFT_APPROACHABLE_CONCURRENCY`,
  whose `NonisolatedNonsendingByDefault` (SE-0461) runs nonisolated
  async functions on the caller's actor — the probe recorded generation
  on the main thread until `@concurrent` forced the cooperative pool.
  The attribute lives on the protocol requirements as well as the
  implementations, because calls through the `any ExportService`
  existential — the view models' actual path — follow the requirement's
  convention, and the probe test calls through the existential for the
  same reason.)* The failure mode stays silent either way — dropping
  the attribute or refactoring to a sync signature would re-block the
  UI without a compiler word — and the instrumented test is what keeps
  this true.
- Inside an entry point, the body is **synchronous from the first
  `ModelContext` creation to the file write** — no suspension points,
  so no context-across-`await` hazard and no need for `@ModelActor`
  (noted as the documented alternative if this shape ever changes).
- Photo blobs are fetched off-main by `PersistentIdentifier` from
  contexts created off the shared `ModelContainer` (`Sendable`). A
  **fresh context per batch of 25 entries**, because a `ModelContext`
  retains every `imageData` it materializes — one long-lived context
  would quietly hold every photo in memory and defeat the streaming.
  Per-entry drawing runs inside `autoreleasepool`.
- Marking `Photo` `nonisolated` (T008) is an accepted widening: every
  `Photo` property becomes compiler-legal to touch off-main. The type
  stays non-`Sendable` — instances can't cross domains — and each
  domain fetches through its own context; today only `PhotoFetcher`
  uses the allowance. Recorded (T019) so a future change doesn't
  inherit it silently; `@ModelActor` remains the documented
  alternative if this ever needs tightening.
- Snapshot identifiers are valid because every mutation path in the app
  saves. An identifier that fails to resolve mid-export (a CloudKit
  delete landing between snapshot and fetch) **skips the photo and
  keeps the entry** — decided behavior, not a crash.

## Delivery and temp-file lifecycle

- **Share sheet**: `UIActivityViewController` wrapped in a
  `UIViewControllerRepresentable` — **flagged UIKit exception**, the
  constitution's first sanctioned shape verbatim, confined to
  `Trove/Views/Shared/ShareSheet.swift` (~25 lines, zero logic). This
  is the spec's only UIKit exception; the PDF module has none.
  Alternatives: `ShareLink` rejected per the review record above;
  `.fileExporter` rejected because it is Files-only and the spec
  requires AirDrop/Mail/anything-the-sheet-offers.
- **Temp lifecycle** (criterion 10): files are written under
  `tmp/Exports/`; the live service purges that directory **before each
  new export set** and **once at app launch** (called from app startup).
  At most the latest file set ever exists — nothing accumulates — and
  the OS reclaims `tmp` independently. Canceling the share sheet needs
  no cleanup hook; the next export or launch sweeps it. *(Restated
  2026-09-01 at `013`/T001: "before each new export" became "before
  each new export **set**" when `ExportService` gained `exportFiles` —
  several files for one share sheet, purged once and written together.
  A list export is a set of one; the rule is the same rule.)*

## Files

New (all under synchronized folder groups — no `.pbxproj` edits):

- `Trove/Export/ExportSchema.swift` — records, headers/column order,
  money & date serializers
- `Trove/Export/CSVWriter.swift` — RFC 4180 writer
- `Trove/Export/PDFComposer.swift` — CG/CT/ImageIO document renderer
- `Trove/Export/ExportService.swift` — protocol + live implementation
  (temp store, purge, off-main entry points)
- `Trove/Views/Shared/ExportBadge.swift` — the "…" header control and
  its menu
- `Trove/Views/Shared/ShareSheet.swift` — the flagged UIKit exception
- Tests: `ExportSchemaTests`, `CSVWriterTests`, `PDFComposerTests`,
  `ExportConcurrencyTests`, `ExportTempFileTests`, `ExportWiringTests`,
  plus export intent coverage in `ItemListViewModelTests` and
  `WishlistViewModelTests`

Modified: `ItemListView.swift` / `WishlistView.swift` (header control,
menu, share sheet, alert), `ItemListViewModel.swift` /
`WishlistViewModel.swift` (intents, injected service, export state),
`TroveApp.swift` or `TroveStore.swift` (launch purge — smallest
sensible hook), `design/tokens.md` (print palette table, export badge
row), `spec.md` (the three amendments, applied with this draft).

## Test plan

Constitution norms applied: every guard is mutation-verified (break the
rule, watch it go red) before it lands; claims in this plan get the test
that would catch them false.

- **CSV escaping round-trip**: writer output parsed back by a small
  test-only RFC 4180 parser; fields containing commas, quotes, CR/LF
  survive exactly (criterion 5's hard cases). Red check: strip the
  quoting logic.
- **Money round-trip** — the invariant `012` actually depends on:
  `Money.cents(from: Decimal(string: field)!) == originalCents` across
  0, 1, 999_999_999, and exact-decimal edges — not just string
  equality.
- **Locale independence** (criterion 7): exact-output assertions for
  tricky values, with the claim carried by the design — no
  `Locale`/`DateFormatter` in the serialization path — rather than by
  an unfalsifiable process-locale switch. Stated honestly: this is a
  design-enforced claim with exact-value tests, not a simulated-locale
  test.
- **Export order = visible order** (criteria 3–4): view-model test sets
  filter + sort against an in-memory store, injects a fake
  `ExportService` that records its inputs, asserts the records match
  `items` exactly — content and order. Red check: build records from a
  refetch instead of the array.
- **Empty disabling** (criterion 2): `canExport` false whenever `items`
  is empty; an `ExportWiringTests` source-scan guard (the
  `ReorderWiringTests` pattern) that both views gate the menu items on
  it and both intents are wired in both views.
- **Off-main generation** (criterion 11, and the T056 lesson —
  instrument the mechanism, don't watch a proxy): a probe inside the
  live service's generation body records `Thread.isMainThread`; the
  test calls the intent from the main actor and asserts the probe saw
  `false`. Red check: force the body onto the main actor.
- **PDF validity and content**: `PDFKit.PDFDocument(data:)` (Apple
  framework, test-side only) — page count; cover page `.string`
  contains the title, count, coverage line, and totals; entry fields
  present; a no-photo entry renders; a multi-photo item exports exactly
  its first, asserted at snapshot level against
  `PhotoSelection.inDisplayOrder`.
- **PDF size bound** (the downsampling guard): a seeded collection with
  deliberately large photos must produce a file under a stated bound.
  Red check: bypass the thumbnail decode.
- **Temp purge** (criterion 10): two exports back-to-back leave exactly
  one file set on disk. Real disk I/O by necessity — the same narrow,
  deliberate exception shape as `CloudKitSchemaTests`, verifying an
  infrastructure claim that can't be checked any other way.
- **Cover arithmetic** (criterion 8): the `CoverSummary` the view model
  builds equals `totalCurrentValueCents` / `totalEstimatedCostCents`
  for the same filtered set.

## Verification

Per the constitution: `xcodebuild build` and `xcodebuild test` green,
actual output reported, before any task is called done. The manual
device pass (its own task, like 010's T038): export from filtered and
sorted states in both formats on both screens, open the CSV in Numbers,
read the PDF end to end — this is the review point for the document
design — cancel the share sheet, export repeatedly, and confirm nothing
accumulates in temp storage.

## Out of scope for this plan

Everything the spec lists as a non-goal, plus: `012`'s parser (it reads
this document's schema section when its time comes), any
export-everything or settings surface, and any change to how
`purchaseDate` is stored (explicitly deferred at the date-format
decision).
