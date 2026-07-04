# WorkspaceContacts — Design Spec

**Date:** 2026-07-04
**Status:** Approved (design), pending implementation plan

## Goal

An **internal iOS app for one Google Workspace org (Imeto)** that lets a colleague
sign in with their `@imeto.com` account and mirror the org directory into the device's
Contacts, so that:

1. **Incoming caller ID** — calls from colleagues show the person's name.
2. **Call-by-name** — the user can type a colleague's name in the native Phone app
   or Spotlight and place a call.

Both goals are achieved by the *same* mechanism: syncing directory people as native
contacts (`CNContact`). Chosen deliberately over alternatives (see Research).

## Decisions (locked)

| Decision | Choice | Rationale |
|---|---|---|
| Distribution | **Internal to Imeto** (TestFlight / Apple Business Manager later) | Original intent is "my colleagues". Avoids public-app viability walls (below). |
| Tenancy | **Single org — imeto.com only** | Sign-in locked to the `imeto.com` domain. |
| OAuth consent screen | **"Internal" user type** (Google Cloud project owned by imeto.com) | No app verification, **no CASA, no 100-user cap** — only imeto.com users can authorize. |
| Data flow | On-device only, no backend | OAuth+PKCE needs no client secret; best privacy story; zero hosting. |
| Mechanism | `CNContact` sync | Only single mechanism that delivers **both** caller ID and native call-by-name. |
| Contact isolation | Not possible on-device | iOS gives no API to create a separate container; contacts land in the user's default account. Consent + explicit removal instead. |
| Sync filter (v1) | Only people with ≥1 phone number | Caller ID is the point; avoids dumping numberless entries. Toggleable later. |
| Build/verify | Mac + Xcode (Simulator now), device + Apple Developer account later | Logic core is headless-testable; caller-ID-on-call needs a real device. |

## Why single-org (viability research)

A public, multi-tenant, per-user, zero-admin-setup version was investigated and rated
**LOW viability** — not for technical reasons but structural ones:

