import Testing
@testable import Trove

/// 013/T006: the About row's version is read from an Info dictionary, with
/// a visible "?" for anything missing — pinned on the dictionary, since the
/// test host's own bundle would make a `Bundle.main` assertion tautological.
@Suite("App version")
struct AppVersionTests {
    @Test func readsBothKeys() {
        let version = AppVersion(info: ["CFBundleShortVersionString": "1.0", "CFBundleVersion": "1"])
        #expect(version == AppVersion(version: "1.0", build: "1"))
        #expect(version.display == "Version 1.0 (1)")
    }

    @Test func aMissingVersionShowsAsAQuestionMark() {
        let version = AppVersion(info: ["CFBundleVersion": "7"])
        #expect(version.version == "?")
        #expect(version.build == "7")
        #expect(version.display == "Version ? (7)")
    }

    @Test func aMissingBuildShowsAsAQuestionMark() {
        let version = AppVersion(info: ["CFBundleShortVersionString": "2.3"])
        #expect(version.display == "Version 2.3 (?)")
    }

    @Test func noDictionaryAtAllStillRenders() {
        #expect(AppVersion(info: nil).display == "Version ? (?)")
    }

    /// `current` reads the running bundle: in the test host that's the app,
    /// which carries both keys — so neither half may be the fallback.
    @Test func theRunningBundleCarriesBothKeys() {
        let current = AppVersion.current
        #expect(current.version != "?")
        #expect(current.build != "?")
    }
}
