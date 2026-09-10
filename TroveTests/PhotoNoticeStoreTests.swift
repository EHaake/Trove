import Foundation
import Testing
@testable import Trove

/// `UserDefaultsPhotoNoticeStore` over an in-memory `UserDefaults(suiteName:)`
/// — never `.standard`. Each test makes its own suite from a fresh UUID and
/// wipes it in a `defer`, so no state leaks between tests or onto the device.
@Suite("Photo notice store")
struct PhotoNoticeStoreTests {
    /// A private `UserDefaults` domain, isolated per call and torn down after
    /// the given work runs.
    private func withFreshDefaults(_ body: (UserDefaults) -> Void) {
        let suiteName = "PhotoNoticeStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        body(defaults)
    }

    @Test func aFreshStoreHasNotAcknowledged() {
        withFreshDefaults { defaults in
            let store = UserDefaultsPhotoNoticeStore(defaults: defaults)
            #expect(store.hasAcknowledged == false)
        }
    }

    @Test func acknowledgingSetsTheFlag() {
        withFreshDefaults { defaults in
            let store = UserDefaultsPhotoNoticeStore(defaults: defaults)
            store.acknowledge()
            #expect(store.hasAcknowledged == true)
        }
    }

    /// The acknowledgement persists: a second store over the same defaults
    /// reads `true`. This is the mutation target — drop the write in
    /// `acknowledge()` and this goes red.
    @Test func asecondStoreOverTheSameDefaultsSeesTheAcknowledgement() {
        withFreshDefaults { defaults in
            UserDefaultsPhotoNoticeStore(defaults: defaults).acknowledge()
            let second = UserDefaultsPhotoNoticeStore(defaults: defaults)
            #expect(second.hasAcknowledged == true)
        }
    }
}
