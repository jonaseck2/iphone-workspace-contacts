# WorkspaceContacts — Sync to Contacts (App Plan B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After sign-in, a one-time consent writes the Imeto directory into the device address book as native `CNContact`s (kept in create/update/delete sync), so colleagues get incoming caller ID and call-by-name; explicit "Remove all" and sign-out remove exactly what the app added.

**Architecture:** Reuse the Plan A seam pattern — pure, headless-testable logic in **Core** behind a protocol (`ContactStoreWriting` + `ContactSyncExecutor`), and the `CNContactStore`-backed implementation in the **app** (`CNContactStoreWriter`). The already-shipped `ContactSync.plan` computes the diff off a **full** directory fetch; the executor applies it and returns the persisted `[SyncedContactRef]`.

**Tech Stack:** Swift 6, SwiftUI, the local `WorkspaceContactsCore` package, `Contacts`/`CNContactStore`, `BackgroundTasks` (`.backgroundTask(.appRefresh)`), swift-testing, XcodeGen.

## Global Constraints

- **Test framework: swift-testing** (`import Testing`, `@Suite`, `@Test`, `#expect`) everywhere — never XCTest.
- **Core tests run headless via `make test`** in `Core/` (not bare `swift test`) — see the `swift-testing-headless` skill. Expected current baseline: **27** tests.
- **App tests + build require full Xcode** (present on this machine). Canonical invocation (per the Plan A archive), run from `app/`:
  ```bash
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all \
    xcodebuild -scheme WorkspaceContacts -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -clonedSourcePackagesDirPath .build-spm -derivedDataPath .dd CODE_SIGNING_ALLOWED=NO test
  ```
  Regenerate the project after `project.yml` changes: `cd app && DEVELOPER_DIR=… xcodegen generate`.
- **`Contacts` is imported only in the app target**, never in Core (Core stays pure/headless).
- **`defaultCountryCode` = `"46"`** (Sweden), single constant.
- **Bundle id:** `com.imeto.workspacecontacts.app`. **Background task id:** `com.imeto.workspacecontacts.app.refresh`.
- **Contact tag:** a dedicated `CNGroup` named exactly `"Imeto Directory"` — the source of truth for "remove all".
- **Sign-out removes all** synced contacts (product decision).
- **The live sign-in E2E only works when run from Xcode (⌘R) with a personal team** (keychain), per the Plan A archive.

---

### Task 1: Core — `SyncedContactRef` Codable + `SyncState`

**Files:**
- Modify: `Core/Sources/WorkspaceContactsCore/ContactSync.swift` (add conformances to `SyncedContactRef`)
- Create: `Core/Sources/WorkspaceContactsCore/SyncState.swift`
- Test: `Core/Tests/WorkspaceContactsCoreTests/SyncStateTests.swift`

**Interfaces:**
- Consumes: existing `SyncedContactRef`.
- Produces: `SyncedContactRef: Equatable, Codable, Sendable`; `public struct SyncState: Codable, Equatable, Sendable { public var refs: [SyncedContactRef]; public init(refs: [SyncedContactRef] = []) }`.

- [x] **Step 1: Write the failing test**

```swift
// Core/Tests/WorkspaceContactsCoreTests/SyncStateTests.swift
import Testing
import Foundation
@testable import WorkspaceContactsCore

@Suite struct SyncStateTests {
    @Test func roundTripsThroughJSON() throws {
        let state = SyncState(refs: [
            SyncedContactRef(resourceName: "people/1", contactIdentifier: "ABC", contentHash: "h1"),
            SyncedContactRef(resourceName: "people/2", contactIdentifier: "DEF", contentHash: "h2"),
        ])
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(SyncState.self, from: data)
        #expect(decoded == state)
    }

    @Test func defaultsToEmpty() {
        #expect(SyncState().refs.isEmpty)
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd Core && make test FILTER=SyncStateTests`
Expected: FAIL to compile — `SyncState` not defined (and `SyncedContactRef` not `Codable`).

- [x] **Step 3: Add conformances to `SyncedContactRef`**

In `Core/Sources/WorkspaceContactsCore/ContactSync.swift`, change the declaration line:

