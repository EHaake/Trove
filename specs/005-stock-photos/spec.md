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

- Any item **without a photo of the person's own** — owned or wanted
  (Decisions 3, 6) — offers a **Find a photo…** action; that is a blank item
  *or* one whose only photo is a stock one, so a stock photo can be swapped for
  a different one in a single tap (P8). The action hides once the item has an
  owned photo. The feature is emphasised on the wishlist, where the blank is
  most common, but is not restricted to it: an owned item with no photo can
  borrow a stock image until the person takes their own.
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

All eleven verified at T016's close-out (2026-09-13), with the two honest
partials named where they fall: the second-device sync check (criterion 4) and
the dual-licensed GFDL + CC-BY-SA file the device pass never met (criterion 2).

1. [x] An item with **no photo of the person's own** — owned or wanted, and
   whether it is blank or holds only a stock photo (Decision 6) — shows **Find
   a photo…**; an item that has an **owned** photo does not. The first **Find a
   photo…** in
   the app shows the one-time notice; **Not now** searches nothing; **Continue**
   searches and the notice never shows again on that device.
    *Verified by*: the gate — `PhotoSelectionCanFindPhotoTests`
    (`falseWhenADevicePhotoIsPresent`, `trueForAnEmptySet`,
    `trueForAStockOnlySet`) and `canFindPhotoFollowsTheOwnedPhotoRule` in all
    four hosting view models (`ItemDetailPhotoTests`,
    `WishlistDetailPhotoTests`, `ItemFormPhotoTests`, `WishlistFormPhotoTests`);
    the notice — the same four suites'
    `findPhotoShowsTheNoticeFirstAndContinueHandsToThePicker`,
    `findPhotoGoesStraightToThePickerWhenAlreadyAcknowledged` and
    `declineLeavesTheFlagFalseAndClosesTheSheet`, over
    `PhotoNoticeStoreTests` for the flag itself (`aFreshStoreHasNotAcknowledged`,
    `acknowledgingSetsTheFlag`,
    `asecondStoreOverTheSameDefaultsSeesTheAcknowledgement` — plan G10). On
    screen: `testAnItemWithNoPhotoOffersFindAPhoto` and
    `testTheFirstFindAPhotoShowsTheNoticeAndNotNowClosesIt`. On the device
    (T015): the notice shown once, **Not now** searching nothing (the
    `searchPhotos` probe empty before and after, and demonstrably live —
    the next action wrote to it), **Continue** firing exactly one search, no
    notice on a second item in the same launch, and the acknowledgement
    surviving relaunches. *Partial*: the acknowledgement that survived the
    relaunch was set in an earlier session, so what the device showed is the
    flag's persistence, not a Continue-then-relaunch in one sitting; the
    Continue → written flag half is the unit suites'.
