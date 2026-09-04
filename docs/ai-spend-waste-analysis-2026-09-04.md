# Token waste analysis — 2026-09-04

Forensic analysis of local AI session logs to find spend that did **not**
contribute to code correctness, architecture quality, or problem resolution;
the two adversarial reviews of the proposed remedies; and the changes actually
shipped.

- **Corpus:** 1,312 session logs, ~3.2 GB — 506 Claude Code JSONL transcripts
  (570 files including worktree sessions) and 806 Codex rollout logs
  (939 files including archived sessions).
- **Method:** the providers' own billed token counters in each record, not
  character estimates. Cost-equivalent units weight cache reads at 0.1x, cache
  writes at 1.25x and output at 5x fresh input.
- **Reviewers:** Muse Spark 1.2 Contributor and Grok 4.6, each used in both
  directions — first critiquing this session's proposals, then proposing while
  this session critiqued.

---

## 1. The central mechanic

Every token that enters a conversation is re-sent to the model on every later
turn. Measured mean amplification: **36.8x on Claude, 40.0x on Codex.**

That single fact reorders the whole problem. A 300-line command dump is not
priced once at 300 lines; it is priced at roughly 300 lines times the number of
turns that follow it. It also means the expensive mistakes are the ones made
*early* in a long session, and that anything sitting in the permanent prompt
prefix — instructions, tool schemas, skill descriptions — is the most expensive
text on the machine.

## 2. Findings

### 2.1 Cache invalidation — the largest Claude leak

**13.5% of all Claude spend.** 2,766 cache-bust events re-billed 224.4M tokens,
which is roughly **81,000 tokens re-billed per bust**.

Cause: 1,399 mid-session mutations of the tool / skill / MCP list across 191 of
506 sessions (38%). MCP servers finish their handshake *after* the first request
has already been sent with whatever tools existed at that moment. The tool list
is part of the cached prompt prefix, so changing it invalidates the prefix and
the whole thing is billed again at full price.

The 81k-per-bust figure is diagnostic on its own: the global instruction file
and the skill manifest together are on the order of 15–20k tokens. Only MCP tool
schemas are large enough to account for the rest.

### 2.2 Oversized tool output

Output arriving in blocks of more than 50 lines:

| | share of tool output | share of spend |
|---|---|---|
| Claude | 52.5% of characters | ~2.1% |
| Codex | 70% of characters (50.27M tokens) | ~6.3% of total, being ~34% of fresh input |

Worst single Claude offender: `sed`, 3,435 calls, 78% of its output oversized —
which is itself evidence that blind line-windowing was already the habit and was
already failing.

### 2.3 Two hypotheses tested and rejected

**Session compounding.** Median session length is 9 turns on Claude and 1 turn
on Codex; only 4 of 506 Claude sessions exceeded 20 turns. Compaction is not
firing late, because it is barely firing at all. No change recommended.

**Output verbosity.** Assistant prose is 3.1% of output tokens, about **0.3% of
spend**. Full-file rewrites where an edit would do occurred 28 times in 506
sessions. Writing shorter replies is not a cost lever. No change recommended.

### 2.4 Spend is concentrated, not spread

This corrected an error in this session's own framing. Because the Codex median
session is 1 turn, it was tempting to conclude that per-session startup cost
dominates. Muse rejected that, and the measurement confirms the rejection:

| Codex sessions | share of spend |
|---|---|
| top 1% | 30.9% |
| top 5% | 58.5% |
| top 10% | 72.2% |
| all sessions with ≤2 tool calls (8% of sessions) | **0.3%** |

**A small tail of long sessions carries the bill.** Cheap throwaway sessions are
numerous and nearly free. This also disposes of a proposal (below) to suppress
short sessions.

### 2.5 Per-server MCP usage on Claude

Across 570 session files:

| server | calls | sessions | share of sessions |
|---|---|---|---|
| supabase | 755 | 60 | 11% |
| 1password | 591 | 49 | 9% |
| devops-mcp | 48 | 3 | 1% |
| playwright | 46 | 4 | 1% |
| codex-cli | 12 | 10 | 2% |
| ag-grid | 4 | 1 | 0% |
| synology-monitor | **1** | 1 | 0% |
| chrome-devtools | **0** | 0 | 0% |

Every server was under the 15%-of-sessions threshold. All of them were loaded
into every session, all day.

### 2.6 Codex MCP usage cannot be measured from logs

All 939 Codex rollout logs contain exactly 22 distinct tool names, and **not one
is an MCP server tool** — `exec` alone accounts for 82,194 calls across 873
sessions. But grepping those logs for known MCP tool names (`item_lookup`,
`op_run`, `execute_sql`, `browser_navigate`, `check_disk_space`, `invoke_tool`,
`take_snapshot`) returns nothing either.

