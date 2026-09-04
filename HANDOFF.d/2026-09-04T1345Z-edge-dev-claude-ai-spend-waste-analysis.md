---
issue: 269
status: OPEN
owner: claude/token-waste-analysis-72cedc
---

# Token waste analysis — session handoff

**Full findings, both reviewers' proposals, and the actions taken:
[`docs/ai-spend-waste-analysis-2026-09-04.md`](../docs/ai-spend-waste-analysis-2026-09-04.md).**
Read that first; this file is the operational state around it.

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

- **Nothing is blocking.** No decision is required to continue.
- One judgement call was made without asking, and is reversible: `playwright` was
  dropped from user scope entirely rather than relocated, because all four of its
  recorded sessions were in DesignFlow repositories that are not checked out on
  this machine. If Albert wants it back, restore it from
  `~/.claude.json.bak-relocate-20260904T131523Z`.
- `1password` was deliberately left at user scope even though it fails the same
  usage threshold as the servers that were moved. Secret work is not tied to one
  repository, and it is the approval-gated interface that keeps secrets out of
  shell arguments. Do not "finish the job" by moving or removing it.

## 1. What this application is

`popcre/ai-devops` holds the machine setup, the global instruction templates that
are synced to `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`, and the shared
skills. Nothing here is a running service; changes here change how every AI
session on every machine behaves.

## 2. What we set out to do this session, and why

Find AI spend that did not contribute to correctness, architecture quality, or
problem resolution — and fix it without losing capability. Method: parse the
1,312 local session logs (~3.2 GB) using the providers' own billed token
counters, then put every proposed remedy through two independent adversarial
reviewers before shipping it.

## 3. Current state — what is true right now

Shipped and verified:

- **Instruction rules** — `## Terminal output discipline`, `## Failed commands`
  and (Claude only) `## Offload noisy work to a subagent` are in both sync-source
  templates and in both live files. Commits `c228d032` then `4fced209`, the
  second being the rewrite that answered Muse's correctness objections.
- **MCP relocation** — user scope is down from six servers to two (`1password`,
  `codex-cli`). `devops-mcp` and `synology-monitor` now live in this repo's
  `.mcp.json` (commit `fa8024af`, which also restored `context7` after a
  same-session regression). `chrome-devtools` was removed on 0 calls in 506
  sessions.
- **`supabase`** is in `u2giants/shared-db` PR #2295, open, mergeable, checks
  running at the time of writing. That PR changes configuration, not prose, so it
  waits for its 13 checks.
- `~/.claude.json` was backed up to `.bak-relocate-20260904T131523Z` before the
  edit. `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md` have
  `.bak-muserev-20260904T122947Z` backups.

Not shipped: everything in §6.

## 4. Everything we tried that did NOT work

- **Demoting `synology-monitor` to per-directory scope via the CLI.** The CLI
  mangled a Windows argument — `/c` became `C:/` — producing a broken entry. It
  was fully reverted rather than left degraded. The relocation was later done by
  writing a committed `.mcp.json` instead, which is also the better shape: a
  committed file is present in every worktree, and this workflow creates
  worktrees constantly.
- **Pruning Codex MCP servers on zero call counts.** Grok rejected it and the
  rejection was accepted. Codex rollout logs record tool *calls* but never the
  tool *definitions* sent in the prompt, so "zero calls" cannot distinguish
  "offered and unused" from "never registered" — and four of the servers are the
  constrained interface whose removal pushes the same work onto unrestricted
  shell.
- **Two hypotheses measured and abandoned:** session compounding (median 9 turns
  Claude, 1 Codex) and output verbosity (assistant prose is 0.3% of spend).
  Neither is a lever. Do not re-propose them.

## 5. Root causes and key findings

- Every token entering a conversation is re-sent on every later turn — measured
  mean amplification **36.8x Claude, 40.0x Codex**. The prompt prefix is the most
  expensive text on the machine.
- **Cache invalidation is 13.5% of Claude spend**: 2,766 busts, 224.4M tokens
  re-billed, ~81k per bust, from 1,399 mid-session tool-list mutations. Only MCP
  schemas are large enough to explain 81k. This is an upstream client defect; no
  instruction text and no local flag fixes it.
- **Spend is tail-concentrated**, not spread: the top 10% of Codex sessions are
  72.2% of spend, and all sessions with ≤2 tool calls together are 0.3%. This
  corrected an error in this session's own framing and killed one of Muse's
  proposals.

## 6. Exact next steps

Tracked as [issue #269](https://github.com/popcre/ai-devops/issues/269):

1. File the cache-invalidation defect with Anthropic, with the figures in §5.
2. **Codex prefix census** — must be run from a Codex session, not Claude.
   Capture a no-op session's first-turn tool list and input token count, then
   disable one low-risk server and re-measure. Expected: plugins and MCP schemas
   are 60–70% of the 29,892-token floor. If instructions dominate instead, trim
   `AGENTS-global-codex.md` and abandon the MCP work there.
3. Re-count Claude cache-bust mutations now that the relocation has landed, to
   measure what it actually bought.
4. Freeze `bin/setup-machine.ps1` so it stops re-adding the removed servers, and
   split its Claude and Codex server sets.
5. Pin the `npx -y` MCP command paths — only if mutations remain after step 3.

Also outstanding from this session: merge `u2giants/shared-db` PR #2295 once its
checks pass.

## 7. Constraints and gotchas in force

- **A Claude session must never edit Codex configuration, and vice versa.** Step
  2 above is therefore a Codex job.
- Removing an MCP server to save tokens is a security regression when that server
  is the constrained interface. `1password`, `supabase`, `devops-mcp` and
  `synology-monitor` all carry approval gates, read-only pins or launcher-injected
  bearer tokens that raw shell bypasses.
- The `ai-devops` primary checkout at `C:\repos\ai-devops` is far behind main.
  This session pushed a stale `.mcp.json` from it once and silently deleted
  another PR's server. Work from a fresh worktree on `origin/main`, and check
  what is on the remote before overwriting a file.
- Codex `total_token_usage.input_tokens` **includes** `cached_input_tokens`.
  Failing to subtract overstates fresh input roughly fivefold.

## 8. Access and environment

- Machine `edge-dev`, Windows 11, Git Bash.
- Logs parsed from `~/.claude/projects/**/*.jsonl` and
  `~/.codex/sessions/**` + `~/.codex/archived_sessions/**`. Parsing scripts were
  throwaway and are not committed; the schema notes needed to rewrite them are in
  §8 of the findings document.
- Reviewer reports are in `.ai/reviews/` (git-ignored, local only):
  `muse-tokenwaste-2026-09-*`, `grok-codex-mcp-prefix-trim-*`,
  `grok-claude-spend-proposals-*`.
- Grok's two turns cost **$0.20** in total. Muse reports tokens only.

## 9. Open questions and risks

- **Unknown:** what the 29,892-token Codex floor is actually made of. Everything
  proposed for the Codex side is gated on step 2 answering this.
- **Unmeasured:** whether the relocation reduced Claude cache busts. The claim is
  8–13.5%; the honest current status is "plausible, unverified" until step 3.
- **Risk:** the next `bin/setup-machine.ps1` run silently undoes the relocation
  and re-adds `chrome-devtools`. Step 4 is the guard, and until it lands the
  relocation is not durable.
- **Correctness risk, accepted:** the new output-discipline rules trade some
  verbosity for tokens. They were rewritten once already to remove six specific
  ways the first draft would have caused a wrong diagnosis. If a session starts
  mis-diagnosing from truncated output, suspect these rules first.
