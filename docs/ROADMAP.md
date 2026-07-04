# Roadmap

Active work. Each line links a plan in [`plans/`](plans/). Add a plan under **Now** / **Next**
when you start it; `close-out` moves it to the [shipped log](plans/archive/ROADMAP.md) when it's
done.

## Now

_Actively building. Link the active plan._

- **TestFlight rollout** — get the built app into colleagues' hands and prove caller ID on a
  real iPhone. Runbook: [`plans/2026-07-04-testflight-rollout-design.md`](plans/2026-07-04-testflight-rollout-design.md).
  The app itself has fully shipped (Core, App Plan A, App Plan B — see
  [shipped log](plans/archive/ROADMAP.md)); this is the distribution phase.

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
