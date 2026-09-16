import AVFoundation
import CoreImage
import Foundation

// The column profile of the brass fill, frame by frame, for a range of
// frames. A *slide* is one contiguous plateau of the fill's width moving
// across; a *crossfade* is two plateaus at the fixed halves whose heights
// trade places. The centroid alone cannot tell them apart, which is why
// this exists.
//
// usage: swift profile.swift <video.mov> <xPt> <yPt> <wPt> <hPt> <fromIndex> <toIndex>

let a = CommandLine.arguments
let url = URL(fileURLWithPath: a[1])
let boxPt = CGRect(x: Double(a[2])!, y: Double(a[3])!, width: Double(a[4])!, height: Double(a[5])!)
let from = Int(a[6])!, to = Int(a[7])!

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
print("each row: one frame. 31 buckets across \(Int(boxPt.width)) pt, brass mass per bucket, 0–9 scaled to the frame's own peak.")
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
    var profile = [Double](repeating: 0, count: buckets)
    for py in 0..<bh {
        for px in 0..<bw {
            let o = (py * bw + px) * 4
            let w = max(0, Double(bytes[o + 2]) - Double(bytes[o]) - 40)
            profile[min(buckets - 1, px * buckets / bw)] += w
        }
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