2. [x] Searching sends **only the item's name** to Wikimedia Commons; the
   picker shows candidate images from Wikimedia Commons, each with its author
   and licence; **only** CC-BY, CC-BY-SA or public-domain / CC0 images are
   offered. A search with no usable results shows the empty state and stores
   nothing.
    *Verified by*: what is sent — `WikimediaPhotoServiceTests.searchSendsOnlyTheNameBesideTheFixedParams`
    (plan G5), `punctuationInTheNameSurvivesTheRoundTrip`,
    `everyRequestCarriesTheUserAgentAndNeverAnAuthorization`; the licence set —
    `WikimediaDecodingTests.onlyReusableFilesSurviveTheMixedResponse` and
    `theClassifierAcceptsReusableAndRejectsTheRest` (G2, the falsifiable
    classifier table added at T003's review); the credit each candidate carries
    — `theAttributionIsStrippedOfHTMLAndCarriesTheLicenceAndSource`,
    `aFileWithNoArtistFallsBackToWikimediaCommons`,
    `commonsPlaceholderAuthorFallsBackToWikimediaCommons` (T015a) and
    `PhotoPickerWiringTests.theCandidateComposesStockPhotoCredit`; the cap —
    `twentyReusableFilesAreCappedToTwelve` (G4); the relevance filter Decision 7
    added — `WikimediaRelevanceTests` (G13); the empty state —
    `PhotoFetchViewModelTests.noCandidatesBecomesTheEmptyPhaseCarryingTheTrimmedQuery`
    and `aBlankQueryReachesNothingAndLeavesTheSheetIdle`, storing nothing by
    construction (only a pick calls `store`). On the device (T015): six Nikon F3
    candidates, each credited, every licence CC-BY, CC-BY-SA or public domain;
    the empty state on a name nothing matches and on "Hasselblad X2D 100C ii".
    *Partial*: no **dual-licensed GFDL + CC-BY-SA** file turned up in the three
    live searches, so plan §3/Q4's "offered, credited by its CC-BY-SA licence"
    path is still unexercised — no fixture can settle it, since it depends on
    the `License` code the live API returns.
3. [x] Picking a candidate stores it on the item as a `Photo` with
   `source = .fetched`; it shows on the detail screen and, when the item has no
   owned photo, as the item's list-row thumbnail; it is **visibly marked as a
   stock image** and its **credit** (author, licence, link to the Commons file
   page) shows wherever it appears.
    *Verified by*: the store — `aStoredPickLandsOneFetchedPhotoOnASecondContext`
    (`ItemDetailPhotoTests`, `WishlistDetailPhotoTests`) and
    `aStoredPickLandsOneFetchedPhotoInPhotos` (`ItemFormPhotoTests`,
    `WishlistFormPhotoTests`), over `PhotoAttributionTests`
    (`theFetchedBuilderSetsSourceToFetched`, `aDevicePhotoHasNoAttribution`,
    `aFetchedPhotoRoundTripsItsAttributionThroughASecondContext`); the detail —
    `PhotoCarouselTests.theBadgeShowsOnlyForAFetchedCurrentPhoto` and
    `theCreditShowsOnlyForAFetchedCurrentPhoto`; the mark and credit themselves
    — `StockPhotoBadgeTests` (`theCreditComposesALinkNotAButton`,
    `theCreditLinksOnlyItsSourceRunAndKeepsTheWholeAuthor`,
    `theCreditReadsItsStringsFromCopy`, `theBadgeReadsItsStringsFromCopy`,
    `theBadgeUppercasesByStyleNotByString`, `theNoAuthorFallbackComposes`) and
    `StockPhotoCreditGlyphTests` (T015c); the row —
    `RowThumbnailTests.theStockMarkRidesAStockLeadingRowButNotAnOwnedLeadingOne`
    over `PhotoSelectionLeadsWithStockTests`. On the device (T015): the stored
    photo on the detail with **STOCK PHOTO** and its credit, the same photo as
    the wishlist row's thumbnail with the corner mark, and the credit's link
    opening *File:Nikon F3.jpg* on Commons.
4. [x] A fetched photo **syncs** to the person's other devices like an owned
   photo — its bytes and its attribution both — and shows there; the market
   figures' no-sync rule does not apply to it.
    *Verified by*: `CloudKitSchemaTests` — the three new `Photo` fields validate
    against a real CloudKit `ModelConfiguration` (plan G1: a field declared
    non-optional without a default turns it red), which is what makes them
    syncable at all; `PhotoAttributionTests.aFetchedPhotoRoundTripsItsAttributionThroughASecondContext`
    for the bytes and the attribution travelling together; the policy half in
    `PrivacyPolicyTests.thePolicyNamesWikimediaCommonsAndStatesThatAFetchedPhotoSyncs`.
    A fetched photo is an ordinary `Photo` row on the synced default store — the
    same path `001`'s owned photos take, unchanged by this spec. *Partial, and
    the honest one*: **a second device was not available**, so nobody has
    watched a fetched photo arrive on one. This criterion rests on the schema
    test and on the shared owned-photo path, not on an observation.
5. [x] Adding an owned photo to an item that already has a stock photo
   **prompts** the person to **Keep both** or **Replace**; **Replace** removes
   the fetched photo, **Keep both** retains both with the **owned photo
   leading**.
    *Verified by*: `PhotoSelectionReplaceKeepTests`
    (`promptsWhenAddingToASetWithAStockPhoto`,
    `doesNotPromptWithNoStockPhotoPresent`, `doesNotPromptWhenThereIsNothingToAdd`,
    `replaceLeavesExactlyOneDevicePhotoAndNoStock`, `theReplacedStockPhotoIsOrphaned`,
    `keepBothLeadsWithTheDevicePhotoAndTrailsWithTheStock`,
    `keepBothNumbersTheResultFromZero` — G9); the wiring —
    `PhotoPickerFieldTests.drawsTheAlertFromStockPhotoCopy` and
    `consultsPhotoSelectionForTheDecisionAndTheOutcomes`; the words —
    `StockPhotoCopyTests.theReplaceKeepAlert`. On the device (T015): both
    outcomes taken — **Keep both** giving PHOTOS 2 with the owned photo leading
    (page 1 unbadged, the stock photo page 2 badged and credited) and
    **Replace** leaving PHOTOS 1, the owned one.
6. [x] An item holds at most one fetched photo; fetching again replaces the
   previous fetched photo; a fetched photo can be removed like any photo.
    *Verified by*: `PhotoSelectionAddingFetchedTests` (`keepsAtMostOneFetchedPhoto`
    — G8, `ownedPhotosLeadTheFetchedOne`, `theReplacedFetchedPhotoIsOrphaned`,
    `numbersTheResultFromZero`) and
    `storingASecondStockPhotoReplacesTheFirstWithNoLeakedBlob` in both detail
    suites. Removal is unchanged from `001` — a fetched photo is a `Photo` row
    in the same strip, and `001`'s photo-removal suites are untouched and green.
    On the device (T015): a second pick left PHOTOS at 1 with the new credit,
    and the fetched photo was removed from the edit strip like any other.
7. [x] Offline or a failed search shows the failure copy and stores nothing;
   a stock photo the item already has is untouched.
    *Verified by*: the service's error mapping —
    `WikimediaPhotoServiceTests.offlineIsUnreachable`, `aFiveHundredIsAServerError`,
    `anOversizeImageIsImageTooLarge`, `aForeignHostImageURLIsNotFetched` (G7);
    the sheet — `PhotoFetchViewModelTests.anErrorBecomesTheFailedPhase`,
    `anErrorThatIsNotAStockPhotoErrorReadsAsFailed`, `aFailedDownloadReturnsNil`;
    nothing stored — `aFailedDownloadStoresNothing` in both detail suites; the
    words — `StockPhotoCopyTests.theFailureCopy`. On the device, by the person
    (2026-09-12, Network Link Conditioner at 100 % loss): "Couldn't reach
    Wikimedia Commons. Try again in a while." with **Search again**, and the
    item still showing NO PHOTOS — nothing stored.
8. [x] A fetched photo **appears in the PDF export** with its credit; the CSV
   export is unaffected.
    *Verified by*: `PDFComposerStockTests` — the credit reaches the page
    (`aFetchedLeadingPhotoCarriesItsCreditAndDrawsIt`), the snapshot carries the
    leading photo's attribution (`theRecordSnapshotCarriesTheLeadingPhotosAttribution`),
    an owned photo draws no credit (`aDevicePhotoEntryCarriesNoCreditAndDrawsNone`,
    `keepingBothDrawsTheOwnedPhotoWithNoCredit` — G11) and a photo deleted
    between snapshot and render draws neither photo nor credit
    (`aCreditWhosePhotoVanishedMidExportDrawsNeitherCreditNorAuthor`, added at
    T016 for plan §7's untested sentence). CSV: nothing in this spec touches the
    schema — `011`'s CSV suites are unchanged and green, and the device pass's
    export carried the same fourteen-column header with no photo column. On the
    device (T015): a two-page PDF with the stock photo drawn in its box and the
    full credit beneath it.
9. [x] `PRIVACY.md` names Wikimedia Commons as a second outside service, states
   that a photo search sends the item's name and only on the person's action,
   states that a fetched photo (unlike the market figures) syncs, and no longer
   reads in a way that a fetched, stored image would contradict; the one-time
   notice's words match the policy.
    *Verified by*: `PrivacyPolicyTests` —
    `thePolicyQuotesTheStockPhotoNoticeVerbatim` (G12),
    `thePolicyNamesWikimediaCommonsAndStatesThatAFetchedPhotoSyncs` (the
    retention row and the iCloud sentence pinned whole),
    `thePolicyNamesEveryRowOfTheRetentionTable` (the two new rows),
    `thePolicyCarriesTheStockPhotoContactAddress`, `thePolicyCarriesNoPlaceholder`
    and `theStockPhotoLinkPointsAtTheSameExistingFile` — the last one made
    falsifiable at T016 by asserting the linked name resolves to a file that
    opens "# Trove — Privacy Policy" (the same repair applied to `002`'s
    `theLinkedURLEndsInTheFilename`); the notice's own wording in
    `StockPhotoCopyTests.theNoticeStrings` and
    `theNoticeReassemblesToTheSpecsSentence`. The "images travel in one
    direction only" rewording carries no guard, as plan §8 said it would not
    (Phase 4 review note 3).
10. [x] The app never fetches a photo on launch, on appear, or in the
    background — only **Find a photo…** does.
    *Verified by*: instrumentation, not inference (CLAUDE.md's Testing rule — a
    `.task` inside sheet content is invisible to the view-model suite). T015's
    temporary file probe inside `WikimediaPhotoService.searchPhotos` recorded
    **seven firings across three launches, one per deliberate action**, and zero
    on launch, appear, tab switch, sheet re-render, picker scroll, return from
    Safari, **Not now**, **Cancel** or the Keep/Replace prompt. In the suites:
    `PhotoFetchViewModelTests.theSeedDrivesTheSearchVerbatim`,
    `aBlankQueryReachesNothingAndLeavesTheSheetIdle` and
    `aSecondSearchWhileOneIsRunningIsIgnored`; nothing searches before Continue
    (`declineLeavesTheFlagFalseAndClosesTheSheet` in all four hosting suites);
    and no test in `TroveTests` opens a connection at all.
11. [x] VoiceOver: the **Find a photo…** action, each picker candidate, the
    stock badge and the credit line are labelled; a stock photo is announced as
    a representative image with its credit, not as the person's own; the
    Wikimedia link says it leaves the app.
    *Verified by*: `StockPhotoBadgeTests.theLinkSaysItLeavesTheApp`,
    `theCreditReadsItsStringsFromCopy`, `theBadgeReadsItsStringsFromCopy`;
    `RowStockA11yTests.itemRowAnnouncesTheStockThumbnailFromTheSharedSources`
    and `wishlistRowAnnouncesTheStockThumbnailFromTheSharedSources` (the row
    announces a *representative image*, from the same copy source);
    `StockPhotoCopyTests.theAccessibilityStrings`;
    `PhotoPickerWiringTests.theIdentifiersArePresent`. On the device, by the
    person (Xcode's Accessibility Inspector, 2026-09-13): the credit is **one
    element**, Label "Photo: Wikimedia Commons · CC BY-SA 3.0 · Wikimedia
    Commons", Traits **Button, Link**, Hint "Opens Wikimedia Commons in your
    browser", and **Activate** opened the Commons file page — so plan §6's
    recorded fallback was not needed. *Partial*: that inspector session settled
    the credit, the hardest case; the action's, the candidates' and the badge's
    labels rest on the copy and wiring tests above and on the sighted device
    pass, not on a second inspector run over each.

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

Added 2026-09-09, at the plan draft's return (the person, resolving the
planner's one product question):

6. **Find a photo… gates on an *owned* photo, not any photo.** The action
   shows whenever the item has no photo the person took — a blank item or one
   whose only photo is a stock one — so a stock photo is replaced by a fresh
   **Find a photo…** (P8), and it hides once an owned photo exists. The Draft's
   criterion 1 read "an item that already has a photo does not", which
   contradicted P5/P8; that wording is corrected here. (Chosen over the strict
   "any photo hides it" reading, which would force removing a stock photo
   before re-searching.)

Added 2026-09-10, from the person's Phase 3 device testing (the person's
call after Claude Code's live-API research):

7. **Offer photos *of* the item, not photos taken *with* it (v1, filter-only).**
   Wikimedia's text search matches a camera/lens model in the metadata of
   photos *taken with* that gear, which crowds out — and for very specific
   names entirely buries — actual product shots. Confirmed by live testing: a
   search for "Canon R5" returns real photos of the camera, but a portrait shot
   on a Hasselblad X2D comes back for "Hasselblad X2D" too. The reliable
   distinguisher is Wikimedia's structured **"Taken with …"** category: a
   product shot of the R5 was itself taken with a *different* camera (so it
   survives), while a portrait taken on the X2D sits in "Taken with Hasselblad
   X2D 100C" (so it is dropped). The picker therefore **filters out any
   candidate categorized as taken with the same make/model the person
   searched.** The query still sends the item's name and nothing else — **P1 is
   unchanged** — so this is a client-side relevance filter, not a change to what
   leaves the device.
   - **Filter-only for v1 (the person's explicit scope).** *Broadening* an
     over-specific name (trimming "…100C ii" → "X2D" so the good files are
     returned at all) is **out of scope** and deferred. A consequence the
     person accepted: a name so specific that Wikimedia returns *no* product
     shot (the motivating "Hasselblad X2D 100C ii" case) still shows the empty
     state — the filter can only reorder/prune what search returns, not conjure
     files it never returned. The eBay follow-up (roadmap) remains the real fix
     for brand-new gear with thin Wikimedia coverage.

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
