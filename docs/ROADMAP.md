# Roadmap

Active work. Each line links a plan in [`plans/`](plans/). Add a plan under **Now** / **Next**
when you start it; `close-out` moves it to the [shipped log](plans/archive/ROADMAP.md) when it's
done.

## Now

_Actively building. Link the active plan._

- WorkspaceContacts (Imeto directory → iOS caller ID). Design spec:
  [`plans/2026-07-04-workspace-contacts-design.md`](plans/2026-07-04-workspace-contacts-design.md).
  Core logic package shipped ✅ (see archive).

## Next

_Decided, not started. A spec may exist; the plan doesn't yet._

- **App-integration plan** (deferred from the Core plan): `AuthService` (AppAuth/PKCE/Keychain,
  `hd=imeto.com`), live `URLSession` fetcher, `CNContactStore` executor for the diff ops, synced-ref
  persistence, SwiftUI shell, `BGAppRefreshTask`, and the Xcode app target — Simulator/device verified.

## Later

_Ideas worth keeping, not yet committed to._

-

---

Shipped → [`plans/archive/ROADMAP.md`](plans/archive/ROADMAP.md)
