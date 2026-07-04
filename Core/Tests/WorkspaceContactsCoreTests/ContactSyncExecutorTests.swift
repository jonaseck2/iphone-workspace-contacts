import Testing
@testable import WorkspaceContactsCore

private func person(_ id: String, phone: String, name: String) -> DirectoryPerson {
    DirectoryPerson(
        resourceName: "people/\(id)", etag: nil, displayName: name,
        givenName: name, familyName: nil, emails: [], phoneNumbers: [phone],
        organizationTitle: nil, department: nil, photoURL: nil
    )
}

/// Records calls and hands back deterministic identifiers; can be told to throw for a resource.
private final class FakeStore: ContactStoreWriting, @unchecked Sendable {
    enum StoreError: Error { case boom }
    var created: [DirectoryPerson] = []
    var updated: [(String, DirectoryPerson)] = []
    var deleted: [String] = []
    var failCreateForResource: String? = nil
    var failUpdateNotFound: Set<String> = []
    var failDeleteNotFound: Set<String> = []
    private var counter = 0

    func create(_ person: DirectoryPerson) throws -> String {
        if person.resourceName == failCreateForResource { throw StoreError.boom }
        created.append(person)
        counter += 1
        return "id-\(counter)"
    }
    func update(identifier: String, with person: DirectoryPerson) throws {
        if failUpdateNotFound.contains(identifier) { throw ContactStoreError.notFound(identifier) }
        updated.append((identifier, person))
    }
    func delete(identifier: String) throws {
        if failDeleteNotFound.contains(identifier) { throw ContactStoreError.notFound(identifier) }
        deleted.append(identifier)
    }
}

@Suite struct ContactSyncExecutorTests {
    private let code = "46"

    @Test func createAssignsIdentifierAndRef() {
        let store = FakeStore()
        let p = person("1", phone: "0701234567", name: "Ada")
        let result = ContactSyncExecutor.apply([.create(p)], using: store, existing: [], defaultCountryCode: code)
        #expect(store.created.count == 1)
        #expect(result.failures.isEmpty)
        #expect(result.refs == [
            SyncedContactRef(resourceName: "people/1", contactIdentifier: "id-1",
                             contentHash: p.contentHash(defaultCountryCode: code))
        ])
    }

    @Test func updateKeepsIdentifierRefreshesHash() {
        let store = FakeStore()
        let p = person("1", phone: "0701234567", name: "Ada B")
        let existing = [SyncedContactRef(resourceName: "people/1", contactIdentifier: "keep-1", contentHash: "old")]
        let result = ContactSyncExecutor.apply(
            [.update(contactIdentifier: "keep-1", p)], using: store, existing: existing, defaultCountryCode: code)
        #expect(store.updated.map(\.0) == ["keep-1"])
        #expect(result.refs == [
            SyncedContactRef(resourceName: "people/1", contactIdentifier: "keep-1",
                             contentHash: p.contentHash(defaultCountryCode: code))
        ])
    }

    @Test func deleteDropsRef() {
        let store = FakeStore()
        let existing = [SyncedContactRef(resourceName: "people/1", contactIdentifier: "gone-1", contentHash: "h")]
        let result = ContactSyncExecutor.apply(
            [.delete(contactIdentifier: "gone-1")], using: store, existing: existing, defaultCountryCode: code)
        #expect(store.deleted == ["gone-1"])
        #expect(result.refs.isEmpty)
    }

    @Test func failedOpIsRecordedWithoutAbortingBatch() {
        let store = FakeStore()
        store.failCreateForResource = "people/1"
        let p1 = person("1", phone: "0701234567", name: "Ada")
        let p2 = person("2", phone: "0709999999", name: "Bea")
        let result = ContactSyncExecutor.apply([.create(p1), .create(p2)], using: store, existing: [], defaultCountryCode: code)
        #expect(result.failures.count == 1)
        #expect(result.failures.first?.op == .create(p1))
        // p2 still created despite p1 failing
        #expect(result.refs.map(\.resourceName) == ["people/2"])
    }

    @Test func updateNotFoundDropsRefSoNextSyncRecreates() {
        let store = FakeStore()
        store.failUpdateNotFound = ["dead-1"]
        let p = person("1", phone: "0701234567", name: "Ada")
        let existing = [SyncedContactRef(resourceName: "people/1", contactIdentifier: "dead-1", contentHash: "old")]
        let result = ContactSyncExecutor.apply(
            [.update(contactIdentifier: "dead-1", p)], using: store, existing: existing, defaultCountryCode: code)
        #expect(result.failures.count == 1)
        #expect(result.refs.isEmpty)
    }

    @Test func deleteNotFoundDropsStaleRef() {
        let store = FakeStore()
        store.failDeleteNotFound = ["gone-1"]
        let existing = [SyncedContactRef(resourceName: "people/1", contactIdentifier: "gone-1", contentHash: "h")]
        let result = ContactSyncExecutor.apply(
            [.delete(contactIdentifier: "gone-1")], using: store, existing: existing, defaultCountryCode: code)
        #expect(result.refs.isEmpty)
    }

    @Test func checkpointFiresPerSuccessfulOp() {
        let store = FakeStore()
        var checkpoints = 0
        let p1 = person("1", phone: "0701234567", name: "Ada")
        let p2 = person("2", phone: "0709999999", name: "Bea")
        _ = ContactSyncExecutor.apply([.create(p1), .create(p2)], using: store, existing: [],
                                      defaultCountryCode: code, checkpoint: { _ in checkpoints += 1 })
        #expect(checkpoints == 2)
    }
}
