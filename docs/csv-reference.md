# Trove CSV Reference

Trove exports and imports the same two CSV layouts — one for owned
items, one for the wishlist. A file Trove exported imports back
losslessly, and a file you build by hand imports as long as it uses
the exact columns below. The easiest way to start one is **⋯ →
Settings → Templates** on either list screen, which hands you a file
with the right header row already in place.

Import never modifies or deletes anything you already have: every
accepted row becomes a **new** entry, appended to the end of your
custom order in the file's own row order. Importing the same file
twice creates two copies of everything in it — the confirmation
step's count is the guard against doing that by accident.

## The files

| | Items | Wishlist |
|---|---|---|
| Export filename | `Trove-Items-YYYY-MM-DD.csv` | `Trove-Wishlist-YYYY-MM-DD.csv` |
| Template filename | `Trove-Items-Template.csv` | `Trove-Wishlist-Template.csv` |
| Columns | 12 | 7 |

Encoding is UTF-8. Trove writes a byte-order mark and CRLF line
endings for Excel's sake; on import both are optional, and any
standard CSV quoting works. Each screen imports its own kind — a
wishlist file offered to the Items screen is recognized and the
alert points you to the right screen.

## Items columns

The header row must contain exactly these names, in this order.

| # | Column | Format | If blank | If unreadable |
|---|--------|--------|----------|---------------|
| 1 | `Name` | text | **row skipped** | — |
| 2 | `Category` | slash path, e.g. `Music/Guitars/Electric` | uncategorized | — any text is a valid path |
| 3 | `Purchase Price` | plain number, e.g. `1250.00` or `1250` | `0.00` † | `0.00` † |
| 4 | `Currency` | 3-letter code, e.g. `USD` | `USD` | `USD` † |
| 5 | `Purchase Date` | `2026-03-09` (`yyyy-MM-dd`) | today † | today † |
| 6 | `Purchase Location` | text | empty | — |
| 7 | `Current Value` | plain number | **not yet valued** (not zero) | not yet valued † |
| 8 | `Desire to Keep` | whole number `1`–`5` | `3` † | `3` † |
| 9 | `Condition` | `new` / `excellent` / `good` / `fair` / `broken` (any casing) | `excellent` † | `excellent` † |
| 10 | `Condition Notes` | text | empty | — |
| 11 | `Serial Number` | text | empty | — |
| 12 | `Notes` | text, line breaks fine inside quotes | empty | — |

† counted and shown in the confirmation as a field that will use a
default. Blank optional fields (and a blank currency) import
silently — empty is a legitimate value there. A blank `Current
Value` means "not yet valued," which Trove treats differently from
worth zero.

## Wishlist columns

| # | Column | Format | If blank | If unreadable |
|---|--------|--------|----------|---------------|
| 1 | `Name` | text | **row skipped** | — |
| 2 | `Category` | slash path | uncategorized | — |
| 3 | `Estimated Cost` | plain number | `0.00` † | `0.00` † |
| 4 | `Currency` | 3-letter code | `USD` | `USD` † |
| 5 | `Desire to Own` | whole number `1`–`3` | `2` † | `2` † |
| 6 | `Added` | `yyyy-MM-dd` — becomes the wish's creation date | today † | today † |
| 7 | `Notes` | text | empty | — |

## Rows that are skipped

Exactly two things skip a row, and both are reported with the row
number your spreadsheet shows (the header is row 1):

- **No name** — after trimming whitespace, the Name cell is empty. A
  nameless item is not an item.
- **More columns than the template** — extra *content* beyond the
  last column. A stray comma shifts every later field one place, and
  there's no safe guess about which one you meant. Fix the row at
  the source and re-import.

Rows with *fewer* columns are fine — missing trailing cells count as
blank. Wholly blank lines are ignored silently. The confirmation
lists the first five skipped rows with reasons, then "and N more."

## Field formats, precisely

- **Money** is a plain number with an optional dot and one or two
  decimal places: `1250.00`, `1250.5`, `1250`. No currency symbols,
  no thousands separators, no negative amounts — `$1,250.00` will
  not read, and the field falls back to its default (counted). If a
  spreadsheet keeps reformatting the column, format it as *plain
  text* or *number without grouping* before saving.
- **Dates** are exactly `yyyy-MM-dd` — `2026-03-09`, zero-padded.
  Anything else (including a date your spreadsheet "helpfully"
  rewrote as `3/9/26`) falls back to today, counted. Dates are read
  as calendar days in your current time zone.
- **Condition** matches its five words in any casing.
- **Currency** is any three letters, stored uppercased. Trove's v1
  displays everything as USD; the code is kept with the item.

## What fails the whole file

These stop the import entirely — nothing is imported, and the alert
says so:

- The header row doesn't match the template (missing, renamed,
  extra, or reordered columns).
- The file isn't UTF-8 text (see the Excel note below).
- An unclosed quote — one runaway `"` swallows the rest of the file,
  so there is nothing safe to salvage.
- The file can't be read at all, or is implausibly large for an
  inventory.

## Excel and Numbers caveats

- **Excel's plain "CSV" save is not UTF-8** on Windows — it writes
  your system's legacy encoding, and any accented character or emoji
  makes the file unreadable to Trove. Use **"CSV UTF-8
  (Comma delimited)"** when saving. Numbers exports UTF-8 already.
- **Excel rewrites date cells** into your locale's format the moment
  it decides a column is dates. If your dates arrive as `3/9/26`
  instead of `2026-03-09`, format the column as text before typing,
  or fix the cells before saving.
- **Long serial numbers get mangled** by Excel's default file-open,
  which coerces long digit strings into scientific notation. Use
  Excel's text-import path (Data → From Text/CSV) when *opening* a
  Trove export, or don't re-save after just looking.
- Files re-saved by Numbers, Excel, or Google Sheets often pick up
  trailing empty columns or blank lines. That's fine — Trove strips
  them before reading.

## The recommended loop

Migrating a spreadsheet in: **⋯ → Settings → Templates**, open it in
your spreadsheet app, fill a row per item (only Name is required —
everything else has a sensible default or can stay blank), save as
CSV (UTF-8), then **⋯ → Import from CSV** and confirm. Nothing is
written until you confirm, and the confirmation tells you exactly
what will be skipped or defaulted first.

Ready-made files for trying all of this — the happy path, a
skip-and-report file, a spreadsheet-damaged file that still imports,
and the whole-file failures — live in [`samples/`](samples/README.md),
each pinned to its documented behavior by a test.

The full contract behind this document — byte-level framing, the
append-only schema growth rule, and every recorded decision — lives
in `specs/011-data-export/plan.md` ("The canonical CSV schema") and
`specs/012-data-import/spec.md`.
