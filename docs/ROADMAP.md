# Roadmap

Active work. Each line links a plan in [`plans/`](plans/). Add a plan under **Now** / **Next**
when you start it; `close-out` moves it to the [shipped log](plans/archive/ROADMAP.md) when it's
done.

## Now

_Actively building. Link the active plan._

- _(nothing actively building)_ — WorkspaceContacts (Imeto directory → iOS caller ID) has fully
  shipped: Core package, App Plan A (signed-in directory list), App Plan B (sync to Contacts).
  All plans and their design specs are in the [shipped log](plans/archive/ROADMAP.md).

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
