import Foundation

/// A person from the Google Workspace directory, flattened for our use.
public struct DirectoryPerson: Equatable, Sendable {
    public let resourceName: String
    public let etag: String?
    public let displayName: String
    public let givenName: String?
    public let familyName: String?
    public let emails: [String]
    public let phoneNumbers: [String]
    public let organizationTitle: String?
    public let department: String?
    public let photoURL: String?

    public init(
        resourceName: String,
        etag: String? = nil,
        displayName: String,
        givenName: String? = nil,
        familyName: String? = nil,
        emails: [String] = [],
        phoneNumbers: [String] = [],
        organizationTitle: String? = nil,
        department: String? = nil,
        photoURL: String? = nil
    ) {
        self.resourceName = resourceName
        self.etag = etag
        self.displayName = displayName
        self.givenName = givenName
        self.familyName = familyName
        self.emails = emails
        self.phoneNumbers = phoneNumbers
        self.organizationTitle = organizationTitle
        self.department = department
        self.photoURL = photoURL
    }
}