```swift
public struct SyncedContactRef: Equatable, Codable, Sendable {
```

- [x] **Step 4: Create `SyncState`**

```swift
// Core/Sources/WorkspaceContactsCore/SyncState.swift
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
```

- [x] **Step 5: Run tests to verify they pass**

Run: `cd Core && make test FILTER=SyncStateTests`
Expected: PASS (2 tests).

- [x] **Step 6: Commit**

```bash
git add Core/Sources/WorkspaceContactsCore/ContactSync.swift Core/Sources/WorkspaceContactsCore/SyncState.swift Core/Tests/WorkspaceContactsCoreTests/SyncStateTests.swift
git commit -m "feat(core): SyncedContactRef Codable/Sendable + SyncState"
```

---

### Task 2: Core — `ContactStoreWriting` + `ContactSyncExecutor`

**Files:**
- Create: `Core/Sources/WorkspaceContactsCore/ContactSyncExecutor.swift`
- Test: `Core/Tests/WorkspaceContactsCoreTests/ContactSyncExecutorTests.swift`

**Interfaces:**
- Consumes: `ContactOp`, `DirectoryPerson`, `SyncedContactRef`, `DirectoryPerson.contentHash(defaultCountryCode:)`.
- Produces:
  - `public protocol ContactStoreWriting: Sendable { func create(_ person: DirectoryPerson) throws -> String; func update(identifier: String, with person: DirectoryPerson) throws; func delete(identifier: String) throws }`
  - `public enum ContactSyncExecutor { public struct Failure: Equatable { public let op: ContactOp; public let message: String }; public struct ExecutionResult: Equatable { public let refs: [SyncedContactRef]; public let failures: [Failure] }; public static func apply(_ ops: [ContactOp], using store: ContactStoreWriting, existing: [SyncedContactRef], defaultCountryCode: String) -> ExecutionResult }`
  - `refs` in the result are sorted by `resourceName` (deterministic).

- [x] **Step 1: Write the failing test**

```swift
// Core/Tests/WorkspaceContactsCoreTests/ContactSyncExecutorTests.swift
import Testing
@testable import WorkspaceContactsCore

private func person(_ id: String, phone: String, name: String) -> DirectoryPerson {
    DirectoryPerson(
        resourceName: "people/\(id)", etag: nil, displayName: name,
        givenName: name, familyName: nil, emails: [], phoneNumbers: [phone],
        organizationTitle: nil, department: nil, photoURL: nil
    )
}

/// Records calls and hands back deterministic identifiers; can be told to throw for a resource.
private final class FakeStore: ContactStoreWriting, @unchecked Sendable {
    enum StoreError: Error { case boom }
    var created: [DirectoryPerson] = []
    var updated: [(String, DirectoryPerson)] = []
    var deleted: [String] = []
    var failCreateForResource: String? = nil
    private var counter = 0

    func create(_ person: DirectoryPerson) throws -> String {
        if person.resourceName == failCreateForResource { throw StoreError.boom }
        created.append(person)
        counter += 1
        return "id-\(counter)"
    }
    func update(identifier: String, with person: DirectoryPerson) throws { updated.append((identifier, person)) }
    func delete(identifier: String) throws { deleted.append(identifier) }
}

@Suite struct ContactSyncExecutorTests {
    private let code = "46"

    @Test func createAssignsIdentifierAndRef() {
        let store = FakeStore()
        let p = person("1", phone: "0701234567", name: "Ada")
        let result = ContactSyncExecutor.apply([.create(p)], using: store, existing: [], defaultCountryCode: code)
        #expect(store.created.count == 1)
        #expect(result.failures.isEmpty)
        #expect(result.refs == [
            SyncedContactRef(resourceName: "people/1", contactIdentifier: "id-1",
                             contentHash: p.contentHash(defaultCountryCode: code))
        ])
    }

    @Test func updateKeepsIdentifierRefreshesHash() {
        let store = FakeStore()
        let p = person("1", phone: "0701234567", name: "Ada B")
        let existing = [SyncedContactRef(resourceName: "people/1", contactIdentifier: "keep-1", contentHash: "old")]
        let result = ContactSyncExecutor.apply(
            [.update(contactIdentifier: "keep-1", p)], using: store, existing: existing, defaultCountryCode: code)
        #expect(store.updated.map(\.0) == ["keep-1"])
        #expect(result.refs == [
            SyncedContactRef(resourceName: "people/1", contactIdentifier: "keep-1",
                             contentHash: p.contentHash(defaultCountryCode: code))
        ])
    }

    @Test func deleteDropsRef() {
        let store = FakeStore()
        let existing = [SyncedContactRef(resourceName: "people/1", contactIdentifier: "gone-1", contentHash: "h")]
        let result = ContactSyncExecutor.apply(
            [.delete(contactIdentifier: "gone-1")], using: store, existing: existing, defaultCountryCode: code)
        #expect(store.deleted == ["gone-1"])
        #expect(result.refs.isEmpty)
    }

    @Test func failedOpIsRecordedWithoutAbortingBatch() {
        let store = FakeStore()
        store.failCreateForResource = "people/1"
        let p1 = person("1", phone: "0701234567", name: "Ada")
        let p2 = person("2", phone: "0709999999", name: "Bea")
        let result = ContactSyncExecutor.apply([.create(p1), .create(p2)], using: store, existing: [], defaultCountryCode: code)
        #expect(result.failures.count == 1)
        #expect(result.failures.first?.op == .create(p1))
        // p2 still created despite p1 failing
        #expect(result.refs.map(\.resourceName) == ["people/2"])
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd Core && make test FILTER=ContactSyncExecutorTests`
Expected: FAIL to compile — `ContactStoreWriting` / `ContactSyncExecutor` not defined.

