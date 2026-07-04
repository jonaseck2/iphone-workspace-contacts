import Foundation

/// Abstract seam over the platform address book so the apply logic stays pure and headless-testable.
/// The live implementation (CNContactStore) lives in the app target.
public protocol ContactStoreWriting: Sendable {
    /// Create a contact for `person`; return its stable contact identifier.
    func create(_ person: DirectoryPerson) throws -> String
    /// Overwrite the mapped fields of the contact with `identifier`.
    func update(identifier: String, with person: DirectoryPerson) throws
    /// Delete the contact with `identifier`.
    func delete(identifier: String) throws
}

/// Applies a `ContactSync.plan` diff through a `ContactStoreWriting`, returning the new ref set.
/// A failing op is recorded and skipped — one bad contact never aborts the batch.
public enum ContactSyncExecutor {
    public struct Failure: Equatable {
        public let op: ContactOp
        public let message: String
        public init(op: ContactOp, message: String) { self.op = op; self.message = message }
    }

    public struct ExecutionResult: Equatable {
        public let refs: [SyncedContactRef]
        public let failures: [Failure]
        public init(refs: [SyncedContactRef], failures: [Failure]) {
            self.refs = refs; self.failures = failures
        }
    }

    public static func apply(
        _ ops: [ContactOp],
        using store: ContactStoreWriting,
        existing: [SyncedContactRef],
        defaultCountryCode: String
    ) -> ExecutionResult {
        var byResource = Dictionary(existing.map { ($0.resourceName, $0) }, uniquingKeysWith: { a, _ in a })
        var resourceByIdentifier = Dictionary(existing.map { ($0.contactIdentifier, $0.resourceName) },
                                              uniquingKeysWith: { a, _ in a })
        var failures: [Failure] = []

        for op in ops {
            switch op {
            case .create(let person):
                do {
                    let id = try store.create(person)
                    byResource[person.resourceName] = SyncedContactRef(
                        resourceName: person.resourceName, contactIdentifier: id,
                        contentHash: person.contentHash(defaultCountryCode: defaultCountryCode))
                    resourceByIdentifier[id] = person.resourceName
                } catch { failures.append(Failure(op: op, message: "\(error)")) }

            case .update(let identifier, let person):
                do {
                    try store.update(identifier: identifier, with: person)
                    byResource[person.resourceName] = SyncedContactRef(
                        resourceName: person.resourceName, contactIdentifier: identifier,
                        contentHash: person.contentHash(defaultCountryCode: defaultCountryCode))
                } catch { failures.append(Failure(op: op, message: "\(error)")) }

            case .delete(let identifier):
                do {
                    try store.delete(identifier: identifier)
                    if let resource = resourceByIdentifier[identifier] { byResource[resource] = nil }
                } catch { failures.append(Failure(op: op, message: "\(error)")) }
            }
        }

        let refs = byResource.values.sorted { $0.resourceName < $1.resourceName }
        return ExecutionResult(refs: refs, failures: failures)
    }
}
