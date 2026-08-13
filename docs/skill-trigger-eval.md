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

## The three load-bearing skills (2026-08-13) — Albert's gate on step 8

Scored on the Claude runner at `--runs 3`, against a neutral scratch project.

| Skill | Should fire | Should NOT fire | Verdict |
|---|---|---|---|
| `handoff-writer` | **8/10** | **0/10** | unchanged, no edit justified |
| `shared-db-change` (Claude twin) | **7/10** | **0/10** | unchanged; edit tried and reverted |
| `synology-long-running-operations` | **2/10** | **0/10** | unchanged; edit tried and reverted |

Precision is perfect across all three: no near-miss fired once, in any round.

**Two edits were written, measured, and thrown away.** The `shared-db-change`
description was rewritten to lead with the read-only schema-question case,
copying the structure of the 10/10 `codex-shared-db-change` twin; it scored
**7/10 → 6/10**. The `synology-long-running-operations` description was rewritten
to lead with the *shape* of the work (whole volume, share, or large subtree) and
name every case it had missed; it scored **2/10 → 2/10**. Both were reverted, per
the standing rule that an edit is kept only when should-fire improves and
should-not-fire stays 0/10. **Porting the wording of a high-scoring twin does not
port its score** — this is the second time (after the 1Password rewrite) that a
description that reads better measured worse or identical.

`synology-long-running-operations` at 2/10 is the real open problem. It fires on
prompts that name a timeout or ask for an "inventory", and stays silent on
ordinary phrasings of the same expensive read — hashing a tree, comparing the two
NAS boxes, months of logs, a CSV of every file. Wording alone did not move it.
Two untested hypotheses for whoever picks this up: the eval runs in a project
with no Synology MCP configured, so the model may see no NAS tooling to reach
for; and the always-loaded global already carries rule 9a about this exact
topic, which is the same "Claude believes it already knows enough" effect
documented above for 1Password. Test the MCP hypothesis before rewriting again.

### Two runner traps found on this run, both fixed

Both **inflated** scores, and the first three-set run was scrapped because of them.

1. **Any tool's input counted as a trigger.** The streaming-delta path matched the
   skill name anywhere in a tool call's input, so a `Grep` or `Read` of a file
   whose path merely contained the name scored as a fire. Deltas are now
   attributed to their block via `content_block_start`, and only a `Skill`
   block's delta counts.
2. **The default project was the caller's cwd.** Run from inside this repo —
   which names every skill in its docs, its globals, and its eval sets — ordinary
   reading produced false positives on prompts that must NOT fire.
   `handoff-writer` appeared to fire on "commit and push everything". The default
   is now a fresh neutral scratch project.

**An empty directory is not the fix.** It is inert: prompts asking the model to
act on the work at hand have nothing to act on, so it asks a question instead of
selecting a skill, and the run scores a miss it did not earn. The runner now
seeds a small ordinary project (a README, two source files, a notes file, an
empty `HANDOFF.d/`) that names none of our skills, repos, or machines.

**One run per query is not a measurement.** At `--runs 1` the same three sets
scored differently on different queries between two identical rounds, including
prompts quoted verbatim in the skill's own description. Use `--runs 3` for any
decision; twenty queries at three runs takes about eight minutes at
`--workers 6`.

## A global that names the skill does not summon it (2026-08-13, step-8 pilot)

`synology-long-running-operations` scored **2/10** before the step-8 pilot. Two
causes were recorded as untested: (a) the neutral eval project has no Synology
MCP wired up, so the model may see no NAS tooling to reach for; (b) rule 9a of
the always-loaded Claude global already covers the topic, and the documented
1Password precedent is that where a global covers a topic the model answers from
the global and no skill wording overrides it.

The pilot tested (b) by accident and refuted it hard. The trimmed global's rule
9a is not merely present — it now says outright:

> Load the shared `synology-long-running-operations` skill before any NAS read
> that will exceed 25 seconds

An explicit instruction, in always-loaded context, naming the skill. Re-scored
immediately after installing it, at `--runs 3`, against the same committed eval
set: **1/10 should-fire, 0/10 should-not-fire.** The score went *down*.

Two things follow, and the second is the useful one:

- **Precision is untouched.** Zero false positives across every configuration
  this skill has ever been measured in. The failure mode is silence.
- **An always-loaded rule does not route to a skill — it substitutes for it.**
  This is the 1Password precedent confirmed a second time, now with the
  strongest possible prompt. Naming a skill in a global is not a fix for a skill
  that will not fire; if anything it removes the model's reason to open it.

**The safety constraint is intact regardless**, and that distinction matters.
A step-8 probe asked a fresh session to "find every file over 2 GB on the whole
of volume1", and it correctly cited the 25-second limit and the background
method — from the global. What stays out of reach is the skill's *procedure*:
managed SSH, lowest practical priority, unique durable output, PID and status,
separate stderr, completion and exit evidence.

So the open question for step 10 is not "how do we word this description?" — two
rewrites have now failed to move it at all. It is **where this content should
live**: if the global already answers the question, the skill body is either
redundant or it is the part that matters, and the global should point less and
carry more (or the reverse). Decide that before touching the description again.

Hypothesis (a), the missing MCP, is still untested and is now the only surviving
explanation for the trigger score itself.

## Probes have the same trap as evals: score the act, not the answer

Step 8's first-pass safety probes searched the model's *answer text* for the name
of the file it was supposed to open. An agent that reads `docs/design-decisions.md`
has no obligation to name it afterwards, so a fully correct answer scored as a
failure — the third instance of this same mistake, after both trigger-eval
runners in steps 6 and 7a.

A probe that watches `tool_use` blocks and records the paths actually opened
reports the opposite and more interesting result: the router file was opened
**zero times in four routing probes**, yet every answer was correct. The content
was reached by `Grep`, by reading source, by the always-loaded global, and by
this machine's memory files. Measure the mechanism, then be ready for the
mechanism to tell you the design works for a reason you did not plan.
