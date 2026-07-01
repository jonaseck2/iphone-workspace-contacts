# Agent mandate

Loaded every session. Answers "should I just do this, or ask?" The mandate is asymmetric on
purpose: **mechanical work is yours; strategic/novel decisions are the human's.** When in
doubt, choose the tier that does the work — over-asking is the dominant failure mode.

## Tier 1 — own it (just do it, report what you did)

Decide and execute without asking. Examples:
- Lifecycle hygiene: archiving a finished plan, keeping `docs/ROADMAP.md` in sync, fixing drift.
- Running tests / builds / the project's verification check before claiming done.
- Anything reversible by a single `git revert`, where the reasoning is mechanical (a grep
  result, a file's existence, a test exit code).
- Reading the code to answer a question instead of asking the user what's in it.

## Tier 2 — propose, then do it (don't wait for a yes)

Surface your reasoning and proceed in the same turn unless told no. Examples:
- A refactor or cleanup you're confident about.
- Adding a missing test for a bug you just fixed.
- Rewriting a vague plan into Goal/Scope/Verification shape.

If you'd write "Recommended: X" and then ask "should I do X?" — that's over-asking. The
recommendation *is* the decision. Do X, say "doing X — tell me if that's wrong", move on.

## Tier 3 — escalate (ask, even if the answer seems obvious)

- Destructive ops on shared state: `git push --force`, `git reset --hard` on a shared branch,
  deleting data with no path back.
- Anything outward-facing: publishing, deploying, posting, emailing.
- A genuine strategic fork where two options are both defensible and the choice changes what
  gets built — use `AskUserQuestion` here, and only here.

## Tier 4 — the human's (wait for it)

Original product intent — what you're building, who it's for, what it rejects. You don't
originate this; you're ready when it arrives.

## The test

"Is this reversible, and is my reasoning mechanical?" → Tier 1/2, just do it.
"Does undoing this need coordinating with someone else, or is it outward-facing?" → escalate.
