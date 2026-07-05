---
name: close-out
description: Use when an implementation plan in docs/plans/ has all its boxes checked and needs to be finished and archived. Captures verification evidence, archives the plan, and updates ROADMAP.md.
---

# Close out a finished plan

Run this when a plan in `docs/plans/` has every `- [ ]` flipped to `- [x]`. It is the
canonical "the plan is done" workflow — don't archive by hand and skip the steps.

See `.claude/rules/plans.md` for the rules this enforces.

## Steps

1. **Confirm it's actually done.** Open the plan. Every checkbox must be `- [x]`.
   If any `- [ ]` remains, stop — the plan is still active.

2. **Produce verification evidence — run it, don't assert it.** Run the command(s) named in
   the plan's **Verification** section. Capture real output: the test summary line, the
   exit code, the tail of a build, a screenshot path. Invoke
   `superpowers:verification-before-completion`. If a verification command hasn't been run
   with output captured, the plan is NOT ready to archive.

3. **Archive the file — and its design spec.**
   ```bash
   mkdir -p docs/plans/archive
   git mv docs/plans/<the-plan>.md docs/plans/archive/
   ```
   If this plan was driven by a design spec (`<topic>-design.md`), archive it in the same step —
   a spec is retired by its plan, not on its own:
   ```bash
   git mv docs/plans/<topic>-design.md docs/plans/archive/
   ```
   Exception: if that spec still has other unfinished plans depending on it, leave it in
   `docs/plans/` until the last of those plans is closed out.

4. **Update the roadmaps.** Remove the plan's line from `docs/ROADMAP.md` (Now/Next), and
   append it to `docs/plans/archive/ROADMAP.md` (newest first) with a one-line outcome.

5. **Keep the user-facing docs honest.** If this plan changed *what the project does*, *how you
   build or run it*, or *its status*, update `README.md` to match — a README that still describes
   an earlier version of the project (or the template it was forked from) is drift, and the last
   plan to touch that surface is the one that owns the fix. Same for `CLAUDE.md` if its top-line
   description no longer fits the project.

6. **Commit, with the evidence in the message.**
   ```bash
   git add -A
   git commit -m "chore: close out <feature>

   <paste the verification output: test counts, exit codes, build tail>"
   ```
   "Should pass" is not evidence. Paste what actually ran.

## What this is not

Not a smoke check, not a vibe check. The point is that the user-observable goal in the
plan's **Goal** section is provably met before the plan leaves `docs/plans/`.

**Green ≠ delivered.** Tests passing means the code works; it does not mean the people the plan
was *for* can use it. If the Goal implies someone using the thing and getting it to them is a
separate step (publish, deploy, distribute, hand off), closing out the build plan is not the end —
make sure that delivery is tracked on `docs/ROADMAP.md` as its own active thread, not quietly
assumed done. A project isn't finished until it's in its users' hands.
