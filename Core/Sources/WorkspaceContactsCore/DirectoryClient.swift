import Foundation

/// Abstraction over the network so the paging logic is testable without URLSession.
public protocol HTTPFetching: Sendable {
    func get(_ url: URL, bearerToken: String) async throws -> Data
}

public struct DirectoryFetchResult: Equatable {
    public let people: [DirectoryPerson]
    public let nextSyncToken: String?
    public init(people: [DirectoryPerson], nextSyncToken: String?) {
        self.people = people
        self.nextSyncToken = nextSyncToken
    }
}

/// Fetches the full directory from People API `listDirectoryPeople`, following pagination.
public struct DirectoryClient {
    private let fetcher: HTTPFetching
    private let readMask: String
    private static let base = "https://people.googleapis.com/v1/people:listDirectoryPeople"

    public init(
        fetcher: HTTPFetching,
        readMask: String = "names,phoneNumbers,emailAddresses,organizations,photos"
    ) {
        self.fetcher = fetcher
        self.readMask = readMask
    }

    public func fetchAll(token: String, syncToken: String?) async throws -> DirectoryFetchResult {
        var accumulated: [DirectoryPerson] = []
        var pageToken: String? = nil
        var latestSyncToken: String? = nil
        var isFirstRequest = true

        repeat {
            let url = makeURL(pageToken: pageToken, syncToken: isFirstRequest ? syncToken : nil)
            let data = try await fetcher.get(url, bearerToken: token)
            let response = try ListDirectoryPeopleResponse.decode(data)
            accumulated.append(contentsOf: response.people)
            latestSyncToken = response.nextSyncToken ?? latestSyncToken
            pageToken = response.nextPageToken
            isFirstRequest = false
        } while pageToken != nil

        return DirectoryFetchResult(people: accumulated, nextSyncToken: latestSyncToken)
    }

    private func makeURL(pageToken: String?, syncToken: String?) -> URL {
        var components = URLComponents(string: Self.base)!
        var items = [
            URLQueryItem(name: "readMask", value: readMask),
            URLQueryItem(name: "sources", value: "DIRECTORY_SOURCE_TYPE_DOMAIN_PROFILE"),
            URLQueryItem(name: "pageSize", value: "1000"),
        ]
        if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        if let syncToken { items.append(URLQueryItem(name: "syncToken", value: syncToken)) }
        // requestSyncToken tells People API to return a nextSyncToken for future incremental syncs.
        items.append(URLQueryItem(name: "requestSyncToken", value: "true"))
        components.queryItems = items
        return components.url!
    }
}
