# TestFlight Rollout — design / runbook

**Goal:** An Imeto colleague installs the app on their own iPhone, signs in with their
`@imeto.com` account, and thereafter sees colleague names on incoming calls and can call them
by name from the native Phone app.

**Why this doc:** The code is built and verified on the Simulator, but "shipped" ≠ "in
colleagues' hands." Getting there is a distribution + rollout phase that is mostly *not* code.
This is the ordered path, with an owner on every step.

**Decisions locked (2026-07-04):** beta channel = **TestFlight**; Imeto **enrolled in the Apple
Developer Program** ✅ (gate cleared); Google OAuth consent screen = **Internal** ✅.

**Owner key:** 🧑 = you (Imeto IT manager — you hold the admin access for every 🧑 step: Apple
enrollment, ABM/MDM, the Google Workspace console) · 🤖 = I can do it here.

**Production channel note:** TestFlight is the fast path to prove it on a real device and run a
beta. For the eventual org-wide rollout you (as IT manager) have a better option than a 90-day
beta: **Apple Business Manager + MDM** pushes the app silently to managed iPhones with no
per-user invite and no expiry. Recommended shape: **TestFlight now → ABM/MDM for GA.** Both use
the same signed build; only the delivery differs. See Stage 5 note.

---

## The gate — CLEARED ✅

- [x] 🧑 Enroll Imeto in the Apple Developer Program → org **Team ID** exists. The one thing
      still needed from you before an archive: **paste the 10-char Team ID** (or
      `export DEVELOPMENT_TEAM=…` before `xcodegen generate`). It never gets committed — it
      lands only in the gitignored generated `.xcodeproj`.

---

## Stage 1 — Google auth works for everyone (do first; free; unblocks sign-in)

Today only I can sign in if the OAuth consent screen is in External/Testing with me as a test
user. Colleagues would hit "access denied."

- [x] 🧑 OAuth consent screen **User type = Internal** (org-only) — done. Any `@imeto.com`
      account can sign in with no per-user allowlist and no Google app verification.
- [x] People API enabled (org) — already done.
- [x] Admin console → external directory sharing → "organization data" — already done.

**Verify:** a *second* `@imeto.com` account (not the original test user) signs in and sees the
directory list.

## Stage 2 — App polish real users will see (🤖, done)

- [x] 🤖 App **icon** — monochrome Imeto-brand mark (person + call badge), 1024px, wired via
      `app/Sources/Assets.xcassets/AppIcon.appiconset`. Verified compiled into the built app
      (`Assets.car` → `AppIcon`, `CFBundleIconName = AppIcon`).
- [x] 🤖 **Launch screen** (minimal system launch screen, `UILaunchScreen {}`) + **display name**
      "WorkspaceContacts" — both set in `project.yml`.
- [x] 🤖 **Privacy manifest** `app/Sources/PrivacyInfo.xcprivacy` (UserDefaults reason CA92.1;
      no tracking; no collected data) — required for App Store upload; verified bundled.
- [x] 🤖 **Privacy policy** drafted → [`../rollout/privacy-policy.md`](../rollout/privacy-policy.md).
      🧑 host it at a stable URL (required by App Store Connect).
- [x] 🤖 **App Privacy** answers pre-filled → [`../rollout/app-store-privacy.md`](../rollout/app-store-privacy.md).

## Stage 3 — Signing config for distribution (🤖 prep, 🧑 finish)

- [x] 🤖 Parameterized the team in `app/project.yml`: `DEVELOPMENT_TEAM: ${DEVELOPMENT_TEAM}`
      + `CODE_SIGN_STYLE: Automatic`. The env value is read at `xcodegen generate` time and only
      reaches the gitignored `.xcodeproj` — **never committed**.
- [ ] 🧑 Register the app's bundle id `com.imeto.workspacecontacts.app` in the Developer portal
      and let Xcode manage the distribution profile under the org team.

## Stage 4 — App Store Connect + first build (needs the account)

- [ ] 🧑 Create the App Store Connect app record (bundle id above).
- [ ] 🧑/🤖 Archive (`xcodebuild archive` + export) and upload the first build.
- [ ] 🧑 Fill App Privacy (from Stage 2), add the privacy policy URL.

## Stage 5 — TestFlight testers + invites

- [ ] 🧑 Add **internal testers** (up to 100, App Store Connect users) — no beta review,
      fastest path for a first real-device check.
- [ ] 🧑 For wider rollout, add an **external test group** (email or public link, up to 10k) —
      this needs a one-time light **beta review** and beta test info (the Stage 2 assets cover it).
- [x] 🤖 Onboarding note drafted → [`../rollout/onboarding.md`](../rollout/onboarding.md)
      (install → sign in → allow Contacts → "Enable & sync" → the iCloud-propagation caveat).

## Stage 6 — The actual end-to-end proof

- [ ] 🧑 A colleague on a physical iPhone: install → sign in → sync, then **have someone in the
      directory call them and confirm the name shows on the incoming-call screen**, and that
      typing the name in Phone finds them. This is the one thing no simulator can prove
      (previously logged in the roadmap's "Later").

---

## Ongoing constraints (carried from build)

- Builds expire every **90 days** on TestFlight — re-upload to keep a beta group live.
- Contacts land in the user's **real address book** and may sync to iCloud (no on-device
  isolation API). Consent copy + "Remove all synced contacts" + sign-out cleanup already
  handle this; the onboarding note must state it plainly.
- Never commit the org Team ID to the shared repo (same rule that kept the personal team out).

## Status — all 🤖 pre-enrollment prep is DONE

Icon, privacy manifest, privacy policy draft, App Privacy answers, signing parameterization, and
the onboarding note are committed and the app builds clean. What remains is all 🧑 and all needs
the enrolled account:

1. **Give me the Team ID** (or set `DEVELOPMENT_TEAM`) → I produce a signed archive.
2. Register the bundle id + create the App Store Connect record (Stage 3–4).
3. Upload the build; fill App Privacy from [`../rollout/app-store-privacy.md`](../rollout/app-store-privacy.md) + host the privacy policy.
4. Add internal testers, install on a real iPhone (Stage 5).
5. **Stage 6** — the one true end-to-end proof: a real incoming call shows a colleague's name.
