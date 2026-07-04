# WorkspaceContacts App — Signed-in Directory List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Execution note:** This plan builds an iOS **app target**, which requires **full Xcode** (Simulator + `xcodebuild`). The CLI/agent environment has Command Line Tools only, so the code is *authored* here but **compiled and run by the developer on a Mac with Xcode**. Only the Core-package change (Task 2) is headless-testable via `swift test`. Every app task's verification is a developer-run build/Simulator step — do not mark those tasks done without pasted build/run output.
>
> **Status (2026-07-04):** All code authored + **built and tested on iOS Simulator (Xcode 26.6, iPhone 17 Pro, iOS 26.5)**. Evidence: `cd Core && make test` → `✔ 27 tests passed`; `xcodegen generate` → project created; `xcodebuild ... test` → **`** TEST SUCCEEDED **`, 2/2 app tests pass** (`URLSessionHTTPFetcherTests`). SwiftPM resolved GoogleSignIn 9.2.0 + full Google dep graph.
> The build surfaced two Swift-6 defects the headless tests couldn't, both fixed: (1) Core value types weren't `Sendable` → app failed to compile (`fix(core): ...Sendable`); (2) the fetcher tests shared a static `URLProtocol` stub and raced under swift-testing's parallel execution → `@Suite(.serialized)` (`fix(app): serialize...`).
> **Only 1 step remains: the live sign-in→list milestone (Task 5 Step 5)** — it needs the real Google Cloud **iOS OAuth client id** in `project.yml` (done) and an interactive Google login, so it can't be automated here. Everything else is verified.
>
> **Signing note for the live step (learned the hard way):** GoogleSignIn writes tokens to the keychain, which needs an `application-identifier` entitlement → the build must be signed with a **team**. A *free* personal Apple ID team suffices (no paid account, no physical device needed for the Simulator). But the entitlement is **only accepted when the app is run from the Xcode IDE (⌘R)** with automatic signing + the team selected — a headless `xcodebuild build` + `simctl install` signs ad-hoc with empty entitlements (keychain fails: "keychain error" / `[keychain] <compose failure>`), and manually re-signing the `.app` with the entitlement makes the Simulator refuse to launch (`FBSOpenApplicationServiceErrorDomain code=1`). So: run Task 5 Step 5 from Xcode (target → Signing & Capabilities → Automatically manage signing + Personal Team → ⌘R). The Google Cloud iOS client needs only a matching **Bundle ID**; App Store ID / Team ID there are optional and unrelated to this.
>
> **Build recipe used here** (full Xcode is installed but `xcode-select` points at Command Line Tools, so `DEVELOPER_DIR` is set per-command; global git config left untouched):
> ```bash
> brew install xcodegen
> DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -downloadPlatform iOS   # once, ~8.5 GB
> cd app && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodegen generate
> DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
>   GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.bareRepository GIT_CONFIG_VALUE_0=all \
>   xcodebuild -scheme WorkspaceContacts -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
>   -clonedSourcePackagesDirPath .build-spm CODE_SIGNING_ALLOWED=NO test
> ```

## Goal

A colleague opens the app, taps "Sign in with Google", authenticates with their `@imeto.com` account, grants directory access, and immediately sees a scrollable list of their Imeto colleagues (name, title, phone, email) fetched live from the Workspace directory.

## Scope

**In:** the first runnable app increment that proves the **read path** end-to-end against live Google — XcodeGen project, GoogleSignIn auth (`@imeto.com` enforced, `directory.readonly` scope), a `URLSession` implementation of the Core `HTTPFetching` seam, and a SwiftUI screen that drives sign-in → fetch (via the Core `DirectoryClient`) → list.

**Out (deferred to the next plan, "Sync to Contacts"):** writing to `CNContactStore`, `SyncedContactRef` persistence, the `ContactSync` diff applied to the device, sign-out contact cleanup / "remove all", `BGAppRefreshTask`, onboarding-consent polish. This plan does **not** touch the device address book at all.

## Verification

This increment is proven on a Mac with Xcode. Runnable checks:

