// app/Sources/AppModel.swift
import Foundation
import WorkspaceContactsCore

enum LoadStatus: Equatable {
    case idle
    case loading
    case loaded(Int)
    case failed(String)
}

enum SyncStatus: Equatable {
    case idle
    case syncing
    case synced(count: Int, at: Date)
    case failed(String)
    case permissionDenied
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var people: [DirectoryPerson] = []
    @Published private(set) var status: LoadStatus = .idle
    @Published private(set) var authState: AuthState = .signedOut
    @Published private(set) var consentGiven: Bool
    @Published private(set) var syncStatus: SyncStatus = .idle

    private let auth: AuthService
    private let client: DirectoryClient
    private let syncService: ContactSyncService
    private let syncStore: SyncStore

    init(auth: AuthService = AuthService(),
         client: DirectoryClient = DirectoryClient(fetcher: URLSessionHTTPFetcher()),
         syncStore: SyncStore = SyncStore(),
         syncService: ContactSyncService = ContactSyncService()) {
        self.auth = auth
        self.client = client
        self.syncStore = syncStore
        self.syncService = syncService
        self.consentGiven = syncStore.consentGiven
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

    func signOut() async {
        // Always remove synced contacts on sign-out (product decision).
        // Attempt to remove synced contacts. If Contacts access was revoked we can't remove them
        // (an OS constraint) — sign-out still proceeds; contacts may remain until access is restored.
        try? syncService.removeAll()
        auth.signOut()
        authState = auth.state
        people = []
        status = .idle
        syncStatus = .idle
    }

    func refresh() async {
        guard let token = await auth.accessToken() else {
            status = .failed("Not signed in.")
            return
        }
        status = .loading
        do {
            let result = try await client.fetchAll(token: token, syncToken: nil)
            people = result.people.sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
            status = .loaded(people.count)
            if consentGiven { await runSync() }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    /// One-time consent path: request Contacts permission, persist consent, first sync.
    func enableSyncWithConsent() async {
        let granted = await syncService.requestAccess()
        guard granted else { syncStatus = .permissionDenied; return }
        syncStore.consentGiven = true
        consentGiven = true
        await runSync()
    }

    func syncNow() async { await refresh() }

    func removeAllSyncedContacts() async {
        do {
            try syncService.removeAll()
            syncStatus = .idle
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
    }

    private func runSync() async {
        guard case .loaded = status else { return }
        syncStatus = .syncing
        do {
            let summary = try syncService.sync(people: people)
            if summary.failed > 0 {
                syncStatus = .failed("\(summary.failed) contact(s) couldn't be saved.")
            } else {
                syncStatus = .synced(count: people.count, at: Date())
            }
        } catch ContactSyncError.accessDenied {
            syncStatus = .permissionDenied
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
    }
}
