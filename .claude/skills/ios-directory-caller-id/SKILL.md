---
name: ios-directory-caller-id
description: >
  Use when designing or debugging how a directory/contact list gets onto an iPhone for
  incoming caller ID and/or calling someone by typing their name in the native Phone app or
  Spotlight. Triggers on "caller ID", "call by name", "show name on incoming call",
  "sync contacts to iPhone", "CNContact", "Call Directory Extension", "Core Spotlight to
  call", "CallKit caller id". Captures verified Apple-platform constraints so you don't
  re-derive them.
---

# iOS directory → caller ID & call-by-name

Verified against Apple docs during a real design (2026-07). The mechanisms are commonly
confused; this is the ground truth.

## The one rule

**Only `CNContact` sync delivers BOTH goals** (incoming caller ID *and* typing a name to call
in the native Phone app). Nothing else does both.

## What each mechanism can and cannot do

| Mechanism | Incoming caller ID | Call-by-name in native Phone app | Notes |
|---|---|---|---|
| **`CNContact` sync** (write directory people to the address book) | ✅ | ✅ | The answer. Both goals from one mechanism. |
| **CallKit Call Directory Extension** (`CXCallDirectoryProvider`) | ✅ | ❌ | Caller ID / blocking only. Entries must be added in **ascending E.164 order**, batched, memory-limited. Good for labeling numbers you don't want as contacts. |
| **Core Spotlight** (`CSSearchableItem`) | ❌ | ❌ | Does **not** feed the Phone/Contacts app search (they read the Contacts DB + call history, not the Spotlight index). A Spotlight tap only **deep-links into your app**, which then fires a `tel:` URL — not native dialing. |
| **INStartCallIntent / SiriKit** | ❌ | ❌ (for cellular) | VoIP-calling domain; third-party apps can't place a **cellular** call this way. |

**Do not** propose Core Spotlight as a way to "call colleagues by name" — it was investigated
and refuted for exactly this. Only `CNContact`s appear in the native dialer's search.

## The isolation gotcha (important)

iOS has **no public API to create a separate `CNContainer`/account.** `CNSaveRequest` writes
to the **default container**, which may be iCloud → synced contacts propagate to the user's
other devices. You cannot wall them off on-device. Mitigations:
- Tag every written contact (dedicated `CNGroup` + a stable marker) and keep a
  `resourceName → contactIdentifier` map, so you can update/remove exactly yours.
- Provide an explicit "remove all synced contacts" action (uninstall alone can't clean iCloud
  contacts).
- Get **explicit user consent** in onboarding stating contacts land in their real address book.
- True isolation only comes from a **CardDAV account** — which needs a server.

## Sourcing directory data (Google Workspace)

People API `people.listDirectoryPeople` with scope `directory.readonly` returns domain
profiles; `readMask` supports `phoneNumbers` — but numbers come back **only where populated**
in each org's profiles. See [[workspace-directory-access]] for the auth/viability constraints.

## Citations
- CNContainer (no create API): https://developer.apple.com/documentation/contacts/cncontainer
- CNSaveRequest container behavior: https://forums.developer.apple.com/forums/thread/718743
- Call Directory extensions: https://developer.apple.com/documentation/callkit/identifying-callers-with-call-directory-app-extensions
- Core Spotlight action type (deep-link, not native call): https://developer.apple.com/documentation/corespotlight/cssearchableitemactiontype
- listDirectoryPeople: https://developers.google.com/people/api/rest/v1/people/listDirectoryPeople