1. **Headless (agent or CI):** `cd Core && swift test` → all tests pass including the new `EmailDomainTests` (Task 2).
2. **Project generates:** `cd app && xcodegen generate` → `WorkspaceContacts.xcodeproj` is created with no errors.
3. **Builds:** open in Xcode (or `xcodebuild -scheme WorkspaceContacts -destination 'generic/platform=iOS Simulator' build`) → build succeeds; SwiftPM resolves the local `WorkspaceContactsCore` package and the remote `GoogleSignIn` package.
4. **Unit tests (Xcode, Cmd-U):** the app test target passes, including `URLSessionHTTPFetcherTests`.
5. **End-to-end (Simulator) — the milestone:** run the app, tap **Sign in with Google**, authenticate with an `@imeto.com` account, grant the directory permission → the app shows a non-empty list of colleagues. Signing in with a non-`imeto.com` account is rejected with a clear message.

## Prerequisites the developer must supply (external, one-time)

The app cannot authenticate until these exist — set them up in the Imeto Google Cloud project (single-org, **Internal** OAuth consent screen):

1. Create an **OAuth 2.0 Client ID** of type **iOS** for bundle id `com.imeto.workspacecontacts.app`.
2. Copy the **iOS client ID** (`NNN-xxxx.apps.googleusercontent.com`) into `app/project.yml` at `GIDClientID`.
3. Compute the **reversed client ID** (`com.googleusercontent.apps.NNN-xxxx`) and put it in `app/project.yml` under `CFBundleURLTypes → CFBundleURLSchemes`.
4. **Enable the People API** on the project, and ensure **directory sharing** is on for the domain.
   Without the API enabled, sign-in succeeds but the first fetch returns `HTTP 403 …
   "reason": "SERVICE_DISABLED"` ("People API has not been used in project NNN before or it is
   disabled"). Enable it (propagation can take a few minutes):

   ```bash
   # Requires gcloud CLI authenticated (`gcloud auth login`) with rights on the project.
   PROJECT_ID=your-gcp-project-id            # numeric id also works, e.g. 950349872392
   gcloud services enable people.googleapis.com --project="$PROJECT_ID"

   # Verify it's active:
   gcloud services list --enabled --project="$PROJECT_ID" --filter="config.name:people.googleapis.com"
   ```
   (GUI equivalent: APIs & Services → Library → "People API" → Enable.) Directory sharing is a
   Workspace **Admin console** setting (Directory → Directory settings → Sharing settings), not a
   `gcloud` toggle. Two sub-settings matter, and both must be right:
   - **Contact sharing** → **ON**.
   - **External directory sharing** → must be **"Organization data and basic profile fields"**
     (the option that shares org profile data for *all* users), **not** "Basic profile fields for
     the authenticated user" (that one shares only the signed-in user and explicitly does **not**
     share other users' profiles → `listDirectoryPeople` returns
     `HTTP 403 … "The G Suite domain admin has disabled external directory sharing"`).
     Takes a few minutes to propagate (Google says up to 24h). Ref: support.google.com/a/answer/6343701.

Until these are filled, Tasks 1–4 still build; only Task 5's live sign-in requires them.

**Architecture:** SwiftUI app (iOS 16) generated by XcodeGen. `AuthService` wraps GoogleSignIn (v9); `URLSessionHTTPFetcher` satisfies the Core package's `HTTPFetching` protocol; `AppModel` orchestrates auth → `DirectoryClient.fetchAll` → `[DirectoryPerson]` and publishes UI state; `ContentView` renders sign-in and the list. The app depends on the already-shipped `WorkspaceContactsCore` package for all directory decoding/paging logic.

**Tech Stack:** Swift 6.1, SwiftUI, XcodeGen, GoogleSignIn-iOS `from: "9.0.0"` (current 9.2.0), the local `WorkspaceContactsCore` SwiftPM package, swift-testing.

## Global Constraints