The rollout log records tool *calls* but never the tool *definitions* sent in the
prompt. Therefore "zero calls" cannot distinguish **offered and unused** from
**never registered**, and cannot price the schemas at all. Codex first-turn input
is a median of 29,892 tokens (p25 27,311, p75 39,178, min 17,604) and its
composition is unknown.

---

## 3. Review round one — the reviewers critiqued this session

### 3.1 Muse on the proposed instruction rules

The first draft of the terminal-output rules traded correctness for tokens.
Muse's objections, all accepted:

1. `sed -n 'X,Yp'` assumes you know the line range. Listing it before `grep`
   teaches blind guessing — miss, re-guess, pay three amplified round trips.
   The right habit is `grep -n` first, then read a window around the hits.
2. "Never `cat` a file over 200 lines" inverts its own goal past a crossover of
   roughly 120–180 lines, where repeated windows cost more than one full read.
3. `head`/`tail` hide a failure in the middle of a build log. Filter by the
   error, not by position.
4. `--stat` instead of a diff, and `gh pr view --json state` instead of the
   discussion, are fine for orienting and fatal for a merge decision.
5. A 5-line error cap never contains the root cause of a Python or TypeScript
   trace.
6. "Never retry a failing command" blocks on a transient 503 and manufactures a
   handoff a human has to clear.
7. The subagent rule's "high-volume but low-judgement" test is too vague and
   will be over-applied to work that needs conversational context.
8. The injected text itself is amplified ~37x and was not priced.

### 3.2 Grok on the proposed Codex MCP removal

Proposal: delete the twelve never-called Codex MCP servers. **Rejected, and the
rejection was accepted.**

- Zero-call evidence is confounded — see §2.6. A failed handshake and a
  deliberate non-use look identical in the logs.
- Four of the twelve are the *constrained* interface, not a convenience:
  `1password` carries per-tool `approval_mode = "approve"` gates; `supabase` is
  pinned `--read-only` with a `--project-ref` cap; `devops-mcp` and
  `synology-monitor` inject bearer tokens through a launcher rather than putting
  them in process arguments. Removing them does not stop the work — it pushes it
  onto raw shell, which bypasses every one of those gates, in a client whose
  portable default is `approval_policy = "never"`.
- Claude and Codex share one MCP definition set in `bin/setup-machine.ps1`, so a
  Codex-only prune done naively strips Claude too.
- The installer still defines `chrome-devtools`, `recall-ai`, `trigger`,
  `ag-grid` and `railway`, and re-adds them on the next run.

---

## 4. Review round two — the reviewers proposed, this session critiqued

### 4.1 Grok's proposals for Claude

| # | proposal | verdict |
|---|---|---|
| 1 | File the cache-bust as an upstream Claude Code defect | **Accepted.** Worth 13.5%, costs nothing, and no local flag fixes it. `~/.claude/settings.json` `mcpServers` is silently ignored; `--strict-mcp-config` restricts which servers start but does not wait for them; the 1Password launcher mutex makes the race *worse* and must not be removed. A SessionStart sleep is a lottery, and enabling a server mid-session *is* another mutation. |
| 2 | Stop loading servers a session will not use; move them to project scope | **Accepted — implemented.** Verified against Grok's own <15% threshold: every server qualified (§2.5). |
| 3 | Confirm the cost-saving proxy is actually switched on | **Rejected on evidence.** `ai-headroom status` shows the persistent user environment variable routing through the proxy, and the proxy healthy. Already reflected in the measured numbers. Saving: 0%. |
| 4 | Replace `npx -y` on the MCP hot path with pinned local installs | **Deferred.** Plausible 2–7%, but it only wins the handshake race more often rather than removing it. Revisit after §4.1-2 lands and mutations are re-counted. |
| 5 | Do not give subagents the ambient MCP list | **Accepted in principle, deferred.** Largely moot now that only two servers remain at user scope. |
| 6 | Shorten skill descriptions | **Rejected.** Under 1%, gated on repeated-run trigger evaluation, and description rewrites have previously *lowered* skill fire rates. |

### 4.2 Muse's proposals for Codex

