---
name: codex-second-opinion
description: Get Codex (GPT-5.x) to independently review a plan, diagnosis, design, or diff, report what it says, state whether Claude agrees — and when Claude disagrees, argue the point back to Codex and report whether either side moved. Use when the user says "run this by codex", "what does codex think", "get a second opinion", "see if codex agrees", "ask codex and tell me if you agree", or "if you disagree, push back and see if it changes its mind". For handing Codex work to *execute*, use codex-handoff instead; for a canned read-only review of the current git diff, ai-codex-review is the lighter tool.
---

# codex-second-opinion

A **debate**, not a delegation. Codex (GPT-5.x) is a genuinely independent engine
with a clean context window, so it's the best available check on Claude's
reasoning — but only if Claude commits to its own position first and then argues
honestly. This skill runs that loop and reports the outcome.

The failure mode this exists to prevent: Claude reads Codex's answer, finds it
plausible, and folds. Two models agreeing because the second one anchored on the
first is worth nothing. The value is in genuine independence, then genuine
argument.

## Trigger phrases

- "run this by codex", "what does codex think", "see if codex agrees"
- "get a second opinion" / "ask the other model"
- "tell me what it says and if you agree"
- "if you disagree, give it your reasoning and see if it changes its opinion"

## Related skills — pick the right one

| Want | Use |
|---|---|
| Codex's *opinion* on reasoning, with Claude's own view and a rebuttal round | **this skill** |
| Codex to *build/run/prove* something autonomously | `codex-handoff` |
| A canned read-only Codex pass over the current git diff → `.ai/reviews/` | `ai-codex-review` (via the `ai-reviewer` skill) |

## Transport — prefer the MCP, fall back to the CLI

**Check for the `codex-cli` MCP first** (`mcp__codex-cli__codex` /
`mcp__codex-cli__codex-reply`). Since 2026-07-16 it is wired to Codex's **own**
`codex mcp-server` — not the old third-party npx wrapper — by
`bin/setup-machine.ps1` (Windows → Claude **Desktop**) and `bin/setup-secrets.sh`
(Ubuntu → Claude Code `~/.claude/settings.json`). It maps onto this skill exactly:

| Step | MCP tool | Args that matter |
|---|---|---|
| 2 — opinion | `codex` | `prompt`, `sandbox="read-only"`, `cwd` |
| 4 — rebuttal | `codex-reply` | continues the same thread — no re-sending the brief |

`codex-reply` is thread continuation, which is precisely the rebuttal round; use
it rather than reconstructing context.

**If the MCP isn't present, use `codex exec` — this is normal, not a fault.** The
wiring is per-surface: Claude Code on Windows has no `codex-cli` MCP (the Windows
script targets Claude Desktop), so a Windows Claude Code session lands on the CLI
path below every time. Confirm with `claude mcp list`.

Historical note, so nobody "re-fixes" this: the **old third-party wrapper** failed
with a false **"Codex CLI Not Found"**. That is not evidence the current native
MCP is broken — don't let an old transcript talk you out of trying the MCP. If
the native one ever does fail, don't retry it; fall back and say so.

For the CLI path, find the binary rather than hardcoding it (`where codex` /
`command -v codex`), and confirm with `codex --version` (expect `codex-cli <ver>`).
Do **not** hardcode `…\Programs\OpenAI\Codex\bin` on Windows — that visible path
is a junction, and Codex's sandbox helper is unreachable through it, so every
sandboxed write fails while `--version` still passes. See the junction incident in
`AGENTS.md`.

## Step 1 — commit to your own position FIRST

Before Codex sees anything, write your own position to
`<scratchpad>/claude-position.md`: the claim, the reasoning, your confidence, and
the specific thing that would change your mind. This is not ceremony — it is the
anchor that makes the comparison in Step 3 honest. Skipping it means you can't
tell agreement from anchoring afterwards.

If you genuinely don't have a position (the question is outside what you can
assess from context), say so to Albert plainly rather than manufacturing one.
"I have no independent read here, so Codex's answer stands unopposed" is a
legitimate and useful outcome.

## Step 2 — send the material and your position to Codex

Codex starts with **zero knowledge of this chat**. The brief is the whole
handoff: hold it to the `handoff-writer` standard — a stranger who walked in
this morning could act on it with no questions. Write it to
`<scratchpad>/codex-brief.md`. Include:

- **The material** — the plan/diagnosis/design/diff itself, in full. Exact file
  paths, function names, SHAs, table and column names, error text. Never "the
  relevant file"; name it. Codex cannot see your scrollback.
- **The question** — what you want judged, stated sharply.
- **Claude's position** — include it, clearly labelled as one input to weigh and
  explicitly *not* the expected answer. Tell Codex to reason from the material
  first and to say so plainly if Claude is wrong. Including it is what makes
  Step 4 a real rebuttal instead of two disconnected monologues.
- **The required output** — its own verdict, the reasoning, its confidence, where
  it agrees and disagrees with Claude's position and why, and anything it could
  not assess from the material given.
- **Read-only** — state that this is an opinion, not a work order: do not edit,
  create, commit, push, or delete anything.