- `directory.readonly` is a **sensitive** scope (not restricted) → standard OAuth
  verification, **no CASA assessment**.
  ([restricted list — directory absent](https://support.google.com/cloud/answer/13464325),
  [sensitive-scope verification](https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification))
- An unverified app is capped at **100 total users**.
  ([100-user cap](https://support.google.com/cloud/answer/7454865))
- **The real wall:** in a managed org, an individual employee **cannot self-grant**
  directory access if the admin hasn't trusted the app — directory data sits behind
  admin *App access control*.
  ([app access control](https://knowledge.workspace.google.com/admin/apps/control-which-third-party-and-internal-apps-access-google-workspace-data))

**Single-org dissolves all three:** an "Internal" consent screen in Imeto's own Cloud
project needs no verification, has no user cap, and the admin gate is a one-time internal
setup we control. Viability → **HIGH**.

## Competitive landscape (prior art)

Getting a Workspace directory into iOS contacts is **not novel** — but every incumbent is
**admin-deployed or cloud-backed**, which is what we avoid:

- **sync.blue** — cloud SaaS, CardDAV/LDAP delivery, caller-ID-by-name. Backend holds a
  copy. ([link](https://www.sync.blue/en/app/directory-for-google-workspace-cloud-identity-and-essentials/))
- **Contactzilla** — cloud + admin OIDC + MDM/QR push; read-only locked list; ~$1.79/device/mo.
  ([link](https://contactzilla.com/sync-google-workspace-directory-contacts/))
- **ContactsFlow / Patronum** — Marketplace apps that copy the directory into each user's
  **Google Contacts**, riding native Google→iOS sync. Admin-initiated.
  ([Patronum](https://www.patronum.io/add-google-directory-contacts-on-ios))
- **Truecaller / Hiya / Sync.ME** — crowdsourced global caller-ID DBs; a privacy
  *anti-model* we explicitly reject (nothing is crowdsourced; data stays on-device).

**Confirmed gap / baseline:** adding a Google account to iOS syncs only *personal*
contacts — the directory never lands on the phone, so caller ID and call-by-name don't
work today. That pain is real and unserved internally at Imeto.

**Design lessons borrowed:** Contactzilla's *read-only, clearly-labeled, cleanly-removable*
contact model; sync.blue's *caller-ID-by-name as the headline*. Avoided: Sync.ME's
data-selling model.

## Research that shaped the mechanism (verified, not assumed)

The claim that **Core Spotlight** could enable call-by-name without touching Contacts was
investigated against Apple docs + forums and **refuted for these goals**:

- Native **Phone/Contacts search reads the Contacts DB + call history, not the Core
  Spotlight index** — a Spotlight-only person never appears there.
  ([CSSearchableItemActionType](https://developer.apple.com/documentation/corespotlight/cssearchableitemactiontype))
- Tapping a person in **system Spotlight deep-links into the owning app** (which must then
  fire a `tel:` URL) — not native dialing.
- **INStartCallIntent** is the VoIP domain; third-party apps cannot place **cellular**
  calls this way.
- **Incoming caller ID** requires a `CNContact` match or a CallKit **Call Directory
  Extension**; Core Spotlight contributes nothing.
  ([Call Directory extensions](https://developer.apple.com/documentation/callkit/identifying-callers-with-call-directory-app-extensions))
- iOS has **no API to create an isolated `CNContainer`**; `CNSaveRequest` writes to the
  **default container**, which may be iCloud (and thus propagate).
  ([CNContainer](https://developer.apple.com/documentation/contacts/cncontainer),
  [CNSaveRequest container thread](https://forums.developer.apple.com/forums/thread/718743))
- **People API `listDirectoryPeople`** supports a `readMask` including `phoneNumbers`, but
  returns numbers only where populated in the org's directory profiles.
  ([listDirectoryPeople](https://developers.google.com/people/api/rest/v1/people/listDirectoryPeople))

**Conclusion:** `CNContact` sync is required; Core-Spotlight-only satisfies neither goal.

## Admin prerequisites (one-time, Imeto)

1. A **Google Cloud project owned by imeto.com** with an **Internal** OAuth consent screen.
2. **People API** enabled; OAuth client (iOS) created.
3. **External/Directory sharing** left enabled (default) so `listDirectoryPeople` returns
   the domain directory. ([directory access control](https://support.google.com/a/answer/6343701))
4. If org *App access control* is restrictive, **trust** this OAuth client. (Internal apps
   in the org's own project are typically already permitted.)

## Architecture

On-device, four isolated and independently testable units.

### AuthService
- Google OAuth 2.0 for iOS via **AppAuth** (PKCE, no client secret).
- Requests scope `directory.readonly`; sets the `hd=imeto.com` hint and **rejects any
  signed-in account whose domain ≠ imeto.com**.
- Refresh token stored in **Keychain**.
- Interface: `signIn() -> Token`, `currentToken`, `signOut()`.
- Depends on: AppAuth, Keychain. Knows nothing about Contacts or the directory.

### DirectoryClient
- Calls People API `people.listDirectoryPeople` with
  `readMask=names,phoneNumbers,emailAddresses,organizations,photos`.
- Handles pagination and the `syncToken` for incremental fetches.
- Interface: `fetch(token, syncToken?) -> (people: [DirectoryPerson], nextSyncToken)`.
- Returns plain `DirectoryPerson` value types. Pure networking; no Contacts knowledge.

### ContactSync (core logic)
- Diffs fetched directory against the previously-synced state; emits a plan of
  create / update / delete operations against `CNContactStore`.
- Normalizes phone numbers to **E.164**.
- Tags every created contact (dedicated `CNGroup` `"Imeto Directory"` + a stable marker)
  and maintains a local `resourceName -> contactIdentifier` map.
- Interface: `plan(existing: [SyncedRef], fetched: [DirectoryPerson]) -> [ContactOp]`.
- **Pure function over inputs → operations.** Unit-testable with zero device.

### SyncCoordinator + SwiftUI shell
- Thin UI: sign-in screen; "Sync now"; last-synced status; sign-out; "Remove all synced
  contacts".
- Triggers sync on launch, on manual refresh, and via a daily `BGAppRefreshTask`.
- Orchestrates Auth → Directory → ContactSync → `CNContactStore.execute`, then persists
  the `resourceName -> contactIdentifier` map and the new `syncToken`.

## Data flow

```
Sign in (AppAuth + PKCE, hd=imeto.com, reject non-imeto accounts)
  -> token in Keychain
  -> DirectoryClient.fetch(readMask, syncToken)
  -> [DirectoryPerson]
  -> ContactSync.plan(existing, fetched)
  -> [ContactOp]
  -> CNContactStore.execute
  -> persist resourceName->contactID map + new syncToken
```

## Contact lifecycle

- **Create**: new directory people (with a phone number) → new `CNContact`, added to the
  `"Imeto Directory"` group and marked as ours.
- **Update**: changed fields → update the mapped contact in place.
- **Delete**: people who left the directory → delete the mapped contact.
- **Incremental**: driven by Google's `syncToken`, so refreshes are cheap.
- **Removal**: an explicit "Remove all synced contacts" action deletes exactly the ones we
  created (tracked via the local map + group membership). Sign-out offers this.
- **iCloud caveat**: contacts go to the default account, so they may sync to the user's
  iCloud and other devices. Onboarding states this plainly and requires consent. Plain
  uninstall cannot clean iCloud contacts — hence the explicit removal action.

## Verification strategy (verification-first)

- **Green check:** `ContactSync` plan logic + phone-number E.164 normalization +
  `DirectoryPerson` parsing, as a Swift Package with **XCTest** unit tests, runnable
  headless. Covers create/update/delete diffing, dedup, and number normalization.
- **Simulator:** OAuth round-trip, `CNContactStore` write, and name search appearing in
  the Simulator's Phone/Contacts apps.
- **Device (later):** caller ID on a live incoming call — a free Apple ID is enough for a
  7-day side-load test; paid Developer account for internal TestFlight distribution.

## Known dependencies & risks

- **Phone-number completeness** in Imeto's directory determines caller-ID value.
- **Admin setup** (Cloud project + Internal consent screen + directory sharing) is a
  one-time prerequisite; without it the app cannot read the directory.
- **Distribution to colleagues** needs a paid Apple Developer account (TestFlight) or
  Apple Business Manager — a rollout task, not a build blocker.

## Non-goals (v1)

No backend. No multi-tenant / public App Store. No Workspace Marketplace listing. No call
blocking. No CallKit Call Directory Extension. No cross-org search. No editing colleagues.
No Android.
