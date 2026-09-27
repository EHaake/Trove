import AVFoundation
import CoreImage
import Foundation

// The column profile of the brass fill, frame by frame, for a range of
// frames. A *slide* is one contiguous plateau of the fill's width moving
// across; a *crossfade* is two plateaus at the fixed halves whose heights
// trade places. The centroid alone cannot tell them apart, which is why
// this exists.
//
// usage: swift profile.swift <video.mov> <xPt> <yPt> <wPt> <hPt> <fromIndex> <toIndex> [bg [spanThreshold [brass|light|dark]]]
//
// 018 T002 (plan Q14) — `bg`: background-difference mode. The mass is no
// longer "how brass" a pixel is but its RGB distance from the box's own
// top-left pixel on that frame (the header's background), so a glass
// capsule's rim and fill and a label in the system's colour register.
// Besides the profile, each frame reports the plan §1 measurement: at the
// box's vertical mid-line (a 3-px band), the *capsule* columns — distance
// above `spanThreshold` (default 10, of 0–441) and not brass — merged into
// runs, gaps of ≤ 2 px closed, and their extent; and, in a ±2 pt band
// about the same line, the *label* columns — brass, R − B > 40 — with
// `out=` counting those beyond the capsule's extent. Colour, not
// brightness, is what separates a brass label from a grey rim — a
// brightness band read the morphing droplet's rim highlight as "label" in
// T002's first pass. **018 T009:** a pixel within 1 px (8-neighbour) of a
// brass pixel is never a capsule pixel either — a label's anti-aliased
// fringe is differing-and-not-brass, and before this exclusion a label
// standing past the rim carried its own fringe with it, so the measured
// capsule grew to cover it and TEAR could not fire (plan §1 As built).
// The label's colour class is the optional last argument: `brass` (the
// default, R − B > 40) for a tinted label, or `light` / `dark` for the
// system glass button's own label since Decision 18 — near-neutral
// (max − min channel < 30) and every channel above 200 / below 70, which
// the fill (48 in Dark, 25–50 above a Light background) and the rim's
// grey highlight never reach.
// Verdicts: EMPTY — no capsule and no label on the mid-line (the box is
// bare while the morph is between the panel and the badge); LABEL-ONLY —
// brass in the band but no capsule column on the mid-line (the label drawn
// before its glass); whole — capsule present, no label pixel outside its
// extent; TEAR — `out=` label pixels past the rim. The run count is
// printed too: one on an opaque fill, many on iOS 26.5's see-through Dark
// fill. `spanThreshold` needs ~20 in Light, where the header background is
// not flat against the box's corner pixel (6–15 across the box) while the
// fill sits at 25–50. Give a box with a few points of margin around the
// badge so the corner pixel is background, not capsule.

let a = CommandLine.arguments
let url = URL(fileURLWithPath: a[1])
let boxPt = CGRect(x: Double(a[2])!, y: Double(a[3])!, width: Double(a[4])!, height: Double(a[5])!)
let from = Int(a[6])!, to = Int(a[7])!
let bgMode = a.count > 8 && a[8] == "bg"
let spanThreshold = a.count > 9 ? Double(a[9])! : 10
let labelClass = a.count > 10 ? a[10] : "brass"

let asset = AVURLAsset(url: url)
let sem = DispatchSemaphore(value: 0)
var track: AVAssetTrack!
var naturalSize: CGSize = .zero
Task {
    track = try! await asset.loadTracks(withMediaType: .video).first!
    naturalSize = try! await track.load(.naturalSize)
    sem.signal()
}
sem.wait()
let scale = naturalSize.width / 402.0
let box = CGRect(x: boxPt.minX * scale, y: boxPt.minY * scale,
                 width: boxPt.width * scale, height: boxPt.height * scale).integral

