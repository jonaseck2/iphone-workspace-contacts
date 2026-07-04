import Foundation
import WorkspaceContactsCore

/// Persists the sync ref-map and the one-time consent flag in UserDefaults.
struct SyncStore {
    private let defaults: UserDefaults
    private let stateKey = "workspacecontacts.syncstate"
    private let consentKey = "workspacecontacts.consentGiven"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func load() -> SyncState {
        guard let data = defaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(SyncState.self, from: data) else {
            return SyncState()
        }
        return state
    }

    func save(_ state: SyncState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: stateKey)
    }

    func clear() { defaults.removeObject(forKey: stateKey) }

    var consentGiven: Bool {
        get { defaults.bool(forKey: consentKey) }
        nonmutating set { defaults.set(newValue, forKey: consentKey) }
    }
}
