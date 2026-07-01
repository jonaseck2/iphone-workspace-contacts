---
name: retro
description: Periodic re-read of recently shipped work against the project's own rules, to catch workflow drift and fix the rules that didn't fire. Use after archiving a few plans, every couple of weeks, or when the user says "let's retro." Where inventory is "what's hanging now" and close-out is "this plan is done", retro is "did the last N plans honor the workflow we said we follow?"
---

# Retro

**Announce at start:** "Running retro — re-reading the last N plans against our rules."

The improvement loop. The template only gets sharper if drift gets caught and the rules get
fixed. This skill finds the drift and commits the fix — it does not just report.

Cadence: after ~3 plans archive, every ~2 weeks, or on request. Not every session (too costly).

## Steps

### 1. Gather

```bash
ls -t docs/plans/archive/*.md 2>/dev/null | grep -v ROADMAP | head -3
git log --since="2 weeks ago" --oneline
```

Skim each archived plan and its commits.

### 2. Plan-format drift (against `.claude/rules/plans.md`)

For each plan, score yes/no:
- Opened with **Goal** in plain user language, not mechanism?
- **Scope** explicit (in, and what was left out)?
- **Verification** observed the goal, not just "lint passed"?
- Close-out captured real **evidence** (test output, exit codes)?
- Archived when done — didn't drift unarchived in `docs/plans/`?

Any "no" is a finding.

### 3. Workflow drift (against `.claude/rules/mandate.md`)

Read the execution's commits and messages:
- Were Tier 1 actions just done, or punted with "want me to…?"
- Were Tier 3 (destructive / outward-facing) actions escalated, not silently taken?

Every "want me to…?" for something the mandate calls Tier 1 is a finding.

### 4. Output + fix

If clean: `Retro <date> — N plans reviewed: clean.`

If findings: list each (what drifted, which rule should have caught it, why it didn't), then —
per `.claude/rules/mandate.md` Tier 2 — **make the rule/skill edits in the same commit**, with the
reasoning in the message. A retro that lists findings without committing fixes is half a retro.

## Not this skill

- Not code review (that's per-PR). Not `inventory` (that's "now"). Not `close-out` (that's one plan).
- Don't debate findings: if a rule didn't fire, fix the rule. If it was right but unused, fix the
  skill that should have invoked it. If both were right but attention slipped, shorten the cadence.
