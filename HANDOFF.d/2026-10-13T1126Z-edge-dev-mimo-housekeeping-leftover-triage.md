---
issue: 1661
status: OPEN
owner: mimo/1585-housekeeping-closeout-handoff
---
# Housekeeping leftover triage after parent #1585

Retargeted to #1661 (housekeeping leftover triage tracking issue). Parent
#1585 is closed; this file carries the leftover inventory and the triage
decisions that #1661 tracks.

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

1. **Which leftover group should the next session triage first?**
   The first `ai-housekeeping` supervised run found items the plan forbids
   deleting without a human ruling. Recommendation: start with the **9
   unattributed handoffs** (authors can add a contract block; no deletion
   needed). Blocks nothing today; it is housekeeping backlog quality.
2. ~~Do the 15 `issue: none` handoffs keep living, or should their work get
   real GitHub issues?~~ DECIDED and executed in batch 2 (2026-10-13, under
   this issue #1661): open one issue per still-relevant workstream and retire
   the rest under the successor rule (with AI reviewer APPROVE before any
   delete). Wrong guess is recoverable (git history keeps the text).
3. **Are the 16 retained-record plans intentional forever?** Recommendation:
   yes — leave them; the plan explicitly rejects sweeping all-done plans
   (Finding 9 / R4).

Already settled — do NOT re-ask:
- 2026-08-13: no file-count cap on `HANDOFF.d/`; count SUCCESSOR REVIEW, not files.
- 2026-08-13 / plan R4: do not sweep root `plan_*.md` whose STATUS is all done.
- 2026-10-12: parent #1585 stages 1–4 are complete and landed; do not redo them.

Put ALL of the above to the owner in ONE message before starting triage work.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI
workflow (Claude, Codex, MiMo, ZCode, and reviewers). It is not an app or
service. Housekeeping tooling lives at
https://github.com/popcre/ai-devops/blob/main/bin/ai-housekeeping
and explains itself in
https://github.com/popcre/ai-devops/blob/main/docs/housekeeping.md

## 2. What we set out to do this session, and why

**Goal (parent issue #1585, now closed):** Albert must be able to run one
command and get a one-screen summary of likely housekeeping work, without
asking an AI session to do the initial inventory.

**This closeout's remaining job:** record the leftover inventory that step 8
of the plan requires a human to decide on, and leave a cold-start prompt.

Source of truth for the original workstream:
https://github.com/popcre/ai-devops/blob/main/plan_repo-housekeeping-visibility.md

## 3. Current state — what is true right now

Verified on `origin/main`:

| Stage | Issue | Merge |
|---|---|---|
| 1 doc/rule corrections (+ wrap-up `--merged` fix) | #1586, #1590 | https://github.com/popcre/ai-devops/commit/84a7f0a7 |
| 2 handoff contract block mandatory | #1587 | https://github.com/popcre/ai-devops/commit/521c9487 |
| 3 `bin/ai-housekeeping`, tests, registration | #1588 | https://github.com/popcre/ai-devops/commit/8269b6ad |
| 4 daily schedule + first supervised run | #1589 | https://github.com/popcre/ai-devops/commit/e844f95e |

Parent #1585 is closed. Plan STATUS rows 1–8 are `✅ done` with evidence in
https://github.com/popcre/ai-devops/blob/main/plan_repo-housekeeping-visibility.md

First supervised run cleanup (already applied):
- 6→1 MERGED CANDIDATE worktrees (landing checkout kept)
- 8→0 MERGED CANDIDATE branches (exact merged-PR `headRefOid` only)

**Left untouched (by design — do not delete without a ruling):**
- ~~9 UNATTRIBUTED handoffs (no contract block)~~ — batch 1 landed as PR #1664 (0 UNATTRIBUTED)
- ~~15 UNPROVABLE handoffs (`issue: none`)~~ — batch 2 universe is 18 UNPROVABLE (count grew); this change retargets 8 and plans to retire 10
- 16 retained-record plans (`all-steps-done` STATUS — review by hand)
- 25 UNKNOWN branches
- 26 UNKNOWN worktrees (review sandboxes, live sessions)

Not started: grouping those leftovers into owner-choosable triage batches.

## 4. Everything we tried that did NOT work

- **Fine-grained PAT cannot merge.** `enablePullRequestAutoMerge` and REST
  `PUT .../merge` both 403 for `github_pat_*` even with repo push. Merge
  queue needs classic OAuth (`gho_`, `repo` scope).
- **OAuth keyring token flaps 401.** Same `gh auth token` works then fails
  within minutes. `gh auth status` can look green while `gh api user` 401s.
  Device login restored it. Do not trust `gh auth status` alone.
- **GitHub App `pop-ai-watchers` cannot push or merge.** Push →
  `Permission denied to pop-ai-watchers[bot]`; merge →
  `Resource not accessible by integration`.
- **`git push` hangs under some credential setups** even when `git ls-remote`
  works. A background `nohup git push` eventually landed. Prefer
  `timeout N git push` and a `GIT_ASKPASS` helper that reads a 0600 token file.
- **Windows `bash` on PATH is WSL** (`bash` → `bash.exe` in WindowsApps). Use
  `C:\Program Files\Git\bin\bash.exe` explicitly.
- **New `bin/` tools fail CI without** `100755` mode + a `bin/<name>.cmd`
  launcher + a `config/ci-suites/<test>.json` manifest row + only `bin/ai-gh`
  for GitHub (no bare `gh` strings — the transport guard is literal).
- **Self-hosted Windows runners flap** (`lost communication with the server`).
  `gh run rerun <id> --failed` is the right fix; do not rewrite the change.

## 5. Root causes and key findings

- Plan Finding 4 is still true: never `git branch --merged` as merge proof.
  Stage 1 removed that from wrap-up.
- `AI_GH_MIN_SPACING_SECONDS=0` is appropriate for a supervised one-shot
  housekeeping run; the throttle otherwise produces false UNKNOWN under lock
  contention.
- PR #1626 tracks `.ai/reviewer-issues/` while reviewer-issue docs say those
  files may contain private data. Boundary checks were tightened on the stage-4
  branch (secret-bearing names/types still fail under the publish path). This
  policy tension is unresolved as a product question.

## 6. Exact next steps

1. Open ONE message with §0 questions; wait for Albert's pick (recommendation:
   unattributed handoffs first).
2. If unattributed: for each of the 9 files under `HANDOFF.d/`, open the file
   on GitHub, add `issue:` / `status:` / `owner:` if the author is known, or
   open a new issue and point `issue:` at it. Verification: `bash
   bin/ai-housekeeping --details` reports 0 UNATTRIBUTED.
3. If `issue: none`: (batch 2 done — retargeted or planned for retirement) open one issue per still-alive workstream, retarget the
   handoff, then apply the successor rule's three conditions before any
   deletion. Verification: UNPROVABLE count drops only when files are retired
   with those three proofs.
4. Re-run `bash bin/ai-housekeeping` and paste the new one-screen summary into
   the issue you open (or into this file's successor). Do not delete UNKNOWN or
   retained-record rows.

You'll know it worked when the next `ai-housekeeping` summary shows the chosen
group at zero and the before/after counts are recorded on a real issue.

## 7. Constraints and gotchas in force

- Report-only tool: `bin/ai-housekeeping` never deletes. Cleanup goes through
  `skills/shared/cleanup-worktree/SKILL.md` / successor rule.
- No `git branch --merged` (Finding 4 / D3).
- Do not edit another session's `HANDOFF.d/` file. Do not rewrite root
  `HANDOFF.md` (static pointer).
- Branch policy: feature branch + PR + merge queue; never push `main` directly;
  never `--admin`.
- Stage only owned files. Identity must be
  `Albert Hazan <u2giants@users.noreply.github.com>` before commit.
- `.ps1` files must be pure ASCII (`tests/test-windows-scripts.sh`).

## 8. Access and environment

- Repo: `https://github.com/popcre/ai-devops` on `origin/main`.
- Machine writing this: `edge-dev`, Windows 11, Git Bash at
  `C:\Program Files\Git\bin\bash.exe`.
- GitHub CLI: OAuth `u2giants` (classic `repo` scope) is required for merge
  queue. Fine-grained `github_pat_*` is read/push only. App tokens cannot
  merge. Secrets live in 1Password vault `vibe_coding` only — never by value
  here.
- Daily schedule: Windows Scheduled Task `AiDevOps-Housekeeping`; log at
  `$HOME/.cache/ai-housekeeping.log` (30 dated blocks retained).

## 9. Open questions and risks

- 2026-10-13: `#1626` publish of `.ai/reviewer-issues/` vs private-data
  documentation — product boundary still tense after content-level checks.
- 2026-10-13: Windows offline lane has shown both pre-existing suite failures
  and runner-comms flaps; do not treat a red Windows section as automatically
  caused by the change under test without reading annotations.
- 2026-10-13: OAuth keyring credentials on edge-dev have been flaky; a future
  session may need another device login (`gh auth login -w`) before merge.

## Part (b) — sub-agent blocks this session

### general-1 — stage 1 (#1586 + #1590)
Asked: plan steps 1–2 and wrap-up `--merged` defect. Did: SUCCESSOR REVIEW
terminology, HANDOFF.d pointer lesson, removed `git branch --merged` from
wrap-up. PR #1605 merged `84a7f0a7`. Deliberately did not edit `session-docs-update` /
`codex-docs-update` residual "STALE files" wording (out of ownership).

### general-2 — stage 2 (#1587)
Asked: mandatory contract block. Did: AGENTS.md + handoff-writer + handoff-standard.
PR #1606 merged `521c9487`. Noted `ai-gh` lock hangs and `ai-pr-wait` false
reviewer-safety escalation (used direct `gh` polling once — process deviation).

### general-3 — stage 3 (#1588)
Asked: `bin/ai-housekeeping`, tests, registration. Did: tool A–H, 12 cases,
`config/machine-tools.tsv`, `docs/housekeeping.md`, CI suite JSON, transport
guard compliance (no bare `gh`). PR #1608 merged `8269b6ad` after coordinator
CI fixes (`.cmd` launcher, `100755`, manifest). Stopped at auth 401 before
merge.

### general-4 — stage 4 start
Interrupted by app restart mid-edits in the stage-4 worktree. Work reused.

### general-5 — stage 4 finish (#1589)
Asked: schedule + first supervised run. Did: `AiDevOps-Housekeeping`, 30-block
log, wrap-up visibility line, first run cleanup (5 worktrees / 8 branches),
STATUS 7–8 evidence. PR #1630 merged `e844f95e` after conflict resolution with
origin/main (public-boundary). Left UNKNOWN/retained items untouched on purpose.

---

## Self-audit (mandatory)

1. **Comprehensive for a brand-new developer?** Yes — §1–§9 cover product,
   goal, live SHAs, dead ends, next steps with gates, constraints, access.
2. **As effective as this session?** Yes — leftover counts, merge-credential
   trap, CI false-red patterns, and per-agent outcomes are written down.
3. **Every relevant detail?** Yes — background, outcome, failures, decisions,
   constraints, risks, exact next actions, verification gates, GitHub URLs.
4. **Section 0 has every owner decision and no technical approval?** Yes —
   three business triage choices only; tech repairs are documented as
   constraints/next steps, not asks.
