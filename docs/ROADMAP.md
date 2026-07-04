# Roadmap

Active work. Each line links a plan in [`plans/`](plans/). Add a plan under **Now** / **Next**
when you start it; `close-out` moves it to the [shipped log](plans/archive/ROADMAP.md) when it's
done.

## Now

_Actively building. Link the active plan._

- WorkspaceContacts (Imeto directory → iOS caller ID). Design spec:
  [`plans/2026-07-04-workspace-contacts-design.md`](plans/2026-07-04-workspace-contacts-design.md).
  Core logic package shipped ✅ (see archive).
- App Plan A shipped ✅ (signed-in directory list; see archive) — colleague list loads live on the
  Simulator against the Imeto Workspace directory.
- **App Plan B — sync to Contacts** (designing → planning). Design spec:
  [`plans/2026-07-04-sync-to-contacts-design.md`](plans/2026-07-04-sync-to-contacts-design.md).
  Executor seam in Core + `CNContactStore` writer in app, one-time consent, incremental sync via
  `syncToken`, `CNGroup` tagging, remove-all, sign-out cleanup, `BGAppRefreshTask`. Verified on
  Simulator; device caller-ID deferred.

## Next

_Decided, not started. A spec may exist; the plan doesn't yet._

- _(nothing queued — App Plan B is active above)_

## Later

_Ideas worth keeping, not yet committed to._

- Real E.164 library (PhoneNumberKit) if single-region heuristic proves insufficient.
- Device caller-ID verification on a physical iPhone (needs paid Apple Developer account).

---

Shipped → [`plans/archive/ROADMAP.md`](plans/archive/ROADMAP.md)
