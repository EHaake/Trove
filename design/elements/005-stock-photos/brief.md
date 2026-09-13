# Trove `005` — Stock photos: the Design pass brief

This is the prompt for the `/design` pass spec `005` asks for (spec's
"Design requirements", the `002` Decision 10 pattern). The person runs
it; Claude Code wrote it from the approved `spec.md`, `plan.md` §6,
`StockPhotoCopy.swift`, `design/brief.md` and `design/tokens.md`.
Everything below the line is the prompt. Paste it whole, attach the
context files it names, iterate in the canvas, and drop the exports back
into this folder as `.dc.html` plus a PNG per artboard — the `002`
layout (`design/elements/002-market-values/`).

Two rules for the pass itself, from the plan (T006):

- **The copy is fixed.** Every string is listed here and lives in
  `StockPhotoCopy.swift`. If the design wants a word this list doesn't
  have, that is a spec question — flag it in the export, don't invent
  it; Claude Code escalates it, never absorbs it. (Two small functional
  strings — the search-field placeholder and the "searching…" status —
  are noted below as **proposed** Wikimedia analogs of `002`'s; draw
  them with the proposed text, and they'll be pinned in `StockPhotoCopy`
  at the picker's implementation, or flagged if you'd word them
  differently.)
- **Values come back as tokens.** `design/tokens.md` gains a "Stock
  photos (`005`)" section sourced from the artboards, one row per
  property, so read the existing tables there as the vocabulary to
  design in.

---

## The prompt

You are designing two new surfaces for **Trove**, a personal gear
inventory app for hobbyists — cameras and lenses, guitars and amps,
audiophile gear. The person tracks what they own and what they paid,
what they want to buy next, and sells underused gear to fund the next
purchase. The app is shipped and has an established visual language;
this pass extends it, it does not restyle anything.

Read these first, in this order:

1. `design/brief.md` — the direction and the rules. Non-negotiable
   ones: dark-first; flat and graphic with **restrained alpha-based
   depth only** (the `010` "extruded plate"); **no rendered materials**
   — no metallic gradients, wood, leather, glass; **bespoke inside the
   page, system in the bars** — nothing drawn inside a page's content
   is a system control; plain, direct voice.
2. `design/tokens.md` — the exact palette, type and spacing. Design in
   these values; add tokens only where a property genuinely has no
   existing one. The tables you will lean on most: **"Market section,
   candidate picker, dashboard variant (`002`)"** — the candidate picker
   there is the sheet whose *shape* this pass reuses; **"Item detail
   (`010` refresh)"** and **"Wishlist detail (`010` refresh)"** — the
   screens the badge and credit sit on; the **row treatment** and
   **corner radii** tables.
3. The shipped screens the surfaces join, for context:
   `design/screens/Trove Item Detail.png`,
   `design/screens/Trove Wishlist Detail.png`,
   `design/screens/Trove Item List.png`,
   `design/screens/Trove Wishlist List.png`; and the existing candidate
   picker for the sheet shape and the notice:
   `design/elements/002-market-values/PickerNotice.png`,
   `PickerResults.png`, `PickerEmpty.png`, `PickerFailed.png`,
   `PickerSearching.png`.

### The feature, in one paragraph

An item with **no photo of the person's own** — a wishlist item that
can't be photographed, or an owned item they haven't shot yet — can be
given a **representative photo** fetched from **Wikimedia Commons**
(a free-media library). The person taps **Find a photo…**, the app
searches by the item's name and shows a small set of freely-licensed
candidate images, and the person picks one. The picked image is stored
like a photo they took — it syncs, it shows offline — but it is always
**visibly marked as a stock photo** and **credited** to its author and
licence, so it is never mistaken for the person's own. It stands in only
until the person adds their own photo. This is the app's second outside
source after Reverb, and it reuses Reverb's posture exactly: on demand
only, a one-time privacy notice, a candidate picker.

### Palette and type, restated

Colors: `background #17181A`, `surface #201F1D`, `surfaceInset #26272A`,
`divider #3A3B3E`; ivory text `#F2EDE4` at 100 / 75 / 60 / 55 / 45 /
40 / 35 / 30 % (`textPrimary`, `textBody`, `textLabel`,
`textLabelSecondary`, `textMonoMeta`, `textQuiet`, `textDisabled`,
`textInactive`); `accentBrass #C79A56` (money, CTAs, external links),
`accentBrassTint rgba(199,154,86,0.12)`, `accentBrassDim #746140`;
`accentMoss #52634F` shapes / `accentMossText #7E9679` text; `accentRust
#9C4A34` shapes / `accentRustText #B8674F` text. Rust and moss as *text*
must use the `Text` lifts — the base values fail contrast on `surface`.

Type: Archivo 600 for display and hero figures; IBM Plex Sans 400/500/
600 for body; IBM Plex Mono 400/500 for money, dates, counts and every
all-caps label (tracked 0.06–0.16em).

