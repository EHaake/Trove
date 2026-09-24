# Sync checks — one pass, later

This is every sync, two-device, offline and signed-in check that no spec has
run yet, from all specs, in one place. The person asked for it on 2026-09-23:
"gather all untested sync tests in one place (from all specs) so we can do
them in one pass later once I have the ability." Each step is tagged with its
spec and criterion (or task), and each ends with where its result goes, so
nothing has to be looked up during the pass.

## What you need

- **Two devices, A and B, signed into the same iCloud account.** Two
  simulators work if both are signed in. Both need the same Trove build
  unless a step says otherwise.
- **Network Link Conditioner** on device A: Settings → Developer → Network
  Link Conditioner, profile **100% Loss**. "Offline" below means that
  profile is on. (Airplane mode also works on a real device.)
- **Two builds of Trove:**
  - **the old build**: `8124f12`, which is `main` before `009`, so sell plans
    are not yet stored;
  - **the new build**: current `main`.
  Parts 1–3 install the old build first and then upgrade over it, because
  several checks are about what happens to data from before `009`.
- About an hour of wall-clock time between steps 1.3's setup and 1.3 itself
  (a market figure has to be over an hour old before Refresh will run).

## How to record a result

For each step:

1. Tick its box here and write the date and one word after it: **passed**,
   **failed** (what you saw instead), or **not reached** (why).
2. Then do what its **Record** line says. That means ticking the criterion in
   the spec it names, or replacing the named "untested / partial" sentence with
   what you saw and the date, for example "done (the person, 2026-10-02)".
   Don't delete the old sentence. Say it is done, the way `006`'s were marked.
3. A step marked **bug to observe** is a known defect or a suspected one. If
   you see it, it goes on a `fix/` branch of its own, per `CLAUDE.md`. Write
   what you saw under the bug's own line, and don't fix it during the pass.

## Before you start — set up both devices on the old build

- Install the **old build** on A and B, both signed in and online. On A,
  make this wishlist, and wait until it shows on B:
  - **W1** "Summicron 35mm": open its Sell Plan and set aside one owned
    item.
  - **W2** "Vox AC15": set aside an owned item, then mark it sold from the
    Sell Plan.
  - **W3** "Hasselblad 80mm": set aside an owned item, mark it sold, then
    mark W3 bought.
  - **W4** "Rode NT5": nothing.
  - **W5** "Nikon FM2": nothing (used for the offline purchase).
- On A, match one owned item to Reverb and refresh it, so it has a market
  figure. Note the time; step 1.3 needs that figure to be over an hour old.

## Part 1 — one device, offline (device A)

Turn Link Conditioner to **100% Loss** on A. Leave B alone.

- [ ] **1.1 — What a signed-in device does when it launches offline.**
  `009` plan Q2 window 1 · **bug to observe** `001` tasks.md:1071.
  **Do**: install the **new build** on A over the old one, and open it while
  still offline. Go to Settings and read the iCloud row. Then open the Plans
  tab.
  **You should see** one of two things. Write down which:
  - (a) the iCloud row says **"iCloud isn't available"**, and the Plans tab
    already lists W1 and W2 on Active and W3 on Completed. That means setup
    finished *failed* and the carry-over ran on this device's copy while
    offline. This is window 1, and it is real.
  - (b) the iCloud row says **"Catching up with iCloud"** and **stays that
    way** for as long as you're offline. That means setup succeeded with no
    network, and the carry-over is correctly waiting. It is also `001`'s
    recorded bug: the copy says data "is on its way" when nothing is coming.
  **Record**: `009` — in `specs/009-sell-plan-list/plan.md`, *As built →
  What is untested*, the Q2 bullet's window 1; and in `DECISIONS.md`, "Sell
  plans as things you create", the "once" entry's **Its limits** paragraph.
  `001` — if you saw (b), write it under the `.working`-forever bullet in
  `specs/001-core-inventory/tasks.md` (line 1071) as observed, with the date.

- [ ] **1.2 — An empty Plans side while plans are waiting.** `009` plan R7 /
  Q10 · criterion 16.
  **Do**: only if 1.1 was (b). Still offline, look at both sides of the Plans
  tab.
  **You should see**: **"Catching up with iCloud"**, not "No sell plans
  yet", on the Active side, because W1 and W2 are waiting to carry over.
  **Record**: `specs/009-sell-plan-list/spec.md`, criterion 16: replace
  "**Not observed**: the offline 'Catching up with iCloud'…" with what you
  saw. If 1.1 was (a), mark this step **not reached** and say why.

