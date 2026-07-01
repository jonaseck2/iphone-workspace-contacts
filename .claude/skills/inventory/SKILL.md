---
name: inventory
description: Session-start ritual. Walks the project state to produce a single-screen view of what's in flight, what's drifted, and the proposed next move. Use at the top of a working session, after losing context, or when asked "what's the state of the project?"
---

# Inventory

**Announce at start:** "Running inventory to see what's in flight."

A fast (< 30s) kanban-board read of the project. Produces a structured summary you use to
*propose the next move* — not a question, and not a free-text dump. Everything checked here is
mechanical: greppable, filesystem-observable, or git-observable. No guessing.

## What it surfaces

### 1. Active plans

```bash
ls docs/plans/ 2>/dev/null | grep -vE '^(archive|README)'
```

Classify each:
- **In progress** — has at least one `- [ ]`.
- **Design-only** — filename ends `-design.md` (a spec, no tasks by intent — not drift).
- **Drift** — every box is `- [x]`, name doesn't end `-design.md`, still not in `archive/`.
  Per `.claude/rules/plans.md` this is a violation. **Action: run the `close-out` skill.**

```bash
for f in docs/plans/*.md; do
  [ -f "$f" ] || continue
  case "$f" in *-design.md|*/README.md) continue ;; esac
  grep -q '\[ \]' "$f" || echo "DRIFT: $f"
done
```

### 2. Roadmap sync

Does `docs/ROADMAP.md` (Now/Next) reflect the active plans above? Does anything in
`docs/plans/archive/` have a line in `docs/plans/archive/ROADMAP.md`? Fix mismatches.

### 3. Local git hygiene

```bash
git status --short
git stash list
git log --oneline origin/main..main 2>/dev/null   # ahead, unpushed
git log --oneline main..origin/main 2>/dev/null    # behind
```

## Output format

```
INVENTORY @ <short SHA> on <branch>

Active plans (N):
  - <file> — in progress / drift / design-only

Roadmap sync: clean / <mismatch>

Git hygiene: clean / <N actions>

Proposed next move: <one sentence, grounded in what was found>
```

The **proposed next move** is your read of the state, not a question (see
`.claude/rules/mandate.md` — Tier 1). The user redirects if it's wrong.

## What it is not

- Not an audit — it doesn't read every file.
- Not verification — it doesn't run tests or builds.
- Don't run it mid-task. It's a session-shape tool.