- **Full Xcode required to build/run.** App-target tasks are verified by developer-run build + Simulator, with pasted output. Only Task 2 (Core change) runs under `swift test`.
- **Test framework: swift-testing** (`import Testing`, `@Suite`, `@Test`, `#expect`) everywhere — never XCTest.
- **App location:** `app/` at repo root, sibling to `Core/`. `app/project.yml`, `app/Sources/`, `app/Tests/`.
- **Bundle id:** `com.imeto.workspacecontacts.app`. **Deployment target:** iOS 16.0.
- **GoogleSignIn:** import `GoogleSignIn`; pin `from: "9.0.0"`. `signIn(withPresenting:hint:additionalScopes:)` is `async throws -> GIDSignInResult`; `addScopes` is on `GIDGoogleUser`; access token is `user.accessToken.tokenString`; forward callback via `GIDSignIn.sharedInstance.handle(url)` in `.onOpenURL`.
- **Directory scope:** `https://www.googleapis.com/auth/directory.readonly`, requested at sign-in via `additionalScopes`.
- **Domain enforcement is client-side UX only:** accept sign-in only when `user.profile?.email` ends with `@imeto.com`; otherwise sign out and show an error. (Real enforcement is the org's Internal consent screen.)
- **Tenancy:** single-org `imeto.com`. The allowed domain is a single constant, not user-configurable.
- **No device Contacts access in this plan** — do not import `Contacts`.

---

### Task 1: XcodeGen project + buildable SwiftUI shell

**Files:**
- Create: `app/project.yml`
- Create: `app/Sources/WorkspaceContactsApp.swift`
- Create: `app/Sources/ContentView.swift`
- Create: `app/.gitignore`

**Interfaces:**
- Consumes: the local `WorkspaceContactsCore` package at `../Core`.
- Produces: a generatable, buildable iOS app target `WorkspaceContacts` that launches to a placeholder screen; SwiftPM resolves both the local Core package and the remote GoogleSignIn package.

- [x] **Step 1: Create `app/project.yml`**

```yaml
name: WorkspaceContacts

options:
  bundleIdPrefix: com.imeto.workspacecontacts
  deploymentTarget:
    iOS: "16.0"

packages:
  WorkspaceContactsCore:
    path: ../Core
  GoogleSignIn:
    url: https://github.com/google/GoogleSignIn-iOS
    from: "9.0.0"

targets:
  WorkspaceContacts:
    type: application
    platform: iOS
    deploymentTarget: "16.0"
    sources:
      - path: Sources
    info:
      path: Sources/Info.plist
      properties:
        UILaunchScreen: {}
        UIApplicationSceneManifest:
          UIApplicationSupportsMultipleScenes: false
        # --- FILL THESE from the Imeto Google Cloud iOS OAuth client (see plan prerequisites) ---
        GIDClientID: YOUR_IOS_CLIENT_ID.apps.googleusercontent.com
        CFBundleURLTypes:
          - CFBundleURLSchemes:
              - com.googleusercontent.apps.YOUR_IOS_CLIENT_ID
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.imeto.workspacecontacts.app
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
        SWIFT_VERSION: "6.0"
        TARGETED_DEVICE_FAMILY: "1"
    dependencies:
      - package: WorkspaceContactsCore
        product: WorkspaceContactsCore
      - package: GoogleSignIn
        product: GoogleSignIn

  WorkspaceContactsTests:
    type: bundle.unit-test
    platform: iOS
    deploymentTarget: "16.0"
    sources:
      - path: Tests
    dependencies:
      - target: WorkspaceContacts
```

- [x] **Step 2: Create the app entry point**

```swift
// app/Sources/WorkspaceContactsApp.swift
import SwiftUI

@main
struct WorkspaceContactsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [x] **Step 3: Create a placeholder `ContentView`**

```swift
// app/Sources/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.largeTitle)
            Text("WorkspaceContacts")
                .font(.headline)
        }
        .padding()
    }
}
```

- [x] **Step 4: Create `app/.gitignore`**

```gitignore
# XcodeGen output — regenerate with `xcodegen generate`
*.xcodeproj
# Xcode user state / build
xcuserdata/
DerivedData/
build/
```

- [x] **Step 5: Generate and build (developer, on a Mac with Xcode)**

```bash
brew install xcodegen        # if not already installed
cd app && xcodegen generate  # writes WorkspaceContacts.xcodeproj
open WorkspaceContacts.xcodeproj
```
Then in Xcode: select an iOS Simulator, Build & Run (Cmd-R).
Expected: SwiftPM resolves `WorkspaceContactsCore` (local) and `GoogleSignIn` (remote); the app launches showing the "WorkspaceContacts" placeholder screen. (Valid `GIDClientID` not required for this build.)

- [x] **Step 6: Commit**

```bash
git add app/project.yml app/Sources app/.gitignore
git commit -m "feat(app): XcodeGen project + buildable SwiftUI shell"
```

---

### Task 2: `EmailDomain` helper in Core (headless TDD)

**Files:**
- Create: `Core/Sources/WorkspaceContactsCore/EmailDomain.swift`
- Test: `Core/Tests/WorkspaceContactsCoreTests/EmailDomainTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `public enum EmailDomain { public static func matches(email: String, domain: String) -> Bool }` — case-insensitive; true only when `email` has exactly one `@` and the part after it equals `domain` (case-insensitively), ignoring surrounding whitespace. Used by the app's `AuthService` to enforce `imeto.com`.

