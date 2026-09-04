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

### WARNING - THREE QUESTIONS THE OWNER ASKED THAT ARE STILL UNANSWERED

Albert asked these at the close of session 2 and explicitly deferred them to the
next session. **Answer all three, in plain non-technical language, before doing
any other work.** Read section 3b first - it holds the evidence each answer needs.

1. **"Forcing the desktop app through Headroom: the setting existed for the past
   two weeks, so it's ignoring the setting."** He is right, and this kills the
   quit-and-reopen theory recorded in section 3b. The Windows user environment
   variable pointing at the proxy has been set for about two weeks, yet the
   desktop app's own process reports the direct Anthropic endpoint. So the app is
   not inheriting it, or is overriding it. Find out where the desktop app
   actually gets its endpoint, whether it can be pointed at the proxy at all, and
   if it cannot, say so plainly - Headroom is then saving nothing on the surface
   where nearly all the spend now happens.
2. **"Every time I type anything into the chat box do I have to end every message
   with `-p work`?"** No - the explanation of Codex named profiles was unclear and
   he has understandably misread it. Explain in plain terms what a named profile
   is, that the flag is typed once when starting a session rather than on every
   message, and what the day-to-day workflow actually looks like.
3. **"I turn off all MCP servers, then mid-session the AI realises it needs the
   database tool - what happens?"** Answer concretely and honestly: what the
   assistant can and cannot do at that moment, whether the tool can be switched on
   without losing the conversation, and what that costs. Session 2 established
   that turning a tool on mid-session invalidates the prompt cache and re-bills
   the whole conversation - the exact waste this workstream exists to remove - so
   the answer has to weigh that.

Do not answer these from memory or from this file alone. Verify against the live
configuration and the Codex CLI's own help output first.

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

## 3b. Session 2 (2026-09-04, later) - what changed and what was learned

### Shipped and verified in session 2

- **`u2giants/shared-db` PR #2295 is MERGED.** Merge commit
  `081b6543b95d6f9e11f8fd8bc947c1dae68a2b09`, guarded-merge run `33880089268`
  succeeded, remote branch deleted. This closes the last open item from section 3.
  Getting there required a durable create-only verdict artifact
  (`refs/db-review-verdicts/2296-2295-5c0bacbc669a54660d13aca3678a8e81dd274005`,
  sha `ea0484ac2b745bfb4292f7351aeff3b8f986b6d6`) - see section 4b for what
  failed first.
- **Claude *desktop app* MCP list trimmed.** This is a different file from the
  CLI user scope that session 1 edited:
  `%APPDATA%\Claude\claude_desktop_config.json`. Removed `chrome-devtools`,
  `supabase`, `devops-mcp`. Kept `1password`, `ag-grid`, `codex-cli`,
  `playwright` (Albert explicitly asked to keep playwright), `recall-ai`,
  `synology-monitor`, `trigger`. Backed up alongside it as
  `claude_desktop_config.json.bak-<UTC>`.
- **Codex config edited once, with explicit one-time owner permission**, after a
  Grok review returned APPROVE. `chrome-devtools` was added to
  `~/.codex/config.toml` with `enabled = false` rather than deleted, so the
  capability stays recoverable. Verified with `codex mcp list`: chrome-devtools
  `disabled`, the other 12 `enabled`. The backup was written **outside**
  `$CODEX_HOME` at `~/.config/ai-devops/codex-config-backups/config.toml.bak-<UTC>`,
  because a `.bak` file inside `$CODEX_HOME` can be picked up as a profile.

### Key findings from session 2

- **There are three separate Claude MCP surfaces on this machine, not one.**
  `~/.claude.json` (CLI user scope), `%APPDATA%\Claude\claude_desktop_config.json`
  (the desktop app - the surface Albert actually uses), and the committed
  repo-root `.mcp.json` (project scope). Session 1 trimmed only the first, so it
  bought **nothing** on the surface that matters. Any future tool-list work must
  say which of the three it is touching.
- **Codex honours `enabled = false` at server level** - proven empirically, not
  assumed. That is the safe way to park a Codex tool. Two things that do *not*
  work: Codex has **no per-directory MCP scoping** (`[projects.'...']` entries are
  trust settings, not tool scoping), and a partial `-c` override such as
  `mcp_servers."x".enabled=false` **replaces the whole table** and yields
  "invalid transport". `--strict-config` is also rejected by `codex mcp`.