- [x] **Step 3: Implement the protocol and executor**

```swift
// Core/Sources/WorkspaceContactsCore/ContactSyncExecutor.swift
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
```

- [x] **Step 4: Run tests to verify they pass**

Run: `cd Core && make test FILTER=ContactSyncExecutorTests`
Expected: PASS (4 tests).

- [x] **Step 5: Run the full Core suite (no regressions)**

Run: `cd Core && make test`
Expected: PASS — 27 (Plan A) + 2 (Task 1) + 4 (Task 2) = **33 tests**.

- [x] **Step 6: Commit**

```bash
git add Core/Sources/WorkspaceContactsCore/ContactSyncExecutor.swift Core/Tests/WorkspaceContactsCoreTests/ContactSyncExecutorTests.swift
git commit -m "feat(core): ContactStoreWriting seam + ContactSyncExecutor"
```

---

### Task 3: App — `SyncStore` (persistence)

**Files:**
- Create: `app/Sources/SyncStore.swift`
- Test: `app/Tests/SyncStoreTests.swift`

**Interfaces:**
- Consumes: `WorkspaceContactsCore.SyncState`.
- Produces: `struct SyncStore { init(defaults: UserDefaults = .standard); func load() -> SyncState; func save(_:); func clear(); var consentGiven: Bool { get nonmutating set } }`.

- [x] **Step 1: Write the failing test**

```swift
// app/Tests/SyncStoreTests.swift
import Testing
import Foundation
@testable import WorkspaceContacts
import WorkspaceContactsCore

@Suite struct SyncStoreTests {
    private func freshDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "SyncStoreTests")!
        d.removePersistentDomain(forName: "SyncStoreTests")
        return d
    }

    @Test func savesAndLoadsState() {
        let store = SyncStore(defaults: freshDefaults())
        let state = SyncState(refs: [SyncedContactRef(resourceName: "people/1", contactIdentifier: "A", contentHash: "h")])
        store.save(state)
        #expect(store.load() == state)
    }

    @Test func loadDefaultsToEmpty() {
        #expect(SyncStore(defaults: freshDefaults()).load().refs.isEmpty)
    }

    @Test func clearResetsState() {
        let store = SyncStore(defaults: freshDefaults())
        store.save(SyncState(refs: [SyncedContactRef(resourceName: "people/1", contactIdentifier: "A", contentHash: "h")]))
        store.clear()
        #expect(store.load().refs.isEmpty)
    }

    @Test func consentPersists() {
        let store = SyncStore(defaults: freshDefaults())
        #expect(store.consentGiven == false)
        store.consentGiven = true
        #expect(store.consentGiven == true)
    }
}
```

