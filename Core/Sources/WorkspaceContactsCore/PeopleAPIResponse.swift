import Foundation

/// Decodes the JSON shape returned by People API `people.listDirectoryPeople`
/// and flattens each person into a `DirectoryPerson`.
public struct ListDirectoryPeopleResponse: Decodable {
    public let people: [DirectoryPerson]
    public let nextPageToken: String?
    public let nextSyncToken: String?

    private enum CodingKeys: String, CodingKey {
        case people, nextPageToken, nextSyncToken
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decodeIfPresent([RawPerson].self, forKey: .people) ?? []
        self.people = raw.map { $0.flattened() }
        self.nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
        self.nextSyncToken = try container.decodeIfPresent(String.self, forKey: .nextSyncToken)
    }

    public static func decode(_ data: Data) throws -> ListDirectoryPeopleResponse {
        try JSONDecoder().decode(ListDirectoryPeopleResponse.self, from: data)
    }
}

// MARK: - Raw People API shapes (private)

private struct RawMetadata: Decodable { let primary: Bool? }

private struct RawName: Decodable {
    let displayName: String?
    let givenName: String?
    let familyName: String?
    let metadata: RawMetadata?
}

private struct RawValue: Decodable {
    let value: String?
    let metadata: RawMetadata?
}

private struct RawOrganization: Decodable {
    let title: String?
    let department: String?
    let metadata: RawMetadata?
}

private struct RawPhoto: Decodable {
    let url: String?
    let metadata: RawMetadata?
}

private struct RawPerson: Decodable {
    let resourceName: String
    let etag: String?
    let names: [RawName]?
    let emailAddresses: [RawValue]?
    let phoneNumbers: [RawValue]?
    let organizations: [RawOrganization]?
    let photos: [RawPhoto]?

    func flattened() -> DirectoryPerson {
        let primaryName = names?.first(where: { $0.metadata?.primary == true }) ?? names?.first
        let primaryOrg = organizations?.first(where: { $0.metadata?.primary == true }) ?? organizations?.first
        let primaryPhoto = photos?.first(where: { $0.metadata?.primary == true }) ?? photos?.first

        return DirectoryPerson(
            resourceName: resourceName,
            etag: etag,
            displayName: primaryName?.displayName ?? "",
            givenName: primaryName?.givenName,
            familyName: primaryName?.familyName,
            emails: (emailAddresses ?? []).compactMap { $0.value },
            phoneNumbers: (phoneNumbers ?? []).compactMap { $0.value },
            organizationTitle: primaryOrg?.title,
            department: primaryOrg?.department,
            photoURL: primaryPhoto?.url
        )
    }
}