- [x] **Step 1: Write the failing test (swift-testing)**

```swift
// Core/Tests/WorkspaceContactsCoreTests/EmailDomainTests.swift
import Testing
@testable import WorkspaceContactsCore

@Suite struct EmailDomainTests {
    @Test func matchesExactDomain() {
        #expect(EmailDomain.matches(email: "jane@imeto.com", domain: "imeto.com"))
    }

    @Test func isCaseInsensitive() {
        #expect(EmailDomain.matches(email: "Jane@IMETO.com", domain: "imeto.com"))
        #expect(EmailDomain.matches(email: "jane@imeto.com", domain: "IMETO.COM"))
    }

    @Test func trimsWhitespace() {
        #expect(EmailDomain.matches(email: "  jane@imeto.com  ", domain: "imeto.com"))
    }

    @Test func rejectsOtherDomain() {
        #expect(!EmailDomain.matches(email: "jane@gmail.com", domain: "imeto.com"))
    }

    @Test func rejectsSubdomainImpersonation() {
        // "imeto.com.evil.com" must NOT match "imeto.com"
        #expect(!EmailDomain.matches(email: "jane@imeto.com.evil.com", domain: "imeto.com"))
        // "notimeto.com" must NOT match
        #expect(!EmailDomain.matches(email: "jane@notimeto.com", domain: "imeto.com"))
    }

    @Test func rejectsMalformed() {
        #expect(!EmailDomain.matches(email: "jane", domain: "imeto.com"))
        #expect(!EmailDomain.matches(email: "jane@a@imeto.com", domain: "imeto.com"))
        #expect(!EmailDomain.matches(email: "", domain: "imeto.com"))
    }
}
```

- [x] **Step 2: Run test to verify it fails**

Run: `cd Core && swift test --filter EmailDomainTests`
Expected: FAIL to compile — `EmailDomain` not defined.

- [x] **Step 3: Implement `EmailDomain`**

```swift
// Core/Sources/WorkspaceContactsCore/EmailDomain.swift
import Foundation

/// Pure helper for verifying an email belongs to a specific domain.
/// Used to enforce single-org (imeto.com) sign-in on the client side.
public enum EmailDomain {
    /// True only when `email` has exactly one `@` and the domain part equals `domain`
    /// (case-insensitively, ignoring surrounding whitespace).
    public static func matches(email: String, domain: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        return parts[1].lowercased() == domain.lowercased()
    }
}
```

- [x] **Step 4: Run tests to verify they pass**

Run: `cd Core && swift test --filter EmailDomainTests`
Expected: PASS (6 tests).

- [x] **Step 5: Run the full Core suite (no regressions)**

Run: `cd Core && swift test`
Expected: PASS — previous 21 + 6 new = **27 tests**.

- [x] **Step 6: Commit**

```bash
git add Core/Sources Core/Tests
git commit -m "feat(core): add EmailDomain helper for single-org enforcement"
```

---

### Task 3: `AuthService` (GoogleSignIn wrapper)

**Files:**
- Create: `app/Sources/RootViewController.swift`
- Create: `app/Sources/AuthService.swift`

**Interfaces:**
- Consumes: `GoogleSignIn`; `WorkspaceContactsCore.EmailDomain` (Task 2).
- Produces:
  - `@MainActor final class AuthService: ObservableObject` with
    `@Published private(set) var email: String?`, `@Published private(set) var state: AuthState`,
    `func signIn() async`, `func restore() async`, `func signOut()`, and
    `func accessToken() async -> String?`.
  - `enum AuthState: Equatable { case signedOut; case signedIn; case error(String) }`.
  - The allowed domain constant `imeto.com` and the scope live here.

- [x] **Step 1: Create the presenting-VC helper**