- [x] **Step 2: Run test to verify it fails (developer, Xcode)**

Run the Global-Constraints `xcodebuild … test` invocation.
Expected: FAIL to compile — `SyncStore` not defined.

- [x] **Step 3: Implement `SyncStore`**

```swift
// app/Sources/SyncStore.swift
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
```

- [x] **Step 4: Run tests to verify they pass (developer, Xcode)**

Run the Global-Constraints `xcodebuild … test` invocation.
Expected: PASS — `SyncStoreTests` (4) green; whole app suite `** TEST SUCCEEDED **`.

- [x] **Step 5: Commit**

```bash
git add app/Sources/SyncStore.swift app/Tests/SyncStoreTests.swift
git commit -m "feat(app): SyncStore (UserDefaults persistence for sync state + consent)"
```

---

### Task 4: App — `CNContactStoreWriter` + Contacts usage string

**Files:**
- Create: `app/Sources/CNContactStoreWriter.swift`
- Modify: `app/project.yml` (add `NSContactsUsageDescription`)
- Test: `app/Tests/CNContactStoreWriterTests.swift`

**Interfaces:**
- Consumes: `WorkspaceContactsCore.ContactStoreWriting`, `DirectoryPerson`.
- Produces: `struct CNContactStoreWriter: ContactStoreWriting` with `init(store: CNContactStore = CNContactStore())`, the protocol methods, plus `func requestAccess() async -> Bool` and `func removeAll() throws`. Contacts are tagged into the `"Imeto Directory"` `CNGroup`; company is set to `"Imeto"`.

- [x] **Step 1: Add the Contacts usage string to `project.yml`**

In `app/project.yml`, under `targets.WorkspaceContacts.info.properties`, add (alongside the existing keys):

```yaml
        NSContactsUsageDescription: WorkspaceContacts adds your Imeto colleagues to your Contacts so their names show on incoming calls and you can call them by name.
```

Then regenerate: `cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate`.

- [x] **Step 2: Write the failing integration test**

```swift
// app/Tests/CNContactStoreWriterTests.swift
import Testing
import Contacts
@testable import WorkspaceContacts
import WorkspaceContactsCore

private func person(_ id: String, given: String, family: String, phone: String) -> DirectoryPerson {
    DirectoryPerson(
        resourceName: "people/\(id)", etag: nil, displayName: "\(given) \(family)",
        givenName: given, familyName: family, emails: ["\(given.lowercased())@imeto.com"],
        phoneNumbers: [phone], organizationTitle: "Engineer", department: nil, photoURL: nil
    )
}

/// Integration test against the Simulator's Contacts DB. Requires contacts access pre-granted
/// (see the Run step: `simctl privacy … grant contacts`). If access isn't authorized, records an
/// issue rather than silently passing.
@Suite(.serialized) struct CNContactStoreWriterTests {
    private func requireAuthorized() -> Bool {
        CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    @Test func createReadUpdateDelete() throws {
        guard requireAuthorized() else {
            Issue.record("Contacts not authorized; run `xcrun simctl privacy booted grant contacts com.imeto.workspacecontacts.app` before testing.")
            return
        }
        let writer = CNContactStoreWriter()
        // clean slate
        try writer.removeAll()

        // create
        let p = person("t1", given: "Ada", family: "Lovelace", phone: "+46701234567")
        let id = try writer.create(p)
        #expect(!id.isEmpty)

        // read back
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [CNContactGivenNameKey, CNContactFamilyNameKey,
                                       CNContactPhoneNumbersKey].map { $0 as CNKeyDescriptor }
        let fetched = try store.unifiedContact(withIdentifier: id, keysToFetch: keys)
        #expect(fetched.givenName == "Ada")
        #expect(fetched.familyName == "Lovelace")
        #expect(fetched.phoneNumbers.first?.value.stringValue == "+46701234567")

        // update
        let p2 = person("t1", given: "Ada", family: "Byron", phone: "+46700000000")
        try writer.update(identifier: id, with: p2)
        let updated = try store.unifiedContact(withIdentifier: id, keysToFetch: keys)
        #expect(updated.familyName == "Byron")
        #expect(updated.phoneNumbers.first?.value.stringValue == "+46700000000")

        // delete
        try writer.delete(identifier: id)
        #expect((try? store.unifiedContact(withIdentifier: id, keysToFetch: keys)) == nil)

        // cleanup group
        try writer.removeAll()
    }
}
```

