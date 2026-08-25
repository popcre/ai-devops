# Gate reviewer prompt-cache measurement — 2026-08-25

This is the measurement spike required by Step 3.1 of
[`plan_reviewer-cache-efficiency.md`](../plan_reviewer-cache-efficiency.md). It
settles, with numbers, whether the two approval-gate reviewers have any
cacheable prompt prefix — the question that item 1 of that plan assumed the
answer to and got wrong.

**Result: they do not have one the wrapper can control. Item 1 is disproven, not
merely unsupported.** A separate, real cost was measured and is recorded below;
its only levers are outside this plan.

Read-only. No source file was changed to produce these numbers.

## Method

Each probe ran the **exact governed gate command**, with only the review prompt
replaced by `Reply with exactly: PROBE_OK`, so the measured prefix is the one a
real review pays for.

```bash
claude -p --model claude-opus-5 --effort high --output-format json \
  --permission-mode plan --tools Read,Grep,Glob --strict-mcp-config \
  --mcp-config '{"mcpServers":{}}' --no-session-persistence --no-chrome \
  --disable-slash-commands
```

Machine `edge-dev`, Git Bash, Claude Code `2.1.234`, 2026-08-25. Numbers come
from the `usage` object in the CLI's own JSON output.

## Claude (`bin/ai-claude-review`)

| Run | Working directory | `input_tokens` | `cache_creation_input_tokens` | `cache_read_input_tokens` |
|---|---|---|---|---|
| 1 | repository worktree | 2 | 11,879 | 2,800 |
| 2 | repository worktree | 2 | 11,878 | 2,800 |
| 3 | repository worktree | 2 | 11,877 | 2,800 |
| 4 | empty scratch dir A | 2 | 7,835 | 2,800 |
| 5 | empty scratch dir A (repeat) | 2 | 7,832 | 2,800 |
| 6 | empty scratch dir B | 2 | 7,833 | 2,800 |

### What these numbers say

**1. The user prompt is negligible and the system prefix is not.** The prompt
itself is 2 tokens of uncached input. Everything else — between 7,800 and 11,900
tokens — is CLI-supplied prefix. The review prompt in `bin/ai-claude-review:90-99`
is 326 bytes, so a real review's prefix is dominated by the same CLI content,
not by anything the wrapper writes.

**2. Cache reads are pinned at 2,800 tokens and never move.** Identical across
every run, in three different working directories, on repeats seconds apart.
Some fixed block — most likely core tool definitions — carries a stable cache
breakpoint and is reused. Nothing else is.

**3. The large block is re-created every invocation and never read back.**
Run 2 and run 3 were byte-identical repeats of run 1 in the same directory, and
each still created ~11.9k tokens and still read only 2,800. The same held in the
scratch directory (runs 4 and 5). Under `--no-session-persistence`, repetition
buys nothing.

**4. The prefix is not byte-stable even when everything the wrapper controls is
identical.** Counts drift by one to three tokens between identical consecutive
runs — 11,879 → 11,878 → 11,877, and 7,835 → 7,832. Something in the CLI's
system content varies per invocation, almost certainly a timestamp. **This is
what makes item 1 impossible rather than merely unhelpful:** no amount of path
determinism on our side can produce an identical prefix when the CLI's own
content changes every run.

**5. The working directory changes prefix size, but not cacheability.** The
repository adds roughly 4,045 tokens over an empty directory (11,877 vs 7,832) —
project context such as `CLAUDE.md` and repository state. That is a real cost of
reviewing inside a repo, but it is *cache-neutral*: `cache_read_input_tokens`
stayed at exactly 2,800 in all six runs. **A deterministic snapshot path could
not have moved this number.**

## Codex (`bin/ai-codex-review`)

```bash
codex exec -m gpt-5.6-sol --skip-git-repo-check --sandbox read-only \
  -c model_reasoning_effort=medium
```

| Run | Reported |
|---|---|
| 1 | `tokens used 17,672` |
| 2 | `tokens used 17,672` |

`codex exec` reports **one total and no cache breakdown at all** — no hit/miss
split, no creation figure. So for Codex the caching question cannot be answered
from the CLI, and a ~17.7k-token floor exists for a two-token prompt.

## The real cost this found

Item 1 aimed at the wrong thing, but the spike did quantify a genuine expense:
**each gate invocation creates roughly 12,000 tokens of prefix that is never
read back**, and the seven-stage pipeline invokes the gate four times. Cache
*creation* is billed above the base input rate, and here it lands in the
one-hour ephemeral tier without ever being redeemed.

The only levers are:

- **Session reuse** — dropping `--no-session-persistence` so one session spans
  the stages. This trades away stage independence: a later stage could "remember"
  an earlier stage's conclusion instead of re-deriving it against the evidence.
  For an approval gate, that independence is the point.
- **Fewer gate invocations** — a scope decision about the pipeline, not a
  wrapper change.

Neither belongs in the cache-reporting plan. Both are recorded here so a future
session starts from measurement instead of from the same wrong assumption.

## Incidental observation, not acted on

The Codex probe emitted an MCP authentication error
(`rmcp::transport::worker … AuthRequired … mcp.cloudflare.com`), which means the
ad-hoc `codex exec` invocation loaded ambient MCP servers. Claude's governed
command pins `--strict-mcp-config` with an empty server map; the governed Codex
command (`bin/ai-codex-review:14`) has no equivalent. Whether a gate reviewer
should be able to reach ambient MCP servers is a **safety** question, unrelated
to caching, and out of scope here. It is written down so it is not lost.

## Bottom line

Item 1 of the plan is closed on evidence: there is no wrapper-controllable
cacheable prefix, cache reads are fixed at 2,800 tokens regardless of path or
repetition, and the CLI's own prefix is not byte-stable between runs. Reopening
it would require a change in CLI or provider behaviour, not a new argument.
