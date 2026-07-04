import Testing
@testable import WorkspaceContactsCore

@Suite struct ContactSyncTests {
    private let cc = "46"

    private func person(_ id: String, name: String, phone: String?) -> DirectoryPerson {
        DirectoryPerson(
            resourceName: id,
            displayName: name,
            phoneNumbers: phone.map { [$0] } ?? []
        )
    }

    @Test func createsNewPeopleWithPhone() {
        let fetched = [person("people/c1", name: "Jane", phone: "0701234567")]
        let ops = ContactSync.plan(existing: [], fetched: fetched, defaultCountryCode: cc)
        #expect(ops == [.create(fetched[0])])
    }

    @Test func skipsPeopleWithoutNormalizablePhone() {
        let fetched = [
            person("people/c1", name: "NoPhone", phone: nil),
            person("people/c2", name: "JunkPhone", phone: "abc"),
        ]
        let ops = ContactSync.plan(existing: [], fetched: fetched, defaultCountryCode: cc)
        #expect(ops == [])
    }

    @Test func noOpWhenHashUnchanged() {
        let jane = person("people/c1", name: "Jane", phone: "0701234567")
        let existing = [SyncedContactRef(
            resourceName: "people/c1",
            contactIdentifier: "ABC",
            contentHash: jane.contentHash(defaultCountryCode: cc)
        )]
        let ops = ContactSync.plan(existing: existing, fetched: [jane], defaultCountryCode: cc)
        #expect(ops == [])
    }

    @Test func updatesWhenContentChanged() {
        let old = person("people/c1", name: "Jane", phone: "0701234567")
        let new = person("people/c1", name: "Jane Doe", phone: "0701234567")
        let existing = [SyncedContactRef(
            resourceName: "people/c1",
            contactIdentifier: "ABC",
            contentHash: old.contentHash(defaultCountryCode: cc)
        )]
        let ops = ContactSync.plan(existing: existing, fetched: [new], defaultCountryCode: cc)
        #expect(ops == [.update(contactIdentifier: "ABC", new)])
    }

    @Test func deletesWhenPersonGone() {
        let existing = [SyncedContactRef(
            resourceName: "people/c1",
            contactIdentifier: "ABC",
            contentHash: "whatever"
        )]
        let ops = ContactSync.plan(existing: existing, fetched: [], defaultCountryCode: cc)
        #expect(ops == [.delete(contactIdentifier: "ABC")])
    }

    @Test func personLosingPhone_isDeleted() {
        let existing = [SyncedContactRef(
            resourceName: "people/c1",
            contactIdentifier: "ABC",
            contentHash: "whatever"
        )]
        let nowNoPhone = [person("people/c1", name: "Jane", phone: nil)]
        let ops = ContactSync.plan(existing: existing, fetched: nowNoPhone, defaultCountryCode: cc)
        #expect(ops == [.delete(contactIdentifier: "ABC")])
    }

    @Test func ordering_createsThenUpdatesThenDeletes() {
        let create = person("people/new", name: "New", phone: "0700000001")
        let updOld = person("people/upd", name: "Old", phone: "0700000002")
        let updNew = person("people/upd", name: "Updated", phone: "0700000002")
        let existing = [
            SyncedContactRef(resourceName: "people/upd", contactIdentifier: "U",
                             contentHash: updOld.contentHash(defaultCountryCode: cc)),
            SyncedContactRef(resourceName: "people/gone", contactIdentifier: "G",
                             contentHash: "x"),
        ]
        let ops = ContactSync.plan(existing: existing, fetched: [create, updNew], defaultCountryCode: cc)
        #expect(ops == [
            .create(create),
            .update(contactIdentifier: "U", updNew),
            .delete(contactIdentifier: "G"),
        ])
    }
}
