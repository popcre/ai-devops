---
handoff: v1
status: open
owner: mimo/1183-process-children
created: 2026-09-30T20:42:00Z
machine: edge-dev
agent: mimo
session: ses_ffe5f0cc4f5beffeMOXfjc54KO
issue: 1183
---

# Handoff — #1183 process children (child 1 landed; next child 2 + live proof)

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

None open on this workstream. Albert already approved the Muse-agreed five-change
order (less process, cut rules, daily merge tax first). Do not re-ask him to pick
technical work. If a later child needs a spend or capacity purchase (new runner,
second host), that is an owner decision — name it, do not decide it.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery toolkit for a multi-model AI
workflow (reviewers, CI, GitHub traffic tools). It is not a product app.
Installation is the deployment mechanism.

## 2. What we set out to do this session, and why

Execute **child 1 only** of parent issue #1183 (Muse-agreed plan §2b in
`docs/process-bottlenecks-and-improvements-2026-09-29.md`):

> Label capacity as capacity. Two labels only (capacity/infra vs result).
> Timeout/kill/rate-limit = capacity. Empty reviewer verdict fails the review
> step and reroutes — never reddens the PR test verdict. Owner: #650
> (workflow-efficiency P7).

Handoff this session inherited:
`HANDOFF.d/2026-09-30T1525Z-edge-dev-mimo-jev-process-plan-muse.md`.

## 3. Current state — what is true right now

**Shipped and on `origin/main`:**

- PR **#1189**, squash-merge commit **`6edee717`** (2026-09-30 3:49 PM EST).
  Title: "Label capacity as capacity; empty verdict fails the review step (#1183 c1)".
- New `tools/ci/action-taxonomy.sh` (mode 100755):
  - `check` → `capacity/infra` | `result` | `review-step` (empty-verdict carve-out)
  - `review` → `review-step` | `capacity/infra` | `result`
  - `detail` → report-only category (timeout-capacity, killed-interrupt,
    rate-limit-capacity, empty-verdict, test-failure, config-drift)
  - Capacity phrases match **summary only**, never the check name, so
    `quota-check` / `skills-lint` / `job-429` stay `result`.
- New `tools/ci/report-scheduled-failure.sh` (mode 100755) used by
  `verify.yml` `report-scheduled-failure`. Labels incidents `capacity/infra`
  or `result`. Mixed capacity+result runs label **result** so a real failure
  is never parked.
- `bin/ai-pr-wait` prints per-check `action=` / `detail=` and the matching
  guidance. Empty-verdict is `review-step` and never `result`.
- GitHub labels created: `capacity/infra`, `result`.
- `tests/test-action-taxonomy.sh` (26 checks) + suite manifest row
  `config/ci-suites/test-action-taxonomy.sh.json`. Tests **execute** the
  classifier; they do not grep for its strings.
- Side fix that unblocked every PR: `bin/ai-public-boundary-check` https arm
  only treats URL **authority** as an endpoint. PR #1190 had put a launchpad
  `.deb` URL whose version `0.26.04.1` matched the old pattern and reddened
  `test-public-boundary.sh` on every full-CI PR.

**Independent review:**

- Claude `final-check` at `188f56c2` → **APPROVE**
  (`C:/repos/ai-devops-wt-1183-c1-labels/.ai/reviews/claude-final-check-20260930T181503-486018-997.md`).
- Two earlier REJECT rounds were fixed (100755 modes, heredoc injection,
  dead empty-verdict carve-out, name-based over-matching, label create
  fallback, mixed-result precedence). Do not undo those fixes.

**Parent #1183:**

- Child 1 ticked `[x]`.
- Checklist item added: `- [ ] live proof (child 1): one real scheduled-failure
  incident carries label capacity/infra or result from
  tools/ci/report-scheduled-failure.sh`.
- Comment posted: `next: child 2`.
- Children 2–5 still `[ ]` — take them one per session, in order.

## 4. Everything we tried that did NOT work

- `bin/ai-task-gates start --class code` then `check --before pr-wait` **STOP**:
  `bin/ai-pr-wait` is reviewer-safety in `.ai-devops/task-gates.json`. Redeclare
  `--class reviewer-safety` and run exact-head independent review. Do not try to
  acknowledge a protected class away.
- First Claude review REJECT: committed tools were `100644` (Linux lane would
  fail `test -x`), unquoted heredoc in `ai-pr-wait`, empty-verdict carve-out
  dead because summary was never passed. Fixed before the APPROVE head.
- Second Claude review REJECT: `git diff origin/main` showed deletion of
  `HANDOFF.d/2026-09-30T1738Z-edge-dev3-claude-screenconnect-black-screen.md`
  and a strip of `docs/edge-dev3-rdp-over-tailscale-2026-09-28.md` — those were
  **not** this session's changes; origin/main had moved (#1190). Merge
  `origin/main` into the branch and the diff cleaned up. Always reconcile before
  review when main has moved.
- `gh pr merge --merge` refused: "merge strategy for main is set by the merge
  queue". `gh pr merge --auto` reports "already queued to merge". Wait for the
  queue entry (`isInMergeQueue`, `mergeQueueEntry.state=AWAITING_CHECKS`).
