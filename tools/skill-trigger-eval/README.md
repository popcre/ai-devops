# skill-trigger-eval

Measures whether a Claude Code skill actually fires on realistic prompts.

```bash
python tools/skill-trigger-eval/skill-trigger-eval.py \
  --skill secrets-to-1password \
  --eval-set tools/skill-trigger-eval/secrets-to-1password.eval.json
```

For Codex, use the sibling runner — Codex has no `Skill` tool event, so the
Claude harness cannot be pointed at it:

```bash
python tools/skill-trigger-eval/codex-trigger-eval.py \
  --skill <installed-skill-name> \
  --eval-set tools/skill-trigger-eval/<name>.eval.json
```

It counts a trigger when Codex **opens** the installed `SKILL.md`, which proves
selection, not obedience. It always passes an explicit `low` (or `medium`)
reasoning effort and a read-only sandbox; `--print-command` shows the exact argv
without calling a model. Eval-set format is identical, so one set feeds both.

**Two detection traps, both found on the first real run, 2026-08-12.** Both are
fixed and locked by `tests/test-codex-trigger-eval.sh` (offline; calls no model).

1. **Escaped separators, which understated the score.** Codex reports the command
   it ran inside a JSON string, and that command is itself a quoted shell string,
   so one real Windows path separator can arrive as two or four backslashes.
   Matching the raw path scored **0/1 on a query where Codex had visibly opened
   the skill**. Backslash runs are now collapsed before matching.
2. **Contamination, which overstated the score.** Matching anywhere in the event
   line counts a run as a trigger whenever the skill path merely *appears* in
   something the model read — and this repo contains several such files,
   including the test above. That produced **4 unearned false positives out of 10
   legitimate negatives**. Only a `command_execution` **command** counts now,
   never its output: the command a model chose to run is a decision, text
   scrolling past in output is not.

Every hit records the exact command in an `evidence` field. Read it before
believing any surprising score, and re-run the single query alone to confirm.

**The two committed Codex sets, and why these two first:**

| Set | Why |
| --- | --- |
| `codex-qwen-code.eval.json` | `skills/codex/codex-qwen-code` and `skills/claude/qwen-code` are the exact-body merge candidate. The descriptions are identical, so **one set scores both clients** — run it before and after any merge. |
| `codex-shared-db-change.eval.json` | Load-bearing: both always-loaded globals name this skill. Its positives cover schema changes *and* Rule 0 read-only inspection, which the description also routes here. |

Needs the `claude` CLI logged in (`claude auth status`) and the skill installed
(`bin/ai-install-skills`) — it tests the real skill in `~/.claude/skills`, via
the real `Skill`-tool mechanism.

Full context, the two traps in the bundled skill-creator harness, and how to read
a "miss" honestly: **`docs/skill-trigger-eval.md`**. Read it before acting on a
low score — the first 1Password run scored 2/10 because the *eval set* was wrong,
not the skill.

Eval sets live here as `<skill-name>.eval.json`. Note `.gitignore` has a narrow
negation for `*secret*.eval.json` in this directory; a set whose filename
contains "secret"/"token"/"private" is otherwise silently refused by `git add`.
Prompt sets must never contain real credential values — a prompt only needs to
mention a credential to test triggering.
