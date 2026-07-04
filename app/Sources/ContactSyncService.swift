// app/Sources/ContactSyncService.swift
import Contacts
import Foundation
import WorkspaceContactsCore

struct ContactSyncSummary: Equatable {
    let created: Int
    let updated: Int
    let deleted: Int
    let failed: Int
}

enum ContactSyncError: Error { case accessDenied }

/// Orchestrates one sync run: diff the full directory against persisted refs, apply to Contacts,
/// persist the new refs. Full-fetch diffing (ContactSync.plan is a full-set diff).
@MainActor
final class ContactSyncService {
    private let store: SyncStore
    private let writer: CNContactStoreWriter
    private let defaultCountryCode = "46"

    init(store: SyncStore = SyncStore(), writer: CNContactStoreWriter = CNContactStoreWriter()) {
        self.store = store
        self.writer = writer
    }

    func requestAccess() async -> Bool { await writer.requestAccess() }

    /// Diff `people` (the complete directory) against persisted refs and apply.
    func sync(people: [DirectoryPerson]) throws -> ContactSyncSummary {
        guard CNContactStore.authorizationStatus(for: .contacts) == .authorized else {
            throw ContactSyncError.accessDenied
        }
        let existing = store.load().refs
        let ops = ContactSync.plan(existing: existing, fetched: people, defaultCountryCode: defaultCountryCode)
        let result = ContactSyncExecutor.apply(
            ops, using: writer, existing: existing, defaultCountryCode: defaultCountryCode,
            checkpoint: { [store] refs in store.save(SyncState(refs: refs)) }
        )
        store.save(SyncState(refs: result.refs))

        var created = 0, updated = 0, deleted = 0
        for op in ops {
            switch op {
            case .create: created += 1
            case .update: updated += 1
            case .delete: deleted += 1
            }
        }
        return ContactSyncSummary(created: created, updated: updated, deleted: deleted,
                                  failed: result.failures.count)
    }

    /// Fetch the full directory, then sync. Used by the background task (no AppModel in memory).
    func syncFromNetwork(token: String, client: DirectoryClient) async throws -> ContactSyncSummary {
        let result = try await client.fetchAll(token: token, syncToken: nil)
        return try sync(people: result.people)
    }

    func removeAll() throws {
        try writer.removeAll()
        store.clear()
    }
}

/// Self-contained background sync entry point for `.backgroundTask(.appRefresh)`.
enum BackgroundSync {
    @MainActor
    static func run() async {
        let store = SyncStore()
        guard store.consentGiven else { return }
        let auth = AuthService()
        await auth.restore()
        guard auth.state == .signedIn, let token = await auth.accessToken() else { return }
        let client = DirectoryClient(fetcher: URLSessionHTTPFetcher())
        let service = ContactSyncService(store: store)
        _ = try? await service.syncFromNetwork(token: token, client: client)
    }
}
