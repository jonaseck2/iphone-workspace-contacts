import Testing
import Contacts
@testable import WorkspaceContacts
import WorkspaceContactsCore

private func person(_ id: String, given: String, family: String, phone: String) -> DirectoryPerson {
    DirectoryPerson(
        resourceName: "people/\(id)", etag: nil, displayName: "\(given) \(family)",
        givenName: given, familyName: family, emails: ["\(given.lowercased())@imeto.com"],
        phoneNumbers: [phone], organizationTitle: "Engineer", department: nil, photoURL: nil
    )
}

/// Integration test against the Simulator's Contacts DB. Requires contacts access pre-granted
/// (see the Run step: `simctl privacy … grant contacts`). If access isn't authorized, records an
/// issue rather than silently passing.
@Suite(.serialized) struct CNContactStoreWriterTests {
    private func requireAuthorized() -> Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    @Test func createReadUpdateDelete() throws {
        guard requireAuthorized() else {
            Issue.record("Contacts not authorized; run `xcrun simctl privacy booted grant contacts com.imeto.workspacecontacts.app` before testing.")
            return
        }
        let writer = CNContactStoreWriter()
        // clean slate
        try writer.removeAll()

        // create
        let p = person("t1", given: "Ada", family: "Lovelace", phone: "+46701234567")
        let id = try writer.create(p)
        #expect(!id.isEmpty)

        // read back
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [CNContactGivenNameKey, CNContactFamilyNameKey,
                                       CNContactPhoneNumbersKey].map { $0 as CNKeyDescriptor }
        let fetched = try store.unifiedContact(withIdentifier: id, keysToFetch: keys)
        #expect(fetched.givenName == "Ada")
        #expect(fetched.familyName == "Lovelace")
        #expect(fetched.phoneNumbers.first?.value.stringValue == "+46701234567")

        // update
        let p2 = person("t1", given: "Ada", family: "Byron", phone: "+46700000000")
        try writer.update(identifier: id, with: p2)
        let updated = try store.unifiedContact(withIdentifier: id, keysToFetch: keys)
        #expect(updated.familyName == "Byron")
        #expect(updated.phoneNumbers.first?.value.stringValue == "+46700000000")

        // delete
        try writer.delete(identifier: id)
        #expect((try? store.unifiedContact(withIdentifier: id, keysToFetch: keys)) == nil)

        // cleanup group
        try writer.removeAll()
    }

    /// removeAll() must delete the group's *members*, not just the (empty) group. This exercises the
    /// path createReadUpdateDelete skips (it deletes its one contact by identifier before removeAll).
    /// Lives in this same serialized suite so it never runs concurrently with the Contacts writes
    /// above (swift-testing parallelizes across suites, and they share the one address book).
    @Test func removeAllDeletesGroupMembers() throws {
        guard requireAuthorized() else {
            Issue.record("Contacts not authorized; run `xcrun simctl privacy booted grant contacts com.imeto.workspacecontacts.app`.")
            return
        }
        let store = CNContactStore()
        let writer = CNContactStoreWriter()
        try writer.removeAll()

        _ = try writer.create(person("ra1", given: "Alpha", family: "RemoveAllTest", phone: "+46701111111"))
        _ = try writer.create(person("ra2", given: "Beta", family: "RemoveAllTest", phone: "+46702222222"))

        // The two we just created exist in the address book (match by our unique family name,
        // so a leftover from another test can't skew the count).
        let mineBefore = try store.unifiedContacts(
            matching: CNContact.predicateForContacts(matchingName: "RemoveAllTest"),
            keysToFetch: [CNContactGivenNameKey as CNKeyDescriptor])
        #expect(mineBefore.count == 2)

        try writer.removeAll()

        let mineAfter = try store.unifiedContacts(
            matching: CNContact.predicateForContacts(matchingName: "RemoveAllTest"),
            keysToFetch: [CNContactGivenNameKey as CNKeyDescriptor])
        #expect(mineAfter.isEmpty)
    }
}
