# WorkspaceContacts Core Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

## Goal

A colleague's directory data can be turned into ready-to-write contact operations entirely by tested, headless logic — People-API JSON in, a reconciled create/update/delete plan out — so the iOS app that follows only has to execute those operations.

## Scope

**In:** a standalone SwiftPM package `WorkspaceContactsCore` with four pieces of pure logic — People-API decoding, E.164 phone normalization, directory paging/syncToken handling, and the contact-diff engine — plus its package scaffold, all verified by `swift test`.

**Out (deferred to the app-integration plan):** `AuthService` (AppAuth/PKCE/Keychain), the live `URLSession` fetcher, the `CNContactStore` executor that applies the ops, local persistence of synced refs, the SwiftUI shell, `BGAppRefreshTask`, and the Xcode app target. This package must not import `Contacts`, `UIKit`, `SwiftUI`, `AppAuth`, or any networking framework.

## Verification

Runnable check for the whole plan:

```bash
cd Core && swift test
```

Expected: build succeeds and **all tests pass** — Task 1 scaffold (1), decoding (2), phone normalization (7), directory client (3), contact diff (7) = **20 tests**, reported by swift-testing as "Test run with 20 tests passed". This green `swift test` is the verification anchor for the app-integration plan that follows.

**Architecture:** A standalone SwiftPM library target (`WorkspaceContactsCore`) with a swift-testing test target. The diff engine is a pure function over value types, the directory client takes an injectable HTTP fetcher, and everything decodes/transforms plain `Foundation` types. This keeps it runnable on macOS via `swift test` with zero Xcode/device.

**Tech Stack:** Swift 5.9+ (toolchain 6.1), SwiftPM, **swift-testing** (`import Testing`), Foundation only.

## Global Constraints

