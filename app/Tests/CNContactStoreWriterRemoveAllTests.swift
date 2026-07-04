import Testing
import Contacts
@testable import WorkspaceContacts
import WorkspaceContactsCore

/// Verifies `removeAll()` actually deletes the group's *members* (the path Task 4's test missed —
/// it deleted its one contact by identifier before calling removeAll, so the group was empty).
@Suite(.serialized) struct CNContactStoreWriterRemoveAllTests {
    private func requireAuthorized() -> Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    private func person(_ id: String, given: String, phone: String) -> DirectoryPerson {
        DirectoryPerson(resourceName: "people/\(id)", displayName: "\(given) RemoveAllTest",
                        givenName: given, familyName: "RemoveAllTest", phoneNumbers: [phone])
    }

    @Test func removeAllDeletesGroupMembers() throws {
        guard requireAuthorized() else {
            Issue.record("Contacts not authorized; run `xcrun simctl privacy booted grant contacts com.imeto.workspacecontacts.app`.")
            return
        }
        let store = CNContactStore()
        let writer = CNContactStoreWriter()
        try writer.removeAll()

        _ = try writer.create(person("ra1", given: "Alpha", phone: "+46701111111"))
        _ = try writer.create(person("ra2", given: "Beta", phone: "+46702222222"))

        // Sanity: both live in the group.
        let group = try #require(try store.groups(matching: nil).first { $0.name == CNContactStoreWriter.groupName })
        let membersBefore = try store.unifiedContacts(
            matching: CNContact.predicateForContactsInGroup(withIdentifier: group.identifier),
            keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
        #expect(membersBefore.count == 2)

        try writer.removeAll()

        // The contacts are gone from the address book.
        let remaining = try store.unifiedContacts(
            matching: CNContact.predicateForContacts(matchingName: "RemoveAllTest"),
            keysToFetch: [CNContactGivenNameKey as CNKeyDescriptor])
        #expect(remaining.isEmpty)
    }
}
