import AVFoundation
import CoreImage
import Foundation

// Per-frame measurement of the Owned/Sold switch's brass fill, from a
// `xcrun simctl io recordVideo` capture. The T056 rule: a screenshot cannot
// show a transition, so the transition is measured frame by frame.
//
// The fill is brass (#C79A56 — r−b ≈ 113); the header's text is grey
// (r−b ≈ 0) and the page is near-black, so a chroma mask isolates the fill
// from everything else in the crop. The brass-weighted centroid is then the
// fill's position in points: x says which half it is over, y says whether
// the control itself moved.
//
// usage: swift analyze.swift <video.mov> <xPt> <yPt> <wPt> <hPt>

let args = CommandLine.arguments
let url = URL(fileURLWithPath: args[1])
let boxPt = CGRect(x: Double(args[2])!, y: Double(args[3])!,
                   width: Double(args[4])!, height: Double(args[5])!)

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

let scale = naturalSize.width / 402.0   // the device's point width
print("video \(Int(naturalSize.width))x\(Int(naturalSize.height))  scale=\(scale)")

let box = CGRect(x: boxPt.minX * scale, y: boxPt.minY * scale,
                 width: boxPt.width * scale, height: boxPt.height * scale).integral

let reader = try! AVAssetReader(asset: asset)
let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
])
reader.add(output)
reader.startReading()

let ci = CIContext(options: [.useSoftwareRenderer: true])
let bw = Int(box.width), bh = Int(box.height)
var bytes = [UInt8](repeating: 0, count: bw * bh * 4)

struct Frame {
    let index: Int
    let time: Double
    let x: Double        // brass centroid, points from the crop's left edge
    let y: Double        // brass centroid, points from the crop's top edge
    let mass: Double     // how much brass is in the crop at all
    let checksum: UInt64
}

var frames: [Frame] = []
var index = 0
while let sample = output.copyNextSampleBuffer() {
    guard let pb = CMSampleBufferGetImageBuffer(sample) else { continue }
    let t = CMSampleBufferGetPresentationTimeStamp(sample).seconds
    let image = CIImage(cvPixelBuffer: pb)
    let crop = CGRect(x: box.minX, y: image.extent.height - box.maxY,
                      width: box.width, height: box.height)
    bytes.withUnsafeMutableBytes { raw in
        ci.render(image, toBitmap: raw.baseAddress!, rowBytes: bw * 4,
                  bounds: crop, format: .BGRA8, colorSpace: CGColorSpaceCreateDeviceRGB())
    }
    var wx = 0.0, wy = 0.0, mass = 0.0
    var checksum: UInt64 = 1469598103934665603
    for py in 0..<bh {
        for px in 0..<bw {
            let o = (py * bw + px) * 4
            let b = Double(bytes[o]), r = Double(bytes[o + 2])
            let w = max(0, r - b - 40)
            wx += Double(px) * w
            wy += Double(py) * w
            mass += w
            checksum = (checksum ^ UInt64(bytes[o])) &* 1099511628211
            checksum = (checksum ^ UInt64(bytes[o + 2])) &* 1099511628211
        }
    }
    frames.append(Frame(index: index, time: t,
                        x: mass > 0 ? wx / mass / Double(scale) : -1,
                        y: mass > 0 ? wy / mass / Double(scale) : -1,
                        mass: mass, checksum: checksum))
    index += 1
}

print("frames read: \(frames.count)")
guard let firstFrame = frames.first, let lastFrame = frames.last else { exit(1) }
print("duration: \(String(format: "%.3f", lastFrame.time - firstFrame.time)) s")

// At rest the fill is centred over one half, a quarter of the crop's width
// either side of its middle. Anything between the two is in flight.
let mid = boxPt.width / 2
let restOffset = boxPt.width / 4 * 0.6
func isRest(_ f: Frame) -> Int? {
    guard f.mass > 200_000 else { return nil }     // the fill is on screen at all
    if f.x < mid - restOffset { return -1 }
    if f.x > mid + restOffset { return 1 }
    return nil
}

var toggles: [(from: Int, to: Int)] = []
var restIndex: Int? = nil
var restSign = 0
for (i, f) in frames.enumerated() {
    guard let sign = isRest(f) else { continue }
    if let r = restIndex, sign != restSign, i - r < 60 { toggles.append((r, i)) }
    restIndex = i
    restSign = sign
}

print("toggles found: \(toggles.count)")
for (n, toggle) in toggles.enumerated() {
    let before = frames[toggle.from], after = frames[toggle.to]
    let span = after.x - before.x
    print("")
    print("--- toggle \(n + 1): \(span > 0 ? "Owned→Sold" : "Sold→Owned") ---")
    func progress(_ f: Frame) -> Double { (f.x - before.x) / span }
    let window = Array(frames[toggle.from...toggle.to])
    print("frame  time(s)  Δt(ms)   fillX(pt)  progress   fillY(pt)  dupOfPrev")
    var prev: Frame?
    for f in window {
        let dt = prev.map { (f.time - $0.time) * 1000 } ?? 0
        let dup = prev.map { $0.checksum == f.checksum } ?? false
        print(String(format: "%5d  %7.3f  %6.1f  %10.2f  %8.3f  %10.2f  %@",
                     f.index, f.time, dt, f.x, progress(f), f.y, dup ? "DUPLICATE" : ""))
        prev = f
    }
    let moving = window.filter { progress($0) > 0.03 && progress($0) < 0.97 }
    print(String(format: "fill centre: %.2f pt → %.2f pt  (vertical: %.2f pt → %.2f pt)",
                 before.x, after.x, before.y, after.y))
    print("intermediate frames: \(moving.count)")
    if let a = moving.first, let b = moving.last {
        print(String(format: "travel across the intermediates: %.0f ms", (b.time - a.time) * 1000))
    }
    print(String(format: "rest-to-rest: %.0f ms", (after.time - before.time) * 1000))
    var monotonic = true
    for (a, b) in zip(moving, moving.dropFirst()) where (b.x - a.x) * span < -0.5 { monotonic = false }
    print("monotonic: \(monotonic)")
    print("distinct intermediate positions: \(Set(moving.map { Int(($0.x * 50).rounded()) }).count)")
    print("repeated frames among the intermediates: \(zip(moving, moving.dropFirst()).filter { $0.checksum == $1.checksum }.count)")
    let gaps = zip(window, window.dropFirst()).map { ($1.time - $0.time) * 1000 }.filter { $0 > 25 }
    print("frame gaps over 25 ms inside the toggle: \(gaps.map { String(format: "%.0f", $0) })")
    let verticalJump = abs(after.y - before.y)
    print(String(format: "vertical movement of the fill, rest to rest: %.2f pt", verticalJump))
}
