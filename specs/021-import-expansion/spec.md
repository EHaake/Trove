# 021 — Import Expansion

**Status**: **Draft** (2026-10-07) — written with the person in this spec
session. The Decisions record below holds every product decision they made
in the conversation; the **P-items** are Claude Code's proposals and become
decisions on approval, as in earlier specs.

Authored in a Claude Code spec session of its own, per `CLAUDE.md`'s model
policy (Opus profile, the session raised to high effort for the spec
conversation).

**Depends on**: `001-core-inventory` (`Item`, `WishlistItem`),
`006-mark-as-sold` and `014-sold-side-parity` (the sale columns and what
selling means), `009-sell-plan-list` (why selling stays the app's own
action), `011-data-export` (the CSV layouts and their append-only growth
rule), `012-data-import` (the importer this spec loosens and extends),
`013-settings-menu` (the templates), `020-purchase-provenance` (the
`Bought` and `Looking For` columns, Very Good). It adds no outside service.

## Summary

Today the importer reads one thing: Trove's own template, exactly. A
spreadsheet a person actually keeps — columns in their own order, prices
written `$3,179.95`, dates written `5/1/2025`, `N/A` where there is no
serial number, a totals row at the bottom — is refused at the header before
a single row is read. And import only ever *adds*: there is no way to
change many items at once by editing a sheet.

This spec does two things, on both lists.

**It reads a human-kept sheet as it is.** Columns are found by their names,
in any order; only a few are required, and the template and every export
mark those with a star. Prices may carry a currency symbol and thousands
commas. Dates may be written `5/1/2025`. `N/A` means empty. A totals row is
recognised and left out. A column the app doesn't know is ignored, and the
confirmation says so.

**It makes the sheet a way to edit the collection.** Every export carries
one more column, **Trove ID**, holding each item's own code. Re-import a
file and a row with a code **updates** that item; a row without one is
**added**. Nothing is ever deleted by an import, and an empty cell never
changes anything.

The person's own file, `My-Gear.csv` — 90 items, ten columns, 13 `N/A`
serial numbers, a totals row — imports as it is: 90 items added, nothing
skipped, nothing defaulted.

## What and why

The person keeps their collection in Google Sheets as well as in the app,
and wants the two to work together. In their words (2026-10-06): "I want to
make it so that the file as is would import. That would allow a human
readable csv file to be maintained in something like google sheets and
could be imported into the app seamlessly." And their example for the
second half: to change many items at once, export the full collection,
edit it in Google Sheets, and re-import it — updating the items that
already exist and adding any that are new.

`012` chose a rigid template on purpose and recorded column mapping as the
likely next step "once real-world friction with the rigid template is
observed". This is that friction, observed on the first real sheet. The
answer here is not a mapping screen: it is a reader that accepts Trove's
own column names wherever they appear and the ordinary ways a spreadsheet
writes a price and a date.

**How the two halves fit together for a sheet kept by hand.** A hand-kept
sheet has no Trove IDs, so its first import adds everything — and so would
a second import of the same file, exactly as today. After that first
import the working file is the app's export: it has every column and every
item's ID, so edits made to it in Sheets come back as updates. This is the
one thing a person has to know, and the reference doc says it first.

## Core behavior

### Finding the columns

- The first row is the header. Each column is recognised by its **name**,
  not its position: the names are Trove's own (`Name`, `Category`,
  `Purchase Price`, … — the list in `docs/csv-reference.md`), compared
  ignoring upper and lower case, spaces around the name, and a trailing
  star. `purchase price`, `Purchase Price` and `Purchase Price *` are the
  same column.
- Columns may come in **any order**, and any column that is not required
  may be **left out**. A column that isn't there behaves exactly like a
  column whose every cell is empty.
- **Required columns.** A file for the Items screen must have `Name`,
  `Purchase Price` and `Purchase Date`. A file for the Wishlist must have
  `Name` and `Estimated Cost`. A file missing any of them is refused —
  nothing is imported — and the alert names the missing columns.
