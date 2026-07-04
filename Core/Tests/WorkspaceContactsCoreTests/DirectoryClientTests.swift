import Testing
import Foundation
@testable import WorkspaceContactsCore

private final class StubFetcher: HTTPFetching, @unchecked Sendable {
    var responses: [Data]
    private(set) var requestedURLs: [URL] = []
    private(set) var tokens: [String] = []

    init(responses: [Data]) { self.responses = responses }

    func get(_ url: URL, bearerToken: String) async throws -> Data {
        requestedURLs.append(url)
        tokens.append(bearerToken)
        return responses.removeFirst()
    }
}

@Suite struct DirectoryClientTests {

    private func page(people: String, nextPage: String?, nextSync: String?) -> Data {
        var obj = "{\"people\":[\(people)]"
        if let n = nextPage { obj += ",\"nextPageToken\":\"\(n)\"" }
        if let s = nextSync { obj += ",\"nextSyncToken\":\"\(s)\"" }
        obj += "}"
        return obj.data(using: .utf8)!
    }

    private let p1 = "{\"resourceName\":\"people/c1\",\"names\":[{\"displayName\":\"A\"}]}"
    private let p2 = "{\"resourceName\":\"people/c2\",\"names\":[{\"displayName\":\"B\"}]}"

    @Test func followsPaging_andReturnsFinalSyncToken() async throws {
        let fetcher = StubFetcher(responses: [
            page(people: p1, nextPage: "PAGE2", nextSync: nil),
            page(people: p2, nextPage: nil, nextSync: "SYNC-END"),
        ])
        let client = DirectoryClient(fetcher: fetcher)

        let result = try await client.fetchAll(token: "TOKEN123", syncToken: nil)

        #expect(result.people.map(\.resourceName) == ["people/c1", "people/c2"])
        #expect(result.nextSyncToken == "SYNC-END")
        #expect(fetcher.requestedURLs.count == 2)
        #expect(fetcher.tokens == ["TOKEN123", "TOKEN123"])
    }

    @Test func singlePage_returnsSyncToken() async throws {
        let fetcher = StubFetcher(responses: [
            page(people: p1, nextPage: nil, nextSync: "SYNC-1"),
        ])
        let client = DirectoryClient(fetcher: fetcher)

        let result = try await client.fetchAll(token: "T", syncToken: "PREV")

        #expect(result.people.count == 1)
        #expect(result.nextSyncToken == "SYNC-1")
        #expect(fetcher.requestedURLs.count == 1)
        // The prior syncToken must be sent as a query item on the first request.
        #expect(fetcher.requestedURLs[0].absoluteString.contains("syncToken=PREV"))
    }

    @Test func readMaskAndSourceAreOnRequest() async throws {
        let fetcher = StubFetcher(responses: [
            page(people: p1, nextPage: nil, nextSync: "S"),
        ])
        let client = DirectoryClient(fetcher: fetcher)
        _ = try await client.fetchAll(token: "T", syncToken: nil)

        let url = fetcher.requestedURLs[0].absoluteString
        #expect(url.contains("readMask=names"))
        #expect(url.contains("sources=DIRECTORY_SOURCE_TYPE_DOMAIN_PROFILE"))
    }
}
