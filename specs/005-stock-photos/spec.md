# 005 — Stock Photos

**Status**: **Approved** (2026-09-09) — the person approved the Draft and
directed planning to proceed in this session, at Opus under the Fallback
clause (below), rather than in a fresh session, since the top tier is
unavailable and the model rationale for splitting the session is therefore
moot.

Authored in-session (the fourth use of the per-spec venue clause). Run at
**Opus 4.8, high effort, under `CLAUDE.md`'s model-policy Fallback clause** —
Fable's budget was spent for this session, exactly as `004-themes` recorded
for its whole spec. Every product decision below was made by the person and is
listed in the Decisions record; a research pass into what image sources
actually offer opened the spec, because — as in `002` — the licensing reality
reshaped the feature before a single product question was worth asking.

**Depends on**: `001-core-inventory` (the `Photo` model and its
`PhotoSource` enum, whose `.fetched` case has sat unused since `001` for
exactly this feature; `Item`/`WishlistItem`; both forms; the detail screens;
the list rows' thumbnail), `011-data-export` (the PDF export a stock photo
appears in), and `013-settings-menu` (Settings › About, where the attribution
and the privacy-policy link live). It reuses three patterns `002` established
— the on-demand, never-in-the-background network posture; the one-time
privacy notice before the first outside request; and the candidate picker —
without depending on `002`'s code.

## Summary

Trove tracks gear you own and gear you want. Owned gear you photograph
yourself; a wishlist item — something you don't own yet — has no photo, so its
row and detail screen are blank where every owned item has an image. This
feature lets you **fetch a representative photo** for such an item from
Wikimedia Commons, on demand, and store it like any other photo — marked as a
stock image, credited to its author, so it is never mistaken for one of your
own. It is most useful for wishlist items, but available for any item that has
no photo yet.

## What and why

The roadmap's `005-stock-photos` entry is one line: "Auto-fetch a
representative photo for items you don't own yet." The research that opened
this spec (record at the end) found that the interesting constraint is not
*fetching* an image but *storing* it — because Trove's photo model, from
`001`, keeps image **bytes** in SwiftData (`@Attribute(.externalStorage)`) and
syncs them to the person's private iCloud database as CloudKit assets. A
fetched photo that behaves like a real photo — syncs across devices, shows
offline — has to be one the app is allowed to store, not just display.

That single constraint sorts the candidate sources:

- **Unsplash** forbids storing images: every display must hotlink the URLs it
  returns, with per-photo attribution and UTM links back. That fights sync and
  offline the way eBay's no-persistence rule fought a computed figure in `002`
  — the photo would be a URL that can rot, cannot sync, and cannot show without
  a connection. Its content is also artistic photography, weak at specific gear
  models.
- **Pexels** requires an API key, is silent-to-ambiguous on caching, forbids
  bulk/ML dataset use, and has the same artistic-not-product-shot problem.
- **Reverb's catalog image** — which the app already fetches at match time in
  `002`'s picker — is a perfect product shot of a matched music item, but
  Reverb's terms mirror Unsplash's: display with a link back, nothing stored
  beyond "reasonable periods." Hotlink-only, matched-music-only, non-syncing.
- **Wikimedia Commons** needs **no API key at all** — so no server secret and
  no hosted proxy, unlike the deferred eBay path — is reached over plain
  HTTPS/JSON (no third-party Swift package, so `CLAUDE.md`'s dependency rule is
  untouched), carries CC / public-domain licences that **permit reuse
  including local storage** with attribution, and holds real per-model photos
  (cameras are organised by model; guitars and hi-fi are decent but uneven).

So Wikimedia Commons is the one source whose terms actually allow what the
feature needs — the direct analogue of `002`'s Decision 1. Its cost is
**attribution**: CC-BY / CC-BY-SA require crediting the author, naming the
licence, and linking back wherever the image appears, so a fetched photo
carries that metadata and the app honours it — the same way `002` honours
Reverb's attribution line.

## Core behavior

### Finding a photo

- Any item **without a photo** — owned or wanted (Decision 3) — offers a
  **Find a photo…** action. The feature is emphasised on the wishlist, where
  the blank is most common, but is not restricted to it: an owned item with no
  photo can borrow a stock image until the person takes their own.