- **Columns the app doesn't know** — `Mount`, `Insured`, a misspelled
  `Purchse Price` — are ignored, and the confirmation lists them by name,
  so a misspelling is noticed before anything is written. (A misspelled
  *required* column is caught by the rule above.)
- **The same column twice** refuses the file, naming the column — there is
  no safe guess about which one is meant.
- A wishlist file offered to the Items screen, or the reverse, is still
  recognised and the alert still points to the right screen.
- Every file an earlier Trove exported still imports. Those files have the
  required columns, so they pass the same rules with no special case.

### Prices

A price is read as its number. A leading currency symbol (`$`, `€`, `£`,
`¥`) and thousands commas are dropped: `$3,179.95` is 3179.95, `500` is
500. The symbol **never sets the currency** — the `Currency` column does,
and without one the item is `USD`, as today. A European-style `1.250,00`
is still not read, because it can't be told from `1,250.00` safely; nor is
a negative amount, an amount in brackets, or a number followed by text.
Those are unreadable, and are treated as an unreadable price is today.

### Dates

`2026-03-09` reads as it always has. A date written with slashes and a
four-digit year — `5/1/2025`, `05/01/2025` — is also read, and **the file
decides** whether the month or the day comes first: if any date in the
file has a number above 12 in one position (`12/28/2025`), that settles
the order for every slash date in the file. If no date settles it, the
phone's region setting does, and the confirmation says which order was
used. If the file contradicts itself — one date only works month-first,
another only day-first — the phone's region is used and the dates that
don't fit it are unreadable.

### N/A

A cell that says `N/A` — in any casing, or the `#N/A` a spreadsheet shows
for a failed lookup — is an **empty cell**, in any column. So `N/A` in
Serial Number is no serial number, in Current Value is not yet valued, in
Year is no year.

### Totals rows

A row is a **totals row** when it has no name (or its name is `Total`,
`Totals`, `Subtotal` or `Sum`), no Trove ID, and every other filled cell
is an amount in a money column. It is left out wherever it sits in the
file, and the confirmation says so in one plain line — it is not listed
among the skipped rows, because nothing is wrong with it. Blank rows
between groups are ignored silently, as they are today.

### Every item has a Trove ID

Each owned item, sold item and wishlist entry has one code of its own. It
is the same on every device, it never changes, and it is never shown in
the app. Its only job is the `Trove ID` column:

- Every CSV export writes it, as the **last** column on both layouts.
- The templates carry the column, empty.
- It is a code, not a number: it must come back from Google Sheets, Excel
  and Numbers exactly as it left.

### Re-importing: added, updated, unchanged

For each row, the app looks at its `Trove ID` cell:

- **Empty** (or no such column): the row is a **new** item. No attempt is
  made to match it by name or anything else — `012`'s "no duplicate
  detection" stands for rows without an ID.
- **A code that belongs to an item in this list**: the row **updates**
  that item. Renaming it in the sheet is just an update to its name.
- **A code that matches nothing** — the item was deleted, or the file is
  being restored onto an empty phone: the row is a **new** item that
  **keeps the code from the file**, so importing the same file again
  updates it rather than adding another copy.
- **A row identical to its item** changes nothing and is counted as
  unchanged.
- **Two or more rows carrying the same code**: **none of them is
  applied.** They are listed with the hint to clear the Trove ID cell on
  the row meant as a new item. An update can't be undone, so the app
  doesn't guess which row is the original.
- **Something in the Trove ID cell that isn't a code**: the row is a new
  item with a fresh ID, and it is counted like any other unreadable cell.

**Nothing is ever deleted.** An item that is in the app and not in the
file is left exactly as it is. Exports can be partial — owned only, a
filtered list — so a missing row never means "delete this".

### What an update changes

**An empty cell never changes anything.** Only a filled, readable cell in
a column the file has updates the item. So:

