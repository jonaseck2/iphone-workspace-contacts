# CLAUDE.md

**WorkspaceContacts** — an iOS app that syncs the Imeto Google Workspace directory into iPhone
Contacts so colleagues show up by name on incoming calls (see [`README.md`](README.md) for what it
is and how to build it). This file is loaded into every session and every subagent — it's the
shared brief for *how we work on it*.

Built mostly agentically with Claude Code, using the workflow below. That workflow — the rules and
skills in [`.claude/`](.claude/) — comes from the
[Imeto Claude project template](https://github.com/imeto-consulting/claude-project-template);
generic improvements to it should flow back there.

## How this repo works

- **Superpowers** (`superpowers@claude-plugins-official`) — the brainstorm → spec → plan →
  implement workflow, enabled in `.claude/settings.json`.
- **A plan convention that doesn't leak tool branding** — plans and specs live in
  `docs/plans/`. **Override:** whenever a Superpowers skill (`brainstorming`, `writing-plans`)
  offers to save to a `docs/superpowers/...` path, save to the matching `docs/plans/...` path
  instead — spec → `docs/plans/YYYY-MM-DD-<topic>-design.md`, plan →
  `docs/plans/YYYY-MM-DD-<feature>.md`. How plans are *written* is governed by the path-scoped
  rule [`.claude/rules/plans.md`](.claude/rules/plans.md) (it loads automatically when you work
  inside `docs/plans/`).
- **A close-out workflow** — the [`close-out`](.claude/skills/close-out/SKILL.md) skill
  archives a finished plan with verification evidence.
- **A roadmap** — [`docs/ROADMAP.md`](docs/ROADMAP.md) is the human-facing index of what's active
  and shipped.
- **An agent mandate** — [`.claude/rules/mandate.md`](.claude/rules/mandate.md) says when to act
  outright vs. ask. Bias is toward doing the work; over-asking is the failure mode.
- **Workflow skills** — [`inventory`](.claude/skills/inventory/SKILL.md) (start a session by
  seeing what's in flight), [`audit-validation`](.claude/skills/audit-validation/SKILL.md)
  (verify claims about the code by grepping before you plan),
  [`subagent-handoff`](.claude/skills/subagent-handoff/SKILL.md) (carry intent into a dispatched
  subagent and prove the outcome before marking it done), and
  [`retro`](.claude/skills/retro/SKILL.md) (periodically check that shipped work honored the
  rules, and fix the rules that didn't fire).

## First-time setup (each person, once)

The plugins are *enabled* in `.claude/settings.json`, but Claude Code installs them on first
use. On your first session, if prompted to install `superpowers@claude-plugins-official`,
accept. Or run `/plugin install superpowers@claude-plugins-official` yourself. After that it
stays enabled across sessions.

## The workflow — verification first

The one lesson behind this workflow: **get verification in early.** A project you can prove
works end-to-end is a project you can ship agentically without second-guessing. So:

1. **Brainstorm.** Start with the `superpowers:brainstorming` skill. Use stream-of-thought —
   just write what you're thinking and react to what comes back until you like the shape. The
   spec is saved to `docs/plans/YYYY-MM-DD-<topic>-design.md`. Commit it immediately.
2. **Plan.** `superpowers:writing-plans` turns the spec into a checkbox plan in `docs/plans/`.
   Every plan opens with **Goal**, **Scope**, **Verification** (see the rule). The verification
   must be something *runnable* — a test or a command with expected output — not "looks right."
   Commit the plan immediately, before creating a worktree.
3. **Implement.** Let Superpowers drive the tasks (`superpowers:using-git-worktrees` for
   isolation, `superpowers:subagent-driven-development` for parallel work). When you dispatch a
   subagent, follow [`subagent-handoff`](.claude/skills/subagent-handoff/SKILL.md): carry the
   goal in, prove the outcome before marking done. Keep the verification check green.
4. **Close out.** When every box is `- [x]`, run the [`close-out`](.claude/skills/close-out/SKILL.md)
   skill: capture evidence, archive the plan (and its design spec), update the roadmaps and the
   README. Remember: green tests mean the code works, not that anyone can use it yet — if getting
   it to its users is a separate step, that step is still open work.
5. **Capture what you learned.** When you land on a pattern or convention worth keeping, ask
   Claude to turn it into a skill (`skill-creator`) or a rule in `.claude/rules/`. Every few
   plans, run [`retro`](.claude/skills/retro/SKILL.md) to catch workflow drift and fix the rules
   that didn't fire. Push generic improvements back to the template so the next project inherits them.

## Conventions

- **Plans & specs:** `docs/plans/` — see [`.claude/rules/plans.md`](.claude/rules/plans.md). This
  is the authoritative rule; read it before writing or archiving a plan.
- **Lagom over-engineering.** Build the smallest version that's shippable and verifiable. Add
  structure when a real need shows up, not in anticipation.
- **Evidence over assertion.** "Tests pass" means you ran them and saw the count. Don't claim
  done without proof.
- **Done means delivered.** Think end-to-end: the goal isn't "the code works," it's "the people
  it's for can use it." Verification proves the first; delivery (publish/deploy/hand-off) closes
  the second. A build plan closing out is not the project finishing.
