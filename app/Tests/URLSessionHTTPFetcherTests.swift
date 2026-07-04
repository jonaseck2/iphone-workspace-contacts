// app/Tests/URLSessionHTTPFetcherTests.swift
import Testing
import Foundation
@testable import WorkspaceContacts

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let handler = StubURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}

private func makeSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}

// .serialized: these tests share `StubURLProtocol.handler` (static). swift-testing runs
// tests in parallel by default, which races on that shared stub; serialize them.
@Suite(.serialized) struct URLSessionHTTPFetcherTests {
    @Test func sendsBearerTokenAndReturnsBody() async throws {
        StubURLProtocol.handler = { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer TOK")
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                       httpVersion: nil, headerFields: nil)!
            return (resp, Data("{\"ok\":true}".utf8))
        }
        let fetcher = URLSessionHTTPFetcher(session: makeSession())
        let data = try await fetcher.get(URL(string: "https://example.com/x")!, bearerToken: "TOK")
        #expect(String(decoding: data, as: UTF8.self) == "{\"ok\":true}")
    }

    @Test func throwsOnNon2xx() async {
        StubURLProtocol.handler = { request in
            let resp = HTTPURLResponse(url: request.url!, statusCode: 403,
                                       httpVersion: nil, headerFields: nil)!
            return (resp, Data())
        }
        let fetcher = URLSessionHTTPFetcher(session: makeSession())
        await #expect(throws: HTTPFetchError.status(403)) {
            _ = try await fetcher.get(URL(string: "https://example.com/x")!, bearerToken: "TOK")
        }
    }
}
