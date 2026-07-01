---
name: audit-validation
description: When a claim about the code ("X is missing", "Y is 800 lines", "Z is duplicated everywhere", "we need to build W") is the input to a plan, verify it by grepping the actual code BEFORE planning. Triggers on phrases like "the audit says", "the analysis found", "X doesn't exist yet", "X is N lines", or any file/symbol/size/pattern claim that would shape the plan.
---

# Audit validation — grep before plan

Before writing a plan against a claim about the code, verify the claim against the code itself.
Audits, AI-generated analyses, and your own assumptions drift from reality. Check first.

## The rule

For every claim that would change the plan's shape, run a one-line verification before
brainstorming or writing the plan.

| Claim shape                        | Verify with                              |
| ---------------------------------- | ---------------------------------------- |
| "File X exists / is gone"          | `ls <path>` / `test -f <path>`           |
| "X is N lines"                     | `wc -l <path>` (order of magnitude)      |
| "Pattern P appears M times"        | `grep -rc '<pattern>' <path>`            |
| "Symbol/module X doesn't exist"    | `grep -rn '<name>' .` / `find . -name`   |
| "X is duplicated across A, B, C"   | grep a unique line from the block; read a sample to confirm it's real duplication |

## How to apply

1. Read the claim until you can list its specific assertions.
2. For each assertion that matters, run the matching check above — *before* writing anything.
3. Record the actual measurement next to the claim in the plan's Scope. Note discrepancies.
4. If a check shows the premise is wrong: don't paper over it. Reframe the plan around the real
   code state, or close it with a one-line "premise didn't hold" note.

## Not this skill's job

Writing the plan (`superpowers:writing-plans`) or exploring intent
(`superpowers:brainstorming`). This is a one-step intake check; normal plan workflow follows.
