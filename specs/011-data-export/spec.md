# 011 — Data Export

Status: **Approved** (2026-08-30; criteria 1–2, the CSV date rule, and
the failure surface amended the same day during planning — see the
amendment notes inline)

## What and why

Export the collection out of Trove as CSV (portable data — backup, or
moving to another tool) and PDF (presentation-quality — insurance
documentation, sharing). This is the differentiator against the
spreadsheet most hobbyists already use: a spreadsheet can't produce an
insurance-grade document of itself, and Trove's data shouldn't be locked
in.

Traces to `001`'s explicit non-goal ("Insurance-document export or
valuation reports"), promoted via `ROADMAP.md`. Decisions made ahead of
this spec, carried in from the roadmap and the idea conversation:

- CSV only on the data side — no `.xlsx`. Any spreadsheet app opens CSV
  and can re-save it as `.xlsx` itself; genuine Excel format would
  likely require a third-party package.
- Photos belong to the PDF, not the CSV.
- The CSV schema is the canonical "item as a row" representation —
  `012-data-import` will reuse it, and export's schema is deliberately
  designed first.

## Core behavior: export follows the view

There is no global "export everything" in this spec. Export acts on
**what the user is currently looking at**:

- On the **Items list**, export produces the owned items currently
  visible — respecting the active category filter *and* the current
  sort order. Filtered to one category exports that category; "All"
  exports everything owned. Rows appear in the file in exactly the
  order they appear on screen.
- On the **Wishlist**, the same rule with wishlist items and the
  wishlist's own filter and sort.
- Items and wishlist are always separate exports with separate schemas
  — never combined into one file or document.

## Entry point

A "…" (more) toolbar action at the top right of both list screens,
positioned after the existing sort picker (which shifts left to make
room). Tapping it opens a small menu with two actions:

- **Export as CSV…**
- **Export as PDF…**

Each goes directly to the iOS share sheet with the generated file —
save to Files, AirDrop, mail, anything the sheet offers. No custom
delivery UI, no in-app export history.

The "…" menu is this app's first overflow affordance and is expected to
accumulate future actions (and eventually appear on other screens); this
spec adds it to the two list screens only, with only the two export
actions in it.

Both export actions are **disabled when the current view is empty**
because a filter or search matched nothing. On an entirely empty
collection the "…" control is hidden along with the rest of the header
controls — the same rule the sort picker already follows ("nothing to
sort on an empty list"), and the empty state's own call-to-action owns
that screen. Either way, an empty file is never produced. *(Amended
2026-08-30 during planning: originally the menu showed disabled even on
an empty collection; a lone "…" floating over the empty state matched
neither the existing screens nor any user need.)*

If generating a file fails, a plain alert says the export couldn't be
completed and nothing was saved; no file is delivered. *(Added
2026-08-30 during planning — the spec previously defined no failure
surface, and a silently dead button is the worst version of one.)*

## What gets exported per item

**The full detail-screen field set, not the list row's.** Every
user-visible persisted field that appears on the item detail screen is
included — name, category, prices (paid and current value), dates,
condition, serial number, notes, desire level, and any other detail
fields — so the CSV is a genuine backup of the data, not a summary.
The authoritative field-by-field column list gets pinned in `plan.md`
against the actual model, not guessed here; the rule is "if the detail
screen shows it, the export includes it," with photos as the one
exception (PDF only, below).

The wishlist export follows the same rule against the wishlist detail
screen's fields (name, category, estimated cost, desire-to-own, notes,
added date).

## The CSV

- One file per export. UTF-8, header row, standard quoting/escaping.
- Dates in ISO 8601 (`2026-08-30`) — the device-local calendar day,
  exactly what the detail screen shows. *(Caveat recorded 2026-08-30
  during planning: purchase dates are stored as raw instants, so the
  calendar day can differ across timezones — a CSV round trip is
  timezone-stable only within one timezone. This is a pre-existing
  storage property that export exposes rather than creates; normalizing
  storage was considered and deferred. `012` inherits the caveat via
  `plan.md`'s schema section.)*
- Money as plain decimal numbers, no currency symbol, dot decimal
  separator regardless of locale (`1250.00`) — this is a data format,
  and `012`'s import will parse it back; locale-formatted money in a
  CSV is a re-import landmine.
- Desire level as its integer (1–5 owned, 1–3 wishlist).
- Category as the full path string, exactly as stored.
- Filename: `Trove-Items-YYYY-MM-DD.csv` / `Trove-Wishlist-YYYY-MM-DD.csv`.

## The PDF

A **collection document**, not per-item sheets: a cover summary
followed by one entry per exported item.

- **Cover summary**: document title, date generated, what the export
  covers (the active filter, e.g. "Category: Guitars", or "All items"),
  item count, and — for the items export — total current value and
  total paid across the exported set. The summary describes the
  exported subset, not the whole collection, consistent with
  export-follows-view.
- **Per-item entry**: the item's first photo (if it has one; entries
  without photos lay out cleanly without a gap), followed by the same
  full detail field set as the CSV. One photo per item in v1 even when
  more exist.
