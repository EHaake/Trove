# Motion probe

Two throwaway-grade Swift scripts kept from `006`/T018b (2026-09-15) for
checking an animation claim on the simulator, since a screenshot cannot
show motion and a centroid cannot tell a slide from a crossfade.

1. Record while driving the gesture from a temporary XCUITest:
   `xcrun simctl io <udid> recordVideo --codec h264 out.mp4`
2. `swift profile.swift out.mp4` — per-frame column profile of the
   masked colour (brass by default) in a region: total mass and the
   moving edge, with Δt between frames.
3. `swift analyze.swift out.mp4` — centroid per frame (a quick look; not
   a discriminator on its own).

Read Δt, not the nominal frame rate: `recordVideo` is variable-rate.
`ffmpeg` is not installed here; the scripts use `AVAssetReader`.

## Background-difference mode (`018` T002, plan Q14)

`swift profile.swift out.mp4 <x> <y> <w> <h> <from> <to> bg [spanThr [brass|light|dark]]`
— the mass is each pixel's RGB distance (0–441) from the box's own
top-left pixel on that frame instead of "how brass", so a glass capsule's
rim and fill register. Each frame then answers plan §1's "whole on every
frame" with the capsule and the label told apart by **colour**: a label
pixel is brass (R − B > 40, the brass mode's own test); a capsule pixel
differs from the background by more than `spanThr` (default 10), is not
brass, **and is not within 1 px (8-neighbour) of a brass pixel** — the
label's anti-aliased fringe is differing-and-not-brass, and until `018`
T009 added that exclusion a label standing past the rim carried its own
fringe with it, so the measured capsule grew to cover it and `TEAR` could
not fire (plan §1 As built). The label's colour class is the last argument:
`brass` (the default, R − B > 40) for a tinted label, `light` / `dark` for
the system glass button's own label since Decision 18 (near-neutral, every
channel above 200 / below 70 — white in Dark, near-black in Light on both
runtimes; the fill and the rim's grey highlight never reach either). The
capsule's **extent** is its first and last capsule column
anywhere in the box; `runs=` lists the mid-line's capsule runs (a 3-px
band, gaps of ≤ 2 px closed) as information; `label=` is the brass
columns in a ±2 pt band about the mid-line and `out=` how many of them
lie beyond the extent — past the rim, which is T029c's tear. Verdicts:
`EMPTY` (no capsule, no label — the box is bare for ~0.1–0.2 s while
iOS 26's menu morph is between the panel and the badge), `LABEL-ONLY`
(brass but no capsule), `whole`, `TEAR`.

What T002's film taught, so the next one needn't relearn it:

- **Calibrate before reading a verdict**: on a settled frame the extent
  must match the badge's XCUITest frame within a point (Date 39.3–108,
  Market ↓ 13–108 in a box at x = 220). On iOS 27.0 it does (within
  0.7 pt, Dark at `spanThr` 10, Light at 20). On iOS 26.5 the settled
  extent *disagrees* with the frame after a menu-driven relabel — that
  disagreement is T002's finding, not an instrument fault: the glass
  keeps the previous label's width.
- Colour, not brightness, separates label from capsule. Two earlier
  drafts could not fail: a brightness band read the morphing droplet's
  grey rim highlight as "label", and an extent taken from *all*
  differing pixels always contained a label pixel past the rim, because
  that pixel is itself a differing pixel. A third (T002–T008) still
  could not: the label's 1-px anti-aliased fringe is differing and not
  brass, so it was the outermost "capsule" column whenever the label
  stood past the rim. T009 excludes any pixel within 1 px of brass. Shown
  on T002's iOS 26.5 Light film, frames 918–945 (Date → Market ↓ with the
  label past the rim): `TEAR` on 6 of 28 frames at `spanThr` 4 and 20 of
  28 at 8, where the unchanged probe said `whole` on all 28. On T002's
  26.5 Dark frames 819–864 the same switch reads `whole` even so, and
  honestly: there the label ends *on* the rim column (label 26.3–94.7
  inside a capsule 24.7–94.7; rim lines at rows 18–20 and 100–102 of the
  box), so nothing is past it — T002's Dark finding was the settled
  extent disagreeing with XCUITest's frame (25–95 against 13–108), which
  the calibration column carries, not `out=`. A glyph touching the rim is
  not counted as `TEAR`; read the extent against the frame for that.
  Compression ringing (4–16 of 441, up to ~7 px from a glyph, inside the
  label's own rows) reads as capsule at `spanThr` 4 in Dark; it never
  reaches past the label, so it cannot produce `TEAR` on its own, but it
  is why a bare label's extent is never `none` at that threshold. On the
  T003 clean films (same switch, Date → Market ↓, 3.5 s after the tap)
  the changed probe reads `whole`/`EMPTY` only: 0 `TEAR` in Dark and
  Light at `spanThr` 4 and 8.
- **On the finished header (T009)** the box is (226, 81, 112 × 46) on
  iOS 27.0 and (216, 81, 112 × 46) on 26.5 — the badge sits 10 pt further
  left there because the glass "…" circle reads 46 wide against 36 —
  which keeps T002's mapping (Date 39.3–108, Market ↓ 13–108, Date sold
  6.3–108, Name 39.3–108). Thresholds: 27.0 Dark 10 / Light 20; 26.5 Dark
  4; 26.5 Light **24** — lower and the "…" circle's drop shadow (it
  reaches the box's right margin) and the badge's own shadow read as
  capsule; 32 and the capsule's right rim flickers below it. On 26.5
  Light the right end still reads 112 after Market ↓ → Date, because the
  wider capsule's shadow stays behind the narrow one until the next tap
  (T002's Light frame 1183, still there); read the left end and the
  frame column for that state.
- The extent is taken over the box's full height, not the mid-line: on
  iOS 26.5 the fill and the side rims sit within 2 of the background on
  the mid-line in both appearances; only the top and bottom rim lines
  register (4–8, six pixels off it). `spanThr` 4 sees them.
- `spanThr` needs ~20 in Light on iOS 27.0, where the header's
  background is not flat against the corner pixel (6–15 across the box)
  while the fill sits at 25–50.
- Give the box a few points of margin round the badge so the corner
  pixel is background, not capsule; the menu panel covers the box while
  open, so those frames read as an extent from 0 with no label.
- The film's clock runs ~2 s ahead of a wall clock taken after
  `recordVideo` starts, and `recordVideo` emits a frame only when
  something changes; locate a tap by its effect, not its timestamp.