- A filled cell that differs from the item replaces that one value: name,
  category (the item moves), prices, currency, dates, place, desire,
  condition, notes, serial number, Reverb product, year, Bought / Looking
  For.
- An empty cell, an `N/A`, or a missing column leaves the item's value as
  it is. A field can't be *cleared* from a sheet; that is done in the app.
- An **unreadable** cell (`abc` for a price) also leaves the value as it
  is, and is counted so the sheet can be fixed.
- A row with a matching ID and an empty Name updates everything else and
  keeps the name.
- **Never touched by any import**: photos, sell plans and what is on them,
  the item's place in your custom order, market figures fetched from
  Reverb, and anything else that isn't a column.
- An updated item stays where it is in custom order. New rows still append
  at the end, in the file's order.

The defaults of `012` are for **new** rows only: a new row with an empty
or unreadable price gets `0.00`, a date gets today, and so on, counted as
today. An update never fills in a default.

### Sold status stays in the app

Selling touches sell plans and their records, so an update can't do it.

- A row that **adds** an item may still arrive already sold, as today.
- A row that updates an item **already sold** may correct its sale date,
  price, place and note.
- A row that updates an item **you still own** and has the sale columns
  filled updates everything else; the sale cells are left unused and the
  confirmation says how many rows that was.
- Emptying the sale cells of a sold item changes nothing — an empty cell
  never does — so a sheet can't un-sell anything either.

### The confirmation

Still one step before anything is written, and Cancel still leaves
everything untouched. It now says:

- how many items will be **added**, how many **updated**, and how many
  rows are **unchanged**;
- the skipped rows, by spreadsheet row number with a reason — the first
  five, then "and N more" — now including rows that share a Trove ID;
- how many cells were unreadable and will use a default (new rows) or be
  left as they are (updates);
- any columns that were not recognised, by name;
- a line for a totals row left out;
- a line for sale cells left unused on items still owned;
- the date order, when the phone's region had to decide it;
- when any item will be updated, that **an update can't be undone**.

If nothing would be added or updated, it is informational only.

### Export and templates

- The template and every CSV export write a star after each required
  column's name: `Name *`, `Purchase Price *`, `Purchase Date *`; on the
  wishlist `Name *`, `Estimated Cost *`.
- `Trove ID` is appended as the last column of both layouts (items 20
  columns, wishlist 11).
- Nothing else about what export writes changes: plain numbers,
  `yyyy-MM-dd` dates. A file Trove wrote still reads back exactly.
- A copy of the app from before this spec **will not read** a file written
  after it. Files move forward, not back.
- The PDF is unchanged.

### Sync

The Trove ID is the same on every device, including for everything that
existed before this update — two devices must never give one item two
different codes. Importing on a device that hasn't finished syncing can
add an item the other device already has; that is true of import today
and is stated, not solved.

## Copy

Proposed wording; the plan may adjust it for fit, not for meaning.

- Missing required columns: "This file is missing **Purchase Price** and
  **Purchase Date**. Trove needs the columns marked * in the template.
  Nothing was imported."
- Counts: "**90 items** will be added." / "**12 items** will be updated
  and **3** added. 75 rows are unchanged."
- Unknown columns: "Not used: **Mount**, **Insured**."
- Totals row: "Row 108 looks like a totals row and was left out."
- Same ID: "rows 14 and 15 — same Trove ID. Clear the Trove ID on the row
  that's a new item."
- Sold status: "3 rows have sale details for items you still own. Mark
  them sold in the app."
- Date order: "Dates read as month/day/year, from this iPhone's region."
- Updates: "Updates can't be undone."

## Design requirements

- The confirmation has more to say than an alert was built for. It stays a
  single confirm-or-cancel step; if an alert can't hold it legibly, it
  becomes a sheet in the app's own style with the same two actions (the
  destructive-colour rule doesn't apply — nothing is deleted).
- No new screen, menu item or setting. Import and the templates stay where
  they are.

## Acceptance criteria

**Reading a sheet as it is**