let reader = try! AVAssetReader(asset: asset)
let out = AVAssetReaderTrackOutput(track: track, outputSettings: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(out)
reader.startReading()

let ci = CIContext(options: [.useSoftwareRenderer: true])
let bw = Int(box.width), bh = Int(box.height)
var bytes = [UInt8](repeating: 0, count: bw * bh * 4)
let buckets = 31
var index = 0
print(bgMode
    ? "each row: one frame. 31 buckets across \(Int(boxPt.width)) pt, distance-from-background mass per bucket, 0–9 scaled to the frame's own peak; then the mid-line span runs (pt from the box's left) and the label's first–last column."
    : "each row: one frame. 31 buckets across \(Int(boxPt.width)) pt, brass mass per bucket, 0–9 scaled to the frame's own peak.")
var lastT = -1.0
while let sample = out.copyNextSampleBuffer() {
    defer { index += 1 }
    guard index >= from, index <= to, let pb = CMSampleBufferGetImageBuffer(sample) else { continue }
    let t = CMSampleBufferGetPresentationTimeStamp(sample).seconds
    let image = CIImage(cvPixelBuffer: pb)
    let crop = CGRect(x: box.minX, y: image.extent.height - box.maxY, width: box.width, height: box.height)
    bytes.withUnsafeMutableBytes { raw in
        ci.render(image, toBitmap: raw.baseAddress!, rowBytes: bw * 4,
                  bounds: crop, format: .BGRA8, colorSpace: CGColorSpaceCreateDeviceRGB())
    }
    // The per-pixel mass: brass (R − B − 40) by default, or in `bg` mode the
    // RGB distance from this frame's top-left box pixel.
    let bg = (Double(bytes[0]), Double(bytes[1]), Double(bytes[2]))
    func mass(_ o: Int) -> Double {
        if bgMode {
            let db = Double(bytes[o]) - bg.0, dg = Double(bytes[o + 1]) - bg.1, dr = Double(bytes[o + 2]) - bg.2
            return (db * db + dg * dg + dr * dr).squareRoot()
        }
        return max(0, Double(bytes[o + 2]) - Double(bytes[o]) - 40)
    }
    var profile = [Double](repeating: 0, count: buckets)
    for py in 0..<bh {
        for px in 0..<bw {
            profile[min(buckets - 1, px * buckets / bw)] += mass((py * bw + px) * 4)
        }
    }
    if bgMode {
        // Plan §1, made falsifiable. The capsule and the label are told
        // apart by colour, because a label pixel past the rim is itself a
        // "differing" pixel and would always sit inside any extent measured
        // from differing pixels alone (an earlier draft of this mode did
        // that and could not fail). A *label* pixel is brass — R − B > 40,
        // the brass mode's own test — and a *capsule* pixel differs from the
        // background by more than `spanThreshold`, is not brass, and is not
        // within 1 px of a brass pixel (the fringe; see `nearBrass`). The
        // capsule's extent is its first and last column over the whole box
        // (see below); its mid-line runs (a 3-px band, gaps of ≤ 2 px
        // closed) are printed as information — one on an opaque fill, many on iOS 26.5's
        // see-through Dark fill, where only the rims register. A label pixel
        // in the ±2 pt band outside that extent is counted in `out=`.
        func isBrass(_ o: Int) -> Bool {
            let b = Double(bytes[o]), g = Double(bytes[o + 1]), r = Double(bytes[o + 2])
            switch labelClass {
            case "light": return min(r, g, b) > 200 && max(r, g, b) - min(r, g, b) < 30
            case "dark": return max(r, g, b) < 70 && max(r, g, b) - min(r, g, b) < 30
            default: return r - b > 40
            }
        }
        // T009: the label's fringe is excluded by adjacency, not colour. A
        // pixel is `nearBrass` if any of its 8 neighbours (or itself) is a
        // label pixel; a capsule pixel must be differing, not label, and not
        // nearBrass. Without this the outermost non-label differing pixel
        // is the fringe of a label past the rim, and the verdict cannot fail.
        var brass = [Bool](repeating: false, count: bw * bh)
        for i in 0..<(bw * bh) { brass[i] = isBrass(i * 4) }
        var nearBrass = [Bool](repeating: false, count: bw * bh)
        for py in 0..<bh {
            for px in 0..<bw where brass[py * bw + px] {
                for ny in max(0, py - 1)...min(bh - 1, py + 1) {
                    for nx in max(0, px - 1)...min(bw - 1, px + 1) { nearBrass[ny * bw + nx] = true }
                }
            }
        }
        func isCapsule(_ px: Int, _ py: Int) -> Bool {
            let i = py * bw + px
            return !nearBrass[i] && mass(i * 4) > spanThreshold
        }
        let mid = bh / 2
        var capsuleCols = [Bool](repeating: false, count: bw)
        for px in 0..<bw {
            for py in max(0, mid - 1)...min(bh - 1, mid + 1) where isCapsule(px, py) { capsuleCols[px] = true }
        }
        var midRuns: [(Int, Int)] = []
        var x = 0
        while x < bw {
            guard capsuleCols[x] else { x += 1; continue }
            var end = x, y = x + 1
            while y < bw {
                if capsuleCols[y] { end = y; y += 1 }
                else if y + 2 < bw, capsuleCols[y + 1] || capsuleCols[y + 2] { y += 1 }
                else { break }
            }
            midRuns.append((x, end)); x = end + 1
        }
        // The extent is taken over the box's full height, not the mid-line:
        // on iOS 26.5 the fill and the side rims sit within 2 of the
        // background on the mid-line in both appearances, and only the top
        // and bottom rim lines register (4–8 six pixels off it). The
        // outermost non-brass differing column anywhere in the box is the
        // silhouette's edge — which is what "inside the capsule" means.
        var first = Int.max, last = -1
        for py in 0..<bh {
            for px in 0..<bw where isCapsule(px, py) { first = min(first, px); last = max(last, px) }
        }
        let extent: (Int, Int)? = last < 0 ? nil : (first, last)
        let band = Int((2 * scale).rounded())
        var labelStart = Int.max, labelEnd = -1, outside = 0, labelCount = 0
        for py in max(0, mid - band)...min(bh - 1, mid + band) {
            for px in 0..<bw where isBrass((py * bw + px) * 4) {
                labelCount += 1
                labelStart = min(labelStart, px); labelEnd = max(labelEnd, px)
                if let e = extent, px < e.0 || px > e.1 { outside += 1 }
            }
        }
        let pt = { (px: Int) in String(format: "%.1f", Double(px) / scale) }
        let runText = midRuns.map { "\(pt($0.0))–\(pt($0.1 + 1))" }.joined(separator: " | ")
        let extentText = extent.map { "\(pt($0.0))–\(pt($0.1 + 1))" } ?? "none"
        let labelText = labelEnd >= 0 ? "\(pt(labelStart))–\(pt(labelEnd + 1))" : "none"
        let verdict: String
        if extent == nil { verdict = labelCount > 0 ? "LABEL-ONLY" : "EMPTY" }
        else { verdict = outside == 0 ? "whole" : "TEAR" }
        let peak = profile.max() ?? 1
        let glyphs = profile.map { p -> String in
            let v = peak > 0 ? Int((p / peak * 9).rounded()) : 0
            return v == 0 ? "." : String(v)
        }.joined()
        let dt = lastT < 0 ? 0 : t - lastT
        lastT = t
        print(String(format: "%4d %7.3f Δt=%.3f  %@  runs=%d [%@]  extent=%@  label=%@ out=%dpx  %@", index, t, dt, glyphs, midRuns.count, runText, extentText, labelText, outside, verdict))
        continue
    }
    let peak = profile.max() ?? 1
    let total = profile.reduce(0, +)
    let glyphs = profile.map { p -> String in
        let v = peak > 0 ? Int((p / peak * 9).rounded()) : 0
        return v == 0 ? "." : String(v)
    }.joined()
    // The fill's left edge, to a fraction of a pixel: the solid block's
    // column mass is flat, so the half-height crossing is the edge. This is
    // the metric a *slide* moves and a crossfade cannot.
    var columns = [Double](repeating: 0, count: bw)
    for py in 0..<bh {
        for px in 0..<bw {
            let o = (py * bw + px) * 4
            columns[px] += max(0, Double(bytes[o + 2]) - Double(bytes[o]) - 40)
        }
    }
    let colPeak = columns.max() ?? 1
    var edge = -1.0
    for x in 1..<bw where columns[x - 1] < colPeak / 2 && columns[x] >= colPeak / 2 {
        let lo = columns[x - 1], hi = columns[x]
        edge = (Double(x - 1) + (colPeak / 2 - lo) / max(hi - lo, 1)) / Double(scale)
        break
    }
    print(String(format: "%4d %7.3f  %@  total=%.0f  leftEdge=%.2f pt", index, t, glyphs, total / 1000, edge))
}
