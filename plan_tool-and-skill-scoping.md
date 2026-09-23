# Plan — Tool and skill scoping (load less before a chat starts)

Tracking issue: [#707](https://github.com/popcre/ai-devops/issues/707).
Phase issues: [#703](https://github.com/popcre/ai-devops/issues/703),
[#704](https://github.com/popcre/ai-devops/issues/704),
[#705](https://github.com/popcre/ai-devops/issues/705),
[#706](https://github.com/popcre/ai-devops/issues/706).
Session record: [`HANDOFF.d/2026-09-23T1803Z-edge-dev-claude-tool-skill-scoping-plan.md`](HANDOFF.d/2026-09-23T1803Z-edge-dev-claude-tool-skill-scoping-plan.md).

## STATUS (read this first — do not re-derive or re-plan)

| Step | State | Date | Evidence |
|---|---|---|---|
| 0. Plan written, issues opened, gateway handoff folded in | ✅ done | 2026-09-23 | this file; issues #703–#707 |
| 1.1 Record live-vs-declared MCP drift on every Windows machine | ⬜ open | | |
| 1.2 Make setup prune undeclared Claude Desktop servers; re-run on edge-dev | ⬜ open | | |
| 1.3 Restore `disable-model-invocation` on `designflow-human-qa`; take suspended `kimi-code-delegation` out of the index | ⬜ open | | |
| 1.4 Add a drift check that fails when installed ≠ declared | ⬜ open | | |
| 2.1 Confirm each client's repository-skill location | ⬜ open | | |
| 2.2 Add per-repository skill membership to the installer | ⬜ open | | |
| 2.3 Move the owned skills; measure manifest before/after | ⬜ open | | |
| 3.1 Add per-project MCP membership to the Windows catalog | ⬜ open | | |
| 3.2 Write project `.mcp.json` entries and shrink global membership | ⬜ open | | |
| 3.3 Linux parity (only if a Linux client still carries a single-project server) | ⬜ open | | |
| 4.1 Measure the remaining Claude Desktop tool prefix | ⬜ open | | |
| 4.2 Try Claude Desktop On-demand tool access; measure | ⬜ open | | |
| 4.3 Gateway decision (passthrough only) | ⬜ open | | |

**Start here:** Albert hands sessions only the parent issue #707. Follow the
steps in #707's body: take the first unticked phase, do only that phase, tick it,
comment the next child issue on #707, and stop. Before each phase, re-read every
later phase and fix anything the previous phase made untrue.

---

## Part 1 — Why

### 1. The ultimate goal

Albert (owner, not a programmer) pays for every token that enters a chat, and
everything loaded before the first message — tool definitions, the skill index,
global instructions — is re-sent on **every** turn (measured amplification
36.8× on Claude, 40.0× on Codex; `docs/ai-spend-waste-analysis-2026-09-04.md`).
Each Claude Code session also starts every configured MCP server as its own
processes (measured 2026-08-26 on edge-dev: 416 node processes, 18.1 GB RAM).

**When this is done:** a chat opened in any repository starts with only the
tools and skills that repository can use; the rest are one step away when needed
(installed in the owning repository, or discoverable by search); what machines
actually load equals what the repository declares, and a check fails if it
drifts. **No capability is lost and no safety gate is bypassed.**

**If a step conflicts with this goal, the goal wins — stop and flag it.** In
particular: a saving that makes a model reach for raw shell instead of a
constrained, approval-gated tool is a loss, not a saving.

### 2. What this application is

`popcre/ai-devops` (also reachable as `u2giants/ai-devops`; both are valid on
purpose) is Albert's machine-setup and AI-tooling repository. It is not a running
service. It holds:

- `bin/setup-machine.ps1` — the Windows installer. Step **5d** (around line 399)
  is the MCP server catalog: one definition per server, then explicit
  **per-client membership** lists `$ClaudeCodeMcpNames`,
  `$ClaudeDesktopMcpNames`, `$ZCodeMcpNames` (around lines 541–557), with Codex
  handled separately around line 1011.
- `bin/ai-install-skills` — installs `skills/shared/*` and `skills/<client>/*`
  into `~/.claude/skills` and `~/.codex/skills`. It stamps, backs up, and
  quarantines retired skills (`config/retired-skills.txt`). `--only NAME` (PR
  #669) refreshes named skills only; it is **not** repository scoping.
- `config/skill-trigger-policy.json` — `protected_skills`: safety-ritual skills
  whose automatic triggering enforces a rule. They must stay in every session.
- `tools/context-audit/context-audit.py` + `tests/test-context-audit.ps1` — the
  measuring tool for always-loaded text and skill manifests. It already excludes
  manual-only (`disable-model-invocation: true`) skills and reports them on
  their own line.
- `.mcp.json` at this repository's root — project-local servers for ai-devops
  (`devops-mcp`, `synology-monitor`, `context7`; PR #197 added context7).
- `~/.config/ai-devops/mcp-remote-launch.cmd` + `bin/mcp-secret-launch.ps1` —
  launch remote servers with secrets injected from 1Password references, never
  written into config files.

Clients on each Windows machine: Claude Code CLI (`~/.claude.json`), Claude
Desktop including its Code tab (`%APPDATA%\Claude\claude_desktop_config.json`
**and** the MSIX copy under
`%LOCALAPPDATA%\Packages\Claude_*\LocalCache\Roaming\Claude\`), Codex
(`~/.codex/config.toml`), ZCode. Machines are listed in
`templates/system/machine-atlas.md`; edge-dev is Albert's main Windows machine.

### 3. What triggered this work

On 2026-09-23 Albert asked where the strategy "reduce the number of tools and
skills loading, absolutely and per repository, without losing usefulness" lives.
Investigation found it was **partly built, partly never landed, and partly
drifted**:

- Built: per-client MCP membership (PR #282), codex-cli suspended (PR #573),
  14 rare skills made manual-only (PR #127), NAS/DevOps servers exposing only
  search-then-invoke tools.
- Never landed: per-project MCP scoping (PR #114, closed unmerged 2026-09-17 as
  superseded and 343 commits behind). Per-repository skill installation was never
  built.
- Drifted: see section 5.

### 4. Scope

**In:** MCP server membership per client and per project; skill installation per
repository; drift detection between declared and installed state; measuring the
remaining prefix; the On-demand/gateway decision.

**NOT in this plan:**
- claude.ai account connectors (Vercel, Outlook/SharePoint, Docs). They live in
  the app's connector store, not in files; measure them in 4.1 but change them
  only through Albert in Settings → Connectors, as a separate decision.
- Global instruction text size (`templates/system/*-global*.md`) — owned by
  `plan_context-engineering-consolidation.md`.
- Tool-output compression (Headroom) — `docs/headroom.md`.
- Recall.ai 403 (issue #68) and its handoff.
- Removing any constrained server (`1password`, `supabase`, `devops-mcp`,
  `synology-monitor`) to save tokens — forbidden, see section 8.

---

## Part 2 — What we already know

### 5. Current state (verified 2026-09-23 on edge-dev, `origin/main` 8eb77fe9)

- Declared Claude Desktop set: `1password, ag-grid, playwright, recall-ai,
  synology-monitor, trigger` (6). Declared Claude Code user set: `1password`.
- **Installed Claude Desktop set on edge-dev (both config copies): 10 servers** —
  the 6 plus `codex-cli` (suspended by #573), `supabase`, `chrome-devtools`,
  `devops-mcp`. So setup either was not re-run or does not remove servers
  outside its declared set. Establishing which is step 1.1.
- `~/.claude.json` global `mcpServers`: `1password` only (matches).
- Skills: 48 installed in `~/.claude/skills`. `designflow-human-qa` lost its
  `disable-model-invocation: true` line in PR #479 (commit 1026bd4d) although
  PR #127 had deliberately made it manual-only. `kimi-code-delegation` is
  SUSPENDED (its own banner) but still auto-invocable. Three skills also appear
  twice in sessions via the `anthropic-skills:` plugin (`grok-cli`,
  `kimi-code-delegation`, `synology-sharesync-triage`) — measure in 4.1; the
  plugin copies are outside this repo.
- Nothing for this plan is committed yet except this file.

### 6. Key findings

1. **Per-client membership works; per-project does not exist.** PR #114's
   design (`$McpProjectScope`, step 7b writing `.mcp.json`) is the right idea but
   was built on the pre-catalog installer. Reuse its reasoning, not its code.
2. **There is no per-session scope.** The finest grain Claude Code offers is per
   project, and servers are read only at session start.
3. **Albert's ownership decision (2026-08-26, recorded in PR #114):**
   `trigger`, `recall-ai` → `oracle`; `railway` → `popdam3`; `ag-grid` →
   `dflow_plm/designflow-frontend`; `devops-mcp`, `synology-monitor` →
   `synology-monitor` repo, **but kept global on machines where that repository
   is not cloned** (edge-dev), because the NAS tools are needed from anywhere.
4. **Search-then-invoke already works** (`devops-mcp`, `synology-monitor`): a
   small fixed tool list, the rest hidden behind `tool_search`/`invoke_tool`.
5. **Mid-session tool-list changes are the expensive failure**: 2,766 cache
   busts, ~81k tokens each, 13.5% of Claude spend. Anything that changes a live
   session's tool list is worse than the problem.
6. **Codex's floor is not MCP**: a fresh Codex turn measured 31,412 tokens with
   no MCP tools present; ignoring user config cut 3,942 tokens (PR #282 census).
7. Manual-only skills still appear in the slash menu and run fully by name, so
   they are the safe first tool for rarely-used skills (PR #127).

### 7. Rejected approaches (do not re-propose)

- **`enable_tool` / injection gateways** — they cause exactly finding 5.
- **Removing Codex MCP servers on zero call counts** — changed nothing (finding 6).
- **leanCTX, ponytail** — compress output (~2% of spend), not the prefix.
- **Reviving PR #114 as-is** — duplicate ownership maps, conflicts, superseded.
- **Removing a constrained server to save tokens** — pushes the work to
  unrestricted shell; a security regression.
- **Making protected skills manual-only or repo-only** — their automatic
  trigger is the enforcement (`config/skill-trigger-policy.json`).
- **Treating `--only` (PR #669) as repo scoping** — it is a refresh filter.

### 8. Decisions

Locked (do not relitigate):
- Passthrough (`invoke_tool`) only, never injection. Never front `1password`.
- Albert's 2026-08-26 MCP ownership map (finding 3).
- One catalog of definitions; membership is data beside it. No second copy.
- Protected skills stay global and auto-invocable.
- Measure before and after every change with the same method.
- One phase = one session = one issue; each phase ends with live proof or one
  leftover-proof issue for that phase.

Open (implementer's judgment, with criteria):
- Owner repository of each scraper and DesignFlow skill: read the skill's own
  text; if a skill is used from a folder that is not a Git repository (e.g. the
  `dflow_plm` parent of the six DesignFlow repos), it stays global.
- Membership of `supabase`, `chrome-devtools`, `playwright`: global only if
  sessions in three or more repositories used it in the last 30 days of
  transcripts (`u2giants/ai-devops-transcripts`); otherwise project-scoped.
- Whether `codex-cli` is removed from installed configs or kept declared-off:
  it is suspended, so it is removed from membership; the definition stays.

---

## Part 3 — How to build it

### 9. Steps

**Phase 1 — drift repair (#703).**

1.1 Run on each reachable Windows machine a read-only listing of server names
in both Claude Desktop config copies, `~/.claude.json`, and
`~/.codex/config.toml`; compare with the membership lists in step 5d. Record
the table in #703. Determine whether the Desktop writer in `setup-machine.ps1`
removes names outside the declared set (search for the function that writes
`claude_desktop_config.json`). *Done when* #703 has a per-machine table and the
cause is named with a line reference.

1.2 If the writer does not prune, make it remove every **managed** catalog name
(`$ManagedMcpServerNames`) not in the client's membership, leaving servers the
catalog does not know about untouched and reported. Back up the file first (the
installer already has backup helpers). Re-run setup on edge-dev. *Done when*
both Desktop config copies list exactly the declared set, plus any unmanaged
names printed as warnings.

1.3 Restore `disable-model-invocation: true` in
`skills/shared/designflow-human-qa/SKILL.md` and add it to
`skills/shared/kimi-code-delegation/SKILL.md` while suspended. Reinstall with
`ai-install-skills --only designflow-human-qa --only kimi-code-delegation`.
*Done when* neither appears in a new session's automatic skill list and both
still run via `/name`.

1.4 Add a drift check to the context audit (or a sibling test) that fails when
an installed client set differs from declared membership, and when a skill that
was manual-only loses the flag without a matching change to the skill list in
`docs/context-engineering.md`. *Done when* the new test fails against a
deliberately drifted fixture and passes on the repaired machine.

**Phase 2 — repository-scoped skills (#704).**

2.1 Confirm from current official docs (context7 or the vendor docs) where each
client reads repository skills: Claude Code `<repo>/.claude/skills/`; Codex
repository skills location (verify — do not assume); ZCode. *Done when* each
location is proven by creating a throwaway skill in a scratch repo and seeing it
listed in a fresh session there and absent elsewhere.

2.2 Add a membership file (e.g. `config/skill-scope.json`: skill → list of
repository identities from `config/repo-identities.tsv`, absent = global).
Teach `bin/ai-install-skills` to install scoped skills into each cloned owning
repository's client skill folder, keep that folder out of Git with the repo's
`.git/info/exclude` (never edit another repo's tracked files), and quarantine the
global copy. Reject any protected skill in the file. *Done when* `--dry-run`
prints the planned moves and the tests below pass.

2.3 Fill the membership file for the non-protected, repository-bound skills
(scrapers, DesignFlow QA/ship/session-start, `disney/nbcu/wb` scrapes) using the
criteria in section 8. Measure the manifest with `context-audit.py` before and
after. *Done when* the global manifest shrinks, each moved skill triggers in its
repository, and the numbers are recorded in `docs/context-engineering.md`.

**Phase 3 — project-scoped MCP (#705).**

3.1 Beside the catalog in step 5d add per-project membership (project →
server names, projects by repository identity, resolved to every clone and
worktree root on the machine). Global Claude Code/Desktop membership becomes
"servers every repository needs" plus finding 3's exception.

3.2 Write project servers into each owning repository's `.mcp.json` only if that
file is untracked or already owned by ai-devops; otherwise use the Claude Code
project entry in `~/.claude.json` (`projects[<path>].mcpServers`). Remove moved
names from global sets (the Phase 1 pruning does this). *Done when* a session
opened in `oracle` has `trigger` and one opened in ai-devops does not, and the
node process count with the same open sessions is lower than before (record
both counts).

3.3 Linux (`bin/setup-machine.sh` / install scripts): only if a Linux client
still configures a single-project server globally.

**Phase 4 — measure and decide (#706).**

4.1 Measure a no-op first turn's billed input tokens in the Claude Desktop Code
tab and Claude Code CLI, in ai-devops and in one app repository, from
`~/.claude/projects/**/*.jsonl` usage records; list the tool names carried.
4.2 Turn on Claude Desktop's On-demand tool-access mode and repeat.
4.3 Only if 4.1–4.2 leave a material remainder (criterion: ≥5,000 tokens of
MCP definitions per session) and a gateway can front the Desktop surface, pilot
one passthrough gateway in front of two or three low-risk servers, declared in
the catalog. Otherwise close #706 with the numbers.

Parallelism: Phases 1 → 3 are sequential (3 depends on 1's pruning). Phase 2
can run after Phase 1 in parallel with Phase 3 (different files: skills
installer vs. setup-machine). Phase 4 runs last.

### 10. Tests

- Extend `tests/test-context-audit.ps1`: manual-only flag regression; installed
  vs. declared MCP drift (fixture configs).
- New `tests/test-ai-install-skills.sh` cases: scoped skill lands only in the
  owning repo; protected skill in the scope file is rejected; global copy is
  quarantined, not deleted; `--dry-run` writes nothing.
- A setup-machine test (follow the existing Pester/PowerShell suite pattern for
  step 5d) proving pruning removes only managed names.
- Must stay green: the repository's full verify workflow (`verify.yml`) and
  `tests/test-context-audit.ps1`.

### 11. Constraints and gotchas

- Feature branch + PR; never push to `main`. The session that opens a PR merges
  it (`gh pr merge --squash`); prose-only PRs may merge with `--admin`.
- Run `ai-task-gates start --class <class>` at the start and
  `ai-task-gates check --before pr-wait|ship` before stronger actions.
- Back up any config file before editing it; never duplicate keys.
- Claude setup must never change Codex configuration and vice versa.
- Secrets only as `op://` references through the launchers; never values.
- A running session never picks up new servers; test in fresh sessions.
- Archiving a Claude Desktop session is the only real close; renamed sessions
  keep their MCP processes alive (affects process-count measurements).
- Windows reviewer shims run from `C:\repos\ai-devops`; a merged fix is not live
  on Windows until that checkout pulls.
- CRLF: scripts must stay LF (`git ls-files --eol`).

### 12. Access and environment

- `gh` authenticated as `u2giants`; repository `popcre/ai-devops`.
- 1Password vault `vibe_coding`; MCP tokens under the item referenced in
  `.mcp.json` (`op://vibe_coding/f335s4oy3m6n74jmwj74hunrtu/...`).
- Windows machines over SSH/Tailscale per `templates/system/machine-atlas.md`.
- Transcript archive: `u2giants/ai-devops-transcripts` (private).

---

## Part 4 — Landing it

### 13. Definition of done, risks, open questions

Done when, for every phase: code and tests merged via PR with CI green; setup
re-run on edge-dev and one other Windows machine; before/after numbers recorded
in `docs/context-engineering.md`; this STATUS table updated with artifacts; the
phase issue closed by the session that opened or took it; #707 closed after #706.

Risks: a moved skill stops triggering where needed (mitigation: global copy
quarantined, restore = delete the scope entry and reinstall); pruning removes a
server Albert added by hand (mitigation: only managed names are pruned, others
warned); a project-scoped server is missing in a worktree (mitigation: resolve
every clone and worktree root, test from a worktree).

Open: Codex's repository-skill location (2.1); whether any gateway can front
Claude Desktop (4.3); plugin-duplicated skills (4.1).

### Self-audit (2026-09-23)

1. A fresh session can execute it without asking: yes — goal (1), app and file
   locations (2, 5), per-step files and gates (9), tests (10), access (12).
2. All background carried, including what was ruled out: yes — findings (6),
   rejected list (7), locked vs. open decisions (8), folded gateway handoff.
3. The goal lets the implementer judge a wrong step: yes — section 1's "goal
   wins" rule and the shell-fallback caveat.
