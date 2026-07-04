# WorkspaceContacts — Sync to Contacts (App Plan B) — Design

> Spec for the second app increment. Builds on the shipped Core package and App Plan A
> (signed-in directory list, archived). Turns the fetched directory into native `CNContact`s so
> colleagues get **incoming caller ID** and **call-by-name** in the native Phone app.

## Goal

After a colleague has signed in and their directory loads (Plan A), they grant a one-time consent
and the app writes those colleagues into the device address book as native contacts — kept in
sync (create/update/delete) on every refresh — so an incoming call from a colleague shows their
name, and typing a name in the Phone app / Spotlight finds them. A clear "Remove all synced
contacts" action, and sign-out, remove exactly what the app added.

## Scope

**In:**
- A `ContactStoreWriting` seam + pure `ContactSyncExecutor` in **Core** (headless-tested) that
  applies `[ContactOp]` (from the already-shipped `ContactSync.plan`) and returns the updated
  `[SyncedContactRef]`.
- `SyncState { refs, nextSyncToken }` persistence.
- A live **`CNContactStore`** implementation in the app: maps `DirectoryPerson → CNMutableContact`,
  tags with a dedicated `CNGroup "Imeto Directory"`, applies add/update/delete, and removes all.
- Orchestration: after the Plan A **full** directory fetch, run `ContactSync.plan` (which diffs the
  complete fetched set against the persisted refs to produce create/update/delete) → execute →
  persist the updated refs.
- One-time **consent** onboarding (contacts land in the real address book; may reach iCloud),
  Contacts permission handling, sync-status UI, "Sync now", "Remove all synced contacts".
- **Sign-out removes all** synced contacts.
- Periodic background sync via `BGAppRefreshTask` (SwiftUI `.backgroundTask(.appRefresh)`).

**Out:**
- Verifying real **incoming caller ID on a physical device** — needs a real iPhone (and a colleague
  with a phone number to call). This plan is verified on the **Simulator** (contacts written /
  updated / removed and visible in the Contacts app). Device caller-ID stays a later manual check.
- A separate `CNContainer`/CardDAV account for isolation — **no public API exists** (see the iOS
  caller-ID constraints); we mitigate with the group + map + explicit removal + consent instead.
- Multi-region phone handling — `defaultCountryCode` is the single constant `"46"` (Sweden),
  matching single-org tenancy.
- **`syncToken`-based incremental fetch.** `ContactSync.plan` is a full-set diff, so incremental
  responses (changed-only, with deletion markers) don't fit it without new Core support. Plan B
  does a full fetch each sync (correct, cheap at this scale); incremental is a later optimization.
- Any change to the Plan A read path (auth, `DirectoryClient`, list rendering) beyond wiring sync in.

## Verification

1. **Headless (`cd Core && make test`):** new `ContactSyncExecutorTests` (apply create/update/delete
   through a fake `ContactStoreWriting`; assert the exact store calls and the resulting
   `[SyncedContactRef]` incl. content-hash) pass alongside the existing suite. Expected: previous
   **27** + new tests, all green.
2. **App tests (`xcodebuild … test` on the Simulator):** an integration test drives the real
   `CNContactStoreWriter` against the Simulator's Contacts DB — create → re-read & assert fields →
   update → assert → delete → assert gone; plus a `SyncStore` round-trip test. Expected:
   `** TEST SUCCEEDED **`.
3. **End-to-end (Simulator) — the milestone:** run the app, sign in with an `@imeto.com` account,
   accept the consent, let it sync → open the **Contacts app** in the Simulator and see the Imeto
   colleagues (name, company/title, phone). Tap **Remove all synced contacts** → they disappear from
   Contacts. Sign out → any remaining synced contacts are gone. Capture screenshots.

## Architecture

Reuses the Plan A seam pattern: pure, headless-testable logic in **Core** behind a protocol; the
platform-specific implementation in the **app**. The existing `ContactSync.plan(existing:fetched:
defaultCountryCode:) -> [ContactOp]` (Core) already computes the diff; Plan B adds the *executor*
and the *live store*.

```
AuthService.accessToken
  -> DirectoryClient.fetchAll(token, syncToken: nil)     // Plan A, full directory
  -> ContactSync.plan(existing: refs, fetched, "46")     // Core (shipped) -> [ContactOp]
  -> ContactSyncExecutor.apply(ops, using: store, ...)   // Core (new) -> [SyncedContactRef]
       \-> CNContactStoreWriter (app) writes CNContacts + CNGroup
  -> SyncStore.save(SyncState{ refs })                   // app persistence (UserDefaults)
```

### Core additions (no `Contacts` import — `make test`-verified)

- **`ContactStoreWriting`** (protocol, `Sendable`):
  - `func create(_ person: DirectoryPerson) throws -> String` (returns the new contact identifier)
  - `func update(identifier: String, with person: DirectoryPerson) throws`
  - `func delete(identifier: String) throws`