Cards: `surface`, `3px` radius, the plate shadow set (`inset 0 1px 0
rgba(242,237,228,0.055)`, `inset 0 -1px 0 rgba(0,0,0,0.4)`, `0 2px 6px
rgba(0,0,0,0.25)`). Thumbnails `2px` radius over `surfaceInset` with
`RowThumbnail`'s hairline photo-glyph placeholder. Chips are fully
rounded (`999`). Screen gutter `24px`.

Buttons in the page are Trove's own: filled brass primary, outlined
brass secondary, text buttons where the `010`/`002` screens use them.
The one external-link convention: brass text + an SF `arrow.up.right`
glyph means "opens in the browser, leaves the app" (`002`'s
`View on Reverb`).

---

## Surface 1 — the candidate picker (a sheet)

Opened by **Find a photo…**. One sheet with two phases; draw both, on a
wishlist detail as the backdrop (a wishlist item is the common case — it
has no photo). **Reuse `002`'s candidate-picker sheet shape** (the
`background` fill, the `12px` top radius, the `36×5` grabber, the medium/
large detents, the system Cancel/title bar) — do not redesign the sheet
chrome. What is genuinely new here is **Phase B's image-first grid**;
spend the effort there.

**Phase A — the one-time notice** (shown only the first time on a device,
before any search). This is `002`'s notice sheet exactly, only the words
change — same medium detent (~`300px`), same `22 / 24 / 32` padding, the
link **under** the paragraph (a SwiftUI `Link` can't flow inside `Text`),
the same stacked `48pt` buttons with an `8px` gap, swipe-down = Not now:

> Finding a photo sends this item's name to Wikimedia Commons — nothing
> else about it. The photo you pick is stored on your device and syncs
> with your other devices, like a photo you take.

"See the privacy policy" is a brass link under the paragraph. Two
buttons: **Continue** (filled brass) and **Not now** (outlined).

**Phase B — the picker** (the large detent, ~`780px`). Title
**Choose a photo**; a **Cancel** action in the sheet's bar; a search
field seeded with the item's name (the shared `SearchField`, `40pt`,
searching on submit only — proposed placeholder **Search Wikimedia
Commons** when the field is cleared); a status line (proposed
**Searching Wikimedia Commons…**, IBM Plex Mono `11.5px` `textQuiet`
with the `12px` brass arc spinner — `002`'s status-line pattern) while a
search runs.

Then the **image-first grid** — this is the new surface, and the design
decision that matters. Unlike `002`'s picker (text-first cards, because
Reverb variants differ by a title suffix), here **the photo is the
choice**: the person is judging whether the image *looks like their
gear*, so the image must be large and legible, the credit secondary but
always present. Design an **image-first grid or list** — your call, but
argue it:

- The images come from Wikimedia and **vary wildly** in aspect ratio,
  background and quality (a white-background product shot, a photo of the
  gear in a room, a detail crop). Decide how to normalise them into a
  tidy grid — a **square crop** (`aspectRatio(contentMode: .fill)`
  clipped to a square, `2px` radius over `surfaceInset`, the
  `RowThumbnail` placeholder while it loads) is the likely answer, but
  show what you chose and why. The cell is tappable; the whole image is
  the target.
- Under each image, a **compact credit**: the author and the licence
  (e.g. `Jane Doe · CC BY-SA 4.0`, or `Wikimedia Commons · Public
  domain` when the file names no author). IBM Plex Sans/Mono in a quiet
  register — legible, never competing with the image, truncating
  gracefully on a long author. (The *full* linked credit — with the
  "Wikimedia Commons" link — lives on the detail screen, Surface 2, not
  in the grid.)
- Show **up to a dozen** candidates in a scrolling grid (the app fetches
  up to 12). Draw a realistic grid of **8–12** varied gear photos so the
  density and the wrapping read true — mix cameras, a guitar, a hi-fi
  component; mix aspect ratios and one or two that are clearly "not quite
  the right thing" (the person is choosing among imperfect matches).
- A **tapped cell downloads then stores** — draw the **downloading
  state** (the tapped cell shows a small brass arc spinner over a dimmed
  image; the rest of the grid stays put). One tap → download → the sheet
  closes → the photo is on the item.

Also draw the two no-result states with Trove's `EmptyStateView` pattern
(a `34px` light glyph at ivory 30 %, an Archivo 600 `19px` headline, an
optional quiet detail, an outlined action) — a statement, no apology:

