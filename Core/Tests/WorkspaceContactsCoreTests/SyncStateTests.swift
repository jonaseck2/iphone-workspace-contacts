import Testing
import Foundation
@testable import WorkspaceContactsCore

@Suite struct SyncStateTests {
    @Test func roundTripsThroughJSON() throws {
        let state = SyncState(refs: [
            SyncedContactRef(resourceName: "people/1", contactIdentifier: "ABC", contentHash: "h1"),
            SyncedContactRef(resourceName: "people/2", contactIdentifier: "DEF", contentHash: "h2"),
        ])
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(SyncState.self, from: data)
        #expect(decoded == state)
    }

    @Test func defaultsToEmpty() {
        #expect(SyncState().refs.isEmpty)
    }
}
