// app/Sources/AppModel.swift
import Foundation
import WorkspaceContactsCore

enum LoadStatus: Equatable {
    case idle
    case loading
    case loaded(Int)
    case failed(String)
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var people: [DirectoryPerson] = []
    @Published private(set) var status: LoadStatus = .idle
    @Published private(set) var authState: AuthState = .signedOut

    private let auth: AuthService
    private let client: DirectoryClient

    init(auth: AuthService = AuthService(),
         client: DirectoryClient = DirectoryClient(fetcher: URLSessionHTTPFetcher())) {
        self.auth = auth
        self.client = client
    }

    func restore() async {
        await auth.restore()
        authState = auth.state
        if authState == .signedIn { await refresh() }
    }

    func signIn() async {
        await auth.signIn()
        authState = auth.state
        if authState == .signedIn { await refresh() }
    }

    func signOut() {
        auth.signOut()
        authState = auth.state
        people = []
        status = .idle
    }

    func refresh() async {
        guard let token = await auth.accessToken() else {
            status = .failed("Not signed in.")
            return
        }
        status = .loading
        do {
            let result: DirectoryFetchResult = try await client.fetchAll(token: token, syncToken: nil)
            people = result.people.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            status = .loaded(people.count)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
