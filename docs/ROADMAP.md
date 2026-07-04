# Roadmap

Active work. Each line links a plan in [`plans/`](plans/). Add a plan under **Now** / **Next**
when you start it; `close-out` moves it to the [shipped log](plans/archive/ROADMAP.md) when it's
done.

## Now

_Actively building. Link the active plan._

- WorkspaceContacts (Imeto directory → iOS caller ID). Design spec:
  [`plans/2026-07-04-workspace-contacts-design.md`](plans/2026-07-04-workspace-contacts-design.md).
  Core logic package shipped ✅ (see archive).
- **App Plan A — signed-in directory list**:
  [`plans/2026-07-04-workspace-contacts-app-signin.md`](plans/2026-07-04-workspace-contacts-app-signin.md).
  XcodeGen + GoogleSignIn auth + live fetch + SwiftUI list. **Needs full Xcode to build/run.**

## Next

_Decided, not started. A spec may exist; the plan doesn't yet._

- **App Plan B — sync to Contacts** (deferred from Plan A): `CNContactStore` executor for the
  `ContactSync` diff ops, `SyncedContactRef` + `nextSyncToken` persistence, sign-out / "remove all"
  cleanup, onboarding consent (iCloud caveat), `BGAppRefreshTask`.

## Later

_Ideas worth keeping, not yet committed to._

- Real E.164 library (PhoneNumberKit) if single-region heuristic proves insufficient.
- Device caller-ID verification on a physical iPhone (needs paid Apple Developer account).

## Later

_Ideas worth keeping, not yet committed to._

-

---

Shipped → [`plans/archive/ROADMAP.md`](plans/archive/ROADMAP.md)