- The action is a deliberate, person-initiated act. The app never fetches a
  photo on launch, on appear, or in the background (Decision 5, the posture
  `002` set) — only this action does.
- The first **Find a photo…** in the app shows a **one-time notice** (Decision
  5): it says what is sent (the item's name), to whom (Wikimedia Commons), and
  that the privacy policy has the rest. **Not now** searches nothing;
  **Continue** searches and the notice never shows again on that device. This
  notice is its own, separate from `002`'s Reverb notice — a different service,
  a different acknowledgement.

### The picker

- Searching sends **the item's name and nothing else** (P1) to Wikimedia
  Commons and shows a **candidate picker**: a small set of matching images
  (P2), each with its thumbnail and its credit (author and licence). The
  person picks one.
- Only images whose Wikimedia licence **permits reuse with attribution**
  (CC-BY, CC-BY-SA, or public domain / CC0) are offered (P3); anything the app
  cannot lawfully store and display with a simple credit is filtered out
  before the picker.
- **No good results** shows a clear empty state — the search found nothing
  usable — and offers to search again with different words. It is not a
  failure; it stores nothing.
- Picking a candidate stores that image on the item.

### What is stored, and how it is marked

- A picked photo is stored as an ordinary `Photo` with **`source = .fetched`**
  and its **image bytes** on the device — so it syncs to the person's other
  devices and shows offline, exactly like a photo they took (Decision 5). The
  app stores a reasonably sized image, not a multi-megabyte original.
- Alongside the bytes the photo carries its **attribution** — the author, the
  licence, and a link to the Commons file page — which syncs with it, so the
  credit is present on every device (P4).
- A fetched photo is **visibly marked as a representative / stock image**
  wherever it appears — never presented as one of the person's own — and its
  **credit line** (author · licence, linking to Wikimedia Commons) shows with
  it (Decision 4; the licence's requirement).
- An item holds **at most one** fetched photo (P5); fetching again replaces it.
  A fetched photo can be **removed** like any photo.

### Owned photos and stock photos together

- When the person adds **their own photo** to an item that already has a stock
  photo, the app **asks** whether to **Replace** the stock photo (remove it) or
  **Keep** it (Decision 4a). It never decides silently.
- **Replace** removes the fetched photo and uses the owned one. **Keep**
  retains both; the **owned photo leads** — it is the item's thumbnail and its
  first image — and the stock photo follows, still marked and credited.
- Because a stock photo stands in only until the person has their own, an item
  that already has an owned photo does not offer **Find a photo…**; the action
  is for the blank case.

### Where it appears

- **List rows**: the fetched photo is the item's thumbnail when the item has no
  owned photo (the common wishlist case); an owned photo, when present, leads.
- **Detail screens** (both kinds): the fetched photo shows with its stock mark
  and its credit line; the credit's link opens the Commons file page in the
  browser.
- **PDF export** (`011`): a fetched photo **appears in the export**, with its
  credit (Decision 4b). The CSV export is unaffected — it carries no photos, as
  `011` settled.

### Offline and failure

- Searching needs a connection. Offline or a failed search shows a clear
  message and stores nothing; any stock photo the item already has is
  untouched (P8, the shape `002` used for a failed refresh).

## Attribution and licensing — what the terms require

Wikimedia Commons files are contributor-licensed, and the licence varies per
file. What the app must do, and does:

- **Offer only reusable images.** CC-BY, CC-BY-SA, and public-domain / CC0
  files are offered; anything else is filtered out (P3).
- **Credit every displayed image**: the author, the licence name, and a link
  back to the file page on Wikimedia Commons — in the picker, on the detail
  screen, and in the PDF export (Decision 4b).
- **Store the credit with the image**, so it travels with the photo and is
  never shown without it.
- **Share-alike (CC-BY-SA)**: displaying an **unmodified** image with its
  credit — in the app and placed alongside the person's own content in the PDF
  — is a *collection*, not an *adaptation*, so it does not put a share-alike
  obligation on the person's document. This is the spec's reading; it is
  flagged for the plan's skeptical review to confirm or tighten, the way `002`
  deferred the reading of Reverb's "reasonable periods" to planning
  (see Non-goals: the app never modifies a fetched image).

## Privacy — what leaves the device, and what is stored

- **What leaves**: an item's **name**, to Wikimedia Commons, only when the
  person taps **Find a photo…** and only after they have accepted the one-time
  notice. Nothing else about the item — not its category, price, condition,
  notes, nor any other photo — is sent (P1). Each request carries the app's
  name, version and contact address as its `User-Agent`, as `002`'s requests do.
- **What is stored, and whether it syncs**: a fetched photo's **bytes and its
  attribution are stored on the device and do sync** to the person's private
  iCloud database, like any photo — this is the person's data now, unlike
  `002`'s market figures, which deliberately do not sync. The one-time-notice
  acknowledgement is stored on the device and does not sync (as `002`'s does
  not).
- **`PRIVACY.md` is updated** (P6): Wikimedia Commons is named as a second
  outside service the app talks to, only on the person's action; the "what
  leaves your device" section gains the photo search; and the policy states
  that a fetched photo, unlike the market figures, does sync. The line "No
  image ever leaves the app" stays true — no image *leaves*; the app only
  fetches — but it is reworded so it cannot be misread now that the app fetches
  images and sends a search query.

## Copy

- The action: **Find a photo…** (on an item with no photo).
- The one-time notice: "Finding a photo sends this item's name to Wikimedia
  Commons — nothing else about it. The photo you pick is stored on your device
  and syncs with your other devices, like a photo you take. See the privacy
  policy." with **Continue** and **Not now**. (Final wording at the copy task,
  as `002`'s was — P7.)
- The picker title: **Choose a photo**; each candidate shows its image and its
  credit; the empty state: "No usable photos found for that name." with a
  **Search again** action.
- The stock mark and credit line: a short badge reading **Stock photo** (final
  word at the design pass — P7) and a credit "Photo: {author} · {licence} ·
  Wikimedia Commons", the last part a link.
- The replace/keep prompt (Decision 4a): "This item has a stock photo. Keep it,
  or replace it with your photo?" with **Keep both** and **Replace**.
- Failure: "Couldn't reach Wikimedia Commons. Try again in a while."
- Copy this spec doesn't fix — the exact badge word, the picker's finer strings
  — is proposed in `plan.md` and joins this section on plan approval, as `002`'s
  did.

## Design requirements

- A **Design pass, in-session with the `design` skill** (the pattern `002`'s
  Decision 10 set), for the two genuinely new surfaces: the **candidate
  picker** (an image-first grid or list with a credit under each — a designed
  choice, not a bare list of rows) and the **stock-photo presentation** on the
  detail screen and list row (the badge and the credit line, in the app's own
  type and tokens, no rendered materials). The design brief's rules apply.
- The **Find a photo…** action joins the forms / detail screens in their
  existing action style.
- The **replace / keep** prompt is a standard system alert — a bespoke surface
  is not warranted for a two-choice question (the app's "system in the bars,
  bespoke in the page" rule from `013`).
- Empty state and failure state are explicit, not afterthoughts — the empty
  "no usable photos" case is common, since Wikimedia coverage is uneven.
- Every action is a single tap; the credit's Wikimedia link opens the file page
  in the browser.

## Acceptance criteria

1. [ ] An item with **no photo** — owned or wanted — shows **Find a photo…**;
   an item that already has a photo does not. The first **Find a photo…** in
   the app shows the one-time notice; **Not now** searches nothing; **Continue**
   searches and the notice never shows again on that device.
2. [ ] Searching sends **only the item's name** to Wikimedia Commons; the
   picker shows candidate images from Wikimedia Commons, each with its author
   and licence; **only** CC-BY, CC-BY-SA or public-domain / CC0 images are
   offered. A search with no usable results shows the empty state and stores
   nothing.
3. [ ] Picking a candidate stores it on the item as a `Photo` with
   `source = .fetched`; it shows on the detail screen and, when the item has no
   owned photo, as the item's list-row thumbnail; it is **visibly marked as a
   stock image** and its **credit** (author, licence, link to the Commons file
   page) shows wherever it appears.
4. [ ] A fetched photo **syncs** to the person's other devices like an owned
   photo — its bytes and its attribution both — and shows there; the market
   figures' no-sync rule does not apply to it.
5. [ ] Adding an owned photo to an item that already has a stock photo
   **prompts** the person to **Keep both** or **Replace**; **Replace** removes
   the fetched photo, **Keep both** retains both with the **owned photo
   leading**.
6. [ ] An item holds at most one fetched photo; fetching again replaces the
   previous fetched photo; a fetched photo can be removed like any photo.
7. [ ] Offline or a failed search shows the failure copy and stores nothing;
   a stock photo the item already has is untouched.
8. [ ] A fetched photo **appears in the PDF export** with its credit; the CSV
   export is unaffected.
9. [ ] `PRIVACY.md` names Wikimedia Commons as a second outside service, states
   that a photo search sends the item's name and only on the person's action,
   states that a fetched photo (unlike the market figures) syncs, and no longer
   reads in a way that a fetched, stored image would contradict; the one-time
   notice's words match the policy.
10. [ ] The app never fetches a photo on launch, on appear, or in the
    background — only **Find a photo…** does.
11. [ ] VoiceOver: the **Find a photo…** action, each picker candidate, the
    stock badge and the credit line are labelled; a stock photo is announced as
    a representative image with its credit, not as the person's own; the
    Wikimedia link says it leaves the app.

## Decisions record

Made by the person, 2026-09-09, in this spec conversation:

1. **Wikimedia Commons, one source, for v1.** The only source whose terms
   permit storing and reusing the image with a simple credit — so a fetched
   photo can sync and show offline like a real photo — and the only one needing
   no API key or server secret. Unsplash, Pexels and reusing Reverb's catalog
   image are ruled out (the first two on the storage rule and their artistic
   content; Reverb's image on its hotlink-only, matched-music-only terms).
   Reusing Reverb's catalog image for matched music gear is noted as a possible
   later enhancement, not built now.
2. **A candidate picker, the person confirms.** Wikimedia search is noisy and
   the photo represents the item everywhere, so the app shows a small set of
   candidates and the person picks — never an automatic top-hit — and handles
   "nothing usable found" gracefully.
3. **Wishlist-emphasised, allowed on any item with no photo.** The core case is
   wishlist items that can't be photographed; an owned item with no photo may
   also borrow a stock image until the person takes their own.
4. **A stock photo is marked and credited, and appears in the export.** It is
   visibly a representative image wherever it shows, never mistaken for the
   person's own, and its author/licence credit travels with it — including in
   the PDF export (4b).
   - **4a. Replace or keep, the person's choice.** Adding an owned photo to an
     item that has a stock photo asks whether to replace the stock photo or
     keep both; kept, the owned photo leads.
   - **4b. Stock photos appear in the PDF export**, with their credit.
5. **On-demand only, with a one-time notice, and `PRIVACY.md` updated.** A
   photo search happens only when the person taps **Find a photo…** — never on
   launch, appear or in the background — a first-time notice states what is sent
   and to whom, and the privacy policy is updated to name Wikimedia Commons, the
   search query that leaves, and that a fetched photo (unlike the market
   figures) syncs.

Proposed at drafting, 2026-09-09, by Claude Code (these become decisions on
plan approval, as `002`'s P-items did):

- **P1. The search sends the item's name and nothing else** — the same posture
  as `002`'s search. The name is text the person can see and edit.
- **P2. The picker asks Wikimedia for a small set of candidates** (a handful,
  each shown whole with its credit); the exact count is a plan detail, tuned so
  a good match is usually on the list.
- **P3. Only reusable licences are offered** — CC-BY, CC-BY-SA, public domain /
  CC0. The app reads each file's licence from Wikimedia's metadata and filters
  out anything it cannot store and display with a plain credit.
- **P4. The attribution is stored on the photo and syncs with it** — author,
  licence name, and the Commons file-page link — so the credit is present on
  every device and never shown without its image.
- **P5. At most one fetched photo per item**; fetching again replaces it. A
  stock photo is a single representative placeholder, not a gallery.
- **P6. `PRIVACY.md` is updated in this spec**, on the branch, before the
  feature is considered done — Wikimedia named, the search query added to "what
  leaves your device", and the sync distinction stated.
- **P7. Copy this spec doesn't fix is settled at the copy/design tasks** — the
  badge word, the picker's finer strings, the final notice wording — and joins
  the Copy section on plan approval.
- **P8. A stored fetched image is not re-fetched or refreshed.** Once picked, it
  is the person's stored photo; there is no freshness rule, no re-fetch, no
  history — unlike `002`'s figures. Replacing it is a fresh, deliberate **Find a
  photo…**.

## Non-goals (explicit)

- **Any source but Wikimedia Commons in v1** — Unsplash, Pexels, Google/Bing
  image search, and reusing Reverb's catalog image are all out (Decision 1);
  the last is a noted later enhancement.
- **Automatic fetching** — no photo is ever fetched on launch, on appear, in
  the background, or without the person tapping **Find a photo…** (Decision 5).
- **Automatic picking** — the person always confirms a candidate (Decision 2).
- **A gallery of stock photos** — one representative photo per item (P5).
- **Editing, cropping, or otherwise modifying a fetched image** — it is stored
  and shown as Wikimedia serves it, which is what keeps it an unmodified
  *collection* rather than a share-alike-triggering *adaptation*.
- **Suggesting a category from a photo** — that is `007-auto-categorization`, a
  spec of its own.
- **Replacing or managing the person's own photos** — a stock photo stands in
  only while an item has none, and yields to an owned photo on the person's
  choice (Decision 4a); it never overrides or edits an owned photo.
- **A stock photo for an item that already has an owned photo** — the action is
  for the blank case (Decision 3).
- **Hotlinking, or any source that forbids storing the image** — the feature
  exists to give an item a photo that syncs and shows offline (Decision 1).
- **Sold-price or market data of any kind** — that is `002`; this spec is only
  the image.

## Inherited caveats

- `001`'s fixed type sizes apply to the new surfaces.
- The app is USD-only and single-region; nothing here changes that.
- `011`'s PDF export takes the fetched photo as it takes any photo; `011`'s
  append-only CSV schema is untouched (no photo columns).
- `013`'s Settings › About is where the attribution context and the
  privacy-policy link live; the app's "system in the bars, bespoke in the page"
  rule governs the new surfaces.

## Research record (2026-09-09)

A research pass into image sources preceded the product decisions; its findings
are what Decision 1 rests on. Developer and licence pages were read the same
day.

- **Wikimedia Commons.** The MediaWiki / Commons API answers **unauthenticated**
  — no API key — and returns, per file, the image and thumbnail URLs and, via
  `imageinfo`'s `extmetadata`, the author and the licence. Commons hosts only
  freely-licensed and public-domain media (unlike Wikipedia, which also holds
  non-free files under fair use), and reuse — including storing the file — is
  permitted with attribution: credit the author, name the licence, link to the
  licence or the file page. Coverage is contributor-driven: cameras are
  organised systematically by model; guitars, amps and hi-fi are present but
  uneven, so "no usable photo" is a normal outcome the UI must handle. Licences
  vary per file, so the app filters to the reusable ones (P3).
- **Unsplash.** Free photos, but the API terms require **hotlinking** the URLs
  it returns — "you cannot store images locally" — with per-photo attribution
  and UTM links back. Storing forbidden, so it cannot back a synced, offline
  photo. Content is artistic photography, weak on specific gear models.
- **Pexels.** Requires an API key; attribution expected; terms silent-to-
  ambiguous on caching and explicit that content may not be mined to build
  datasets or train ML at scale. Same artistic-not-product-shot limitation.
- **Reverb's catalog image.** Already fetched at match time in `002`. A true
  product shot for matched music gear, but Reverb's terms are hotlink-and-
  link-back with no storage beyond reasonable periods — so matched-music-only,
  non-syncing, transient. A candidate for a later enhancement, not v1.
- **Google / Bing image search and manufacturer sites.** Ruled out as `002`
  ruled out a crawler: arbitrary web images carry unknown copyright, the search
  APIs need a paid server secret, and scraping breaches written terms.
