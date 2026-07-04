---
name: workspace-directory-access
description: >
  Use when deciding whether/how an app can read a Google Workspace directory (colleague list)
  via the People API, or assessing viability of a per-user vs admin-deployed vs single-org
  design. Triggers on "directory.readonly", "listDirectoryPeople", "read the company
  directory", "Google Workspace OAuth scope", "CASA", "OAuth verification", "admin consent",
  "multi-tenant Google app viability". Captures verified scope/verification/admin-gating facts.
---

# Google Workspace directory access — viability & constraints

Verified against Google Cloud / Workspace docs during a real viability assessment (2026-07).
The headline: a **public, per-user, multi-tenant, zero-admin** app reading the directory is
**structurally blocked**; a **single-org** design dissolves the blockers.

## The blockers (why per-user multi-tenant fails)

1. **Admin OAuth gating is the real wall.** Because the app requests *directory data* (not just
   sign-in), it falls under Workspace **App access control**. In a managed org an individual
   employee **cannot self-grant** `directory.readonly` unless an admin has trusted the app.
   (https://knowledge.workspace.google.com/admin/apps/control-which-third-party-and-internal-apps-access-google-workspace-data,
   https://support.google.com/a/answer/6343701)
2. **Unverified apps cap at 100 users** total across all orgs → a public launch needs full
   OAuth verification. (https://support.google.com/cloud/answer/7454865)

## The good news (cost is lower than feared)

- `https://www.googleapis.com/auth/directory.readonly` is a **SENSITIVE** scope, **not
  RESTRICTED** — so **no CASA** third-party security assessment (the $500–$4,500/yr audit that
  kills indie Gmail/Drive apps does **not** apply). Just standard OAuth/brand verification.
  (restricted list, directory absent: https://support.google.com/cloud/answer/13464325 ;
  sensitive-scope verification: https://developers.google.com/identity/protocols/oauth2/production-readiness/sensitive-scope-verification)

## The pivot that works: single-org "Internal"

An OAuth consent screen set to **"Internal"** user type, in the org's **own** Cloud project:
- **No app verification, no CASA, no 100-user cap.**
- Only that domain's users can authorize.
- The admin gate becomes a **one-time internal setup** you control (trust the client + leave
  directory sharing on). Viability → HIGH.

This is why the iPhone-contacts project is scoped single-org (imeto.com). See
[[single-org-decision]].

## Baseline facts worth knowing

- Adding a Google Workspace account in **iOS Settings syncs only personal contacts**, not the
  company directory/GAL — the directory never lands on the phone natively.
  (https://support.google.com/a/users/answer/7559344)
- **No first-party** Google mechanism pushes the directory to employee devices; the market is
  served by admin-deployed third-party tools (Contactzilla, sync.blue, Patronum) via
  CardDAV/MDM or by copying the directory into each user's Google Contacts.
- `people.listDirectoryPeople` (scope `directory.readonly`) returns domain profiles; `readMask`
  can include `phoneNumbers`, but numbers appear **only where populated** in profiles.
  (https://developers.google.com/people/api/rest/v1/people/listDirectoryPeople)

## Decision shortcut

Serving one known org (your own) → single-org + Internal consent screen. HIGH viability.
Wanting any org to self-serve with no admin action → **don't** — it will silently fail to
authorize in managed orgs. Pivot to admin-deployed / Workspace Marketplace instead.
