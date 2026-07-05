---
paths:
  - "docs/plans/**"
---

# Plan authoring rules

Loads when working with files in `docs/plans/`. How plans and specs are written, structured,
and retired. (The *where to save* override lives in `CLAUDE.md`, since it's decided before a
plan file exists to trigger this rule.)

## Filenames

- spec → `docs/plans/YYYY-MM-DD-<topic>-design.md`
- plan → `docs/plans/YYYY-MM-DD-<feature>.md`

## Commit the plan as soon as it's written

When you finish writing a spec or plan under `docs/plans/`, commit it in the same step — before
anything else, and before creating a worktree. A worktree branches from `main`'s current commit;
an uncommitted plan on `main` won't exist inside the worktree. Commit first, then branch.

## States — exactly two

- **active**: ≥1 `- [ ]` → file in `docs/plans/`
- **done**: all `- [x]` → file in `docs/plans/archive/`, via the `close-out` skill

Last `[ ]` flipping to `[x]` while the file is still in `docs/plans/` is drift. Run `close-out`.

## Specs archive with their plan

A design spec (`-design.md`) has no checkboxes, so it isn't retired on its own — it's retired by
the plan it drove. When you `close-out` an implementation plan, archive its design spec in the
same commit. If one spec drove several plans, archive it when the **last** of them is closed out.
A spec still in `docs/plans/` after its implementation has fully shipped is drift.

## Every plan opens with, in order

1. **Goal** — user-observable outcome, plain language, not mechanism.
2. **Scope** — what's in, and explicitly what's out.
3. **Verification** — a runnable check (test or command + expected output). Lint-only ≠ verified.
   Two things a verification skips at its peril:
   - **Prerequisites.** Name what must be true in the *environment* for the check to run — external
     services enabled, credentials/signing set up, admin/config toggles flipped. If the reader has
     to discover a setup step by hitting the error, it belonged in the plan. Capture prerequisites
     up front, not reactively.
   - **Drive the real artifact.** If the thing has a runtime a user touches (an app, a CLI, an
     endpoint), the check exercises *that*, not only unit tests underneath it. Unit-green while the
     built product is broken (wrong name on screen, a button that does nothing) is the classic gap
     manual testing catches too late.

## Failure modes / RCA — when the plan follows a failure

If this plan follows a failed attempt, or fixes a bug you've hit before, end the preamble with a
short **Failure modes / RCA** note: the *root cause* (not the symptom) and a citation — the
commit, the prior plan, or the error. The fix in Scope must target that cause. For the debugging
that finds the root cause in the first place, use `superpowers:systematic-debugging`.

## Close-out

Archiving requires pasted evidence (test counts, exit codes, output tail) — not "should pass".
Invoke `superpowers:verification-before-completion`.

## Roadmaps

- `docs/ROADMAP.md` — active work: Now / Next / Later. Add a plan when you start it.
- `docs/plans/archive/ROADMAP.md` — shipped log. `close-out` appends here on archive.
