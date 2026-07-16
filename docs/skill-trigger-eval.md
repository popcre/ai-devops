# Measuring whether a skill actually triggers

A skill only helps if Claude *invokes* it. The `description:` in a skill's
frontmatter is the entire triggering mechanism — Claude reads the name and
description in its available-skills list and decides from that alone. Everything
below the frontmatter is invisible until it fires.

This is measurable rather than a matter of taste, and `tools/skill-trigger-eval/`
measures it: run realistic prompts through `claude -p` and count how often the
model calls the `Skill` tool.

## Running it

```bash
python tools/skill-trigger-eval/skill-trigger-eval.py \
  --skill secrets-to-1password \
  --eval-set tools/skill-trigger-eval/secrets-to-1password.eval.json
```

Requirements: the `claude` CLI **logged in** (`claude auth status` → `loggedIn:
true`; if not, run `claude` then `/login` in a normal terminal — it cannot be
done from inside a Claude Code session), and the skill installed
(`bin/ai-install-skills`). The runner tests the skill as installed in
`~/.claude/skills`, so install before measuring.

An eval set is realistic prompts plus the answer key:

```json
[{"query": "stick this key in 1password", "should_trigger": true},
 {"query": "wrap up", "should_trigger": false}]
```

The **should-not-trigger near-misses matter more than the positives.** Anything
can score 10/10 on prompts that shout the skill's name; the question is whether
the description is discriminating or just keyword-matching. Good near-misses
share vocabulary but need a different answer — for the 1Password skill, `"wrap
up"` and `"update the .md files"` (other skills own the chain and should fire
instead), reading a secret rather than storing one, or setting an env var on a
container.

## Two traps, both of which cost a session to find (2026-07-16)

**Don't use skill-creator's bundled `scripts/run_loop.py` on Windows.** It scored
every query 0 for two independent reasons:

1. **It is Unix-only.** It calls `select.select()` on a subprocess pipe; on
   Windows `select()` accepts only sockets, so every query died with
   `WinError 10038` — *while the run still reported exit 0*. A silent failure
   that hands the optimiser constant-zero noise to "improve" against. Fixable by
   replacing the `select()`/`os.read()` loop with a reader thread pushing
   `stream.read1()` chunks onto a `Queue`.
2. **It tests a mechanism that no longer triggers.** It writes a file into
   `.claude/commands/` and assumes that makes the skill model-invocable. It does
   not: commands surface as user-typed `slash_commands`, while the model invokes
   skills from `.claude/skills/` via the `Skill` tool. A fabricated command never
   fired once in 40 attempts; the real installed skill fired normally in the same
   environment.

Trap 2 is why this repo has its own runner: fixing the Windows bug alone still
measures the wrong thing.

## Reading the results honestly

**A should-trigger miss is only real if the model could have acted.** The first
run of the 1Password eval scored 2/10 and looked damning. Most of those
"failures" were prompts that asked to store a secret without ever including the
value — Claude asked for the value first, which is correct behaviour, not a
triggering failure. Re-running with the values pasted flipped them to firing.
The eval set was wrong, not the skill.

So: if a positive query doesn't fire, read the transcript before touching the
description. Half the time the model did the right thing.

**Also note what a description cannot fix.** A pushier rewrite of the
1Password description — explicit "use even before the value is pasted",
anti-improvise language — scored *identically*. Where `~/.claude/CLAUDE.md`
already covers a topic (it carries the 1Password vault rules), Claude often
answers directly because it believes it already knows enough, and no amount of
description wording overrides that. Wording is not the only lever, and sometimes
it isn't the lever at all.

## Baseline: secrets-to-1password (2026-07-16)

| Measure | Result |
|---|---|
| Should-NOT-trigger fired | **0/10** — every near-miss correctly declined |
| Fires on realistic "here's the secret, store it" | **2/3** |
| Pushier candidate description | identical — no change shipped |

Precision is the strong suit; sensitivity is adequate. No description change was
justified, so none was made. Re-run this before and after any edit to that
description — a rewrite that reads better but fires less is a regression, and
without the numbers you'd never know.
