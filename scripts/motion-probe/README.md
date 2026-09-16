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