- [x] **Step 3: Run test to verify it fails (developer, Xcode)**

Run the Global-Constraints `xcodebuild … test` invocation.
Expected: FAIL to compile — `CNContactStoreWriter` not defined.

- [x] **Step 4: Implement `CNContactStoreWriter`**

```swift
// app/Sources/CNContactStoreWriter.swift
import Contacts
import WorkspaceContactsCore

enum ContactWriteError: Error, Equatable {
    case notFound(String)
}

/// Live `ContactStoreWriting` over CNContactStore. Tags every contact into a dedicated
/// "Imeto Directory" CNGroup (the source of truth for "remove all").
struct CNContactStoreWriter: ContactStoreWriting {
    static let groupName = "Imeto Directory"
    static let companyName = "Imeto"

    private let store: CNContactStore
    init(store: CNContactStore = CNContactStore()) { self.store = store }

    func requestAccess() async -> Bool {
        (try? await store.requestAccess(for: .contacts)) ?? false
    }

    func create(_ person: DirectoryPerson) throws -> String {
        let group = try ensureGroup()
        let contact = CNMutableContact()
        Self.apply(person, to: contact)
        let save = CNSaveRequest()
        save.add(contact, toContainerWithIdentifier: nil)
        save.addMember(contact, to: group)
        try store.execute(save)
        return contact.identifier
    }

    func update(identifier: String, with person: DirectoryPerson) throws {
        guard let existing = try? store.unifiedContact(withIdentifier: identifier, keysToFetch: Self.fetchKeys),
              let mutable = existing.mutableCopy() as? CNMutableContact else {
            throw ContactWriteError.notFound(identifier)
        }
        Self.apply(person, to: mutable)
        let save = CNSaveRequest()
        save.update(mutable)
        try store.execute(save)
    }

    func delete(identifier: String) throws {
        guard let existing = try? store.unifiedContact(withIdentifier: identifier,
                                                       keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor]),
              let mutable = existing.mutableCopy() as? CNMutableContact else {
            throw ContactWriteError.notFound(identifier)
        }
        let save = CNSaveRequest()
        save.delete(mutable)
        try store.execute(save)
    }

    /// Delete every contact in the group (robust even if the persisted map is lost), then the group.
    func removeAll() throws {
        guard let group = try store.groups(matching: nil).first(where: { $0.name == Self.groupName }) else { return }
        let predicate = CNContact.predicateForContactsInGroup(withIdentifier: group.identifier)
        let members = try store.unifiedContacts(matching: predicate,
                                                keysToFetch: [CNContactIdentifierKey as CNKeyDescriptor])
        let save = CNSaveRequest()
        for m in members {
            if let mutable = m.mutableCopy() as? CNMutableContact { save.delete(mutable) }
        }
        if let mutableGroup = group.mutableCopy() as? CNMutableGroup { save.delete(mutableGroup) }
        try store.execute(save)
    }

    // MARK: - Private

    private func ensureGroup() throws -> CNGroup {
        if let existing = try store.groups(matching: nil).first(where: { $0.name == Self.groupName }) {
            return existing
        }
        let group = CNMutableGroup()
        group.name = Self.groupName
        let save = CNSaveRequest()
        save.add(group, toContainerWithIdentifier: nil)
        try store.execute(save)
        return group
    }

    static let fetchKeys: [CNKeyDescriptor] = [
        CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey,
        CNContactEmailAddressesKey, CNContactOrganizationNameKey, CNContactJobTitleKey,
        CNContactDepartmentNameKey, CNContactIdentifierKey,
    ].map { $0 as CNKeyDescriptor }

    private static func apply(_ person: DirectoryPerson, to c: CNMutableContact) {
        c.givenName = person.givenName ?? person.displayName
        c.familyName = person.familyName ?? ""
        c.organizationName = companyName
        c.jobTitle = person.organizationTitle ?? ""
        c.departmentName = person.department ?? ""
        c.phoneNumbers = person.phoneNumbers.map {
            CNLabeledValue(label: CNLabelWork, value: CNPhoneNumber(stringValue: $0))
        }
        c.emailAddresses = person.emails.map {
            CNLabeledValue(label: CNLabelWork, value: $0 as NSString)
        }
    }
}
```