- **Empty** (the search found nothing usable — a common outcome, since
  Wikimedia's gear coverage is uneven): headline **No usable photos
  found for that name.** and the outlined **Search again** action. If you
  want a hint line beneath (the `002` empty state has one), propose its
  words — that's a copy flag, don't invent it into the artboard as final.
- **Failure** (offline or the search failed): **Couldn't reach Wikimedia
  Commons. Try again in a while.** with the outlined **Search again**
  action.

Sample data to draw with: a wishlist **Leica M6** (camera; several
white-background and in-use shots, one clearly a different Leica); a
**Fender Telecaster** (guitar; a couple of good matches); a **Rega
Planar 3** turntable (one decent shot, one that's the wrong model). Vary
the credits: real author names, one `Wikimedia Commons · Public domain`,
licences `CC BY-SA 4.0`, `CC BY 2.0`, `CC0`.

## Surface 2 — the stock-photo presentation (detail screen + list row)

How a stored stock photo is **marked and credited** wherever it appears.
Two placements; design both.

**On the detail screen** (both kinds — draw it on the item detail; the
wishlist detail is the same treatment). The fetched photo shows where the
person's photos show today (the detail screen's photo/hero area — see the
shipped `Trove Item Detail.png`). It carries:

- a **Stock photo** badge — a small **capsule chip** (fully rounded,
  `999`) marking the image as representative, over the photo. It must
  read clearly over *any* image (a light product shot or a dark room
  photo), so give it its own ground — a solid or scrim-backed chip, in
  the app's own type and tokens (IBM Plex Mono `monoLabel` all-caps is
  the app's chip idiom; or a small sans label — your call, but pick from
  the existing type roles). **No rendered materials**, no glass. Decide
  its corner (over the image), padding, ground and text tone, and its
  contrast floor over both a light and a dark photo (draw it over both).
- a **credit line** beneath the photo: **Photo: {author} · {licence} ·
  Wikimedia Commons**, where **Wikimedia Commons** is a brass external
  link (the `arrow.up.right` "leaves the app" convention — it opens the
  Commons file page in the browser). The separators are the app's middle
  dot `·`. Example lines to set:
  `Photo: Jane Doe · CC BY-SA 4.0 · Wikimedia Commons` and, for an
  author-less file, `Photo: Wikimedia Commons · Public domain ·
  Wikimedia Commons`. Choose the type register (a quiet secondary line,
  in the `textLabelSecondary`/`textMonoMeta` family — it must not
  compete with the screen's hero figures) and how it wraps on a long
  author + licence.

Draw the case that matters most for a wishlist item: **the stock photo
is the item's only image**, so it is the hero of the photo area, badged
and credited. Also show, briefly, an **owned photo leading with a kept
stock photo following** (Decision 4a: when both exist the owned photo
leads and is un-badged; the stock photo follows, still badged and
credited) — enough to show the badge only ever sits on the fetched image,
never on an owned one.

**On the list row.** The row thumbnail (see `Trove Wishlist List.png` /
`Trove Item List.png`) shows the item's leading photo. When that leading
photo is the stock one (the common wishlist case — no owned photo), a
**small Stock-photo mark** overlays the thumbnail so the list reads at a
glance which rows carry a representative image versus the person's own.
The thumbnail is small (`~44–56px` in the rows), so the mark must be
tiny and legible — a corner glyph or a miniature of the badge; decide the
form and draw a wishlist list with a mix of stock-photo rows and one
owned-photo row (no mark) so the distinction reads.

### Not designed in this pass

- The **replace / keep** prompt (when the person adds their own photo to
  an item that already has a stock photo) is a **standard system alert**
  — "This item has a stock photo. Keep it, or replace it with your
  photo?" with **Keep both** / **Replace**. A bespoke surface isn't
  warranted for a two-choice question (the app's "system in the bars"
  rule); don't draw it.
- The **Find a photo…** action itself joins the detail/form screens in
  their existing action style — no new component.
- The **PhotosPicker** and the person's own photo flow are unchanged.

## Accessibility to hold in mind (not drawn, but the design must allow it)

- The badge is announced as **"Representative stock image"**; a stock
  photo is announced as a representative image with its credit, never as
  the person's own. Leave the badge room to be its own labelled element.
- The credit's Wikimedia link says it **leaves the app** ("Opens
  Wikimedia Commons in your browser"). Keep it a real, separately
  focusable link, distinct from the image.

## Deliverables

- `.dc.html` artboards (one canvas holding both surfaces is fine), each
  state on its own artboard, at iPhone width, dark:
  - picker: **notice**, **searching**, **results grid**, a **downloading
    cell**, **empty**, **failure**;
  - presentation: **detail with a stock-photo hero (badge + credit)**,
    **detail with an owned photo leading + a kept stock photo**, a
    **list with stock-photo rows and one owned-photo row**, and the
    **badge over a light photo and over a dark photo**.
- A PNG per artboard.
- Any property this brief leaves open, stated as a value (size, weight,
  color token, spacing, the badge's ground and contrast, the grid's
  column count and cell size, the crop rule) so it can be written
  straight into `design/tokens.md`'s new "Stock photos (`005`)" section.
- Any copy you wanted and didn't have — the search placeholder wording,
  the "searching…" status, an empty-state hint — listed separately. It
  goes to the spec, not into the artboards as final.
