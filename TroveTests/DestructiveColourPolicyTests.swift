import Foundation
import Testing
@testable import Trove

/// `009` plan §9a (T009d), the person's standard: **a destructive action is
/// always drawn in rust.** Where the app draws the control, the colour goes on
/// the control itself; where the system draws it, the role alone does it —
/// `design/tokens.md`, "Destructive actions".
///
/// The reason it needs a guard: `ContentView`'s brass `.tint` cascades over
/// the destructive role's red on every control the app draws, so a
/// `role: .destructive` Button left to itself reads brass — the Sell Plan's
/// toolbar Delete shipped that way. This is a fact about view bodies no view
/// model can observe, so it is a source scan, `MenuPolicyTests`' shape.
///
/// Every `.destructive` in production view code is classified by its
/// enclosing brackets — one pass per file, a bracket stack that skips string
/// literals (and the code inside their interpolations):
/// - inside `.alert`, `.confirmationDialog`, `.contextMenu` or `Menu`, the
///   system draws it: exempt;
/// - otherwise the nearest enclosing call must be `Button(` — anything else
///   is an unclassified site, and fails — and that Button's extent (its
///   parentheses, trailing closures and modifier chain) must name
///   `accentRust`.
///
/// A file whose brackets don't balance was misread, and its sites can't be
/// trusted — so every file holding a `.destructive` must end with an empty
/// stack, and every such file must have been balance-checked. The one known
/// way to unbalance one is a `//` inside a string literal, which
/// `SourceScan.production` cuts as a comment (a URL literal, say). Files
/// with no site aren't checked: nothing in them is classified.
///
/// One exemption, itself pinned: `SettingsView.swift`'s rows colour their
/// label through `SettingsActionRow.color`, away from the Button.
///
/// What it proves is that the colour is *named* on the control, not that it
/// renders — that half is the device check. It does not reach a destructive
/// action without the role, nor which rust token a site chose.
@Suite("Destructive colour policy")
struct DestructiveColourPolicyTests {
    private let systemDrawn: Set<String> = [".alert", ".confirmationDialog", ".contextMenu", "Menu"]
    private let settingsFile = "Trove/Views/Settings/SettingsView.swift"
    private let settingsColour = "isDestructive ? theme.colors.accentRustText"

