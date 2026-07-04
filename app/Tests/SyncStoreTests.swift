import Testing
import Foundation
@testable import WorkspaceContacts
import WorkspaceContactsCore

@Suite struct SyncStoreTests {
    private func freshDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "SyncStoreTests")!
        d.removePersistentDomain(forName: "SyncStoreTests")
        return d
    }

    @Test func savesAndLoadsState() {
        let store = SyncStore(defaults: freshDefaults())
        let state = SyncState(refs: [SyncedContactRef(resourceName: "people/1", contactIdentifier: "A", contentHash: "h")])
        store.save(state)
        #expect(store.load() == state)
    }

    @Test func loadDefaultsToEmpty() {
        #expect(SyncStore(defaults: freshDefaults()).load().refs.isEmpty)
    }

    @Test func clearResetsState() {
        let store = SyncStore(defaults: freshDefaults())
        store.save(SyncState(refs: [SyncedContactRef(resourceName: "people/1", contactIdentifier: "A", contentHash: "h")]))
        store.clear()
        #expect(store.load().refs.isEmpty)
    }

    @Test func consentPersists() {
        let store = SyncStore(defaults: freshDefaults())
        #expect(store.consentGiven == false)
        store.consentGiven = true
        #expect(store.consentGiven == true)
    }
}