```swift
// app/Sources/RootViewController.swift
import UIKit

/// Finds the top-most view controller to present the Google sign-in sheet from,
/// which SwiftUI does not expose directly.
@MainActor
enum RootViewController {
    static func topMost() -> UIViewController {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let root = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? UIViewController()
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}
```

- [x] **Step 2: Implement `AuthService`**

```swift
// app/Sources/AuthService.swift
import Foundation
import GoogleSignIn
import WorkspaceContactsCore

enum AuthState: Equatable {
    case signedOut
    case signedIn
    case error(String)
}

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var email: String?
    @Published private(set) var state: AuthState = .signedOut

    private let allowedDomain = "imeto.com"
    private let directoryScope = "https://www.googleapis.com/auth/directory.readonly"

    /// Interactive sign-in. Requests the directory scope up front, then enforces the domain.
    func signIn() async {
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: RootViewController.topMost(),
                hint: nil,
                additionalScopes: [directoryScope]
            )
            try accept(result.user)
        } catch let authError as AuthError {
            state = .error(authError.message)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Silent restore on launch (also refreshes expired tokens).
    func restore() async {
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else { return }
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            try accept(user)
        } catch {
            state = .signedOut
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        email = nil
        state = .signedOut
    }

    /// A fresh access token for API calls, refreshing if needed. Nil if not signed in.
    func accessToken() async -> String? {
        guard let user = GIDSignIn.sharedInstance.currentUser else { return nil }
        if let refreshed = try? await user.refreshTokensIfNeeded() {
            return refreshed.accessToken.tokenString
        }
        return user.accessToken.tokenString
    }

    // MARK: - Private

    private func accept(_ user: GIDGoogleUser) throws {
        guard let addr = user.profile?.email,
              EmailDomain.matches(email: addr, domain: allowedDomain) else {
            GIDSignIn.sharedInstance.signOut()
            throw AuthError.wrongDomain(allowedDomain)
        }
        guard (user.grantedScopes ?? []).contains(directoryScope) else {
            GIDSignIn.sharedInstance.signOut()
            throw AuthError.missingScope
        }
        email = addr
        state = .signedIn
    }

    private enum AuthError: Error {
        case wrongDomain(String)
        case missingScope

        var message: String {
            switch self {
            case .wrongDomain(let d): return "Please sign in with your @\(d) account."
            case .missingScope: return "Directory access is required to show colleagues."
            }
        }
    }
}
```

- [x] **Step 3: Build (developer)**

Run: in Xcode, Build (Cmd-B) after `cd app && xcodegen generate`.
Expected: compiles cleanly; `AuthService` and `RootViewController` are part of the target. (Behavior is exercised in Task 5.)

- [x] **Step 4: Commit**

```bash
git add app/Sources/RootViewController.swift app/Sources/AuthService.swift
git commit -m "feat(app): AuthService wrapping GoogleSignIn with imeto.com enforcement"
```

---

### Task 4: `URLSessionHTTPFetcher` (implements Core `HTTPFetching`)

**Files:**
- Create: `app/Sources/URLSessionHTTPFetcher.swift`
- Test: `app/Tests/URLSessionHTTPFetcherTests.swift`

**Interfaces:**
- Consumes: `WorkspaceContactsCore.HTTPFetching`.
- Produces: `struct URLSessionHTTPFetcher: HTTPFetching` — `init(session: URLSession = .shared)`; `func get(_ url: URL, bearerToken: String) async throws -> Data` sends `Authorization: Bearer <token>`, and throws `HTTPFetchError.status(Int)` for non-2xx responses. This is the live implementation of the seam the Core `DirectoryClient` consumes.

- [x] **Step 1: Write the failing test (swift-testing, URLProtocol stub)**

```swift
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

@Suite struct URLSessionHTTPFetcherTests {
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
```

- [x] **Step 2: Run test to verify it fails (developer, Xcode Cmd-U)**

Expected: FAIL to compile — `URLSessionHTTPFetcher` / `HTTPFetchError` not defined.

- [x] **Step 3: Implement the fetcher**

```swift
// app/Sources/URLSessionHTTPFetcher.swift
import Foundation
import WorkspaceContactsCore

public enum HTTPFetchError: Error, Equatable {
    case notHTTP
    case status(Int)
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
            throw HTTPFetchError.status(http.statusCode)
        }
        return data
    }
}
```

- [x] **Step 4: Run tests to verify they pass (developer, Xcode Cmd-U)**

