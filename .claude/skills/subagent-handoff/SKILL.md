---
name: subagent-handoff
description: Use whenever you dispatch a subagent to do real work (implement a task, review, investigate). Layers a delivery contract on top of superpowers:subagent-driven-development so the handoff carries intent in and proves the outcome out — a subagent can't come back vague or "done" without evidence.
---

# Subagent handoff

A reliability layer over `superpowers:subagent-driven-development` (and
`superpowers:dispatching-parallel-agents`). Use that skill's flow; add the three rules below to
every dispatch. The failure mode this prevents: a subagent reports "done", the dispatcher marks
it done on faith, and nobody checked the actual user-observable result.

## 1. Carry intent IN — every prompt opens with the goal

Start each subagent prompt with a **Goal** section, copied verbatim from the plan's Goal (the
user-observable outcome, not the mechanism). Instruct the subagent: *if the task as specified
doesn't serve this goal, stop and report `BLOCKED` with why* — don't build the wrong thing well.

## 2. Fixed report shape — so it can't come back vague

The subagent's final message must answer three questions, explicitly:

1. **What I did** — the concrete change or finding.
2. **How I verified the goal** — the user-observable check actually run (a command + its output,
   a file read, a request/response). Not "tests pass." If nothing was verified, say so.
3. **What I assumed / deviated** — anywhere it diverged from the spec or goal.

Reject and re-dispatch any report missing one of the three.

## 3. Verify outcomes OUT — before marking done

For any task whose goal is user-observable, the **dispatcher** runs its own verification before
marking it done — don't mark done on the subagent's word alone. Run the command, read the file,
hit the endpoint. Lint and unit tests passing are hygiene; they are not proof the goal is met.
(See `superpowers:verification-before-completion` and `.claude/rules/plans.md`.)

## When dispatching several at once

Parallel subagents must have non-overlapping scope (separate files/dirs) — see
`superpowers:dispatching-parallel-agents`. If they'd edit the same files, give each its own git
worktree (`superpowers:using-git-worktrees`) and, before each commit, confirm the worktree is on
its own branch, not `main`. Drive a worktree with `git -C <path> …` rather than
`cd <path> && git …` — the `cd`-compound form triggers a permission prompt on every variation
and breaks your flow.