- [ ] **1.3 — Market figure offline.** `002` criterion 11.
  **Do**: still offline, open the owned item you matched to Reverb (its
  figure must be over an hour old) and tap Refresh.
  **You should see**: **"Couldn't reach Reverb. The figure below is from …"**,
  with the old median, spread, count and age still shown and nothing cleared.
  **Record**: `specs/002-live-market-value/spec.md`, criterion 11: replace
  "T018: Link Conditioner was not used — *partial*" with the result.

- [ ] **1.4 — Buying something needs no network.** `015` criterion 14.
  **Do**: still offline, swipe W5 on the Wishlist, tap Buy, and confirm the
  purchase.
  **You should see**: the purchase complete exactly as it does online, with no
  error and no waiting. W5 leaves the Wishlist and appears on Items. (This
  observes that nothing waits on a connection. It doesn't prove none was
  tried.)
  **Record**: `specs/015-mark-as-bought/spec.md`, criterion 14 (already
  ticked by inspection): add the observation and the date.

Turn Link Conditioner **off** on A.

## Part 2 — one device, back online (device A)

- [ ] **2.1 — Old plans carry over once iCloud catches up.** `009`
  criterion 4, the iCloud path.
  **Do**: quit A and reopen it, now online. Watch the Plans tab for a minute.
  **You should see**: a brief "Catching up with iCloud", then W1 ("1 item set
  aside") and W2 ("1 sold toward it") on Active, and W3 on Completed ("1 was
  sold toward it"). W4 appears on neither side. W5 appears on neither side,
  because it was bought with no plan. If 1.1 was (a), the plans were
  already there: write that down.
  **Record**: `specs/009-sell-plan-list/spec.md`, criterion 4: replace the
  "**Stated plainly**: … its timing against real synced data is sync
  untested" sentence with the result.

- [ ] **2.2 — The iCloud row when caught up.** `013` criterion 9.
  **Do**: open Settings on A.
  **You should see**: **"Syncing with iCloud" / "This device has your
  collection."**
  **Record**: `specs/013-settings-menu/spec.md`, the verification record for
  criterion 9 (around line 809): replace "caught-up and catching-up need a
  signed-in device" with what you saw (and 3.9's result).

## Part 3 — two devices, both online

A is on the new build. **B is still on the old build.**

- [ ] **3.1 — An older app editing a row keeps the new fields.** `009` plan
  Q2 window 3 (second half).
  **Do**: on B (old build), open W1 and edit its notes, then save. Wait for
  it to reach A.
  **You should see**: on A, W1 still on Active with its plan, and its page
  still reading "View your sell plan". The old app's edit didn't wipe the
  plan.
  **Record**: `009` plan.md *As built → What is untested*, Q2 window 3, and
  the matching sentence in `DECISIONS.md` ("whether an app older than `009`
  editing a row keeps fields it doesn't know").

- [ ] **3.2 — Plans carried over on one device, seen on the other.** `009`
  criterion 17 (sync half, part 1).
  **Do**: install the **new build** on B over the old one and open it
  online. Wait for the Plans tab to settle.
  **You should see**: the same plans as A, on the same sides, and W1's
  set-aside count the same as on A. Nothing appears twice, and W4 and W5 are
  on neither side.
  **Record**: with 3.3, `specs/009-sell-plan-list/spec.md` criterion 17.
  Tick it once 3.2 and 3.3 both pass, and replace "**What has not been
  done**…" with the result.

- [ ] **3.3 — A plan made, sold through and deleted on one device.** `009`
  criterion 17 (sync half, part 2).
  **Do**: on A, open W4 and tap **Create a sell plan**, then set aside an owned
  item. Check B. On A, mark that item sold from the Sell Plan. Check B. On
  A, delete W4's plan from its row's swipe. Check B.
  **You should see** on B, in turn: W4 on Active reading "1 item set aside";
  then "1 sold toward it"; then W4 gone from the Plans tab, its page offering
  **Create a sell plan**, and the sold item still on Items → Sold.
  **Record**: as 3.2.

- [ ] **3.4 — A purchase leaves the wanted item on both devices.** `015`
  criterion 12.
  **Do**: first, on A, give W1 a photo (Edit → add a photo from the library)
  and wait for it on B. Then on A, swipe W1 on the Wishlist → Buy → confirm.
  **You should see** on B: W1 gone from the Wishlist, and a "Summicron 35mm"
  item on Items carrying the photo.
  **Record**: `specs/015-mark-as-bought/spec.md`, criterion 12. Tick it, and
  replace "**What has not been done: the two-device sync check.**" with the
  result. Also update `specs/ROADMAP.md`'s `015` status row ("one honest
  partial named").

- [ ] **3.5 — A completed plan's picture on the other device.** `009`
  criterion 20 (sync half).
  **Do**: after 3.4, open the Plans tab's Completed side on B.
  **You should see**: W1 on Completed, its row showing **W1's photo** (the
  bought item's picture), not the grey placeholder.
  **Record**: `specs/009-sell-plan-list/spec.md`, criterion 20. Tick it and
  replace "**Unticked — sync untested…**" with the result.

- [ ] **3.6 — A stock photo on the other device.** `005` criterion 4.
  **Do**: on A, open an owned item with no photo, tap **Find a photo…**, and
  pick one.
  **You should see** on B: the same photo on that item, with the **STOCK
  PHOTO** badge and the credit (photographer, licence, link) under it.
  **Record**: `specs/005-stock-photos/spec.md`, criterion 4: replace
  "*Partial, and the honest one*: **a second device was not available**…"
  with the result.

- [ ] **3.7 — A Reverb match on the other device, and no history with it.**
  `002` criteria 3 and 12.
  **Do**: on A, match a second owned item to Reverb (Find on Reverb… → pick
  → close the value step). Wait for it on B, then open that item on B.
  **You should see**: on B the item is **matched to the same product**
  (criterion 3), but B shows **none of A's figures or history**: no median
  and no trend arrow; its Market section reads **"Not refreshed on this
  device."** rather than showing A's numbers (criterion 12). The figures stay on the device that fetched them.
  **Record**: `specs/002-live-market-value/spec.md`, criteria 3 and 12:
  replace each "*Partial*: … second device …" sentence with the result.

- [ ] **3.8 — Changing a match on the other device (known gap N1).** `002`
  plan N1 · **bug to observe**.
  **Do**: on B, change that same item's match to a different Reverb
  product. Wait for it on A. On A, open the item, and also look at the
  Dashboard's Market line.
  **You may see the bug**: A still shows the **old product's title and
  median** as current, and its Refresh is disabled for up to an hour. It
  should correct itself after A's next refresh.
  **Record**: `specs/002-live-market-value/plan.md`, the *Known gap … (N1)*
  paragraph: write what you saw and the date. If seen, it is the `fix/`
  branch that paragraph already calls for.

- [ ] **3.9 — The iCloud row while catching up.** `013` criterion 9.
  **Do**: delete Trove from B and install the new build again, then open
  Settings straight away.
  **You should see**: **"Catching up with iCloud" / "Your collection is on
  its way to this device."** while the collection downloads, then **"Syncing
  with iCloud"**.
  **Record**: with 2.2, `specs/013-settings-menu/spec.md` criterion 9's
  record.

- [ ] **3.10 — Delete all sell plans on one device.** `009` criterion 22
  (sync half).
  **Do**: on A, make sure there are plans (create one on W2 if needed). Open
  Settings → **Delete All Sell Plans…** → Delete All.
  **You should see** on B: both Plans sides empty ("No sell plans yet" /
  "Nothing completed yet"), with every wanted item, owned item and sale still
  there, and each wanted item's page offering **Create a sell plan**.
  **Record**: `specs/009-sell-plan-list/spec.md`, criterion 22. Tick it once
  4.1 also passes, and replace "**Unticked — sync untested…**" with the
  result.

## Part 4 — long absence and conflicts

- [ ] **4.1 — A plan made on one device while the other deletes all.**
  `009` plan RA2's window.
  **Do**: turn B **offline**. On B, open W4 and **Create a sell plan**. On A
  (online), create a plan on W2 and then run **Delete All Sell Plans…**. The
  alert's count should include W2 but **not** B's W4. Delete. Then bring B
  back online and wait.
  **You should see**: B's W4 plan survives, and after the sync it appears on
  A's Active side. W2's plan is gone on both devices.
  **Record**: `009` plan.md *As built → What is untested* (RA2's window) and
  `DECISIONS.md`, the "Delete all sell plans" entry. It also counts toward
  criterion 22 (3.10).

- [ ] **4.2 — A long absence.** `009` plan Q2 window 2 (a first import in
  several passes).
  **Do**: delete Trove from B and install the **old build**. Let it download
  the collection, then add a wanted item **W6** with one owned item set
  aside. Wait for W6 to reach A, where it carries over as a plan. On A, delete
  W6's plan. Now turn B off, or keep it offline, for as long as practical
  (ideally a day). Meanwhile on A, import a large CSV (for example
  `docs/samples/items-full.csv`) so there is a lot for B to catch up on. Then
  install the **new build** on B and open it online.
  **You should see**: W6 with **no plan** on either device, including after
  B has fully caught up. A plan deleted on A must not come back from B's old
  copy.
  **Record**: `009` plan.md *As built → What is untested*, Q2 window 2, and
  `DECISIONS.md`'s "Its limits" paragraph.

- [ ] **4.3 — A carried row meets a deletion made elsewhere.** `009` plan Q2
  window 3 (first half).
  **Do**: as in 4.2's setup: B on the **old build**, a new wanted item **W7**
  with an item set aside, synced to A. Put B **offline**. On A, W7 carries
  over as a plan; delete W7's plan on A. Now install the **new build** on B
  and open it **offline**. If 1.1 was (a), B carries W7 over on its old copy.
  Then bring B online and wait for both devices to settle.
  **You should see**: which write CloudKit keeps. The good outcome is W7
  with **no plan** on both devices. Write down whatever you see.
  **Record**: `009` plan.md *As built → What is untested*, Q2 window 3, and
  `DECISIONS.md`'s "Its limits" paragraph.

## Any time — one signed-out device

- [ ] **5.1 — A signed-out device stuck on "Catching up".** `001`
  tasks.md:1064 · **bug to observe** (a theory, never seen).
  **Do**: on a device **signed out** of iCloud, quit and reopen Trove ten
  times. Each time, look at the Items tab when it's empty (or at Settings'
  iCloud row).
  **You should see** every time: **"iCloud isn't available"**, never
  "Catching up with iCloud" for the whole launch. If it ever sticks, the bug
  is real: `SyncMonitor` missed the setup event posted before it started
  listening.
  **Record**: `specs/001-core-inventory/tasks.md`, under the bullet at line
  1064: observed or not, with the date and how many launches.

## Steps per spec

`009` — 11 (1.1, 1.2, 2.1, 3.1, 3.2, 3.3, 3.5, 3.10, 4.1, 4.2, 4.3) ·
`002` — 3 (1.3, 3.7 covering criteria 3 and 12, 3.8) · `013` — 2 (2.2,
3.9) · `015` — 2 (1.4, 3.4) · `005` — 1 (3.6) · `001` — 2 bugs to observe
(1.1's second reading, 5.1).

## Already done — nothing to run

- **`001` T048** (`specs/001-core-inventory/tasks.md`:674): an item added on
  one device appears on the other. Observed.
- **`001` T055** (`specs/001-core-inventory/tasks.md`:924): "Catching up
  with iCloud" shows during a real sync window on a signed-in device.
  Observed.
- **`005` criterion 7** (`specs/005-stock-photos/spec.md`:365): offline, the
  failure copy and nothing stored. Done (the person, 2026-09-12, Network Link
  Conditioner at 100 % loss).
- **`006` criterion 15** (`specs/006-mark-as-sold/spec.md`:572): marking sold
  and returning to the collection both synced across two iCloud devices.
  Done (the person, 2026-09-16), with criterion 16's Accessibility Inspector
  pass the same day. Several lines still called both steps pending, and they
  were marked "done (the person, 2026-09-16)" on 2026-09-23, not deleted:
  - `specs/006-mark-as-sold/spec.md`: the criteria block's opening paragraph
    (~317) and criterion 15's "Nobody had watched a sale arrive…" (~587);
  - `specs/006-mark-as-sold/tasks.md`: the Status line (3), T019's
    **[person]** step (~1078), the **[person]** note (~1104), and the
    close-out's last line (~1157);
  - `specs/006-mark-as-sold/plan.md`: "**Still the person's**" (~987);
  - `specs/006-mark-as-sold/PAUSE-phase5.md`: the "Remaining" line (~5–6);
  - `specs/ROADMAP.md`: the `006` status row's "two honest partials named".
