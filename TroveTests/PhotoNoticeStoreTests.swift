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

    /// The reset is structurally gated on the built store's mode: only the
    /// in-memory `.ephemeral` launch clears the flag, never a persistent one.
    @Test func onlyTheInMemoryStoreTriggersTheReset() {
        #expect(UserDefaultsPhotoNoticeStore.shouldResetForUITesting(mode: .ephemeral) == true)
        #expect(UserDefaultsPhotoNoticeStore.shouldResetForUITesting(mode: .localOnly) == false)
        #expect(UserDefaultsPhotoNoticeStore.shouldResetForUITesting(mode: .cloudKit) == false)
    }

    /// On the in-memory launch the reset clears an already-acknowledged flag,
    /// so a fresh store over the same defaults reads `false` — the controlled
    /// "not acknowledged" start a UI test needs.
    @Test func theResetClearsAnAcknowledgedFlagOnTheInMemoryStore() {
        withFreshDefaults { defaults in
            UserDefaultsPhotoNoticeStore(defaults: defaults).acknowledge()
            UserDefaultsPhotoNoticeStore.resetForUITesting(mode: .ephemeral, defaults: defaults)
            #expect(UserDefaultsPhotoNoticeStore(defaults: defaults).hasAcknowledged == false)
        }
    }

    /// A persistent store refuses the reset: the person's acknowledgement
    /// survives even when `resetForUITesting` is called against it. This is the
    /// "refusing a persistent store" the 003 amendment asks to be shown, and
    /// the mutation target — loosen the guard and this goes red.
    @Test func theResetRefusesAPersistentStore() {
        withFreshDefaults { defaults in
            UserDefaultsPhotoNoticeStore(defaults: defaults).acknowledge()
            UserDefaultsPhotoNoticeStore.resetForUITesting(mode: .localOnly, defaults: defaults)
            #expect(UserDefaultsPhotoNoticeStore(defaults: defaults).hasAcknowledged == true)
        }
    }
}
