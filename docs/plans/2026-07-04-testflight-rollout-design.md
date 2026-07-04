# TestFlight Rollout — design / runbook

**Goal:** An Imeto colleague installs the app on their own iPhone, signs in with their
`@imeto.com` account, and thereafter sees colleague names on incoming calls and can call them
by name from the native Phone app.

**Why this doc:** The code is built and verified on the Simulator, but "shipped" ≠ "in
colleagues' hands." Getting there is a distribution + rollout phase that is mostly *not* code.
This is the ordered path, with an owner on every step.

**Decisions locked (2026-07-04):** beta channel = **TestFlight**; Imeto has **no Apple Developer
account / ABM / MDM yet** (or unconfirmed).

**Owner key:** 🧑 = you (Imeto IT manager — you hold the admin access for every 🧑 step: Apple
enrollment, ABM/MDM, the Google Workspace console) · 🤖 = I can do it here.

**Production channel note:** TestFlight is the fast path to prove it on a real device and run a
beta. For the eventual org-wide rollout you (as IT manager) have a better option than a 90-day
beta: **Apple Business Manager + MDM** pushes the app silently to managed iPhones with no
per-user invite and no expiry. Recommended shape: **TestFlight now → ABM/MDM for GA.** Both use
the same signed build; only the delivery differs. See Stage 5 note.

---

## The gate

Everything Apple-side is blocked on one thing: **🧑 enroll Imeto in the Apple Developer
Program** ($99/yr) → yields an org **Team ID**. The personal team used for local ⌘R runs
cannot distribute. Nothing reaches a phone until this exists.

Everything below marked 🤖, plus the Google-side work, can proceed **before** enrollment.

---

## Stage 1 — Google auth works for everyone (do first; free; unblocks sign-in)

Today only I can sign in if the OAuth consent screen is in External/Testing with me as a test
user. Colleagues would hit "access denied."

- [ ] 🧑 In Google Cloud console → OAuth consent screen, set **User type = Internal** (org-only).
      This lets any `@imeto.com` account sign in with no per-user allowlist and no Google app
      verification (Internal apps skip verification even with the sensitive
      `directory.readonly` scope). 🤖 I'll write the exact click-path.
- [x] People API enabled (org) — already done.
- [x] Admin console → external directory sharing → "organization data" — already done.

**Verify:** a *second* `@imeto.com` account (not the original test user) signs in and sees the
directory list.

## Stage 2 — App polish real users will see (🤖, no account needed)

- [ ] 🤖 App **icon** (currently SF Symbol placeholder) — real icon set for the home screen.
- [ ] 🤖 **Launch screen** + confirm **display name**.
- [ ] 🤖 Draft a **privacy policy** (Contacts data: what's read, where it's written, iCloud
      caveat, how to remove). 🧑 host it at a stable URL (required by App Store Connect).
- [ ] 🤖 Pre-fill **App Privacy** nutrition-label answers (Contacts = used, not linked to
      identity, not for tracking) so the App Store Connect form is copy-paste.

## Stage 3 — Signing config for distribution (🤖 prep, 🧑 finish)

- [ ] 🤖 Parameterize the team in `app/project.yml` (read `DEVELOPMENT_TEAM` from env / a
      gitignored xcconfig) so the org Team ID is **never committed** to the shared repo.
- [ ] 🧑 Once enrolled: register the app's bundle id `com.imeto.workspacecontacts.app` and let
      Xcode manage the distribution profile under the org team.

## Stage 4 — App Store Connect + first build (needs the account)

- [ ] 🧑 Create the App Store Connect app record (bundle id above).
- [ ] 🧑/🤖 Archive (`xcodebuild archive` + export) and upload the first build.
- [ ] 🧑 Fill App Privacy (from Stage 2), add the privacy policy URL.

## Stage 5 — TestFlight testers + invites

- [ ] 🧑 Add **internal testers** (up to 100, App Store Connect users) — no beta review,
      fastest path for a first real-device check.
- [ ] 🧑 For wider rollout, add an **external test group** (email or public link, up to 10k) —
      this needs a one-time light **beta review** and beta test info (the Stage 2 assets cover it).
- [ ] 🤖 Draft the onboarding note colleagues get: install → sign in with `@imeto.com` → allow
      Contacts → tap "Enable & sync" → what the iCloud-propagation caveat means for them.

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

## What I can start now, in order (all 🤖, all pre-enrollment)

1. Stage 1 click-path for the OAuth "Internal" switch.
2. App icon + launch screen + display name (Stage 2).
3. Privacy policy draft + App Privacy answers (Stage 2).
4. `project.yml` team parameterization (Stage 3).
5. Onboarding note (Stage 5).

Enrollment (the gate) and everything 🧑 is yours.
