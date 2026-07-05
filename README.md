# WorkspaceContacts

**See your Imeto colleagues' names on incoming calls.** WorkspaceContacts is an iOS app that syncs
your Imeto Google Workspace directory into your iPhone Contacts — so when a colleague calls you see
their **name** instead of a number, and you can find them by name in the native Phone app.

> Internal Imeto tool. The source is public, but sign-in is restricted to `@imeto.com` accounts and
> the app only reads Imeto's own Workspace directory.

## Why it works this way

On iOS, **only writing real `CNContact`s delivers both goals at once** — incoming caller ID *and*
call-by-name in the native dialer. CallKit call-directory extensions do caller ID but not
call-by-name; Spotlight and SiriKit do neither for cellular calls. So the app writes directory
people into your address book (tagged in an "Imeto Directory" group) and keeps them in sync. See
[`.claude/skills/ios-directory-caller-id`](.claude/skills/ios-directory-caller-id/SKILL.md) for the
full mechanism comparison.

## How it works

1. **Sign in** with Google — restricted to `@imeto.com`.
2. **Fetch** the org directory via the Google People API (`people.listDirectoryPeople`,
   `directory.readonly`): names, titles, emails, phone numbers (where populated).
3. **Consent**, then **sync**: the app diffs the directory against what it previously wrote and
   creates / updates / deletes `CNContact`s accordingly, in a dedicated "Imeto Directory" group.
4. **Stay current**: a background app-refresh task re-syncs periodically.
5. **Clean up**: "Remove all synced contacts" (or signing out) deletes everything the app added.

## Architecture

Pure logic lives in a headless Swift package so it can be tested without a simulator; the app is a
thin platform shell over it, connected by protocol *seams*.

| Module | What's in it |
| --- | --- |
| [`Core/`](Core/) — `WorkspaceContactsCore` (SwiftPM) | People API decoding, E.164 phone normalization, `DirectoryClient` (paging + syncToken), the `ContactSync` diff engine and `ContactSyncExecutor`, `EmailDomain` org enforcement. Seams: `HTTPFetching`, `ContactStoreWriting`. No platform dependencies. |
| [`app/`](app/) — the iOS app (XcodeGen) | `AuthService` (GoogleSignIn, `@imeto.com` enforced), `URLSessionHTTPFetcher`, `CNContactStoreWriter`, `SyncStore` (persistence), `ContactSyncService`, SwiftUI UI (consent, list, per-row on-device/cloud badge), `BGAppRefreshTask` background sync. |

**Tech:** Swift 6 · iOS 16+ · Xcode 26.6 · [XcodeGen](https://github.com/yonaskolb/XcodeGen) ·
[GoogleSignIn-iOS](https://github.com/google/GoogleSignIn-iOS) ·
[swift-testing](https://github.com/apple/swift-testing) (not XCTest — so the Core suite runs
headlessly under Command Line Tools).

## Build & test

**Core (headless — no Xcode app required):**

```bash
cd Core && make test        # runs the swift-testing suite via `swift test`
```

**App (requires full Xcode + an iOS Simulator):**

```bash
cd app
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodegen generate           # project.yml -> WorkspaceContacts.xcodeproj (gitignored)
xcodebuild test -project WorkspaceContacts.xcodeproj -scheme WorkspaceContacts \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Signing for device/TestFlight builds reads `DEVELOPMENT_TEAM` from the environment at
`xcodegen generate` time, so the org Team ID lands only in the generated (gitignored) project,
never in the repo: `export DEVELOPMENT_TEAM=XXXXXXXXXX` before generating.

## Prerequisites (Google Workspace side)

- **People API enabled** in the Google Cloud project.
- **OAuth consent screen = Internal**, so any `@imeto.com` user can sign in without an allowlist.
- **Admin console → external directory sharing → "organization data"**, so directory phone numbers
  are visible to the API.
- An **iOS OAuth client ID** in [`app/project.yml`](app/project.yml) (non-secret; ships in the app).

## Privacy

Contacts the app creates land in your **real device address book** and may sync to iCloud — iOS has
no API to isolate them on-device. The app requires explicit consent, tags everything it writes, and
offers one-tap removal. It has no backend, analytics, or tracking. Full policy:
[`docs/rollout/privacy-policy.md`](docs/rollout/privacy-policy.md).

## Status

- ✅ **Core package** — shipped, verified headlessly.
- ✅ **Directory list** — sign in and see the live colleague list (verified on Simulator).
- ✅ **Sync to Contacts** — full create/update/delete sync + background refresh (verified on Simulator).
- 🚧 **Distribution** — TestFlight rollout in progress; see the runbook
  [`docs/plans/2026-07-04-testflight-rollout-design.md`](docs/plans/2026-07-04-testflight-rollout-design.md).
- ⏳ **Real-device caller ID** — the one thing a simulator can't prove; pending a physical iPhone build.

See [`docs/ROADMAP.md`](docs/ROADMAP.md) for what's active and [`docs/plans/archive/`](docs/plans/archive/)
for shipped plans with their verification evidence.

## Repository layout

| Path | What's there |
| --- | --- |
| [`Core/`](Core/) | Headless logic package (`WorkspaceContactsCore`) + its tests |
| [`app/`](app/) | The iOS app (XcodeGen `project.yml`, `Sources/`, `Tests/`) |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Now / Next / Later |
| [`docs/plans/`](docs/plans/) | Specs and active plans; [`archive/`](docs/plans/archive/) holds shipped ones |
| [`docs/rollout/`](docs/rollout/) | Privacy policy, App Store privacy answers, colleague onboarding note |

## How this repo is developed

This project is built **mostly agentically with Claude Code**, using a brainstorm → plan → build →
verify → close-out loop with verification baked in from the start. That workflow — and the rules and
skills in [`.claude/`](.claude/) that enforce it — comes from the
[Imeto Claude project template](https://github.com/imeto-consulting/claude-project-template); see
its README for the full explanation.
