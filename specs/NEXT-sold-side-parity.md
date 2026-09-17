# Carried out of 006 for the next spec (2026-09-16, the person's request after the merge)

Product asks, verbatim in substance, not yet specced:

1. **A visible Mark as sold button on the item detail page**, in addition to
   (or instead of) the "…" menu row. Reverses `006` spec Decision 4's
   placement.
2. **A Mark as sold action on the leading swipe of Items rows.** Reverses
   `006` Decision 4 and criterion 1 ("the Items list's swipe stays
   delete-only").
3. **The Sold side of the Items tab gains the search bar, the category
   chips, and the Sort By selector**, matching the Owned side. Sort By's
   "Date" option becomes **"Date sold"** there; the remaining options
   should make sense for sold items (the person's words: "the rest of the
   options in the sort by filter should make sense given the context").
   Reverses `006` P16 ("no filtering or grouping on the Sold side") and
   touches Q15/G33 (switching sides clears the narrowing) and the CSV's
   narrowing rule (Q5).

What exists to build on: `ItemListViewModel.side`/`show(_:)`, `narrowed(_:)`
applied to both halves for the CSV, `areInSoldOrder`, `SortPicker`'s
option set, `SideSwitch`, `SoldItemRow`. Open product questions a spec
session should settle: which sort options apply on the Sold side (name,
date sold, sale price, gain/loss?); whether a narrowing carries across the
switch or clears; whether the leading swipe's action opens the sheet
directly.