- [x] **Step 5: Run tests to verify they pass (developer, Xcode)**

Pre-grant Contacts on the booted Simulator, then run tests:
```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl bootstatus 'iPhone 17 Pro' -b || true
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl privacy booted grant contacts com.imeto.workspacecontacts.app
```
Then run the Global-Constraints `xcodebuild … test` invocation.
Expected: PASS — `CNContactStoreWriterTests` green (create/read/update/delete asserted), `** TEST SUCCEEDED **`. (If it records the "not authorized" issue, boot the Simulator + re-run the grant, then retest.)

- [x] **Step 6: Commit**

```bash
git add app/Sources/CNContactStoreWriter.swift app/Tests/CNContactStoreWriterTests.swift app/project.yml
git commit -m "feat(app): CNContactStoreWriter (live Contacts writer, Imeto Directory group)"
```

---

### Task 5: App — `ContactSyncService` + `AppModel` wiring

**Files:**
- Create: `app/Sources/ContactSyncService.swift`
- Modify: `app/Sources/AppModel.swift`

**Interfaces:**
- Consumes: `SyncStore` (Task 3), `CNContactStoreWriter` (Task 4), `ContactSync`, `ContactSyncExecutor`, `DirectoryClient`, `URLSessionHTTPFetcher`, `AuthService`.
- Produces:
  - `struct ContactSyncSummary: Equatable { let created, updated, deleted, failed: Int }`
  - `@MainActor final class ContactSyncService { init(store: SyncStore = SyncStore(), writer: CNContactStoreWriter = CNContactStoreWriter()); func requestAccess() async -> Bool; func sync(people: [DirectoryPerson]) throws -> ContactSyncSummary; func syncFromNetwork(token: String, client: DirectoryClient) async throws -> ContactSyncSummary; func removeAll() throws }`
  - `enum BackgroundSync { static func run() async }`
  - `AppModel` gains: `@Published private(set) var consentGiven: Bool`, `@Published private(set) var syncStatus: SyncStatus`, `func enableSyncWithConsent() async`, `func syncNow() async`, `func removeAllSyncedContacts() async`, and `func signOut() async` (replacing the sync `signOut()`), where `enum SyncStatus: Equatable { case idle; case syncing; case synced(count: Int, at: Date); case failed(String); case permissionDenied }`.

- [x] **Step 1: Implement `ContactSyncService` + `BackgroundSync`**

```swift
// app/Sources/ContactSyncService.swift
import Foundation
import WorkspaceContactsCore

struct ContactSyncSummary: Equatable {
    let created: Int
    let updated: Int
    let deleted: Int
    let failed: Int
}

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
        var state = store.load()
        let ops = ContactSync.plan(existing: state.refs, fetched: people, defaultCountryCode: defaultCountryCode)
        let result = ContactSyncExecutor.apply(ops, using: writer, existing: state.refs,
                                               defaultCountryCode: defaultCountryCode)
        state.refs = result.refs
        store.save(state)

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
```

- [x] **Step 2: Wire sync into `AppModel`**

Replace the body of `app/Sources/AppModel.swift` with:

```swift
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

    func syncNow() async { await runSync() }

    func removeAllSyncedContacts() async {
        do {
            try syncService.removeAll()
            syncStatus = .idle
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
    }

    private func runSync() async {
        syncStatus = .syncing
        do {
            let summary = try syncService.sync(people: people)
            syncStatus = .synced(count: people.count, at: Date())
            _ = summary
        } catch {
            syncStatus = .failed(error.localizedDescription)
        }
    }
}
```

- [x] **Step 3: Build (developer)**

