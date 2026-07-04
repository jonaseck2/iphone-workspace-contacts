import Foundation

/// Persisted sync bookkeeping: the map of directory people we've written to the address book.
/// A thin, versionable wrapper (kept as a struct so fields can be added later without breaking
/// the stored JSON shape).
public struct SyncState: Codable, Equatable, Sendable {
    public var refs: [SyncedContactRef]
    public init(refs: [SyncedContactRef] = []) {
        self.refs = refs
    }
}
