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
- App Plan B shipped ✅ (sync to Contacts; see archive) — directory writes to the device address
  book, kept in sync, with a per-row on-device/cloud badge; verified on Simulator.

## Next

_Decided, not started. A spec may exist; the plan doesn't yet._

- _(nothing queued)_

## Later

_Ideas worth keeping, not yet committed to._

- Real E.164 library (PhoneNumberKit) if single-region heuristic proves insufficient.
- Device caller-ID verification on a physical iPhone (needs paid Apple Developer account).
- `syncToken`-based incremental fetch (needs deletion-marker handling in Core; Plan B does full-fetch diff).
- Selective per-contact sync (tap a row to include/exclude) — deferred; conflicts with auto-sync-all's caller-ID-for-everyone goal.
- Batched `CNSaveRequest` for large directories (Plan B does one save per op).

---

Shipped → [`plans/archive/ROADMAP.md`](plans/archive/ROADMAP.md)