Run it read-only, so the sandbox enforces what the brief says:

```bash
export PATH="$PATH:/c/Users/<user>/AppData/Local/Programs/OpenAI/Codex/bin"
SP="<scratchpad-dir>"
codex exec \
  -s read-only \                    # opinion, not a work order — sandbox-enforced
  -c model_reasoning_effort='medium' \  # REQUIRED — low|medium only, never high/none
  -C "C:\\path\\to\\repo" \
  -o "$SP/codex-opinion.md" \       # final message → file
  --color never \
  - < "$SP/codex-brief.md" \
  > "$SP/codex-stdout.log" 2>&1
```

`-c model_reasoning_effort` is **not optional**: Albert's standing rule
(2026-07-16) is GPT-5.6 at `low` or `medium` ONLY, never `high` or `none`. Pass
it explicitly — an unset effort has been observed to start a run at `none`.
Judgement work like a second opinion wants `medium`. Check the `reasoning
effort:` line in the stdout header and kill the run if it says anything else.

Never paste a secret value into the brief. If Codex needs a credential, point it
at 1Password (`op`, vault `vibe_coding`) — and note that `-s read-only` blocks
that anyway, which is another reason opinion work shouldn't need secrets.

## Step 3 — report Codex's answer, then your agreement

Two clearly separate things, in this order — never blend them into one voice:

1. **What Codex said.** Its verdict and reasoning, faithfully. Don't paraphrase
   away the parts that are inconvenient for your position. If it raised
   something you'd missed, say that outright.
2. **Whether you agree**, per point, with reasoning. Partial agreement is the
   common case and is more useful than a forced binary — say which parts you
   accept and which you don't.

If Codex changed your mind, say so and stop; there's nothing to argue. Genuinely
updating on a better argument is the *point* of the exercise, not a loss.

## Step 4 — the rebuttal round (only on real disagreement)

Only if you still disagree on something that matters. Resume the same session so
Codex argues with its own reasoning in context rather than starting cold:

**`resume` takes a different flag set from `exec`** — verified against codex-cli
0.144.5. It rejects `-s`, `-C`, and `--color` (`error: unexpected argument '-s'`).
Set the sandbox via `-c sandbox_mode="read-only"` and `cd` to the repo instead:

```bash
cd "C:/path/to/repo"                      # resume has no -C
SID="$(grep -oE 'session id: [0-9a-f-]+' "$SP/codex-stdout.log" | awk '{print $3}')"
codex exec resume "$SID" \
  -c sandbox_mode="read-only" \           # resume has no -s
  -c model_reasoning_effort='medium' \    # low|medium only — carry the rule into the resume too
  -o "$SP/codex-rebuttal.md" \
  - < "$SP/claude-rebuttal.md" \
  > "$SP/codex-rebuttal-stdout.log" 2>&1
```

Step 2's stdout log prints `session id: <uuid>` in its header — take it from
there. `codex exec resume --last` also works and resumes the newest session for
this working directory, but it's a guess: any other Codex run in between silently
wins. Use the explicit id.

Confirm the resumed run reports `sandbox: read-only` in its header — that header
is the proof the sandbox override actually took, since a mistyped `-c` key would
otherwise fail open to the config default.

The rebuttal must be an argument, not a re-assertion: name the specific claim you
reject, give the evidence Codex didn't have or didn't weigh, and ask it directly
whether that changes its verdict — and to say plainly if it does not, rather than
splitting the difference to be agreeable.

**Cap it at two rounds.** Past that, models converge on politeness rather than
truth. If it's still unresolved after two, the disagreement is real and Albert
should see it as a real disagreement — that's a finding, not a failure.

## Step 5 — the verdict

Close with exactly one of these, in plain English:

- **Agreed** — we independently reached the same conclusion. (Note when Codex
  merely confirmed rather than tested — cheap agreement isn't strong evidence.)
- **Codex conceded** — it changed its verdict after the rebuttal, and why.
- **Claude conceded** — you changed yours, and what specifically moved you.
- **Still split** — state the crux: the one factual question or judgement call
  the disagreement reduces to, and what would settle it. This is the most
  valuable outcome of all; never paper over it with a false "we broadly agree".

Then say what you recommend doing about it.

## Anti-patterns

- **Reading Codex's answer before writing your own position.** Destroys the
  independence the whole skill exists to buy.
- **Folding because Codex sounds confident**, or holding your position out of
  stubbornness. Both are failures of the same thing: arguing from the evidence.
- **Softening Codex's disagreement** when reporting it, because you'd rather be
  right.
- Skipping the `codex-cli` MCP because an old transcript says it's broken — that
  was the retired third-party wrapper, not today's native `codex mcp-server`.
- Hardcoding the junction path `…\Programs\OpenAI\Codex\bin` on Windows.
- Running the debate with write access (`--dangerously-bypass-approvals-and-sandbox`
  or `-s workspace-write`) — an opinion round has no business editing the repo.
- Inlining a giant prompt on the command line instead of a brief file.
- Pasting a connection string, token, or key into the brief.
- More than two rounds, or reporting "we agree" when you're actually still split.
