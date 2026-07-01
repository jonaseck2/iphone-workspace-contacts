# docs/plans/

Specs and implementation plans live here — the written record of *what* you're building and
*how*. This is step 2–3 of the workflow in the root [`README.md`](../../README.md); the
authoring rules are enforced by [`.claude/rules/plans.md`](../../.claude/rules/plans.md), which
loads automatically whenever Claude works inside this folder.

## What goes here

- `YYYY-MM-DD-<topic>-design.md` — **specs**, from `superpowers:brainstorming`
- `YYYY-MM-DD-<feature>.md` — **implementation plans**, from `superpowers:writing-plans`
- `archive/` — **finished plans** (every box `- [x]`), moved here by the `close-out` skill, plus
  the shipped log at [`archive/ROADMAP.md`](archive/ROADMAP.md)

## Lifecycle

A plan file is in exactly one of two states:

- **Active** — at least one `- [ ]` remains; the file lives here in `docs/plans/`.
- **Done** — every box is `- [x]`; the `close-out` skill moves it to `archive/` and updates the
  roadmaps. A done plan still sitting here is drift — `inventory` flags it, `close-out` fixes it.

Commit a spec or plan in the same step you write it (and before branching a worktree). This
directory is used instead of Superpowers' default `docs/superpowers/plans/` so the repo's paths
stay free of tool branding.
