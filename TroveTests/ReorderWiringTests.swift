import Foundation
import Testing
@testable import Trove

/// T039d. The reorder design's three load-bearing wiring claims, pinned as
/// source scans — the same shape as `PullToRefreshTests`, and for the same
/// reason: no unit test can drag a row or run VoiceOver, so what a test *can*
/// catch is the wiring quietly changing out from under a decision that
/// reversed three times on the way here.
@Suite("Reorder wiring")
struct ReorderWiringTests {
    private nonisolated static let lists = [
        "Trove/Views/Items/ItemListView.swift",
        "Trove/Views/Wishlist/WishlistView.swift",
    ]

    /// T028a's final decision: no edit-mode UI — drag handles, Reorder
    /// buttons, formal `editMode` — ever appears on either screen. The
    /// decision reversed three times (T028 → T028a), and until now its only
    /// enforcement was a prose note that a one-time grep found nothing.
    @Test func noEditModeUIAnywhereInTheAppTarget() throws {
        for path in try Self.allAppSwiftFiles() {
            let code = try SourceScan.production(path)
            #expect(!code.contains("editMode"), "\(path) touches editMode")
            #expect(!code.contains("EditButton"), "\(path) uses EditButton")
        }
    }

    /// The drag itself is offered exactly when the view model says reordering
    /// is on — `.onMove` handed a nil action detaches the gesture entirely,
    /// which is what keeps swipe actions working under every other sort.
    @Test(arguments: lists)
    func theDragGatesOnCanReorder(path: String) throws {
        let code = try SourceScan.production(path)
        let gated = code.ranges(of: ".onMove(perform: viewModel.canReorder ?").count
        let any = code.ranges(of: ".onMove").count

        #expect(any == 1, "\(path) has \(any) .onMove modifiers, expected exactly 1")
        #expect(gated == 1, "\(path)'s .onMove is not gated on viewModel.canReorder")
    }

    /// T029b's invariant, the actual cause of a shipped defect: the
    /// `.accessibilityActions` block is gated on `canReorder` alone and its
    /// structure never depends on the row's position — restructuring a row's
    /// AX content while a drag settles makes the List repaint the pre-drag
    /// order. The ends of the list are handled by `moveUp`/`moveDown`'s own
    /// no-ops, so both actions are always offered together.
    @Test(arguments: lists)
    func accessibilityActionsAreNotPositionConditional(path: String) throws {
        let bodies = SourceScan.closureBodies(after: ".accessibilityActions", in: try SourceScan.production(path))

        #expect(bodies.count == 1, "\(path) has \(bodies.count) .accessibilityActions blocks, expected exactly 1")
        for body in bodies {
            #expect(body.contains("if viewModel.canReorder"), "\(path)'s AX actions aren't gated on canReorder")
            #expect(body.contains("Move up") && body.contains("Move down"),
                    "\(path) doesn't offer both move actions")
            #expect(!body.contains("canMoveUp") && !body.contains("canMoveDown") && !body.contains("firstIndex"),
                    """
                    \(path)'s .accessibilityActions block looks position-conditional, \
                    which is exactly what T029b removed: \(body)
                    """)
        }
    }

    /// Every Swift file under `Trove/`, repo-relative — the walk itself is
    /// asserted non-trivial so a moved source root fails loudly instead of
    /// scanning nothing and passing.
    private static func allAppSwiftFiles(file: StaticString = #filePath) throws -> [String] {
        let root = URL(filePath: "\(file)")
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Trove")
        let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var paths: [String] = []
        while let url = walker?.nextObject() as? URL {
            if url.pathExtension == "swift" {
                paths.append("Trove/" + url.path.replacingOccurrences(of: root.path + "/", with: ""))
            }
        }
        try #require(paths.count > 20, "source walk found only \(paths.count) files — wrong root?")
        return paths.sorted()
    }
}