| # | proposal | verdict |
|---|---|---|
| 1 | Cap `exec` output through the global instruction template | **Already shipped** earlier the same day, including the refinements Muse itself demanded in round one. Largest measured Codex lever at 3–4.5% of spend. |
| 2 | Decompose the 29,892-token first-turn floor before cutting anything | **Accepted as the next step.** Requires a live instrumented Codex session; the logs cannot answer it (§2.6). |
| 3 | Suppress 1-turn session churn, estimated 3–4% | **Rejected on evidence.** Sessions with ≤2 tool calls are 8% of Codex runs and **0.3% of spend** (§2.4). The proposal's own premise — that fixed per-session cost dominates — is false. |
| 4 | Trim `AGENTS-global-codex.md` toward 120 lines | **Deferred.** ~1.5% claimed, but it competes directly with the safety rules that live in that file. Not worth doing before §4.2-2 says whether instructions or schemas dominate the floor. |
| 5 | Delete 17 stale `config.toml` backups | **Deferred to a Codex session.** Zero token impact; a Claude session must not touch Codex configuration. |

Muse also corrected this session's framing, which is recorded in §2.4.

---

## 5. Changes shipped

### 5.1 Instruction rules — `popcre/ai-devops`

`templates/system/CLAUDE-global.md` and `templates/system/AGENTS-global-codex.md`
gained `## Terminal output discipline`, `## Failed commands`, and (Claude only)
`## Offload noisy work to a subagent`. The live copies at `~/.claude/CLAUDE.md`
and `~/.codex/AGENTS.md` were updated identically, with timestamped backups.

- `c228d032` — first draft.
- `4fced209` — revision after Muse's round-one objections: grep before reading,
  one full pass past ~150 lines, filter logs by error rather than position, read
  the real diff and the PR discussion before a merge, report skipped and ignored
  test counts, retry transient failures up to three times with backoff, and a
  narrowed subagent rule requiring verbatim evidence rather than a bare verdict.

### 5.2 MCP relocation

`chrome-devtools` was removed from user scope on 0 calls in 506 sessions. The
remaining set was then relocated:

| server | from | to |
|---|---|---|
| `supabase` | user scope | `u2giants/shared-db` — PR #2295 |
| `devops-mcp` | user scope | `popcre/ai-devops` `.mcp.json` |
| `synology-monitor` | user scope | `popcre/ai-devops` `.mcp.json` |
| `playwright` | user scope | removed here; its four recorded sessions were all in DesignFlow repos, which are not on this machine |
| `1password` | user scope | **unchanged** — the constrained secret interface, and secret work is not repository-bound |
| `codex-cli` | user scope | **unchanged** — native executable, two tools, negligible schema |

Project scope was chosen over per-directory scope deliberately: a committed
`.mcp.json` is present in every worktree of a repository, whereas a machine-local
per-directory entry would miss every new worktree — and this workflow creates
them constantly.

- `fa8024af` — `.mcp.json` in `popcre/ai-devops`.
- `~/.claude.json` backed up to `.bak-relocate-20260904T131523Z` before the edit.

**Incident during this change.** The first push rewrote `ai-devops/.mcp.json`
from a stale local checkout and silently dropped the project-local `context7`
server added in #197. Caught by inspecting the file's history immediately after
pushing, and restored verbatim in `fa8024af`. The lesson is the one already in
the instruction template: check what is on the remote before overwriting a file
from a checkout that is behind.

---

## 6. What is still open

1. **File the cache-invalidation defect with Anthropic** — the 13.5% item, with
   the 2,766 busts / 224.4M tokens / 81k-per-bust / 1,399-mutation figures.
2. **Codex prefix census** — from a Codex session, run a no-op session and
   capture its first-turn tool list and input token count, then disable one
   low-risk server and re-measure. This is the only way to price the 29,892-token
   floor. Expected: plugins and MCP schemas are 60–70% of it. If instructions
   dominate instead, trim `AGENTS-global-codex.md` and abandon the MCP work.
3. **Re-count Claude cache-bust mutations** after the relocation, to measure what
   §5.2 actually bought.
4. **Freeze the installer** so `bin/setup-machine.ps1` cannot re-add
   `chrome-devtools` and the other removed servers, and split the Claude and
   Codex server sets so a change to one cannot alter the other.
5. **Pin the `npx -y` MCP command paths** — only if mutations remain after 3.

## 7. Cost of the reviews

Grok reported $0.0924 and $0.1046 across its two turns — **$0.20 total**. Muse
reported tokens only: 17,858 and 22,199 across its two turns.

## 8. Reproducing this

The parsing scripts are throwaway and were not committed. The measurements come
from `~/.claude/projects/**/*.jsonl` (Claude, `message.usage` plus `tool_use` and
`tool_result` content blocks) and `~/.codex/sessions/**` and
`~/.codex/archived_sessions/**` (Codex, `response_item` payloads of type
`function_call` and `custom_tool_call`, and `token_count` events carrying
`info.total_token_usage`).

One correction worth repeating: Codex's `total_token_usage.input_tokens`
**includes** `cached_input_tokens`. Subtracting is required, and failing to do so
overstates fresh input by roughly a factor of five.