    @Test func everyAppDrawnDestructiveControlIsColouredRust() throws {
        let files = try SourceScan.swiftFiles(under: "Trove/Views", minimum: 40)
            + SourceScan.swiftFiles(under: "Trove/App", minimum: 5)

        var total = 0
        var system = 0
        var appDrawn = 0
        var settingsExempted = 0
        var balanceChecked = 0
        var unbalanced: [String] = []
        var miscounted: [String] = []
        var offenders: [String] = []
        let destructive = try Regex(#"\.destructive\b"#)

        for file in files {
            let text = try SourceScan.production(file)
            let code = Array(text)
            let scan = Self.scan(code)
            // Exact, per file: every `.destructive` in the production text is
            // a site the scan classified. No production string literal holds
            // the word, so the regex's count and the scan's must agree — a
            // site the bracket pass skipped shows up here, named.
            let written = text.matches(of: destructive).count
            if scan.sites.count != written {
                miscounted.append("\(file): \(scan.sites.count) classified of \(written)")
            }
            if !scan.sites.isEmpty {
                balanceChecked += 1
                if !scan.balanced { unbalanced.append(file) }
            }

            for site in scan.sites {
                total += 1
                let location = Self.location(of: site.index, in: code, file: file)
                if site.stack.contains(where: { systemDrawn.contains($0.callee) }) {
                    system += 1
                    continue
                }
                guard let call = site.stack.last, call.open == "(", call.callee == "Button" else {
                    offenders.append("unclassified destructive site — \(location)")
                    continue
                }
                appDrawn += 1
                if file == settingsFile {
                    settingsExempted += 1
                    continue
                }
                let extent = Self.buttonExtent(openParen: call.start, in: code, matches: scan.matches)
                if !String(code[call.start...extent]).contains("accentRust") {
                    offenders.append("app-drawn destructive Button not coloured rust — \(location)")
                }
            }
        }

        #expect(unbalanced.isEmpty, "the bracket stack did not end empty — the scan misread \(unbalanced)")
        #expect(offenders.isEmpty, "\(offenders)")

        #expect(miscounted.isEmpty, "the scan did not classify every `.destructive` in \(miscounted)")

        // A backstop behind the exact check, at today's counts: the file
        // listing itself shrinking would pass the per-file check vacuously.
        try #require(balanceChecked >= 9, "only \(balanceChecked) files hold a destructive site")
        try #require(total >= 15, "found only \(total) destructive sites — the scan is missing some")
        try #require(system >= 9, "found only \(system) system-drawn destructive sites")
        try #require(appDrawn >= 6, "found only \(appDrawn) app-drawn destructive sites")

        // The exemption is only honest while Settings still colours its
        // destructive rows rust on its own, and still has one to colour.
        #expect(settingsExempted >= 1, "SettingsView has no app-drawn destructive site — the exemption is stale")
        let settings = try SourceScan.production(settingsFile)
        #expect(settings.contains(settingsColour), "SettingsActionRow.color must read `\(settingsColour)`")
    }

    // MARK: - The scan

    private struct Frame {
        let open: Character
        /// The call the bracket belongs to: `Button`, `Menu`, or `.alert` for
        /// a modifier — a trailing closure inherits its call's name.
        let callee: String
        let start: Int
    }

    private struct Site {
        let index: Int
        let stack: [Frame]
    }

    private struct Scan {
        var sites: [Site] = []
        var matches: [Int: Int] = [:]
        var balanced = true
    }

    private static func scan(_ c: [Character]) -> Scan {
        var result = Scan()
        var stack: [Frame] = []
        var calleeOfClose: [Int: String] = [:]
        let pairs: [Character: Character] = [")": "(", "}": "{", "]": "["]
        var i = 0

        while i < c.count {
            let ch = c[i]
            if ch == "\"" {
                i = endOfString(c, from: i) + 1
                continue
            }
            if "({[".contains(ch) {
                stack.append(Frame(open: ch, callee: callee(before: i, in: c, calleeOfClose: calleeOfClose), start: i))
            } else if let opener = pairs[ch] {
                // A mismatch is recorded and the pass carries on, so the
                // file's sites are still found and it still gets checked.
                if let top = stack.popLast(), top.open == opener {
                    result.matches[top.start] = i
                    calleeOfClose[i] = top.callee
                } else {
                    result.balanced = false
                }
            } else if ch == ".", word(at: i + 1, in: c) == "destructive" {
                result.sites.append(Site(index: i, stack: stack))
            }
            i += 1
        }
        // Both halves: a crossed pair that nets to zero leaves the stack
        // empty, and must not wash out the mismatch recorded above.
        result.balanced = result.balanced && stack.isEmpty
        return result
    }

    /// `i` at an opening quote; returns the closing quote's index — or the
    /// line's end, since a single-line literal can't span one (and one cut
    /// short by a stripped `//` must not swallow the rest of the file).
    private static func endOfString(_ c: [Character], from i: Int) -> Int {
        var j = i + 1
        while j < c.count, c[j] != "\n" {
            if c[j] == "\\" {
                if j + 1 < c.count, c[j + 1] == "(" {
                    j = endOfInterpolation(c, from: j + 1) + 1
                } else {
                    j += 2
                }
                continue
            }
            if c[j] == "\"" { return j }
            j += 1
        }
        return j
    }

    /// `i` at an interpolation's `(`; returns its matching `)`.
    private static func endOfInterpolation(_ c: [Character], from i: Int) -> Int {
        var depth = 0
        var j = i
        while j < c.count {
            switch c[j] {
            case "\"": j = endOfString(c, from: j)
            case "(": depth += 1
            case ")":
                depth -= 1
                if depth == 0 { return j }
            default: break
            }
            j += 1
        }
        return c.count
    }

    private static func isIdentifier(_ ch: Character) -> Bool {
        ch.isLetter || ch.isNumber || ch == "_"
    }

    /// The whole identifier starting at `i`, or "" if there isn't one.
    private static func word(at i: Int, in c: [Character]) -> String {
        var j = i
        while j < c.count, isIdentifier(c[j]) { j += 1 }
        return String(c[i..<j])
    }

    private static func skipSpaceBackward(from i: Int, in c: [Character]) -> Int {
        var j = i
        while j >= 0, c[j].isWhitespace { j -= 1 }
        return j
    }

    private static func skipSpaceForward(from i: Int, in c: [Character]) -> Int {
        var j = i
        while j < c.count, c[j].isWhitespace { j += 1 }
        return j
    }

    /// What an opening bracket at `i` belongs to: the identifier before it
    /// (`.name` when it is a member, so a local named `alert` isn't the
    /// modifier), or — for a trailing closure after `)` or a labelled one
    /// after `} label:` — the call that closure trails.
    private static func callee(before i: Int, in c: [Character], calleeOfClose: [Int: String]) -> String {
        var j = skipSpaceBackward(from: i - 1, in: c)
        guard j >= 0 else { return "" }
        if ")}]".contains(c[j]) { return calleeOfClose[j] ?? "" }
        if c[j] == ":" {
            j -= 1
            while j >= 0, isIdentifier(c[j]) { j -= 1 }
            j = skipSpaceBackward(from: j, in: c)
            return j >= 0 && c[j] == "}" ? calleeOfClose[j] ?? "" : ""
        }
        guard isIdentifier(c[j]) else { return "" }
        let end = j
        while j >= 0, isIdentifier(c[j]) { j -= 1 }
        let name = String(c[(j + 1)...end])
        return j >= 0 && c[j] == "." ? "." + name : name
    }

    /// The last index of a Button whose `(` is at `openParen`: past its
    /// parentheses, any trailing closures (labelled or not), and every
    /// `.modifier(…)` chained onto it.
    private static func buttonExtent(openParen: Int, in c: [Character], matches: [Int: Int]) -> Int {
        var end = matches[openParen] ?? openParen
        while true {
            let k = skipSpaceForward(from: end + 1, in: c)
            guard k < c.count else { return end }
            if c[k] == "{", let close = matches[k] {
                end = close
                continue
            }
            if c[k] == "." {
                let name = word(at: k + 1, in: c)
                guard !name.isEmpty else { return end }
                let after = k + 1 + name.count
                if after < c.count, c[after] == "(", let close = matches[after] {
                    end = close
                } else {
                    end = after - 1
                }
                continue
            }
            let label = word(at: k, in: c)
            if !label.isEmpty {
                let colon = skipSpaceForward(from: k + label.count, in: c)
                if colon < c.count, c[colon] == ":" {
                    let brace = skipSpaceForward(from: colon + 1, in: c)
                    if brace < c.count, c[brace] == "{", let close = matches[brace] {
                        end = close
                        continue
                    }
                }
            }
            return end
        }
    }

    /// `file:line: text` for a site. Line comments keep their newline when
    /// stripped, so the number is the file's own unless a `/* */` block sits
    /// above the site.
    private static func location(of i: Int, in c: [Character], file: String) -> String {
        var start = i
        while start > 0, c[start - 1] != "\n" { start -= 1 }
        var end = i
        while end < c.count, c[end] != "\n" { end += 1 }
        let number = c[..<start].filter { $0 == "\n" }.count + 1
        let text = String(c[start..<end]).trimmingCharacters(in: .whitespaces)
        return "\(file):\(number): \(text)"
    }
}