1. [ ] A file shaped like the person's sheet — the ten columns in their
   order, `$` prices with commas, `M/D/YYYY` dates, `N/A` serial numbers,
   blank rows between groups, three blank rows and a totals row at the
   end — imports into the Items screen with every item row added, nothing
   skipped, no defaults counted, and one totals-row line.
2. [ ] The person's own `My-Gear.csv`, imported on a device at the
   walkthrough, adds 90 items; the 13 `N/A` serial numbers arrive empty;
   `0185654` keeps its leading zero; the Alienware monitor's value is 500.
3. [ ] Columns are found by name in any order: the same rows with the
   columns shuffled import to identical items.
4. [ ] Header names match regardless of case, surrounding spaces and a
   trailing star.
5. [ ] An Items file missing `Name`, `Purchase Price` or `Purchase Date`,
   or a Wishlist file missing `Name` or `Estimated Cost`, imports nothing
   and the alert names every missing required column.
6. [ ] A file with only the required columns imports; every other field
   takes what a blank cell gives it today.
7. [ ] An unrecognised column is ignored, its cells affect nothing, and
   the confirmation names it. Several are all named.
8. [ ] A file with the same recognised column twice imports nothing and
   the alert names the column.
9. [ ] Every layout an earlier Trove exported (items at 12, 14, 18 and 19
   columns; wishlist at 7, 9 and 10) still imports with zero skips and
   zero defaults.
10. [ ] A wishlist file offered to the Items screen, and the reverse, is
    recognised as the other list's file in the alert.
11. [ ] Prices: `$3,179.95`, `€1,250`, `£99.5`, `¥500`, `1,250.00` and
    `500` read to the exact cent; the symbol does not change the item's
    currency; `1.250,00`, `-5`, `(5.00)`, `1,25` and `500 USD` are
    unreadable.
12. [ ] Dates: `yyyy-MM-dd` reads as before. In a file where any slash
    date has a number above 12 in one position, every slash date is read
    in that order — month-first and day-first files each shown.
13. [ ] Dates: in a file where no date settles the order, the phone's
    region decides and the confirmation states the order used; in a file
    that contradicts itself, the region decides and the dates that don't
    fit are unreadable. A two-digit year is unreadable.
14. [ ] `N/A`, `n/a` and `#N/A` read as an empty cell in every column: no
    serial number, not yet valued, no year; in a required cell of a new
    row, the same default and count as a blank one; in Name, the row is
    skipped as nameless.
15. [ ] A totals row — no name or a name of `Total`, `Totals`, `Subtotal`
    or `Sum`, no Trove ID, every other filled cell an amount in a money
    column — is left out anywhere in the file, with one line in the
    confirmation and no entry in the skipped list. A nameless row with
    anything else filled is still skipped as nameless.
16. [ ] The wishlist reads by all of the rules in 3–15 against its own
    columns.

**Trove ID and export**

17. [ ] Every owned item, sold item and wishlist entry has a Trove ID,
    including everything that existed before the update; it does not
    change across relaunches or edits.
18. [ ] Every CSV export — owned, sold, owned and sold, wishlist, Export
    All — writes `Trove ID` as its last column with each row's code, and
    stars the required columns' names. The templates have the same header
    and no rows.
19. [ ] A Copy of an item, and an item made by Mark as bought, has a new
    Trove ID of its own.
20. [ ] The code survives a spreadsheet: an export opened and re-saved as
    CSV keeps every Trove ID readable and matching. (The person's
    walkthrough does this in Google Sheets; a recorded re-saved file pins
    it in the tests.)
21. [ ] The PDF is unchanged.

**Re-importing**

22. [ ] **Round trip**: a full export re-imported unchanged adds nothing,
    updates nothing, and reports every row as unchanged.
23. [ ] A row whose Trove ID belongs to an item updates that item from its
    filled, readable cells: name, category, purchase price, currency,
    purchase date, place, current value, desire, condition, condition
    notes, serial number, notes, Reverb product, year and Bought each
    shown changing. The confirmation counts it as updated.