- Long `ai-pr-wait` / poll loops get ChildProcess.kill from the desktop tool
  (≈10 min). Use short bounded checks and leave the PR as the card.
- PowerShell mangles multi-line `bash -lc` with nested quotes. Write a temp
  script under the worktree and run it; delete the script before commit.
- `bash '$TAX'` inside a double-quoted test string does **not** expand `$TAX`
  the way you want — define a shell function (`tax() { bash "$TAX" "$@"; }`).

## 5. Root causes and key findings

- Capacity timeout/kill/rate-limit were reported as ordinary test failures, so
  sessions re-diagnosed mislabeled red for hours (plan §3.3, FM-2/FM-4).
- Empty reviewer verdict could show as PASS (bare PASS + empty report) or be
  treated like a test failure. It must fail the **review step** and reroute;
  it must never be labeled `result`.
- The action taxonomy is two labels only for red work; detailed categories stay
  in reports only. Empty-verdict is the review-step carve-out.
- Public-boundary `https?://…IP` over-matched version numbers in paths.

## 6. Exact next steps

1. Open **#1183**. Take **child 2 only**
   ("Parallelize the merge critical path + fast-fail. Finish P3/P5/P6
   acceptance. Required verification-closure and merge queue survive. Windows
   stays gating (parallel lanes). No path filters. Never raise ceilings.
   Owner: #650."). Do not start 3–5 in the same session.
2. Separately (can ride the same session if small, else its own): tick the
   **live proof** checklist item on #1183 after one real scheduled-failure
   incident carries `capacity/infra` or `result`. Do not open a new issue.
3. Implement child 2 with branch + PR + merge queue. If the change set touches
   `bin/ai-pr-wait` or another reviewer-safety path, declare
   `ai-task-gates start --class reviewer-safety` and get exact-head
   independent review (`ai-review <provider> final-check --implementer mimo`).
4. Tick child 2 on #1183, comment `next: child 3`, stop.
5. Do not open a new `plan_*.md`. Map every row to #650 / #658 / #1061 / #511.

## 7. Constraints and gotchas in force

- Live proof before close. Exact-head independent review for reviewer-safety
  paths. No path filters on required checks. `verification-closure` + merge
  queue stay. #401 and #204 stay closed. Leftover-proof mill stays deleted.
- Required `ai-blocker-watch wait` registration is OUT (Muse-agreed).
- Windows runner slowness is infra (#209 / #262), not process. Never raise CI
  ceilings to hide capacity.
- Janitor bounds: 6h per-PR cooldown, comments only, never opens issues, no
  comment after human activity in 24h, kill switch on #1061 lineage.
- Public repo: never commit raw transcript text, secrets, or private paths.
- `bin/ai-gh` for GitHub. Times in EST/EDT, named.
- Canonical checkout is landing-only. Use worktrees. Never touch another
  session's `HANDOFF.d/` file.
- Mixed capacity+result incidents label **result** (a real failure is never
  parked as capacity).

## 8. Access and environment

- Machine: edge-dev (Windows). Git Bash at `C:\Program Files\Git\bin\bash.exe`
  for bash tools (`& "C:\Program Files\Git\bin\bash.exe" -lc "..."` or run a
  script file). `$env:MIMO_PYTHON` for Python.
- Session worktree (remove after cleanup if clean):
  `C:\repos\ai-devops-wt-1183-c1-labels`, branch `mimo/1183-c1-capacity-labels`
  (squash-merged; branch can be deleted after `origin/main` contains
  `6edee717`).
- Public labels `capacity/infra` and `result` already exist on
  `popcre/ai-devops`.
- Independent review reports (do not commit): under the worktree
  `.ai/reviews/claude-final-check-20260930T*.md`.

## 9. Open questions and risks

- **Live proof for child 1 is open** — checklist item on #1183. Labels exist
  and the script is wired, but no scheduled incident has been observed
  carrying them yet. That is the proof, not another code change.
- `tools/ci/report-scheduled-failure.sh` has no dedicated executing test
  (Claude APPROVE medium note). A later child may add one; not required for
  child 2 unless the file changes.
- `bin/ai-public-boundary-check` precision fix is on main via this PR; if a
  true `https://<numeric-IP>/` endpoint ever needs to fail, the authority-only arm
  still catches it. Do not widen the project-identifier pattern.
- Windows section (2) and reviewer-fallback were slow on the #1189 run; that
  is capacity, not process (do not "fix" by raising ceilings).

## Mandatory self-audit gate

- [x] Sections 0–9 present
- [x] Next steps are actionable cold (issue #1183 + child 2 + live-proof item named)
- [x] Failures in §4 include what was tried and why it failed
- [x] Constraints match AGENTS.md / agreed plan (no path filters, live proof, no new plan_*.md)
- [x] No secrets, tokens, or raw private transcript text in this file
- [x] Owner-only decisions called out (none open)
- [x] Someone who has never seen this chat can pick up #1183 child 2 from this file alone
