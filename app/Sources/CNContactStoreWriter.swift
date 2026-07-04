import Contacts
import WorkspaceContactsCore

/// Live `ContactStoreWriting` over CNContactStore. Tags every contact into a dedicated
/// "Imeto Directory" CNGroup (the source of truth for "remove all").
// @unchecked Sendable: CNContactStore is documented thread-safe; the struct's only stored
// property is that store, so it is safe to share across isolation domains.
struct CNContactStoreWriter: ContactStoreWriting, @unchecked Sendable {
    static let groupName = "Imeto Directory"
    static let companyName = "Imeto"

    private let store: CNContactStore
    init(store: CNContactStore = CNContactStore()) { self.store = store }

    func requestAccess() async -> Bool {
        (try? await store.requestAccess(for: .contacts)) ?? false
    }

    func create(_ person: DirectoryPerson) throws -> String {
        let group = try ensureGroup()
        let contact = CNMutableContact()
        Self.apply(person, to: contact)
        let save = CNSaveRequest()
        save.add(contact, toContainerWithIdentifier: nil)
        save.addMember(contact, to: group)
        try store.execute(save)
        return contact.identifier
    }

    func update(identifier: String, with person: DirectoryPerson) throws {
        guard let existing = try? store.unifiedContact(withIdentifier: identifier, keysToFetch: Self.fetchKeys),
              let mutable = existing.mutableCopy() as? CNMutableContact else {
            throw ContactStoreError.notFound(identifier)
        }
        Self.apply(person, to: mutable)
        let save = CNSaveRequest()
        save.update(mutable)
        try store.execute(save)
    }

    func delete(identifier: String) throws {
        guard let existing = try? store.unifiedContact(withIdentifier: identifier,
                                                       keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]),
              let mutable = existing.mutableCopy() as? CNMutableContact else {
            throw ContactStoreError.notFound(identifier)
        }
        let save = CNSaveRequest()
        save.delete(mutable)
        try store.execute(save)
    }

    /// Delete every contact in the group (robust even if the persisted map is lost), then the group.
    func removeAll() throws {
        guard let group = try store.groups(matching: nil).first(where: { $0.name == Self.groupName }) else { return }
        let predicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
        let members = try store.unifiedContacts(matching: predicate,
                                                keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
        let save = CNSaveRequest()
        for m in members {
            if let mutable = m.mutableCopy() as? CNMutableContact { save.delete(mutable) }
        }
        if let mutableGroup = group.mutableCopy() as? CNMutableGroup { save.delete(mutableGroup) }
        try store.execute(save)
    }

    // MARK: - Private

    private func ensureGroup() throws -> CNGroup {
        if let existing = try store.groups(matching: nil).first(where: { $0.name == Self.groupName }) {
            return existing
        }
        let group = CNMutableGroup()
        group.name = Self.groupName
        let save = CNSaveRequest()
        save.add(group, toContainerWithIdentifier: nil)
        try store.execute(save)
        return group
    }

    static var fetchKeys: [CNKeyDescriptor] {
        [
            CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey, CNContactOrganizationNameKey, CNContactJobTitleKey,
            CNContactDepartmentNameKey, CNContactIdentifierKey,
        ].map { $0 as CNKeyDescriptor }
    }

    private static func apply(_ person: DirectoryPerson, to c: CNMutableContact) {
        c.givenName = person.givenName ?? person.displayName
        c.familyName = person.familyName ?? ""
        c.organizationName = companyName
        c.jobTitle = person.organizationTitle ?? ""
        c.departmentName = person.department ?? ""
        c.phoneNumbers = person.phoneNumbers.map {
            CNLabeledValue(label: CNLabelWork, value: CNPhoneNumber(stringValue: $0))
        }
        c.emailAddresses = person.emails.map {
            CNLabeledValue(label: CNLabelWork, value: $0 as NSString)
        }
    }
}
