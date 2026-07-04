// app/Sources/URLSessionHTTPFetcher.swift
import Foundation
import WorkspaceContactsCore

public enum HTTPFetchError: Error, Equatable {
    case notHTTP
    /// Non-2xx response. Carries the status code and the (truncated) response body, which for
    /// the People API is a JSON error explaining the cause (e.g. API not enabled, scope, sharing).
    case status(Int, body: String)
}

extension HTTPFetchError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notHTTP:
            return "The server response was not HTTP."
        case .status(let code, let body):
            let snippet = body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(600)
            return snippet.isEmpty ? "HTTP \(code)" : "HTTP \(code): \(snippet)"
        }
    }
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
            throw HTTPFetchError.status(http.statusCode, body: String(decoding: data, as: UTF8.self))
        }
        return data
    }
}