- **Headroom is live but the desktop app bypasses it.** Proxy totals to date:
  2,083 requests, 4,903,080 of 110,889,819 input tokens saved (about 4.4%, about
  $158), `last_activity_at` 2026-09-01. Inside a desktop-app session the effective
  endpoint is `https://api.anthropic.com` while the Windows user variable says
  `http://100.66.37.58:8787`. Session 2 proposed a quit-and-reopen test;
  **Albert has since pointed out the variable has been set for two weeks, so that
  theory is dead** - see question 1 at the top of this file.
- **Recommended against, with reasons:** leanCTX and ponytail (they compress tool
  *output*, which is about 2% of spend - the 13.5% is cache invalidation, which
  they do not touch), and wiring Codex to Headroom now (its OpenAI pipeline has
  carried zero traffic lifetime, sign-in is fussier, and the spend is in the
  desktop app anyway).
- **The NAS tool cannot be project-scoped while every other tool can.** The
  launcher chain is `~/.config/ai-devops/mcp-remote-launch.cmd` then
  `bin/mcp-secret-launch.ps1`, and that script resolves secret references against
  `~/.config/ai-devops/mcp.env`, throwing "Secret reference is not managed by ..."
  when it cannot. That throw is the prime suspect. A background task
  (`task_c2eac5fa`, "Fix NAS tool project scoping", cwd `C:\repos\ai-devops`) was
  queued for it and is **still waiting for Albert to start it**.

### The shared checkout question (asked and answered)

Albert asked whether the uncommitted edits sitting in `C:\repos\ai-devops` -
`bin/ai-muse`, `bin/ai-grok-review` and 15 other files, on a checkout 162 commits
behind `origin/main` - belonged to this session. **They do not.** They belong to
the reviewer-cache-efficiency workstream. This session's only footprint in that
folder is git-ignored review reports under `.ai/reviews/`, which block nothing.
Nothing there was touched, staged, stashed, or committed. Going forward, review
wrappers are to be run from a dedicated worktree, not that shared checkout.

## 4b. What did NOT work in session 2

- **Relaying a reviewer's APPROVE as a PR comment does not satisfy the shared-db
  merge gate.** It refused with "head ... has no durable APPROVE artifact". The
  only sanctioned recorder is `scripts/run-governed-review.mjs`, which spawns the
  reviewer itself and binds the artifact to the comment it posts. Recording before
  posting is structurally impossible - do not try to shortcut it.
- **A stale PR comment of our own blocked the gate.** It carried both the head SHA
  and a bare `VERDICT: APPROVE` line, which the validator read as a second verdict.
  Fixed by rewriting that line to begin "VOIDED RELAYED LINE". The rule: **no line
  anywhere in a review body may begin with a decision word** after stripping
  leading whitespace and markdown punctuation.
- **The reviewer preflight requires a clean worktree at the exact head SHA.** A
  dirty scratch checkout failed it; the fix was to copy the report out and reset.
- **A broad Grok review brief burned 1,592,118 tokens and $0.185 and returned no
  answer**, cancelled at the 20-turn ceiling. Per the grok-cli skill that exact
  session was *not* retried. A fresh, narrowly scoped session answered the same
  question for 31,775 tokens and $0.014 - a 13x cost difference. Narrow the brief;
  never widen the turn limit.

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

Added by session 2, in priority order:

6. **Answer Albert's three questions at the top of this file.** That is the first
   task of the next session, ahead of everything else listed here.
7. Determine where the Claude desktop app takes its API endpoint from, and whether
   it can be routed through Headroom at all. Until that is known, the proxy saves
   nothing on the machine's main surface.
8. Start the queued NAS scoping task (`task_c2eac5fa`), or do the work directly:
   prove why the repo-scoped NAS entry fails, repair it, and remove the duplicate
   global entry. Repair it - do not delete the tool.

No longer outstanding: `u2giants/shared-db` PR #2295 is merged (see section 3b).

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
- **Now known false:** the session-2 theory that the desktop app bypasses Headroom
  because it was launched before the environment variable was set. The variable has
  been in place about two weeks. Treat the bypass as deliberate app behaviour until
  proven otherwise.
- **Open:** the three owner questions at the top of this file.
- **Correctness risk, accepted:** the new output-discipline rules trade some
  verbosity for tokens. They were rewritten once already to remove six specific
  ways the first draft would have caused a wrong diagnosis. If a session starts
  mis-diagnosing from truncated output, suspect these rules first.
