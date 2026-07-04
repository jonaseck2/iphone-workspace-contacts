// app/Sources/URLSessionHTTPFetcher.swift
import Foundation
import WorkspaceContactsCore

public enum HTTPFetchError: Error, Equatable {
    case notHTTP
    case status(Int)
}

/// Live `HTTPFetching` over URLSession. Adds the bearer token and rejects non-2xx responses.
struct URLSessionHTTPFetcher: HTTPFetching {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func get(_ url: URL, bearerToken: String) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HTTPFetchError.notHTTP }
        guard (200...299).contains(http.statusCode) else {
            throw HTTPFetchError.status(http.statusCode)
        }
        return data
    }
}