Expected: PASS (2 tests) in the `WorkspaceContactsTests` target.

- [x] **Step 5: Commit**

```bash
git add app/Sources/URLSessionHTTPFetcher.swift app/Tests/URLSessionHTTPFetcherTests.swift
git commit -m "feat(app): URLSessionHTTPFetcher implementing Core HTTPFetching"
```

---

### Task 5: `AppModel` + list UI (sign-in → fetch → list)

**Files:**
- Create: `app/Sources/AppModel.swift`
- Modify: `app/Sources/ContentView.swift`
- Modify: `app/Sources/WorkspaceContactsApp.swift`

**Interfaces:**
- Consumes: `AuthService` (Task 3), `URLSessionHTTPFetcher` (Task 4), `WorkspaceContactsCore.DirectoryClient` / `DirectoryPerson` / `DirectoryFetchResult`.
- Produces:
  - `@MainActor final class AppModel: ObservableObject` with
    `@Published private(set) var people: [DirectoryPerson]`,
    `@Published private(set) var status: LoadStatus`,
    `@Published private(set) var authState: AuthState`,
    `func signIn() async`, `func restore() async`, `func signOut()`, `func refresh() async`.
  - `enum LoadStatus: Equatable { case idle; case loading; case loaded(Int); case failed(String) }`.
  - `AppModel` mirrors the nested `AuthService.state` into its own `@Published authState` after every auth call, so the SwiftUI view (which observes `AppModel`, not the nested `AuthService`) re-renders on sign-in/error. `ContentView` reads `model.authState`, never `model.auth.state`.
  - `ContentView` observing `AppModel`: shows a sign-in button when signed out, the colleague list when loaded, and error/loading states.

- [x] **Step 1: Implement `AppModel`**

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
```

- [x] **Step 2: Replace `ContentView` with the real UI**

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
                            Button("Sign out") { model.signOut() }
                        }
                    }
                }
        }
        .task { await model.restore() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.status {
        case .idle where model.authState != .signedIn:
            signInScreen
        case .loading:
            ProgressView("Loading directory…")
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message).multilineTextAlignment(.center).foregroundStyle(.secondary)
                Button("Try again") { Task { await model.refresh() } }
            }.padding()
        default:
            list
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

- [x] **Step 3: Wire the OAuth callback in the app entry point**

```swift
// app/Sources/WorkspaceContactsApp.swift
import SwiftUI
import GoogleSignIn

@main
struct WorkspaceContactsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
```

- [x] **Step 4: Fill credentials, generate, build (developer)**

Ensure `app/project.yml` has the real `GIDClientID` and reversed `CFBundleURLSchemes` (see plan prerequisites), then:
```bash
cd app && xcodegen generate
```
Build & Run on an iOS Simulator (Cmd-R). Expected: launches to the sign-in screen.

- [x] **Step 5: End-to-end verification (developer, Simulator) — the milestone**

1. Tap **Sign in with Google**, complete Google auth with an **@imeto.com** account, and grant the directory permission.
   Expected: the app shows a non-empty, alphabetically sorted list of colleagues (name, title, phone where present).
2. Sign out, then sign in with a **non-imeto** Google account.
   Expected: rejected with "Please sign in with your @imeto.com account." and no list shown.

Paste the observed result (row count and the two outcomes) into the commit message / close-out evidence.

- [x] **Step 6: Commit**

```bash
git add app/Sources/AppModel.swift app/Sources/ContentView.swift app/Sources/WorkspaceContactsApp.swift
git commit -m "feat(app): sign-in -> live directory fetch -> colleague list"
```

---

## What this plan intentionally defers (next plan: "Sync to Contacts")

- `ContactWriter` — a `CNContactStore` executor applying `[ContactOp]` (create/update/delete), a `CNGroup` "Imeto Directory" tag, and Contacts permission handling.
- `SyncStore` — persistence of `[SyncedContactRef]` + `nextSyncToken` (so `ContactSync.plan` can diff incrementally).
- Wiring `ContactSync.plan` into the app and executing the ops after fetch.
- Sign-out / "Remove all synced contacts" cleanup, onboarding consent copy about the iCloud caveat.
- `BGAppRefreshTask` for periodic background sync.
- Phone-number `defaultCountryCode` selection (Sweden `"46"`) surfaced where the diff engine is invoked.
