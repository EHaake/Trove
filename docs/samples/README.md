# Sample CSVs

Hands-on files for trying the import (⋯ → **Import from CSV…** on the
Items or Wishlist screen). Get them onto a device via AirDrop or
iCloud Drive; on a simulator, drop them into Files. Every claim below
is pinned by `TroveTests/DocsSampleTests.swift`, which runs each file
through the production import pipeline — if a sample stops doing what
this table says, the suite goes red.

| File | Import on | What happens |
|---|---|---|
| `items-full.csv` | Items | The happy path: 12 items, every field filled. "Import 12 items? No problems found." |
| `items-partial.csv` | Items | Skip-and-report: **5 import**, rows 5 and 7 are skipped (no name; an extra comma), and **6 fields fall back to defaults** (blank price, an unparseable date, desire `9`, condition `mint`, a truncated row). The confirmation itemizes all of it before anything is written. |
| `items-resaved.csv` | Items | Transport tolerance: the shape a spreadsheet re-save leaves behind — no BOM, LF endings, trailing empty columns, blank lines between rows. Imports 5 items with no complaints. |
| `wishlist.csv` | Wishlist | A valid wishlist file: 4 wants, with their original **Added** dates restored. Offered to the **Items** screen instead, it demonstrates wrong-list detection: "This looks like a Wishlist export." |
| `bad-headers.csv` | Items | Whole-file failure: the first column is renamed (`Item Name`), so the header gate rejects it — nothing is imported. |
| `bad-unclosed-quote.csv` | Items | Whole-file failure: a runaway `"` swallows the rest of the file, so the import refuses rather than guessing. |
| `bad-encoding.csv` | Items | Whole-file failure: the file is Latin-1, not UTF-8 (what Windows Excel's plain "CSV" save produces) — the alert points at Excel's "CSV UTF-8" option. |

The one whole-file failure with no sample is the oversized-file guard
(~10 MB) — committing a file that size to demonstrate it would be its
own kind of bad row.

Column formats, defaults, and caveats: [`../csv-reference.md`](../csv-reference.md).
