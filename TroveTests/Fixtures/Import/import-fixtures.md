# Import layout fixtures

`items-020-layout.csv` and `wishlist-020-layout.csv` are byte copies of
`docs/samples/items-full.csv` and `docs/samples/wishlist.csv` as `020`
shipped them — the 19-column items layout and the 10-column wishlist
layout, before `021` added the `Trove ID` column. They are the evidence
that a file an earlier Trove exported still imports (`ImportLayoutTests`),
so they must never be edited or regenerated. A later layout gets its own
fixture beside them.
