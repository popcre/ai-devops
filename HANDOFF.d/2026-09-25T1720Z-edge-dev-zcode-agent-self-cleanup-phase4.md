---
issue: 711
status: OPEN
owner: zcode/agent-self-cleanup-phase3-docs
---

# Handoff — agent self-cleanup Phase 4/5 (daily-sweep verify + live proof)

Plan: [`plan_agent-self-cleanup.md`](../plan_agent-self-cleanup.md)
Issue that proves this done: [#711](https://github.com/popcre/ai-devops/issues/711)

This file replaces `2026-09-25T1343Z-edge-dev-mimo-agent-self-cleanup-phase3.md`
(successor rule: Phase 3 landed as merge `dbe9637430f668ba0953dd907fea8c5e31fd0072`
(PR #855); its open obligations — Phase 4, Phase 5, the PID-marker decision, the
six dirty Codex work folders, and the locked-folder moves — are all carried
forward here).

---

## 0. Decisions only the owner can make

**Put this WHOLE list to Albert in ONE message before starting work.**

### Blocking
- None for Phase 4 or Phase 5. Start there.

### Wrong guess is recoverable
1. **Phase 5 reviewer pick** — one real, low-risk review (docs-only PR) must run
   through the new front door. Recommendation: Muse (it is the exact-head
   reviewer Phases 1–3 used; pool health verified 2026-09-25).
2. **Retire the daily task after 14 green days?** — plan says the owner may;
   recommendation (plan §13): **keep it** as belt-and-braces. Only Albert
   decides; nothing blocks until then.

### Outside this workstream — nobody else is on it
3. **Six dirty Codex work folders** (`C:\Users\ahazan\.codex\worktrees\`) still
   hold uncommitted work. Separate session; prompt is
   `prompt_six-dirty-codex-worktrees.md`. Recommendation: run that session
   before deleting anything there.
4. **Last locked folders** `C:\Users\ahazan\.local\share\ai-devops` and the
   Codex sqlite history files still live on C: while tools run.
   Recommendation: close Codex/opencode, then run
   `C:\Users\ahazan\.local\bin\ai-housekeeping\move-bulk-to-d.ps1`.
5. **Evidence-packet gap seen during the PR #855 review (process, not code)** —
   the review packet's `MANIFEST.md` claimed "No tests were run" although the
   dispatch carried `--tests 'bash tests/test-orphan-sweep-age.sh'` (exit 0),
   and §4 pointed at a `patch.diff` absent from the packet. Muse read the files
   directly and APPROVEd anyway. Nobody owns a fix yet. Recommendation: file it
   against the packet tool (`bin/ai-review-packet`) in a new issue.

### Already settled — do NOT re-ask
- Reviews must not copy full Git history (Phase 1, 2026-09-24, `af80fcf0`).
- The creating run deletes its copy; daily sweep is backup only (Phase 2,
  2026-09-25, `41f8e75a`; owner ruling 2026-09-23).
- Parent sweep at 2 h marker age, ≤16 removals per run, wired at the
  `bin/ai-review` front door (Phase 3, 2026-09-25, `dbe96374`, PR #855).
- Sweep age and cap are code-locked; NO environment override (an injected
  shrunken age could delete a live concurrent snapshot).
- PID marker (plan Step 3.2) deferred — see §5.6; do not re-implement casually.
- Live code and tool programs stay on C:; growth/bulk stays on D: via junctions.
- Daily task `AI-Debris-Housekeeping` stays until 14 green days after Phase 5.
- Albert does not merge PRs — the working agent merges.
- Muse APPROVE at exact head is the independent-review pattern for
  reviewer-safety changes.

## 1. What this application is

`popcre/ai-devops` is Albert Hazan's AI development-operations toolkit on his
Windows workstation `EDGE-DEV`. It dispatches AI reviewers (Muse, Grok, Qwen,
Gemini, DeepSeek; GLM and Kimi are out of rotation) against GitHub repos
(`popcre/ai-devops`, `u2giants/shared-db`, `u2giants/licensor-source-data`,
`popcre/poppim-web`, `popcre/popdam3`). Wrappers live in `bin/`; policies in
`config/`; tests in `tests/`. Albert is a business owner, not a programmer.

Review sandboxes live under
`C:\Users\ahazan\.local\state\ai-devops\review-sandboxes\` (junction to
`D:\ai-data\local\state\ai-devops\review-sandboxes`). At Phase-3 merge time the
root held ~690 managed snapshots; 575+ were older than 2 h (92 without evidence
owners — deletable by the sweep; the rest held for unreconciled evidence).

## 2. What we set out to do this session, and why

**Business goal:** stop AI tooling from filling Albert's disks. The run that
creates a temporary copy deletes it (Phase 2); a killed run's leftovers are
swept by the next review start (Phase 3, this session); the daily task remains
the backup net (Phase 4); one live review proves the whole chain (Phase 5).

**This session (2026-09-25) delivered Phase 3** of
`plan_agent-self-cleanup.md`, merged as PR #855 /
`dbe9637430f668ba0953dd907fea8c5e31fd0072`, Muse final-check APPROVE at exact
head `e9f36a91ad42763b492f6bfa5cf96c2751981f81`, CI 20 pass / 0 fail.

## 3. Current state — what is true right now

| Item | State |
|------|--------|
| Phase 1 (shrink the copy) | Done — `af80fcf0` (PR #797) |
| Phase 2 (self-delete) | Done — `41f8e75a` (PR #823) |
| Phase 3 (parent orphan sweep) | **Done** — `dbe96374` (PR #855). `ai-review-sandbox sweep-orphans` (marker >2 h, ≤16/run, evidence-checked) wired at the `bin/ai-review` front door; skipped under `AI_DEVOPS_TEST_MODE` |
| Phase 4 (daily sweep verify) | Not started. No code change expected: Phase 3 changed no paths or marker names, so only the plan's verification gate remains (run the task once, read the log) |
| Phase 5 (live proof) | Not started. One real review must leave zero sandboxes from that run; free space before/after recorded |
| Issue #711 | OPEN (Phases 4–5). The live-proof obligation is tracked by this issue; no separate leftover-proof issue was filed (same pattern as Phases 1–2) |
| Tests at `dbe96374` | orphan-sweep 26/26; sandbox 108/108; self-cleanup 22/22; delete-guard 9/9 (+4 symlink skips where `ln -s` is unavailable); bounded-history 23/23; lifecycle 51/51; claude-review 38/38; codex-review 50/50 |

Worktrees this session: `C:\tmp\ai-devops-self-cleanup-zcode` (code, merged,
safe to retire) and `C:\tmp\ai-devops-baseline-check` (read-only baseline used
to prove the codex-suite failures were the draft wiring, safe to retire).

## 4. Everything we tried that did NOT work

1. **Wiring the sweep inside `ai-review-lifecycle begin`** (the first
   implementation). Every wrapper suite calls `begin` directly without test
   mode and without redirecting the sandbox root, so each call swept the REAL
   machine root (690 dirs on an HDD): the codex suite collapsed to 18 passed /
   32 failed locally while claude stayed 38/38. Proven cause: the same suite
   runs 50/50 on clean `origin/main` AND 50/50 on the final front-door
   revision. Fix: wire once at the `bin/ai-review` front door (suites call
   wrappers directly, production goes through the front door) and skip under
   `AI_DEVOPS_TEST_MODE`. `bin/ai-review-lifecycle` is byte-identical to
   pre-Phase-3 main.
2. **Environment override for the orphan age** (`AI_REVIEW_SANDBOX_ORPHAN_MAX_AGE`).
   Removed before review: an injected value of 1 s would make the next parent
   run delete a concurrent review's live snapshot. Tests use the explicit
   `--max-age-seconds` flag; the age (7200 s) and cap (16) are code-locked.
3. **No removal cap in the first draft.** With 575 real old orphans on this
   machine, an uncapped sweep could park a review start behind a mass HDD
   cleanup. Fix: `ORPHAN_SWEEP_MAX_REMOVALS=16` + a "cap reached" log line.
4. **Counting live sweep effect from the orphan count** — the count went 575 →
   597 during the session because other sessions keep creating snapshots; the
   delta hides any ≤16 sweep effect. Phase 5 must prove the sweep by observing
   ONE run's own snapshot, not by aggregate counts.
5. `bash` on this host resolves to WSL (no distro) — always use Git Bash
   explicitly (`C:\Program Files\Git\bin\bash.exe`). `ai-task-gates start`
   via bare PowerShell path fails; run through Git Bash.
6. `ai-pr-wait` from a worktree needed `--repo popcre/ai-devops` ("cannot
   determine the repository"). The machine-wide GitHub throttle was contended
   all session (another session's calls; back-offs up to ~13 min) — bounded
   waiters absorb this; never hand-poll.
7. `gh pr checks` "fail" grep matches check NAMES (e.g.
   `report-scheduled-failure`); parse the status column instead.

## 5. Root causes and key findings

1. The Phase-3 leak is bounded by design: a killed wrapper's snapshot is
   untouched until its marker is 2 h old, then the next review start removes
   at most 16; the 24 h daily task is the floor for the rest.
2. Marker mtime is the age clock. It is written at build, rewritten when a
   reviewer FIRST binds an owner (`tools/reviewer_events.py` `bind_sandbox`,
   `write_sandbox_owner`), and rebuilt by `refresh-copy` — so an active session
   keeps a fresh marker. (Muse L-level nit: repeat binds of the same owner do
   NOT rewrite it; the comment in `bin/ai-review-sandbox` overstates this.
   Safety holds because `remove_sandbox` → `verify-sandbox` refuses
   unreconciled evidence — proven by `unreconciled_evidence_retained` in
   `tests/test-orphan-sweep-age.sh`.)
3. Evidence retention beats disk age by intent: of 575 old orphans at merge
   time, 483 carried `evidence_owner=` lines and are retained until reconciled;
   only 92 were immediately deletable. The sweep never force-deletes them.
4. The sweep cannot refuse or delay a review: `|| true` at the front door,
   unconditional exit 0, per-entry subshell isolation, and `AI_KEEP_SANDBOX=1`
   still honored inside `remove_sandbox`.
5. `bin/ai-review` hard-pins `$REAL_DIR/ai-review-sandbox` (no env
   substitution on the approval-gate path) — keep it that way.
6. PID marker (Step 3.2) deferred with cause: `ai-review-sandbox` is
   short-lived ("prints a path and exits"), so a PID it writes is dead
   immediately and the "PID not running AND age > 15 min" rule would delete
   live session snapshots 15 minutes in. Correct ownership needs every session
   wrapper to adopt/refresh the marker — a create-side change across eight
   reviewer wrappers on the reviewer-safety surface. Add it only with its own
   reviewed change; the sweep's shape leaves room.
7. Muse review of PR #855 returned APPROVE with 4 informational findings: the
   comment nit above; a stat-then-delete millisecond race (mitigated by the
   evidence gate; same class as existing `bin/ai-glm` orphan handling);
   nondeterministic cap order (by design; test asserts counts); and the
   evidence-packet gap promoted to §0.5 here.

## 6. Exact next steps

1. Work only **Phase 4** of `plan_agent-self-cleanup.md` unless Albert says
   continue. New worktree from `origin/main`; declare
   `ai-task-gates start --class reviewer-safety` (the daily-task rules sit on
   the reviewer-safety periphery; if the gate says otherwise, follow the gate).
   - Expect NO code change: Phase 3 changed no paths or marker names. Verify
     `cleanup-ai-debris.ps1`'s rules still match reality (it deletes sandboxes
     >24 h; markers/paths unchanged), then run
     `schtasks /Run /TN AI-Debris-Housekeeping` and read
     `D:\ai-data\logs\housekeeping.log` for a completed line with free space.
   - **You'll know it worked when** the log shows a completed run and the plan
     STATUS row 4 is ticked (same follow-up-docs-PR pattern as Phase 3).
2. **Phase 5 — one real review end-to-end.** Record free space on C: and D:,
   dispatch one real low-risk review (docs-only PR) through
   `bin/ai-review <provider> final-check ...` from a task worktree, and after
   it returns verify `D:\ai-data\local\state\ai-devops\review-sandboxes`
   contains NOTHING from that run (the sweep's own deletions may appear in its
   stderr — count them, ≤16).
   - **You'll know it worked when** zero sandboxes from that run remain, the
     dispatch log shows the cleanup/sweep lines, and the reviewer still
     produced a usable verdict. Record before/after free space in the PR or
     issue comment.
   - If live proof is deferred again: it stays tracked under issue #711 (no
     additional leftover-proof issue; one per merge is the cap, and #711
     already carries it).
3. After 14 days with zero leftover sandboxes older than 24 h, put the
   keep-or-retire question for `AI-Debris-Housekeeping` to Albert (§0.2).
4. Separately (not this workstream): `prompt_six-dirty-codex-worktrees.md`,
   then `move-bulk-to-d.ps1` when tools are closed.

## 7. Constraints and gotchas in force

- Never edit canonical checkouts under `C:\repos\...` for write work — new
  worktree from `origin/main` first. Never push to protected `main`; branch →
  PR → merge yourself (Albert does not merge). Docs-only PRs (all prose) merge
  immediately with `--squash --admin`; anything with code/tests/config waits
  for checks + merge queue.
- Reviewer-safety class needs one read-only exact-head independent review
  before merge (Muse is the pattern). Freeze the branch after APPROVE.
- Git identity `Albert Hazan <u2giants@users.noreply.github.com>` (`git var
  GIT_COMMITTER_IDENT` before the first commit). Sign GitHub posts
  `Posted by ZCode chat <id> on edge-dev` (`unknown` if the session id is
  empty). Use Git Bash explicitly; bare `bash` is WSL here.
- Make GitHub calls through `bin/ai-gh`; waits through `bin/ai-pr-wait <pr>
  --repo popcre/ai-devops`; never open-ended `gh` loops.
- Delete only inside `.../review-sandboxes/<created-name>` or a proven-clean
  worktree group; never delete dirty copies. `AI_KEEP_SANDBOX=1` is debugging
  only.
- New bash tests: register in `config/ci-suite-manifest.json` — Linux-only
  suites need the `bash` list entry + `linux_offline_suite_seconds` entry, and
  the list must exactly match disk. Windows lanes pick suites from the
  manifest's windows lists; sandbox suites are Linux-lane-only.
- Shared-db structure changes never belong in this workstream.

## 8. Access and environment

- Machine `EDGE-DEV`, user `ahazan`. Canonical repo `C:\repos\ai-devops`
  (landing-only; `git fetch` fine). GitHub via `gh` as `u2giants` through
  `bin/ai-gh` (throttle was heavily contended 2026-09-25 — expect back-offs).
- Secrets: 1Password vault `vibe_coding` only. None appeared this session.
- Reviewer pool verified healthy 2026-09-25: muse, grok, qwen, gemini,
  deepseek registered + installed-healthy; kimi (credit) and glm (owner
  removal 2026-09-22) out; NO GLM/ZCode reviewer ever for GLM-orchestrated
  work (owner ruling 2026-09-17).
- Daily task `AI-Debris-Housekeeping` @ 03:30; log
  `D:\ai-data\logs\housekeeping.log`; growth root `D:\ai-data\` via junctions.
- Worktrees this session: `C:\tmp\ai-devops-self-cleanup-zcode`,
  `C:\tmp\ai-devops-baseline-check`, `C:\tmp\ai-devops-711-phase3-docs` (this
  handoff's PR).

## 9. Open questions and risks

1. **Live proof still unproven** — until Phase 5 runs, the daily sweeper
   remains load-bearing; the 14-day clock for §0.2 has not started.
2. **483 evidence-held orphans** stay until their evidence is reconciled or
   the 24 h daily task takes them; the parent sweep will not force them.
3. **Stat-then-delete race** (Muse L-level): a bind landing between the mtime
   sample and the delete is not re-checked; the evidence gate refuses the
   delete in that window, so the exposure is theoretical. Same class as
   existing glm orphan handling.
4. **Marker-refresh comment nit** in `bin/ai-review-sandbox` (repeat binds do
   not rewrite the marker). Fix opportunistically in the next code change that
   touches that file; do not reopen a reviewed head for it alone.
5. **Evidence-packet gap** (§0.5): packet says "No tests were run" despite
   `--tests`; needs an owner and its own issue.
6. **Windows `ln -s`** cannot exercise the symlink delete-guard case (4 skips
   locally); Linux CI runs them.
7. **Plan STATUS counts** — row 3 cites the final local numbers; if CI numbers
   drift, tick from CI output in the Phase 4 docs PR.

---

## Self-audit (handoff-writer)

1. **Brand-new developer could continue without questions** — §1
   product/paths/pool state; §3 exact state with SHAs; §6 numbered steps with
   verification gates; §4 dead ends (begin wiring!) with the proof that
   isolated the cause.
2. **As effective as this session** — §5 root causes (marker mtime clock,
   evidence-vs-disk, cap rationale, PID deferral); §7 toolchain traps; §8
   access incl. throttle contention.
3. **Every relevant detail** — background §1–2; state §3; failures §4;
   findings §5; next steps §6; constraints §7; access §8; risks §9; owner
   items consolidated in §0 with recommendations and a settled list.
4. **Section 0 sweep** — blocking: none. Recoverable: Phase 5 reviewer pick,
   daily-task retirement. Outside: six dirty folders, locked-folder moves,
   evidence-packet gap (promoted from a Muse review finding). Every §1–9 item
   needing the owner also appears in §0.

**Answers:** Yes / Yes / Yes / Yes.