- **`ContactSyncExecutor`**:
  - `static func apply(_ ops: [ContactOp], using store: ContactStoreWriting, existing: [SyncedContactRef], defaultCountryCode: String) -> ExecutionResult`
  - Iterates ops: `.create` → `store.create` → new `SyncedContactRef(resourceName, newID, contentHash)`;
    `.update` → `store.update` → refreshed ref (new contentHash); `.delete` → `store.delete` → drop ref.
  - Returns the merged `[SyncedContactRef]` plus a list of per-op failures (so one bad contact
    doesn't abort the batch). Pure and deterministic; unit-tested with a fake store.
- **`SyncState: Codable`** = `{ refs: [SyncedContactRef] }` (thin versioned wrapper); make
  `SyncedContactRef: Codable, Sendable`.

### App additions (built + tested on Simulator)

- **`CNContactStoreWriter: ContactStoreWriting`** (imports `Contacts`):
  - Lazily ensures a `CNGroup` named `"Imeto Directory"` exists; caches its identifier.
  - Maps `DirectoryPerson → CNMutableContact`: given/family name (fallback to `displayName`),
    `phoneNumbers` (labelled `.work`), organization `company` + `jobTitle`, `emailAddresses`.
  - `create`: build contact, `CNSaveRequest.add(_:toContainerWithIdentifier: nil)` +
    `addMember(_:to:)`; return `contact.identifier`.
  - `update`: fetch mutable copy by identifier, overwrite the mapped fields, `CNSaveRequest.update`.
    If the contact was deleted out from under us, surface a typed error the executor records as a
    failure (the coordinator can drop the stale ref).
  - `delete`: fetch by identifier, `CNSaveRequest.delete`.
  - `removeAll()`: enumerate members of the group (robust even if the persisted map is lost), delete
    them, then delete the group.
  - `requestAccess()` wraps `CNContactStore.requestAccess(for: .contacts)`.
- **`SyncStore`** — load/save `SyncState` as JSON in `UserDefaults` (`consentGiven` flag lives here too).
- **`ContactSyncService`** (`@MainActor`) — orchestrates one sync run: `sync(people:)` diffs the
  given full directory against persisted refs via `ContactSync.plan`, applies through
  `ContactSyncExecutor` + the live writer, and persists the new refs; `syncFromNetwork(token:client:)`
  fetches then calls `sync(people:)` (used by the background task); `removeAll()`; and a
  `ContactSyncSummary` (created/updated/deleted/failed) return.
- **`AppModel`** — gains `consentGiven`, `syncStatus` (idle/syncing/synced(count, date)/failed);
  after a successful fetch it runs a sync **iff consent is granted**; wires "Sync now",
  "Remove all", and **sign-out → removeAll()**.
- **UI (`ContentView`)** — adds:
  - A one-time **consent screen** (shown when signed in but `!consentGiven`): plain-language copy
    that contacts are written to the real address book and may sync to iCloud; "Enable & sync"
    requests Contacts permission and runs the first sync; a "Not now" keeps Plan A's read-only list.
  - A **status row** (last synced, N contacts) and a toolbar menu with "Sync now" and
    "Remove all synced contacts".
- **Background** — `WorkspaceContactsApp` gets `.backgroundTask(.appRefresh("com.imeto.workspacecontacts.app.refresh"))`
  running a silent sync; schedule the next request after each run. `project.yml` `Info.plist` adds
  `NSContactsUsageDescription` and `BGTaskSchedulerPermittedIdentifiers`.

## Error handling

- **Contacts permission denied:** show an explanatory state with a button to open Settings; no sync
  attempted; read-only list still works.
- **Per-contact write failure:** `ContactSyncExecutor` records it and continues; the ref for that
  person is not added/updated, so the next sync retries it. Never abort the whole batch for one bad
  record.
- **Stale identifier (contact deleted by the user):** `update`/`delete` treat "not found" as a soft
  failure; the coordinator drops the ref so the next sync recreates it.
- **Fetch/network errors:** reuse Plan A's `HTTPFetchError` surfacing (status + body); a failed
  fetch aborts the sync run with the error shown, leaving existing synced contacts untouched.

## Testing strategy

- **Core (headless):** `ContactSyncExecutorTests` with an in-memory fake `ContactStoreWriting` that
  records calls and hands back deterministic identifiers — assert create/update/delete routing, the
  resulting `[SyncedContactRef]` (identifiers + content-hash), and that a failing op is reported
  without aborting the batch. `SyncState` Codable round-trip.
- **App (Simulator, `xcodebuild test`):** integration test against the Simulator Contacts DB via
  `CNContactStoreWriter` (create → re-read fields → update → delete → assert gone), guarded to run
  only when Contacts access is available; `SyncStore` UserDefaults round-trip.
- **E2E (Simulator):** the milestone above, with screenshots of the Contacts app before/after.

## Failure modes / RCA

Not a re-attempt of a failed plan. Relevant hard-won constraints carried in from Plan A + the
caller-ID research so we don't re-derive them:
- **No `CNContainer` isolation API** → contacts go to the default (possibly iCloud) container;
  mitigated by group + map + explicit removal + consent, not by walling off.
- **Keychain/signing:** the live sign-in (Plan A) only works when run from Xcode with a team; the
  Simulator E2E for this plan inherits that (run via ⌘R). Documented in the Plan A archive.
- **swift-testing on CLT** uses `make test` (see the `swift-testing-headless` skill), not bare
  `swift test`.