- **Foundation-only.** No import of `Contacts`, `UIKit`, `SwiftUI`, `AppAuth`, or any networking framework in this package — it must compile and test on macOS headlessly. (Verified by `swift test` succeeding on a Mac with Command Line Tools only.)
- **Test framework: swift-testing, NOT XCTest.** Use `import Testing`, `@Suite`, `@Test`, and `#expect(...)`. The CLI environment has Command Line Tools only, where **XCTest is unavailable** (`import XCTest` → "no such module"); swift-testing ships with the toolchain and runs headlessly. Do not `import XCTest` anywhere.
- **Package location:** `Core/` at repo root (`Core/Package.swift`, `Core/Sources/WorkspaceContactsCore/`, `Core/Tests/WorkspaceContactsCoreTests/`). Run all commands from `Core/`.
- **Swift tools version:** `5.9`. Platforms: `.iOS(.v16)`, `.macOS(.v13)`. The macOS floor is required — without it swift-testing macros fail with "'Actor' is only available in macOS 10.15 or newer".
- **Tenancy:** single-org; no multi-tenant logic belongs here (domain checks live in the app's AuthService, not Core).
- **Sync filter:** only people with ≥1 *normalizable* phone number are eligible for sync (enforced in the diff engine).
- **Default region:** phone normalization takes an explicit `defaultCountryCode` parameter (no hardcoded region inside the normalizer). Tests use `"46"` (Sweden).

---

### Task 1: Package scaffold

**Files:**
- Create: `Core/Package.swift`
- Create: `Core/Sources/WorkspaceContactsCore/WorkspaceContactsCore.swift`
- Create: `Core/Tests/WorkspaceContactsCoreTests/ScaffoldTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: a buildable `WorkspaceContactsCore` library target and a runnable swift-testing test target.

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WorkspaceContactsCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "WorkspaceContactsCore", targets: ["WorkspaceContactsCore"]),
    ],
    targets: [
        .target(name: "WorkspaceContactsCore"),
        .testTarget(
            name: "WorkspaceContactsCoreTests",
            dependencies: ["WorkspaceContactsCore"]
        ),
    ]
)
```

- [ ] **Step 2: Create a placeholder source file**

```swift
// Core/Sources/WorkspaceContactsCore/WorkspaceContactsCore.swift
import Foundation

/// Namespace marker for the WorkspaceContacts core logic package.
public enum WorkspaceContactsCore {
    public static let version = "0.1.0"
}
```

- [ ] **Step 3: Write a scaffold test (swift-testing)**

```swift
// Core/Tests/WorkspaceContactsCoreTests/ScaffoldTests.swift
import Testing
@testable import WorkspaceContactsCore

@Suite struct ScaffoldTests {
    @Test func packageVersionIsSet() {
        #expect(WorkspaceContactsCore.version == "0.1.0")
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Core && swift test`
Expected: build succeeds, `packageVersionIsSet` PASSES (swift-testing reports "Test run with 1 test passed").

- [ ] **Step 5: Commit**

```bash
git add Core/Package.swift Core/Sources Core/Tests
git commit -m "feat(core): scaffold WorkspaceContactsCore swift package"
```

---

### Task 2: DirectoryPerson model + People API decoding

**Files:**
- Create: `Core/Sources/WorkspaceContactsCore/DirectoryPerson.swift`
- Create: `Core/Sources/WorkspaceContactsCore/PeopleAPIResponse.swift`
- Test: `Core/Tests/WorkspaceContactsCoreTests/PeopleAPIDecodingTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `public struct DirectoryPerson: Equatable` with fields
    `resourceName: String`, `etag: String?`, `displayName: String`, `givenName: String?`,
    `familyName: String?`, `emails: [String]`, `phoneNumbers: [String]`,
    `organizationTitle: String?`, `department: String?`, `photoURL: String?`.
  - `public struct ListDirectoryPeopleResponse: Decodable` with
    `people: [DirectoryPerson]`, `nextPageToken: String?`, `nextSyncToken: String?`.
  - `public static func ListDirectoryPeopleResponse.decode(_ data: Data) throws -> ListDirectoryPeopleResponse`.

- [ ] **Step 1: Write the failing test (swift-testing)**

```swift
// Core/Tests/WorkspaceContactsCoreTests/PeopleAPIDecodingTests.swift
import Testing
import Foundation
@testable import WorkspaceContactsCore

@Suite struct PeopleAPIDecodingTests {
    private let json = """
    {
      "people": [
        {
          "resourceName": "people/c1",
          "etag": "etag-1",
          "names": [
            {"displayName": "Jane Doe", "givenName": "Jane", "familyName": "Doe", "metadata": {"primary": true}}
          ],
          "emailAddresses": [
            {"value": "jane@imeto.com", "metadata": {"primary": true}},
            {"value": "j.doe@imeto.com"}
          ],
          "phoneNumbers": [
            {"value": "+46701234567", "type": "mobile"}
          ],
          "organizations": [
            {"title": "Consultant", "department": "Engineering", "metadata": {"primary": true}}
          ],
          "photos": [
            {"url": "https://example.com/jane.jpg", "metadata": {"primary": true}}
          ]
        },
        {
          "resourceName": "people/c2",
          "names": [{"displayName": "No Phone Person"}],
          "emailAddresses": [{"value": "nophone@imeto.com"}]
        }
      ],
      "nextPageToken": "page-2",
      "nextSyncToken": "sync-abc"
    }
    """.data(using: .utf8)!

    @Test func decodesPeopleAndTokens() throws {
        let response = try ListDirectoryPeopleResponse.decode(json)

        #expect(response.nextPageToken == "page-2")
        #expect(response.nextSyncToken == "sync-abc")
        #expect(response.people.count == 2)

        let jane = response.people[0]
        #expect(jane.resourceName == "people/c1")
        #expect(jane.etag == "etag-1")
        #expect(jane.displayName == "Jane Doe")
        #expect(jane.givenName == "Jane")
        #expect(jane.familyName == "Doe")
        #expect(jane.emails == ["jane@imeto.com", "j.doe@imeto.com"])
        #expect(jane.phoneNumbers == ["+46701234567"])
        #expect(jane.organizationTitle == "Consultant")
        #expect(jane.department == "Engineering")
        #expect(jane.photoURL == "https://example.com/jane.jpg")

        let second = response.people[1]
        #expect(second.displayName == "No Phone Person")
        #expect(second.phoneNumbers.isEmpty)
        #expect(second.organizationTitle == nil)
    }

    @Test func missingDisplayNameFallsBackToEmpty() throws {
        let data = """
        {"people": [{"resourceName": "people/c3"}]}
        """.data(using: .utf8)!
        let response = try ListDirectoryPeopleResponse.decode(data)
        #expect(response.people[0].displayName == "")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Core && swift test --filter PeopleAPIDecodingTests`
Expected: FAIL to compile — `ListDirectoryPeopleResponse` / `DirectoryPerson` not defined.

- [ ] **Step 3: Write `DirectoryPerson`**

```swift
// Core/Sources/WorkspaceContactsCore/DirectoryPerson.swift
import Foundation

/// A person from the Google Workspace directory, flattened for our use.
public struct DirectoryPerson: Equatable {
    public let resourceName: String
    public let etag: String?
    public let displayName: String
    public let givenName: String?
    public let familyName: String?
    public let emails: [String]
    public let phoneNumbers: [String]
    public let organizationTitle: String?
    public let department: String?
    public let photoURL: String?

    public init(
        resourceName: String,
        etag: String? = nil,
        displayName: String,
        givenName: String? = nil,
        familyName: String? = nil,
        emails: [String] = [],
        phoneNumbers: [String] = [],
        organizationTitle: String? = nil,
        department: String? = nil,
        photoURL: String? = nil
    ) {
        self.resourceName = resourceName
        self.etag = etag
        self.displayName = displayName
        self.givenName = givenName
        self.familyName = familyName
        self.emails = emails
        self.phoneNumbers = phoneNumbers
        self.organizationTitle = organizationTitle
        self.department = department
        self.photoURL = photoURL
    }
}
```

- [ ] **Step 4: Write the People API decoding**

```swift
// Core/Sources/WorkspaceContactsCore/PeopleAPIResponse.swift
import Foundation

/// Decodes the JSON shape returned by People API `people.listDirectoryPeople`
/// and flattens each person into a `DirectoryPerson`.
public struct ListDirectoryPeopleResponse: Decodable {
    public let people: [DirectoryPerson]
    public let nextPageToken: String?
    public let nextSyncToken: String?

    private enum CodingKeys: String, CodingKey {
        case people, nextPageToken, nextSyncToken
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decodeIfPresent([RawPerson].self, forKey: .people) ?? []
        self.people = raw.map { $0.flattened() }
        self.nextPageToken = try container.decodeIfPresent(String.self, forKey: .nextPageToken)
        self.nextSyncToken = try container.decodeIfPresent(String.self, forKey: .nextSyncToken)
    }

    public static func decode(_ data: Data) throws -> ListDirectoryPeopleResponse {
        try JSONDecoder().decode(ListDirectoryPeopleResponse.self, from: data)
    }
}

// MARK: - Raw People API shapes (private)

private struct RawMetadata: Decodable { let primary: Bool? }

private struct RawName: Decodable {
    let displayName: String?
    let givenName: String?
    let familyName: String?
    let metadata: RawMetadata?
}

private struct RawValue: Decodable {
    let value: String?
    let metadata: RawMetadata?
}

private struct RawOrganization: Decodable {
    let title: String?
    let department: String?
    let metadata: RawMetadata?
}

private struct RawPhoto: Decodable {
    let url: String?
    let metadata: RawMetadata?
}

private struct RawPerson: Decodable {
    let resourceName: String
    let etag: String?
    let names: [RawName]?
    let emailAddresses: [RawValue]?
    let phoneNumbers: [RawValue]?
    let organizations: [RawOrganization]?
    let photos: [RawPhoto]?

    func flattened() -> DirectoryPerson {
        let primaryName = names?.first(where: { $0.metadata?.primary == true }) ?? names?.first
        let primaryOrg = organizations?.first(where: { $0.metadata?.primary == true }) ?? organizations?.first
        let primaryPhoto = photos?.first(where: { $0.metadata?.primary == true }) ?? photos?.first

        return DirectoryPerson(
            resourceName: resourceName,
            etag: etag,
            displayName: primaryName?.displayName ?? "",
            givenName: primaryName?.givenName,
            familyName: primaryName?.familyName,
            emails: (emailAddresses ?? []).compactMap { $0.value },
            phoneNumbers: (phoneNumbers ?? []).compactMap { $0.value },
            organizationTitle: primaryOrg?.title,
            department: primaryOrg?.department,
            photoURL: primaryPhoto?.url
        )
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd Core && swift test --filter PeopleAPIDecodingTests`
Expected: PASS (2 tests).

- [ ] **Step 6: Commit**

```bash
git add Core/Sources Core/Tests
git commit -m "feat(core): decode People API listDirectoryPeople into DirectoryPerson"
```

---

### Task 3: Phone number E.164 normalization

**Files:**
- Create: `Core/Sources/WorkspaceContactsCore/PhoneNormalizer.swift`
- Test: `Core/Tests/WorkspaceContactsCoreTests/PhoneNormalizerTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `public enum PhoneNormalizer` with
  `public static func e164(_ raw: String, defaultCountryCode: String) -> String?`.
  Returns a `+`-prefixed digit string of length 8–15, or `nil` if the input can't be
  normalized. `defaultCountryCode` is digits only (e.g. `"46"`).

- [ ] **Step 1: Write the failing test (swift-testing)**

```swift
// Core/Tests/WorkspaceContactsCoreTests/PhoneNormalizerTests.swift
import Testing
@testable import WorkspaceContactsCore

@Suite struct PhoneNormalizerTests {
    private func norm(_ s: String) -> String? {
        PhoneNormalizer.e164(s, defaultCountryCode: "46")
    }

    @Test func alreadyE164_passesThrough() {
        #expect(norm("+46701234567") == "+46701234567")
    }

    @Test func stripsFormatting() {
        #expect(norm("+46 70-123 45 67") == "+46701234567")
        #expect(norm("(070) 123.45.67") == "+46701234567")
    }

    @Test func nationalWithLeadingZero_usesDefaultCountryCode() {
        #expect(norm("0701234567") == "+46701234567")
    }

    @Test func doubleZeroInternationalPrefix_becomesPlus() {
        #expect(norm("004670 123 45 67") == "+46701234567")
    }

    @Test func bareNationalDigits_getDefaultCountryCode() {
        // No +, no leading 0, no 00 -> treat as national subscriber number.
        #expect(norm("701234567") == "+46701234567")
    }

    @Test func emptyOrJunk_returnsNil() {
        #expect(norm("") == nil)
        #expect(norm("   ") == nil)
        #expect(norm("abc") == nil)
        #expect(norm("+") == nil)
    }

    @Test func tooShortOrTooLong_returnsNil() {
        #expect(norm("+123") == nil)                 // 3 digits, too short
        #expect(norm("+1234567890123456") == nil)    // 16 digits, too long
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Core && swift test --filter PhoneNormalizerTests`
Expected: FAIL to compile — `PhoneNormalizer` not defined.

- [ ] **Step 3: Write the normalizer**

```swift
// Core/Sources/WorkspaceContactsCore/PhoneNormalizer.swift
import Foundation

/// Best-effort E.164 normalization. A pragmatic heuristic (not a full libphonenumber);
/// good enough for a single-region corporate directory. Swap in a real library later if
/// multi-region correctness is needed.
public enum PhoneNormalizer {

    /// Returns a `+`-prefixed E.164-ish string (8–15 digits after `+`), or nil.
    /// - Parameters:
    ///   - raw: the raw phone string from the directory.
    ///   - defaultCountryCode: digits only, e.g. "46" for Sweden.
    public static func e164(_ raw: String, defaultCountryCode: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let hasPlus = trimmed.hasPrefix("+")
        let digits = trimmed.filter { $0.isNumber }
        guard !digits.isEmpty else { return nil }

        let national: String
        if hasPlus {
            national = digits
        } else if digits.hasPrefix("00") {
            national = String(digits.dropFirst(2))
        } else if digits.hasPrefix("0") {
            national = defaultCountryCode + String(digits.dropFirst(1))
        } else {
            national = defaultCountryCode + digits
        }

        guard (8...15).contains(national.count) else { return nil }
        return "+" + national
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Core && swift test --filter PhoneNormalizerTests`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add Core/Sources Core/Tests
git commit -m "feat(core): add heuristic E.164 phone normalizer"
```

---

### Task 4: DirectoryClient paging + syncToken logic

**Files:**
- Create: `Core/Sources/WorkspaceContactsCore/DirectoryClient.swift`
- Test: `Core/Tests/WorkspaceContactsCoreTests/DirectoryClientTests.swift`

**Interfaces:**
- Consumes: `ListDirectoryPeopleResponse`, `DirectoryPerson` (Task 2).
- Produces:
  - `public protocol HTTPFetching { func get(_ url: URL, bearerToken: String) async throws -> Data }`
  - `public struct DirectoryFetchResult: Equatable { public let people: [DirectoryPerson]; public let nextSyncToken: String? }`
  - `public struct DirectoryClient` with
    `init(fetcher: HTTPFetching, readMask: String = "names,phoneNumbers,emailAddresses,organizations,photos")`
    and `func fetchAll(token: String, syncToken: String?) async throws -> DirectoryFetchResult`.
  - The client follows `nextPageToken` until absent, accumulating people, and returns the
    final page's `nextSyncToken`.

- [ ] **Step 1: Write the failing test (swift-testing)**

```swift
// Core/Tests/WorkspaceContactsCoreTests/DirectoryClientTests.swift
import Testing
import Foundation
@testable import WorkspaceContactsCore

private final class StubFetcher: HTTPFetching, @unchecked Sendable {
    var responses: [Data]
    private(set) var requestedURLs: [URL] = []
    private(set) var tokens: [String] = []

    init(responses: [Data]) { self.responses = responses }

    func get(_ url: URL, bearerToken: String) async throws -> Data {
        requestedURLs.append(url)
        tokens.append(bearerToken)
        return responses.removeFirst()
    }
}

@Suite struct DirectoryClientTests {

    private func page(people: String, nextPage: String?, nextSync: String?) -> Data {
        var obj = "{\"people\":[\(people)]"
        if let n = nextPage { obj += ",\"nextPageToken\":\"\(n)\"" }
        if let s = nextSync { obj += ",\"nextSyncToken\":\"\(s)\"" }
        obj += "}"
        return obj.data(using: .utf8)!
    }

    private let p1 = "{\"resourceName\":\"people/c1\",\"names\":[{\"displayName\":\"A\"}]}"
    private let p2 = "{\"resourceName\":\"people/c2\",\"names\":[{\"displayName\":\"B\"}]}"

    @Test func followsPaging_andReturnsFinalSyncToken() async throws {
        let fetcher = StubFetcher(responses: [
            page(people: p1, nextPage: "PAGE2", nextSync: nil),
            page(people: p2, nextPage: nil, nextSync: "SYNC-END"),
        ])
        let client = DirectoryClient(fetcher: fetcher)

        let result = try await client.fetchAll(token: "TOKEN123", syncToken: nil)

        #expect(result.people.map(\.resourceName) == ["people/c1", "people/c2"])
        #expect(result.nextSyncToken == "SYNC-END")
        #expect(fetcher.requestedURLs.count == 2)
        #expect(fetcher.tokens == ["TOKEN123", "TOKEN123"])
    }

    @Test func singlePage_returnsSyncToken() async throws {
        let fetcher = StubFetcher(responses: [
            page(people: p1, nextPage: nil, nextSync: "SYNC-1"),
        ])
        let client = DirectoryClient(fetcher: fetcher)

        let result = try await client.fetchAll(token: "T", syncToken: "PREV")

        #expect(result.people.count == 1)
        #expect(result.nextSyncToken == "SYNC-1")
        #expect(fetcher.requestedURLs.count == 1)
        // The prior syncToken must be sent as a query item on the first request.
        #expect(fetcher.requestedURLs[0].absoluteString.contains("syncToken=PREV"))
    }

    @Test func readMaskAndSourceAreOnRequest() async throws {
        let fetcher = StubFetcher(responses: [
            page(people: p1, nextPage: nil, nextSync: "S"),
        ])
        let client = DirectoryClient(fetcher: fetcher)
        _ = try await client.fetchAll(token: "T", syncToken: nil)

        let url = fetcher.requestedURLs[0].absoluteString
        #expect(url.contains("readMask=names"))
        #expect(url.contains("sources=DIRECTORY_SOURCE_TYPE_DOMAIN_PROFILE"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Core && swift test --filter DirectoryClientTests`
Expected: FAIL to compile — `HTTPFetching` / `DirectoryClient` not defined.

- [ ] **Step 3: Write the client**

```swift
// Core/Sources/WorkspaceContactsCore/DirectoryClient.swift
import Foundation

/// Abstraction over the network so the paging logic is testable without URLSession.
public protocol HTTPFetching: Sendable {
    func get(_ url: URL, bearerToken: String) async throws -> Data
}

public struct DirectoryFetchResult: Equatable {
    public let people: [DirectoryPerson]
    public let nextSyncToken: String?
    public init(people: [DirectoryPerson], nextSyncToken: String?) {
        self.people = people
        self.nextSyncToken = nextSyncToken
    }
}

/// Fetches the full directory from People API `listDirectoryPeople`, following pagination.
public struct DirectoryClient {
    private let fetcher: HTTPFetching
    private let readMask: String
    private static let base = "https://people.googleapis.com/v1/people:listDirectoryPeople"

    public init(
        fetcher: HTTPFetching,
        readMask: String = "names,phoneNumbers,emailAddresses,organizations,photos"
    ) {
        self.fetcher = fetcher
        self.readMask = readMask
    }

    public func fetchAll(token: String, syncToken: String?) async throws -> DirectoryFetchResult {
        var accumulated: [DirectoryPerson] = []
        var pageToken: String? = nil
        var latestSyncToken: String? = nil
        var isFirstRequest = true

        repeat {
            let url = makeURL(pageToken: pageToken, syncToken: isFirstRequest ? syncToken : nil)
            let data = try await fetcher.get(url, bearerToken: token)
            let response = try ListDirectoryPeopleResponse.decode(data)
            accumulated.append(contentsOf: response.people)
            latestSyncToken = response.nextSyncToken ?? latestSyncToken
            pageToken = response.nextPageToken
            isFirstRequest = false
        } while pageToken != nil

        return DirectoryFetchResult(people: accumulated, nextSyncToken: latestSyncToken)
    }

    private func makeURL(pageToken: String?, syncToken: String?) -> URL {
        var components = URLComponents(string: Self.base)!
        var items = [
            URLQueryItem(name: "readMask", value: readMask),
            URLQueryItem(name: "sources", value: "DIRECTORY_SOURCE_TYPE_DOMAIN_PROFILE"),
            URLQueryItem(name: "pageSize", value: "1000"),
        ]
        if let pageToken { items.append(URLQueryItem(name: "pageToken", value: pageToken)) }
        if let syncToken { items.append(URLQueryItem(name: "syncToken", value: syncToken)) }
        // requestSyncToken tells People API to return a nextSyncToken for future incremental syncs.
        items.append(URLQueryItem(name: "requestSyncToken", value: "true"))
        components.queryItems = items
        return components.url!
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Core && swift test --filter DirectoryClientTests`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add Core/Sources Core/Tests
git commit -m "feat(core): add DirectoryClient with paging and syncToken handling"
```

---

### Task 5: ContactSync diff engine

**Files:**
- Create: `Core/Sources/WorkspaceContactsCore/ContactSync.swift`
- Test: `Core/Tests/WorkspaceContactsCoreTests/ContactSyncTests.swift`

**Interfaces:**
- Consumes: `DirectoryPerson` (Task 2), `PhoneNormalizer` (Task 3).
- Produces:
  - `public struct SyncedContactRef: Equatable { public let resourceName: String; public let contactIdentifier: String; public let contentHash: String }`
  - `public enum ContactOp: Equatable { case create(DirectoryPerson); case update(contactIdentifier: String, DirectoryPerson); case delete(contactIdentifier: String) }`
  - `public extension DirectoryPerson { func contentHash(defaultCountryCode: String) -> String }`
  - `public enum ContactSync { public static func plan(existing: [SyncedContactRef], fetched: [DirectoryPerson], defaultCountryCode: String) -> [ContactOp] }`
  - Rules: skip fetched people with no normalizable phone number; `create` when a fetched
    person's `resourceName` is not in `existing`; `update` when it exists but the content
    hash differs; no-op when hash matches; `delete` for existing refs whose `resourceName`
    is absent from the (phone-eligible) fetched set. Output order: creates, then updates,
    then deletes; within each group, input order is preserved.

- [ ] **Step 1: Write the failing test (swift-testing)**

```swift
// Core/Tests/WorkspaceContactsCoreTests/ContactSyncTests.swift
import Testing
@testable import WorkspaceContactsCore

@Suite struct ContactSyncTests {
    private let cc = "46"

    private func person(_ id: String, name: String, phone: String?) -> DirectoryPerson {
        DirectoryPerson(
            resourceName: id,
            displayName: name,
            phoneNumbers: phone.map { [$0] } ?? []
        )
    }

    @Test func createsNewPeopleWithPhone() {
        let fetched = [person("people/c1", name: "Jane", phone: "0701234567")]
        let ops = ContactSync.plan(existing: [], fetched: fetched, defaultCountryCode: cc)
        #expect(ops == [.create(fetched[0])])
    }

    @Test func skipsPeopleWithoutNormalizablePhone() {
        let fetched = [
            person("people/c1", name: "NoPhone", phone: nil),
            person("people/c2", name: "JunkPhone", phone: "abc"),
        ]
        let ops = ContactSync.plan(existing: [], fetched: fetched, defaultCountryCode: cc)
        #expect(ops == [])
    }

    @Test func noOpWhenHashUnchanged() {
        let jane = person("people/c1", name: "Jane", phone: "0701234567")
        let existing = [SyncedContactRef(
            resourceName: "people/c1",
            contactIdentifier: "ABC",
            contentHash: jane.contentHash(defaultCountryCode: cc)
        )]
        let ops = ContactSync.plan(existing: existing, fetched: [jane], defaultCountryCode: cc)
        #expect(ops == [])
    }

    @Test func updatesWhenContentChanged() {
        let old = person("people/c1", name: "Jane", phone: "0701234567")
        let new = person("people/c1", name: "Jane Doe", phone: "0701234567")
        let existing = [SyncedContactRef(
            resourceName: "people/c1",
            contactIdentifier: "ABC",
            contentHash: old.contentHash(defaultCountryCode: cc)
        )]
        let ops = ContactSync.plan(existing: existing, fetched: [new], defaultCountryCode: cc)
        #expect(ops == [.update(contactIdentifier: "ABC", new)])
    }

    @Test func deletesWhenPersonGone() {
        let existing = [SyncedContactRef(
            resourceName: "people/c1",
            contactIdentifier: "ABC",
            contentHash: "whatever"
        )]
        let ops = ContactSync.plan(existing: existing, fetched: [], defaultCountryCode: cc)
        #expect(ops == [.delete(contactIdentifier: "ABC")])
    }

    @Test func personLosingPhone_isDeleted() {
        let existing = [SyncedContactRef(
            resourceName: "people/c1",
            contactIdentifier: "ABC",
            contentHash: "whatever"
        )]
        let nowNoPhone = [person("people/c1", name: "Jane", phone: nil)]
        let ops = ContactSync.plan(existing: existing, fetched: nowNoPhone, defaultCountryCode: cc)
        #expect(ops == [.delete(contactIdentifier: "ABC")])
    }

    @Test func ordering_createsThenUpdatesThenDeletes() {
        let create = person("people/new", name: "New", phone: "0700000001")
        let updOld = person("people/upd", name: "Old", phone: "0700000002")
        let updNew = person("people/upd", name: "Updated", phone: "0700000002")
        let existing = [
            SyncedContactRef(resourceName: "people/upd", contactIdentifier: "U",
                             contentHash: updOld.contentHash(defaultCountryCode: cc)),
            SyncedContactRef(resourceName: "people/gone", contactIdentifier: "G",
                             contentHash: "x"),
        ]
        let ops = ContactSync.plan(existing: existing, fetched: [create, updNew], defaultCountryCode: cc)
        #expect(ops == [
            .create(create),
            .update(contactIdentifier: "U", updNew),
            .delete(contactIdentifier: "G"),
        ])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd Core && swift test --filter ContactSyncTests`
Expected: FAIL to compile — `ContactSync` / `SyncedContactRef` / `ContactOp` / `contentHash` not defined.

- [ ] **Step 3: Write the diff engine**

```swift
// Core/Sources/WorkspaceContactsCore/ContactSync.swift
import Foundation

/// A record of a contact we previously wrote, used to diff against a fresh fetch.
public struct SyncedContactRef: Equatable {
    public let resourceName: String
    public let contactIdentifier: String
    public let contentHash: String
    public init(resourceName: String, contactIdentifier: String, contentHash: String) {
        self.resourceName = resourceName
        self.contactIdentifier = contactIdentifier
        self.contentHash = contentHash
    }
}

/// An operation the app should apply to CNContactStore.
public enum ContactOp: Equatable {
    case create(DirectoryPerson)
    case update(contactIdentifier: String, DirectoryPerson)
    case delete(contactIdentifier: String)
}

public extension DirectoryPerson {
    /// A stable string capturing the fields we mirror into a contact. If this changes, the
    /// contact needs updating. Phones are normalized so formatting-only changes don't churn.
    func contentHash(defaultCountryCode: String) -> String {
        let normalizedPhones = phoneNumbers
            .compactMap { PhoneNormalizer.e164($0, defaultCountryCode: defaultCountryCode) }
            .sorted()
        let parts: [String] = [
            displayName,
            givenName ?? "",
            familyName ?? "",
            emails.sorted().joined(separator: ","),
            normalizedPhones.joined(separator: ","),
            organizationTitle ?? "",
            department ?? "",
            photoURL ?? "",
        ]
        return parts.joined(separator: "|")
    }

    /// True if this person has at least one phone number we can normalize.
    func hasNormalizablePhone(defaultCountryCode: String) -> Bool {
        phoneNumbers.contains { PhoneNormalizer.e164($0, defaultCountryCode: defaultCountryCode) != nil }
    }
}

/// Pure diff: given what we synced before and what the directory returns now, produce the
/// create/update/delete operations to reconcile them.
public enum ContactSync {
    public static func plan(
        existing: [SyncedContactRef],
        fetched: [DirectoryPerson],
        defaultCountryCode: String
    ) -> [ContactOp] {
        let eligible = fetched.filter { $0.hasNormalizablePhone(defaultCountryCode: defaultCountryCode) }
        let existingByResource = Dictionary(
            existing.map { ($0.resourceName, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let eligibleResourceNames = Set(eligible.map(\.resourceName))

        var creates: [ContactOp] = []
        var updates: [ContactOp] = []
        var deletes: [ContactOp] = []

        for person in eligible {
            if let ref = existingByResource[person.resourceName] {
                if ref.contentHash != person.contentHash(defaultCountryCode: defaultCountryCode) {
                    updates.append(.update(contactIdentifier: ref.contactIdentifier, person))
                }
            } else {
                creates.append(.create(person))
            }
        }

        for ref in existing where !eligibleResourceNames.contains(ref.resourceName) {
            deletes.append(.delete(contactIdentifier: ref.contactIdentifier))
        }

        return creates + updates + deletes
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd Core && swift test --filter ContactSyncTests`
Expected: PASS (7 tests).

- [ ] **Step 5: Run the whole suite**

Run: `cd Core && swift test`
Expected: PASS — all tests across Tasks 1–5 green (20 tests total).

- [ ] **Step 6: Commit**

```bash
git add Core/Sources Core/Tests
git commit -m "feat(core): add ContactSync diff engine (create/update/delete)"
```

---

## What this plan intentionally defers (next plan)

- `AuthService` (AppAuth + PKCE, `hd=imeto.com`, non-imeto rejection, Keychain).
- Live `HTTPFetching` implementation over `URLSession`.
- `CNContactStore` executor that applies `[ContactOp]` (create/update/delete, `CNGroup`
  tagging, marker) — Simulator/device verified.
- Local persistence of `[SyncedContactRef]` + `nextSyncToken`.
- SwiftUI shell, `BGAppRefreshTask`, onboarding consent + "Remove all synced contacts".
- The Xcode app target wiring the package in.
