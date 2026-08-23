import Foundation
import Testing
@testable import Trove

/// The save bar's promise, which was a hardcoded string that quietly went
/// false when T002 turned sync on. Nothing failed; it just started lying.
///
/// So the rule is a function now, and these are the two claims that must never
/// be made by the wrong mode.
@Suite("Save caption")
struct SaveCaptionTests {
    private nonisolated static let nouns = ["library", "wishlist"]

    @Test(arguments: nouns)
    func theSyncingModeDoesNotPromiseTheDeviceIsTheOnlyCopy(noun: String) {
        let caption = SaveCaption.text(for: .cloudKit, noun: noun)

        #expect(!caption.localizedCaseInsensitiveContains("on this device"), "\(caption)")
        #expect(caption.localizedCaseInsensitiveContains("iCloud"), "\(caption)")
    }

    /// `.localOnly` is reached when CloudKit won't load at all, so a caption
    /// mentioning sync there would be the more damaging direction of the same
    /// mistake: telling someone their collection is backed up when the reason
    /// this mode exists is that it isn't.
    @Test(arguments: nouns)
    func theFallbackModeDoesNotPromiseSync(noun: String) {
        let caption = SaveCaption.text(for: .localOnly, noun: noun)

        #expect(!caption.localizedCaseInsensitiveContains("iCloud"), "\(caption)")
        #expect(!caption.localizedCaseInsensitiveContains("sync"), "\(caption)")
    }

    /// A UI-test store doesn't outlive the process, so of the two it's the
    /// local wording that's closer to true.
    @Test(arguments: nouns)
    func theUITestStoreDoesNotPromiseSyncEither(noun: String) {
        #expect(SaveCaption.text(for: .ephemeral, noun: noun) == SaveCaption.text(for: .localOnly, noun: noun))
    }

    @Test(arguments: nouns)
    func everyModeSaysWhichCollection(noun: String) {
        for mode: StorageMode in [.cloudKit, .localOnly, .ephemeral] {
            #expect(SaveCaption.text(for: mode, noun: noun).contains(noun), "\(mode)")
        }
    }

    /// Fits on one line under the save button at `monoLabel`'s 10.5pt with
    /// 1.2pt tracking, inside the 24pt screen gutters on the narrowest device
    /// this ships to. The caption has no `lineLimit`, so overflowing wraps and
    /// silently changes the save bar's height rather than truncating —
    /// invisible in a test run, obvious only on a device.
    @Test(arguments: nouns)
    func everyCaptionFitsOnOneLine(noun: String) {
        for mode: StorageMode in [.cloudKit, .localOnly, .ephemeral] {
            let caption = SaveCaption.text(for: mode, noun: noun)
            // Uppercased by `monoLabel`'s `.textCase`, and IBM Plex Mono is
            // fixed-pitch, so character count is the measurement.
            let width = Double(caption.count) * (10.5 * 0.6 + 1.2)
            #expect(width <= 375 - 48, "\(caption.uppercased()) — \(Int(width))pt wide")
        }
    }
}

/// The other half of T049a: the views actually ask.
///
/// `SaveCaptionTests` above pins what each mode says, and stays green if both
/// form views ignore it and keep their hardcoded line. Same shape as
/// `UnvaluedCopyTests` — the failure is a literal reappearing somewhere, so
/// the check has to look at the source.
@Suite("Save caption wiring")
struct SaveCaptionWiringTests {
    private nonisolated static let forms = [
        "Trove/Views/Items/ItemFormView.swift",
        "Trove/Views/Wishlist/WishlistFormView.swift",
    ]

    private func source(_ path: String) throws -> String {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: path)
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test(arguments: forms)
    func theFormAsksForTheCaptionRatherThanStatingIt(path: String) throws {
        // Comment-stripped for the same reason StillSyncingWiringTests is: a
        // bare `contains` is satisfied by a comment mentioning the call.
        let contents = try SourceScan.production(path)

        #expect(contents.contains("SaveCaption.text("), "\(path) doesn't use SaveCaption")
        #expect(
            !contents.contains("\"Saves to your"),
            "\(path) still hardcodes a save caption, so it can't reflect the store"
        )
    }
}
