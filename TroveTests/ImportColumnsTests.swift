import Testing
@testable import Trove

/// 021 T003, guard G5: columns found by name (plan §3; P1–P3). Every header
/// here is built from `ExportSchema`'s own arrays — the known names are read,
/// never copied — so a schema change reshapes these tests by construction.
struct ImportColumnsTests {
    // Plan §6's temporary seam: the known names are each array plus
    // `troveIDHeader` until T008 appends it to the arrays.
    private let itemsKnown = ExportSchema.itemHeaders + [ExportSchema.troveIDHeader]
    private let wishlistKnown = ExportSchema.wishlistHeaders + [ExportSchema.troveIDHeader]

    private func items(_ header: [String]) throws(ImportColumns.HeaderError) -> ImportColumns {
        try ImportColumns.match(
            header: header,
            known: itemsKnown,
            required: ExportSchema.itemRequiredHeaders,
            otherRequired: ExportSchema.wishlistRequiredHeaders
        )
    }

    private func wishlist(_ header: [String]) throws(ImportColumns.HeaderError) -> ImportColumns {
        try ImportColumns.match(
            header: header,
            known: wishlistKnown,
            required: ExportSchema.wishlistRequiredHeaders,
            otherRequired: ExportSchema.itemRequiredHeaders
        )
    }

    private func replacing(_ name: String, with spelling: String, in header: [String]) throws -> [String] {
        var header = header
        header[try #require(header.firstIndex(of: name))] = spelling
        return header
    }

    // MARK: - Criterion 4: case, surrounding spaces, a trailing star

    @Test func caseSpacesAndAStarAreOneColumn() throws {
        let expected = try #require(ExportSchema.itemHeaders.firstIndex(of: "Purchase Price"))
        for spelling in ["purchase price", " Purchase Price ", "Purchase Price *", "PURCHASE PRICE*"] {
            let header = try replacing("Purchase Price", with: spelling, in: ExportSchema.itemHeaders)
            let columns = try items(header)
            #expect(columns.position(of: "Purchase Price") == expected, "\(spelling)")
            #expect(columns.unused.isEmpty, "\(spelling)")
        }
    }

    /// The template's own header (P2): every required name starred.
    @Test func aStarredRequiredHeaderMatches() throws {
        let starred = ExportSchema.itemHeaders.map {
            ExportSchema.itemRequiredHeaders.contains($0) ? "\($0) *" : $0
        }
        let columns = try items(starred)
        for (index, name) in ExportSchema.itemHeaders.enumerated() {
            #expect(columns.position(of: name) == index)
        }
        #expect(columns.unused.isEmpty)
    }

    // MARK: - Criterion 3: any order

    /// Reversed, then the middle name swapped to the front, so no name keeps
    /// its schema position — a matcher that read positions from the schema
    /// order would get every one of them wrong.
    @Test func aShuffledHeaderGivesEachNameItsNewPosition() throws {
        let names = ExportSchema.itemHeaders
        var shuffled = Array(names.reversed())
        shuffled.swapAt(0, names.count / 2)
        #expect(Set(shuffled) == Set(names))
        #expect(zip(shuffled, names).allSatisfy { $0 != $1 })

        let columns = try items(shuffled)
        for name in names {
            #expect(columns.position(of: name) == shuffled.firstIndex(of: name))
        }
        #expect(columns.width == names.count)
        // A known name the file doesn't carry has no position.
        #expect(columns.position(of: ExportSchema.troveIDHeader) == nil)
    }

    // MARK: - Criterion 5: every missing required name, in schema order

    @Test func everyMissingRequiredNameIsReportedInSchemaOrder() {
        let header = ExportSchema.itemHeaders.filter { $0 != "Purchase Price" && $0 != "Purchase Date" }
        #expect(throws: ImportColumns.HeaderError.missing(["Purchase Price", "Purchase Date"])) {
            try items(header)
        }
        let wishlistHeader = ExportSchema.wishlistHeaders.filter { $0 != "Name" && $0 != "Estimated Cost" }
        #expect(throws: ImportColumns.HeaderError.missing(["Name", "Estimated Cost"])) {
            try wishlist(wishlistHeader)
        }
    }

    /// An empty file is a header of no cells — missing every required name,
    /// not a case of its own and not "wrong list".
    @Test func anEmptyHeaderIsMissingEveryRequiredName() {
        #expect(throws: ImportColumns.HeaderError.missing(ExportSchema.itemRequiredHeaders)) {
            try items([])
        }
        #expect(throws: ImportColumns.HeaderError.missing(ExportSchema.wishlistRequiredHeaders)) {
            try wishlist([])
        }
    }

    // MARK: - Criterion 8: the same recognised column twice

    @Test func aRecognisedNameTwiceIsADuplicate() {
        #expect(throws: ImportColumns.HeaderError.duplicate("Name")) {
            try items(ExportSchema.itemHeaders + ["name *"])
        }
    }

    // MARK: - Criterion 7: unknown names, listed once, in file order

    @Test func unknownNamesAreListedOnceInFileOrder() throws {
        var header = ["Mount"] + ExportSchema.itemHeaders
        header.insert("", at: 2)
        header.insert("Insured", at: 4)
        header += ["mount", "Purchse Price", " Insured*", "  "]

        let columns = try items(header)
        #expect(columns.unused == ["Mount", "Insured", "Purchse Price"])
        // The unknown cells shift the known ones; each is still found.
        #expect(columns.position(of: "Name") == 1)
        #expect(columns.position(of: "Purchase Price") == header.firstIndex(of: "Purchase Price"))
        #expect(columns.width == header.count)
    }

    // MARK: - Criterion 10: the other list's file, both ways, every shipped layout

    @Test func theOtherListsHeaderIsWrongListAtEveryShippedLayout() {
        // The shipped layouts by literal width — the boundary arrays they were
        // read from went with the width gate (021 T007, Q6).
        let wishlistWidths = [7, 9, 10]
        let itemWidths = [12, 14, 18, 19]

        for width in wishlistWidths {
            #expect(throws: ImportColumns.HeaderError.wrongList, "wishlist \(width)") {
                try items(Array(ExportSchema.wishlistHeaders.prefix(width)))
            }
        }
        for width in itemWidths {
            #expect(throws: ImportColumns.HeaderError.wrongList, "items \(width)") {
                try wishlist(Array(ExportSchema.itemHeaders.prefix(width)))
            }
        }
    }

    /// The other half of criterion 10's rule: a file at one of those widths
    /// that is *not* the other list's is "missing", so wrong-list can't be
    /// decided by counting cells.
    @Test func aHeaderAtTheOtherListsWidthIsNotWrongListByCount() {
        let itemsAtWishlistWidth = Array(ExportSchema.itemHeaders.prefix(10)).filter { $0 != "Purchase Date" }
        #expect(itemsAtWishlistWidth.count == 9)
        #expect(throws: ImportColumns.HeaderError.missing(["Purchase Date"])) {
            try items(itemsAtWishlistWidth)
        }

        let wishlistAtItemsWidth = ExportSchema.wishlistHeaders.filter { $0 != "Estimated Cost" }
            + ["Mount", "Insured", "Strings"]
        #expect(wishlistAtItemsWidth.count == 12)
        #expect(throws: ImportColumns.HeaderError.missing(["Estimated Cost"])) {
            try wishlist(wishlistAtItemsWidth)
        }
    }
}
