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

`swift profile.swift out.mp4 <x> <y> <w> <h> <from> <to> bg [spanThr]`
— the mass is each pixel's RGB distance (0–441) from the box's own
top-left pixel on that frame instead of "how brass", so a glass capsule's
rim and fill register. Each frame then answers plan §1's "whole on every
frame" with the capsule and the label told apart by **colour**: a label
pixel is brass (R − B > 40, the brass mode's own test); a capsule pixel
differs from the background by more than `spanThr` (default 10) and is
not brass. The capsule's **extent** is its first and last capsule column
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
  that pixel is itself a differing pixel.
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
