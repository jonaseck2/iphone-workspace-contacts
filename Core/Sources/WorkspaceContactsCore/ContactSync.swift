import Foundation

/// A record of a contact we previously wrote, used to diff against a fresh fetch.
public struct SyncedContactRef: Equatable, Codable, Sendable {
    public let resourceName: String
    public let contactIdentifier: String
    public let contentHash: String
    public init(resourceName: String, contactIdentifier: String, contentHash: String) {
        self.resourceName = resourceName
        self.contactIdentifier = contactIdentifier
        self.contentHash = contentHash
    }
}

/// An operation the app should apply to CNContactStore.
public enum ContactOp: Equatable {
    case create(DirectoryPerson)
    case update(contactIdentifier: String, DirectoryPerson)
    case delete(contactIdentifier: String)
}

public extension DirectoryPerson {
    /// A stable string capturing the fields we mirror into a contact. If this changes, the
    /// contact needs updating. Phones are normalized so formatting-only changes don't churn.
    func contentHash(defaultCountryCode: String) -> String {
        let normalizedPhones = phoneNumbers
            .compactMap { PhoneNormalizer.e164($0, defaultCountryCode: defaultCountryCode) }
            .sorted()
        let parts: [String] = [
            displayName,
            givenName ?? "",
            familyName ?? "",
            emails.sorted().joined(separator: ","),
            normalizedPhones.joined(separator: ","),
            organizationTitle ?? "",
            department ?? "",
            photoURL ?? "",
        ]
        return parts.joined(separator: "|")
    }

    /// True if this person has at least one phone number we can normalize.
    func hasNormalizablePhone(defaultCountryCode: String) -> Bool {
        phoneNumbers.contains { PhoneNormalizer.e164($0, defaultCountryCode: defaultCountryCode) != nil }
    }
}

/// Pure diff: given what we synced before and what the directory returns now, produce the
/// create/update/delete operations to reconcile them.
public enum ContactSync {
    public static func plan(
        existing: [SyncedContactRef],
        fetched: [DirectoryPerson],
        defaultCountryCode: String
    ) -> [ContactOp] {
        let eligible = fetched.filter { $0.hasNormalizablePhone(defaultCountryCode: defaultCountryCode) }
        let existingByResource = Dictionary(
            existing.map { ($0.resourceName, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let eligibleResourceNames = Set(eligible.map(\.resourceName))

        var creates: [ContactOp] = []
        var updates: [ContactOp] = []
        var deletes: [ContactOp] = []

        for person in eligible {
            if let ref = existingByResource[person.resourceName] {
                if ref.contentHash != person.contentHash(defaultCountryCode: defaultCountryCode) {
                    updates.append(.update(contactIdentifier: ref.contactIdentifier, person))
                }
            } else {
                creates.append(.create(person))
            }
        }

        for ref in existing where !eligibleResourceNames.contains(ref.resourceName) {
            deletes.append(.delete(contactIdentifier: ref.contactIdentifier))
        }

        return creates + updates + deletes
    }
}
