---
issue: 711
status: OPEN
owner: claude/plan-agent-self-cleanup
---

# Handoff — stop review full-history waste + agent self-cleanup

Plan: [`plan_agent-self-cleanup.md`](../plan_agent-self-cleanup.md)  
Issue that proves this done: [#711](https://github.com/popcre/ai-devops/issues/711)

---

## 0. Decisions only the owner can make

**Put this WHOLE list to Albert in ONE message before starting work.**

### Blocking
- None for Phase 1 (shrink the copy). Start there.

### Wrong guess is recoverable
1. **A wrapper that cannot work without real Git history** — if found, choose `--depth 1` for that wrapper only vs leaving it full. **Recommendation: `--depth 1`.** Blocks Phase 1 completion only for that wrapper.
2. **Snapshot format** — `git archive` (no `.git`) vs `--depth 1` clone. **Recommendation: `git archive` + `patch.diff`.** Decide in Phase 1 with size/time measurements.

### Outside this workstream — nobody else is on it
3. **Six dirty Codex work folders** still hold uncommitted work (`C:\Users\ahazan\.codex\worktrees\`). Separate session; prompt is `prompt_six-dirty-codex-worktrees.md`. **Recommendation: run that session before deleting anything there.** Blocks disk tidy-up only, not this plan.
4. **Last locked folder** `C:\Users\ahazan\.local\share\ai-devops` (and Codex sqlite history files) could not move to D: while tools were running. **Recommendation: close Codex/opencode, then run `C:\Users\ahazan\.local\bin\ai-housekeeping\move-bulk-to-d.ps1`.** Blocks only the leftover move, not this plan.

### Already settled — do NOT re-ask (2026-09-23)
- Reviews must not copy full Git history.
- The creating run must delete its copy; daily sweep is backup only.
- Live code and tool programs stay on the SSD (C:); growth/bulk stays on D: via junctions.
- Daily task `AI-Debris-Housekeeping` stays until 14 days green.
- Do not touch the six dirty work folders in this workstream.
- Albert does not merge PRs — the working agent merges.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's AI development-operations toolkit on his Windows workstation `EDGE-DEV`. It dispatches AI reviewers (Claude, Codex, Gemini, Grok, Qwen, GLM, DeepSeek, Muse) against GitHub repos (`popcre/ai-devops`, `u2giants/shared-db`, `u2giants/licensor-source-data`, `popcre/poppim-web`, `popcre/popdam3`). Wrappers live in `bin/`; policies in `config/`; tests in `tests/`. Albert is a business owner, not a programmer.

Review sandboxes are created under
`C:\Users\ahazan\.local\state\ai-devops\review-sandboxes\`
(now a junction to `D:\ai-data\local\state\ai-devops\review-sandboxes`).

## 2. What we set out to do this session, and why

**Business goal:** stop AI tooling from filling the system disk.

**Trigger (2026-09-23):** Albert reported `.local` and `.codex` were taking the entire C drive (5 GB free). Cleanup recovered ~229 GB. He then ruled: the agent that makes the mess cleans it up; daily sweep is backup only; reviews must not need full history; write an implementation plan.

**This session did:** machine cleanup, D: junctions for growth paths, daily sweeper task, `plan_agent-self-cleanup.md`, and two work prompts. **It did not implement the plan code.**

## 3. Current state — what is true right now

| Item | State |
|------|--------|
| C: free space | Was 5 GB → **~267 GB free** after cleanup |
| Review sandboxes >24h | Deleted (~3,700 dirs) |
| Clean/empty Codex worktree groups | 154 removed |
| Six dirty Codex work folders | **Still present** (see §0.3) |
| Growth paths on D: | Junctions live for review-sandboxes, worktrees, archived_sessions, sessions, grok |
| Still on C: (locked) | `share/ai-devops`, Codex `thread_history_1.sqlite` / `logs_2.sqlite` |
| Daily task | `AI-Debris-Housekeeping` @ 03:30 installed and registered |
| Plan file | `plan_agent-self-cleanup.md` in this repo (this PR) |
| Prompts | `prompt_fix-review-full-history.md`, `prompt_six-dirty-codex-worktrees.md` |
| Implementation code | **Not started** |
| Issue | [#711](https://github.com/popcre/ai-devops/issues/711) OPEN |

Half-done: none in code. Machine move is partial only where noted above.

## 4. Everything we tried that did NOT work

1. **Recursive `Get-ChildItem` size scans** — timed out on 192 GB of tiny Git files. Workaround: `robocopy /L` for sizing, `robocopy /MIR` from an empty dir for deletes.
2. **Sequential `Remove-Item -Recurse`** — too slow (~10 min per 200 clones). Workaround: 4–8 parallel jobs + robocopy wipe.
3. **`Move-Item` cross-volume of 23 GB of git objects** — timed out mid-copy. Workaround: rename-aside + `mklink /J` to D:, then wipe disposable aside instead of moving it (they were documented disposable snapshots).
4. **Assuming reviews need history** — rejected after measurement; owner ruled against it. Full history was most of the 192 GB.

## 5. Root causes and key findings

1. **Full-clone sandboxes:** each review copied `.git` history. ~50 MB × 3,950 = ~192 GB. `AI-REVIEW-SANDBOX.md` already documents copies as disposable.
2. **Cleanup specified in prose, not code:** "deleted when the review session ends" with no trap/finally and no sweeper until 2026-09-23. Recurring: a 2026-09-11 log shows 14,664 items removed then.
3. **Second growth site:** `C:\Users\ahazan\.codex\worktrees\` (34 GB / 160 groups).
4. **Windows delete/move cost:** millions of tiny Git objects make cleanup itself slow — smaller snapshots fix disk *and* cleanup time.
5. **Junctions work** without rewriting `CODEX_HOME` or wrapper paths.
6. **SSD vs HDD:** C: is NVMe SSD (keep live code + tool programs). D: is 1 TB HDD (bulk/growth). Do not put day-to-day checkouts on D:.

## 6. Exact next steps

1. Paste `prompt_fix-review-full-history.md` into a **new** session (or continue here if asked). Work only Phase 1 of `plan_agent-self-cleanup.md` unless Albert says continue.
   - **You'll know it worked when** PR merged and dry-run shows `test ! -e "$SNAP/.git"` plus `du -sh "$SNAP"` well under 100 MB.
2. Then Phases 2–3 (self-delete trap + orphan sweep) per the plan.
   - **You'll know it worked when** `tests/test-ai-review-sandbox-self-cleanup.sh` passes and a failed run leaves no sandbox dir.
3. Phase 5 live proof: one real review leaves zero leftovers.
   - **You'll know it worked when** `ls D:\ai-data\local\state\ai-devops\review-sandboxes` has no dir from that run and the reviewer still returned a verdict.
4. Separately: paste `prompt_six-dirty-codex-worktrees.md` into a Codex session to ship or discard the six dirty folders.
5. Separately: when tools are closed, run `move-bulk-to-d.ps1` for the last locked paths.

## 7. Constraints and gotchas in force

- Never edit canonical checkouts under `C:\repos\...` for write work — new worktree from current upstream first.
- Never push protected `main` directly. Branch → PR → working agent merges (not Albert), except DesignFlow (`develop`, never self-merge) or if Albert said he wants to review.
- Docs-only PRs (all prose) merge immediately with `gh pr merge --squash --admin`.
- Signature on every GitHub body: `Posted by <Claude|Codex> chat <id> on <machine>`.
- Secrets only in 1Password vault `vibe_coding` — never values in chat/logs/commits.
- Never delete dirty working copies without proof (`cleanup-worktree` skill).
- Never `git clean` / `reset --hard` over unreviewed work. Never touch another session's `HANDOFF.d/` file. Never rewrite root `HANDOFF.md`.
- Shared-db structure only via `u2giants/shared-db` branch+PR. This workstream should not need that.
- Junctions: those C: paths are links to `D:\ai-data\...`. Do not "fix" by deleting the link without moving data first.

## 8. Access and environment

- Machine `EDGE-DEV`, Windows, user `ahazan`. Git ident: `Albert Hazan <u2giants@users.noreply.github.com>`.
- GitHub `gh` authenticated. Orgs: `u2giants` (personal), `popcre` (DesignFlow + ai-devops).
- Secrets: 1Password vault `vibe_coding` (titles only).
- Local repos: `C:\repos\{ai-devops,shared-db,licensor-source-data,poppim-web,popdam3}`.
- Daily task `AI-Debris-Housekeeping`; log `D:\ai-data\logs\housekeeping.log`.
- Housekeeping scripts: `C:\Users\ahazan\.local\bin\ai-housekeeping\`.
- Workspace copies of these files also live under
  `C:\Users\ahazan\XiaomiMiMoProjects\2026-09-23\on-this-computer-there-s-something\`.

## 9. Open questions and risks

1. Snapshot format final pick (open — §0.2), dated 2026-09-23.
2. Whether Muse/DeepSeek private-review paths need a different untracked allowlist (inspect in Phase 1).
3. After 14 days green, retire daily task or keep? **Recommendation: keep** (2026-09-23).
4. Risk: a wrapper secretly needs `.git` → grep `bin/` for `git log|rev-list|cat-file` and explain hits.
5. Risk: `trap` misses `kill -9` → parent sweep + daily net.
6. Risk: another session still using a dirty work folder → never batch-delete those six.

---

### Self-audit

1. Street-newcomer can continue without questions? **Yes** — §0 decisions, §5 root causes, §6 steps with gates, §7 rules, §8 access.
2. As effective as this session right now? **Yes** — includes failed approaches (§4), junction layout (§5), locked vs open decisions (§0).
3. Every owner decision in §1–§9 also in §0? **Yes** — wrapper-history choice, snapshot format, six folders, last locked move, daily-task retirement recommendation. Settled items listed so they are not re-asked.
