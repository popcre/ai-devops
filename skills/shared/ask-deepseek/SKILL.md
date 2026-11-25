---
name: ask-deepseek
description: "DeepSeek (V4.1 Flash; V4 Pro for hard builds) second opinion, debate, review, or scoped implementation. Opinions run through `ai-deepseek-agent`; code changes run through `ai-deepseek` in a private clone you land yourself. Use for \"ask DeepSeek\", \"run this by DeepSeek\", \"what does DeepSeek think\", \"debate DeepSeek\", \"have DeepSeek build/fix X\", or delegating repository work to DeepSeek."
---

# Ask DeepSeek

DeepSeek gives second opinions, debates, and delegated changes. Review is
advice only (owner ruling 2026-10-29, #2104): nothing waits on DeepSeek.

## Opinions and debates: `ai-deepseek-agent`

A thread-preserving wrapper. Ordinary `send` and `reply` run the read-only
DeepSeek Harness (OpenRouter) with built-in repository inspection in a
disposable, remote-less copy of the repo (no network, no credentials); your
checkout is never touched. Attach anything the tools cannot reach with
`--file`.

```bash
ai-deepseek-agent send "<brief>" [--file plan.md]                 # prints SESSION_ID (read-only harness)
ai-deepseek-agent reply <session-id> "<rebuttal>"                 # same thread, full memory
ai-deepseek-agent show <session-id> | list
ai-deepseek-agent send --review "<brief>"                         # direct API; must end in ## Verdict
```

Do not pass `--repo-tools` on ordinary `send` unless you explicitly want the
legacy direct-API tool loop instead of the default DeepSeek Harness. A formal
assigned review adds `--governed-verdict <exact-head-sha> --model
deepseek-flash` and ends in one `VERDICT: <word> <sha>` line; `--system`
cannot combine with `--review`. Set `AI_DEEPSEEK_CALLER` (`claude` or
`codex`). A nonzero exit is incomplete evidence, never approval. Missing or
rejected key: run `ai-deepseek-agent store-key` outside a review.

## Implementation: `ai-deepseek`

DeepSeek edits, commits and runs shell commands in a private clone with no
remote; you land and ship it. Never use this harness for a review verdict.

```bash
ai-deepseek doctor --live                                        # proves harness, key, one real turn
ai-deepseek implement <task> --repo <path> --prompt-file <brief> [--model deepseek-v4-pro]
ai-deepseek ask <task> --prompt "..."                            # continue, full memory
ai-deepseek diff <task>                                          # read it; rerun the tests yourself
ai-deepseek land <task>                                          # fetches branch deepseek/<task>
ai-deepseek cleanup <task>                                       # refuses unlanded commits without --force
```

Ship the landed branch from your own worktree under the repository's normal
rules. DeepSeek's report is a claim, not proof.

## Debate is the default

Every opinion, review, or second opinion is a **debate**, not a lookup, unless
the user asks only for a one-line fact or for `implement`. Two models agreeing
because the second anchored on the first is worth nothing; the value is real
independence, then real argument.

1. **Commit to your own position first.** Before DeepSeek sees anything, write
   your claim, reasoning, confidence, and what would change your mind to
   `<scratchpad>/claude-position.md`. With no real position, say so plainly:
   "I have no independent read; DeepSeek's answer stands unopposed."
2. **Send the brief plus your position**, labelled as one input to weigh and
   *not* the expected answer. Tell DeepSeek to reason from the material first
   and say plainly if you are wrong. State that this is read-only.
   `ai-deepseek-agent send "<brief>" [--file plan.md]`
3. **Report two separate things:** what DeepSeek said, faithfully (keep the
   parts that hurt your position), then whether you agree, point by point. If
   it changed your mind, say so and stop.
4. **Rebut only real disagreement**, in the same session so it argues with its
   own reasoning: `ai-deepseek-agent reply <session-id> "<rebuttal>"`. Name the claim you reject, give the evidence it
   lacked, and ask whether that changes its verdict; tell it not to split the
   difference to be agreeable. Use `templates/delegation/debate-turn.md` for
   the turn. **Cap at two rounds.**
5. **Close with one verdict:** *Agreed* (note when it merely confirmed),
   *DeepSeek conceded*, *Claude conceded* (and what moved you), or *Still split*
   with the crux and what would settle it. Then recommend what to do.

Never read DeepSeek's answer before writing your position, fold because it
sounds confident, soften its disagreement, run a debate with write access, or
report "we agree" when you are still split.

## Brief content — the other model gets nothing but this

DeepSeek starts with **zero knowledge of this session**. Standard: **a
stranger who walked in this morning could make the right call from the brief
alone.** Never write "as discussed" or "the usual setup". Every brief carries:

- **Background** — what the work is, why, and every prior decision, owner
  ruling, constraint, or incident that bears on it.
- **The material** — exact paths, functions, SHAs, error text; `--file` for
  anything long or unreachable.
- **The question** (or the task and what "done" means, with how to test).
- **Constraints** — scope limits and what must not change.
- **Required output** — verdict or artifact, evidence, confidence, and what is
  unassessable.

Never put a secret, token, connection string, or `.env` value in a brief.

## Debate discipline

1. Commit to your own position (claim, confidence, what would change your
   mind) before DeepSeek answers; include it labelled as one input to weigh.
2. Report what DeepSeek said faithfully, then whether you agree, per point.
3. Rebut only real disagreement, with `reply` on the same session, and at most
   two rounds. Use `templates/delegation/debate-turn.md`.
4. Close with one verdict: **Agreed**, **DeepSeek conceded**, **I conceded**,
   or **Still split** (state the crux and what would settle it), then a
   recommendation.

Never fold because DeepSeek sounds confident, never soften its disagreement,
and never start a new session for a rebuttal.