24. [ ] An empty cell, an `N/A`, and a column missing from the file each
    leave the item's value as it was — shown for an optional field
    (serial number), for a required one (purchase date) and for Current
    Value.
25. [ ] An unreadable cell on an update leaves the value as it was and is
    counted; no default is ever written onto an existing item.
26. [ ] A matching row with an empty Name updates the rest and keeps the
    name.
27. [ ] A row with no Trove ID is added as new even when an item with the
    same name exists; importing an ID-less file twice makes two copies.
28. [ ] A row whose Trove ID matches nothing is added as a new item that
    carries that ID; importing the same file again updates it and adds
    nothing.
29. [ ] Two or more rows with the same Trove ID: none is applied, each is
    listed with the hint, and the item they name is untouched.
30. [ ] Text in the Trove ID cell that isn't a code: the row is added as
    new with a fresh ID, counted.
31. [ ] An item in the app and absent from the file is unchanged after
    the import — shown with a file holding one row of a larger collection.
32. [ ] An update never changes an item's photos, its sell plans, its
    place in custom order or its fetched market figures. New rows append
    at the end of custom order in file order.
33. [ ] Setting `Bought` on many items at once works: an export with the
    Bought column filled in for every row re-imports as updates and each
    item reads new or used accordingly.
34. [ ] Sold status: a row updating an owned item with the sale columns
    filled updates its other fields, leaves it owned, and the confirmation
    counts the row; a row updating a sold item changes its sale date,
    price, place and note; emptying a sold item's sale cells leaves it
    sold; a new row with a readable sale pair still arrives sold.
35. [ ] The wishlist follows 22–32 with its own columns and its own IDs,
    `Looking For` and `Added` included.

**The confirmation, and the rest**

36. [ ] The confirmation precedes any write and states added, updated and
    unchanged counts; skipped rows (first five, then "and N more");
    unreadable cells; unused columns; the totals-row line; unused sale
    cells; the date order when the region decided it; and "can't be
    undone" whenever anything will be updated. Cancel leaves the store
    untouched. With nothing to add or update it offers no import action.
37. [ ] A failed import — unreadable file, not UTF-8, unclosed quote, too
    large, missing required column, duplicated column — imports nothing,
    never a partial batch.
38. [ ] The app stays responsive while a 300-row file of mixed adds and
    updates is read and applied.
39. [ ] `docs/csv-reference.md` describes the rules as they now are, leads
    with the hand-kept-sheet loop (import once, then work from the
    export), and its sample files are updated and still each pinned by a
    test. `011`'s and `012`'s specs carry superseded-by notes where this
    spec changes what they say.
40. [ ] Sync: an item's Trove ID is the same on a second device, and an
    update applied by import on one device reaches the other. (Joins
    `specs/SYNC-CHECKS.md`; expected to stay unticked until the
    two-device pass, like the sync criteria before it.)

## Decisions record

All made by the person, 2026-10-07, in the spec conversation.

1. **Both halves are this spec**: lenient reading and update-on-re-import.
2. **Required columns are marked with a star** in the header of the
   template and of every export.
3. **Required**: `Name`, `Purchase Price`, `Purchase Date`; on the
   wishlist `Name`, `Estimated Cost`. A file missing one is refused, and
   the message names what's missing. Everything else, `Bought` included,
   is optional.
4. **A blank or unreadable cell in a required column** is handled as
   today: no name skips the row; a price becomes `0.00` and a date today,
   counted.
5. **A column the app doesn't know is ignored, and the confirmation says
   so.**
6. **Dates: the file decides** whether month or day comes first; the
   phone's region only when the file can't.
7. **`N/A` is an empty cell, in any column.**
8. **A totals row is left out, with one plain line** — not listed as a
   problem.
9. **A row finds its item by a Trove ID column** that export writes.
   No matching by name.
10. **An empty cell never changes anything on an update.** The cost is
    accepted: a field can't be cleared from a sheet.