Run: `cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate` then the Global-Constraints `xcodebuild … test` invocation (compiles the app + reruns tests).
Expected: `** TEST SUCCEEDED **` (existing tests still pass; new code compiles). Note: `Date()` in `SyncStatus` isn't unit-asserted here; it's exercised in the Task 7 E2E.

- [x] **Step 4: Commit**

```bash
git add app/Sources/ContactSyncService.swift app/Sources/AppModel.swift
git commit -m "feat(app): ContactSyncService + AppModel sync wiring (consent, sync, remove-all, sign-out cleanup)"
```

---

### Task 6: App — Consent/sync UI + background refresh

**Files:**
- Modify: `app/Sources/ContentView.swift`
- Modify: `app/Sources/WorkspaceContactsApp.swift`
- Modify: `app/project.yml` (add `BGTaskSchedulerPermittedIdentifiers`)

**Interfaces:**
- Consumes: `AppModel` (Task 5), `BackgroundSync` (Task 5).
- Produces: consent screen + sync status + "Sync now" / "Remove all synced contacts" menu; `.backgroundTask(.appRefresh("com.imeto.workspacecontacts.app.refresh"))`; scheduled `BGAppRefreshTaskRequest`.

- [x] **Step 1: Add the background task identifier to `project.yml`**

In `app/project.yml`, under `targets.WorkspaceContacts.info.properties`, add:

```yaml
        BGTaskSchedulerPermittedIdentifiers:
          - com.imeto.workspacecontacts.app.refresh
```

Then regenerate: `cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate`.

- [x] **Step 2: Replace `ContentView` with the consent + sync UI**

```swift
// app/Sources/ContentView.swift
import SwiftUI
import WorkspaceContactsCore

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Colleagues")
                .toolbar {
                    if model.authState == .signedIn {
                        ToolbarItem(placement: .primaryAction) {
                            Menu {
                                Button("Sync now") { Task { await model.syncNow() } }
                                Button("Remove all synced contacts", role: .destructive) {
                                    Task { await model.removeAllSyncedContacts() }
                                }
                                Divider()
                                Button("Sign out") { Task { await model.signOut() } }
                            } label: { Image(systemName: "ellipsis.circle") }
                        }
                    }
                }
        }
        .task { await model.restore() }
    }

    @ViewBuilder
    private var content: some View {
        switch (model.authState, model.consentGiven, model.status) {
        case (let s, _, _) where s != .signedIn:
            signInScreen
        case (.signedIn, false, _):
            consentScreen
        default:
            signedInBody
        }
    }

    private var signInScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle").font(.system(size: 56))
            Text("See your Imeto colleagues on incoming calls.")
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Sign in with Google") { Task { await model.signIn() } }
                .buttonStyle(.borderedProminent)
            if case .error(let msg) = model.authState {
                Text(msg).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
        }.padding()
    }

    private var consentScreen: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.plus").font(.system(size: 56))
            Text("Add colleagues to Contacts")
                .font(.headline)
            Text("To show colleague names on incoming calls and let you call them by name, "
                 + "WorkspaceContacts adds them to your device Contacts. These contacts live in "
                 + "your real address book and may sync to iCloud. You can remove them anytime with "
                 + "\u{201C}Remove all synced contacts\u{201D}, and signing out removes them.")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Enable & sync") { Task { await model.enableSyncWithConsent() } }
                .buttonStyle(.borderedProminent)
            if model.syncStatus == .permissionDenied {
                Text("Contacts access is off. Enable it in Settings › WorkspaceContacts › Contacts.")
                    .font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
        }.padding()
    }

    @ViewBuilder
    private var signedInBody: some View {
        VStack(spacing: 0) {
            syncStatusRow
            listOrStatus
        }
    }

    @ViewBuilder
    private var syncStatusRow: some View {
        switch model.syncStatus {
        case .syncing:
            Label("Syncing to Contacts…", systemImage: "arrow.triangle.2.circlepath")
                .font(.caption).foregroundStyle(.secondary).padding(.vertical, 4)
        case .synced(let count, _):
            Label("\(count) colleagues synced to Contacts", systemImage: "checkmark.circle")
                .font(.caption).foregroundStyle(.secondary).padding(.vertical, 4)
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.red).padding(.vertical, 4)
        case .idle, .permissionDenied:
            EmptyView()
        }
    }

    @ViewBuilder
    private var listOrStatus: some View {
        switch model.status {
        case .loading:
            Spacer(); ProgressView("Loading directory…"); Spacer()
        case .failed(let message):
            Spacer()
            VStack(spacing: 12) {
                Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Try again") { Task { await model.syncNow(); await model.restore() } }
            }.padding()
            Spacer()
        default:
            list
        }
    }

    private var list: some View {
        List(model.people, id: \.resourceName) { person in
            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName).font(.body)
                if let title = person.organizationTitle {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                }
                if let phone = person.phoneNumbers.first {
                    Text(phone).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .refreshable { await model.refresh() }
    }
}
```

