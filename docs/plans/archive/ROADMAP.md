# Shipped

Log of completed plans, archived in this folder by the `close-out` skill. Kept as decision
records — what shipped, and the verification evidence that it worked. Newest first.

<!-- close-out appends: - YYYY-MM-DD [<feature>](<file>.md) — one-line outcome -->

- 2026-07-04 [App Plan A — signed-in directory list](2026-07-04-workspace-contacts-app-signin.md) — XcodeGen app + GoogleSignIn (`@imeto.com` enforced) + `URLSessionHTTPFetcher` + SwiftUI list on Core's `DirectoryClient`. Verified on iOS Simulator (Xcode 26.6, iPhone 17 Pro/iOS 26.5): Core 27/27 headless (`make test`), app 2/2 unit tests (`** TEST SUCCEEDED **`), and the **live E2E milestone** — sign in with an `@imeto.com` account → full colleague list from the Workspace directory. Live run also drove out fixes (Core `Sendable`, serialized fetcher tests, richer `HTTPFetchError`) and documented prerequisites (People API `gcloud` enable; Admin-console External directory sharing → "organization data").
- 2026-07-04 [WorkspaceContacts Core package](2026-07-04-workspace-contacts-core.md) — headless SwiftPM logic core (People-API decoding, E.164 normalization, DirectoryClient paging/syncToken, ContactSync diff engine); `swift test` green 21/21 under Command Line Tools via swift-testing.