11. **An item missing from the file is left alone. Import never deletes.**
12. **Sold status stays in the app.** An update can correct the details
    of a sale, never make or undo one.
13. **Both lists.**
14. **A Trove ID that matches nothing**: added as new, keeping the ID.
15. **The same Trove ID on two rows**: neither is applied.
16. **Prices**: any leading currency symbol and thousands commas are
    dropped; the symbol never sets the currency; `1.250,00` is not read.

### The P-items

Claude Code's proposals. Each becomes a decision on approval; say so to
change one.

- **P1. Trove's own column names only.** No synonyms (`Price`, `Cost`,
  `Serial`), and the header must be the first row. Matching ignores case,
  outer spaces and the star. Guessing at other names is the mapping screen
  by another route.
- **P2. The star is written `Name *`** — a space, then the star.
- **P3. The same column twice refuses the file.**
- **P4. Slash dates need a four-digit year.** `3/9/26` stays unreadable:
  reading it means guessing the century. One order is settled for the
  whole file, not per column.
- **P5. A totals row may also be labelled** — `Total`, `Totals`,
  `Subtotal` or `Sum` in the Name cell — and may sit anywhere, so
  per-group subtotals are left out too. Your answer covered the unnamed
  row in your sheet; a labelled one would otherwise import as an item
  called "Total".
- **P6. `#N/A` counts as `N/A`; `NA`, `none` and `-` do not.**
- **P7. Something that isn't a code in the Trove ID cell** makes the row
  a new item, counted — not a skipped row.
- **P8. A matching row with an empty Name** updates the rest and keeps
  the name, rather than being skipped as nameless.
- **P9. The confirmation gives counts, not a list of what will change in
  each item**, and adds "Updates can't be undone." It may become a sheet
  instead of an alert if an alert can't hold it.
- **P10. Export keeps writing plain numbers and `yyyy-MM-dd`.** It does
  not start writing `$3,179.95` or `5/1/2025` to look like your sheet;
  Sheets can format the columns, and the importer reads either.
- **P11. Changing an item's Reverb product or year from a sheet** is an
  ordinary update: the item is re-matched and its figure is fetched fresh
  at the next refresh.
- **P12. Your real sheet is not committed.** The repository is public and
  the file holds serial numbers, so the test file copies its shape with
  invented rows, and your own file is tried by you at the walkthrough
  (criterion 2).
- **P13. No protection against a spreadsheet stripping leading zeros.**
  Open an export in Sheets and `0185654` may become `185654`; re-import
  and the item's serial number is updated to match, because the cell is
  filled and different. The reference doc warns to format that column as
  plain text. (The alternative — treating a serial number that differs
  only by lost leading zeros as unchanged — is a guess about your data,
  and is left out unless you want it.)

## Non-goals (explicit)

- **A column-mapping screen**, and synonyms for column names.
- **Matching by name**, or any duplicate detection for rows without a
  Trove ID.
- **Deleting by omission**, and any other delete through import.
- **Clearing a field from a sheet.**
- **Marking sold or un-selling from a sheet**; sell plans in a file.
- **A per-item preview of changes**, and **undo** of an import.
- **European number formats, two-digit years, title rows above the
  header.**
- **`.xlsx`, Numbers files, or a live Google Sheets connection** — CSV
  files, moved by hand.
- **Photos in a file.**
- **Showing the Trove ID in the app.**

## Inherited caveats

- **A spreadsheet can damage a file before Trove sees it**, and now that
  a re-import updates, the damage is written onto real items rather than
  onto new copies: leading zeros stripped from serial numbers, long digit
  strings turned into scientific notation. See P13.
- **Dates are calendar days in the phone's time zone** (`011`).
- **The append-only growth rule** (`011`) is kept — `Trove ID` is appended
  last — but its reason changes: position no longer matters to the reader,
  only to files being read by eye.
- **Importing before sync has finished** can add what another device
  already has.