- The wishlist PDF is the same document shape with the wishlist field
  set; its cover totals the estimated costs of the exported set.
- Visual treatment should read as belonging to Trove (typography and
  restraint consistent with the app) but is print-first: light
  background, dark text — this is a document for paper and PDF viewers,
  not a screenshot of the dark UI. Exact treatment is a design/plan
  concern, not fixed here.
- Filename: `Trove-Items-YYYY-MM-DD.pdf` / `Trove-Wishlist-YYYY-MM-DD.pdf`.

## Acceptance criteria

1. [x] Both list screens show the "…" action at the top right, right of the
   sort picker, whenever the sort picker itself shows (a non-empty
   collection), on all size classes; the sort picker's behavior is
   unchanged. *(Amended 2026-08-30 — see Entry point: on an empty
   collection the control hides with the rest of the header controls.)*
   *(Superseded in part by `012-data-import` criterion 1, 2026-09-01:
   the "…" — renamed `OverflowBadge` — now shows regardless of
   collection size, because its menu carries Import and Get Blank
   Template and a fresh install must reach them. The export actions'
   disabled state and the sort badge's hide-when-empty are unchanged.)*
   *Verified: both headers share one visibility gate
   (`ItemListView.header` / `WishlistView.header`);
   `ExportWiringTests.theBadgeIsFedByTheViewModelAndFiresBothIntents`;
   simulator checks at T012/T013. The layout is intrinsic (no
   size-class branching exists to diverge).*
2. [x] The "…" menu shows exactly two actions, Export as CSV… and Export
   as PDF…, both disabled when the current view is empty (a filter or
   search matching nothing; the entirely-empty collection is covered by
   criterion 1's visibility rule). *(Amended 2026-08-30, same decision.)*
   *Verified: `ExportWiringTests.bothMenuActionsGateOnCanExport` (two
   pinned strings, each individually gated);
   `canExportTracksTheVisibleListNotTheStore` and
   `nothingIsExportedWhenTheViewIsEmpty` in both view-model suites.*
2a. [x] A failed export shows a plain alert and delivers nothing. *(Added
   2026-08-30 during planning.)*
   *Verified: `aThrowingServiceSurfacesTheSharedFailureCopy` in both
   view-model suites (shared copy, nothing staged, progress cleared);
   `ExportWiringTests.theShareSheetAndFailureAlertAreWired`.*
3. [x] Exporting from a filtered Items list produces a file containing
   exactly the visible items, in the visible order; changing filter or
   sort and re-exporting reflects the change.
   *Verified:
   `ItemListViewModelExportTests.exportedRowsAreTheVisibleItemsInVisibleOrder`
   — filter + non-default sort, mutation-verified (a refetch leaked the
   filtered-out item and went red).*
4. [x] The same holds on the Wishlist with its filter and sort.
   *Verified: the wishlist twin in `WishlistViewModelExportTests`,
   independently mutation-verified.*
5. [x] The CSV opens correctly in Numbers and in Excel (via a standard
   CSV import) with all columns intact — including fields containing
   commas, quotes, and newlines in notes.
   *Verified: the format half by `CSVWriterTests` (RFC 4180 round trip
   through a real parser over the comma/quote/newline hard cases; BOM
   for Excel). The open-it-and-look half rests on T018's record —
   "csvs are readable", apps not itemized (T019/S5) — and plan.md's
   Excel serial-number caveat stands (Excel's default open coerces long
   digit strings; the criterion's own "standard CSV import" path with
   text columns is what holds).*
6. [x] A round-trip sanity check: every detail-screen field for a given
   item can be located in that item's CSV row with the correct value.
   *Verified: `itemRowCarriesEveryColumnInHeaderOrder` +
   `itemRecordCarriesEveryFieldFromTheModel` (and wishlist twins) in
   `ExportSchemaTests` — model → record → row, per column. Condition
   matches case-insensitively (raw lowercase in the CSV, capitalized on
   screen), recorded in plan.md's schema table.*
7. [x] Money and date values in the CSV match the formats above regardless
   of device locale.
   *Verified: `moneySerializesExactValues`,
   `moneyRoundTripsThroughTheParseSide`, `daySerializesZeroPaddedISO`,
   `dayIsAlwaysGregorianRegardlessOfDeviceCalendar` — money is
   locale-free by construction (integer math), dates
   calendar-identifier-free by construction (the serializer takes only
   a `TimeZone` and builds its own Gregorian calendar). The T019 review
   caught the first implementation defaulting to `Calendar.current`,
   which would have written Buddhist year 2569 on so-configured
   devices; plan.md's serialization section records the correction.*
8. [x] The PDF's cover figures match the app's own arithmetic for the same
   filtered set.
   *Verified: `pdfCoverFiguresAreTheViewModelsOwnArithmetic` (items) and
   `pdfCoverTotalsTheViewModelsOwnEstimatedCost` (wishlist) — the cover
   the service receives carries the view models' own totals, checked
   against live properties and concrete figures both.*
9. [x] An item with no photos produces a clean PDF entry; an item with
   several photos shows exactly its first.
   *Verified: `entriesStartOnTheirOwnPageWithTheFullFieldGrid` (a
   no-photo entry renders all fields — text-level; the full-width/no-gap
   *layout* property is carried by the composer's resolve-before-layout
   branch and T018's eyeball, since extracted text can't measure
   geometry — narrowed at T019/S4),
   `anUnresolvablePhotoIdentifierKeepsTheEntryPhotoFree`,
   `firstPhotoFollowsDisplayOrderNotInsertionOrder` ("first" =
   `PhotoSelection.inDisplayOrder`, the one definition, mutation-verified
   at snapshot level), and the embed proven real by
   `photosEmbedDownsampledAndBoundTheFileSize`.*
10. [x] Both formats deliver via the standard share sheet; canceling the
    sheet leaves no residue (no stray temp files accumulating across
    repeated exports).
    *Verified: delivery live on the simulator at T012 (CSV) and T013
    (PDF); `aSecondExportLeavesExactlyOneFileSet` (purge-before-write,
    mutation-verified) and `launchSweepClearsTheRealStagingDirectory` —
    and T014's on-device sweep removed exactly the residue T013's
    canceled sheet had left.*
11. [x] Exporting a large collection (hundreds of items, with photos) does
    not block the UI — some progress affordance appears if generation
    is not effectively instant.
    *Verified: `ExportConcurrencyTests.generationRunsOffTheMainThreadForBothFormats`
    — instrumented through the `any ExportService` existential, the
    probe recording the actual thread, mutation-verified (stripping
    `@concurrent` put generation back on the main thread and went red);
    `photosEmbedDownsampledAndBoundTheFileSize` bounds the with-photos
    path; the progress affordance is the badge's spinner, fed by
    `isExporting` (`ExportWiringTests` pins the feed). Honestly
    partial, matching T018's record: a hundreds-of-items collection was
    not exercised by hand — the criterion's mechanics are carried by
    the instrumented probe and the size bound, its feel is not
    separately confirmed. (T019/B2 corrected an earlier "confirmed"
    here that contradicted T018's own note.)*

## Non-goals (explicit)

- **Export-everything** (both lists at once, from anywhere) — deferred
  to a future settings menu, which this deferral partly motivates.
- **Dashboard export** — the Dashboard has no view context to follow; a
  future custom dashboard export (summary figures plus detail) is a
  roadmap idea, not this spec.
- **Detail-screen / per-item export** — per-item PDF sheets are a
  possible future refinement of the collection document.
- **`.xlsx`** — decided ahead of this spec, see above.
- **Multi-photo PDF entries** — first photo only in v1.
- **Import** — `012`, which consumes this spec's CSV schema.
- **Export history, scheduling, or cloud delivery** — the share sheet
  is the whole delivery story.
- **Combined items+wishlist files or documents.**