- [x] **Step 3: Register + schedule the background refresh in the app entry point**

```swift
// app/Sources/WorkspaceContactsApp.swift
import SwiftUI
import GoogleSignIn
import BackgroundTasks

@main
struct WorkspaceContactsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    static let refreshTaskID = "com.imeto.workspacecontacts.app.refresh"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in GIDSignIn.sharedInstance.handle(url) }
        }
        .backgroundTask(.appRefresh(Self.refreshTaskID)) {
            await BackgroundSync.run()
            await Self.scheduleRefresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Task { await Self.scheduleRefresh() } }
        }
    }

    /// Ask the system to run our refresh no earlier than ~6 hours from now.
    @MainActor
    static func scheduleRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
```

- [x] **Step 4: Build & run (developer)**

Run: `cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate`, then build via the Global-Constraints invocation (or open in Xcode).
Expected: build succeeds; app launches to the sign-in screen; after sign-in a signed-out-of-consent user sees the consent screen.

- [x] **Step 5: Commit**

```bash
git add app/Sources/ContentView.swift app/Sources/WorkspaceContactsApp.swift app/project.yml
git commit -m "feat(app): consent/sync UI + BGAppRefreshTask background sync"
```

---

### Task 7: End-to-end verification (developer, Simulator) — the milestone

**Files:** none (verification only).

- [x] **Step 1: Run the full headless Core suite**

Run: `cd Core && make test`
Expected: `✔ Test run with 33 tests in 8 suites passed` (27 + 2 + 4).

- [x] **Step 2: Run the app test suite on the Simulator**

Pre-grant contacts, then run the Global-Constraints `xcodebuild … test` invocation.
Expected: `** TEST SUCCEEDED **` including `SyncStoreTests` and `CNContactStoreWriterTests`.

- [x] **Step 3: E2E in the Simulator (run from Xcode ⌘R with your personal team)**

1. Launch, **Sign in with Google** with an `@imeto.com` account.
2. On the **consent screen**, tap **Enable & sync**; grant the Contacts prompt.
   Expected: status row shows "N colleagues synced to Contacts".
3. Open the **Contacts app** in the Simulator.
   Expected: the Imeto colleagues appear (given/family name, company "Imeto", job title, work phone), grouped under "Imeto Directory".
4. Back in the app, open the menu → **Remove all synced contacts**.
   Expected: they disappear from the Contacts app.
5. Sync again (menu → **Sync now**), then **Sign out**.
   Expected: after sign-out, the synced contacts are gone from the Contacts app.

Capture screenshots (Contacts app before/after remove) and paste the observed counts into the close-out evidence.

- [x] **Step 4: Commit any final tweaks + close out**

```bash
git add -A
git commit -m "chore: App Plan B verified end-to-end on Simulator"
```
Then run the `close-out` skill (all boxes checked) to archive this plan with the pasted evidence.

---

## What this plan intentionally defers

- **Real incoming caller ID on a physical device** — needs a real iPhone + a colleague to call; the Simulator can't place a real cellular call.
- **`syncToken`-based incremental fetch** — needs deletion-marker handling in Core so it composes with `ContactSync.plan`'s full-set diff.
- **Batched `CNSaveRequest`** — Plan B does one save per op (fine for a few hundred contacts); batching is a later performance optimization.
