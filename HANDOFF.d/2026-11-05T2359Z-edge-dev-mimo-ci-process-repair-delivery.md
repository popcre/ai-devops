---
issue: 2367
status: OPEN
owner: mimo/ci-process-repair-delivery
---

# HANDOFF — CI process repair delivery (2026-11-05 23:59 UTC, edge-dev/MiMo)

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

One question was put to Albert four times and never answered: `u2giants/poppim-web` PR #24 is
green but that repository's branch protection requires a review approval, while Albert's ruling
of 2026-10-29 says no review gates anything. **The coordinator's decision was to leave it
unmerged** — the conservative, reversible choice that preserves his control. Do not admin-merge
a code change. If he wants it landed unaided, that is his one call.

No other decision is his.

## 1. What this application is

`popcre/ai-devops` (public) is Albert's toolkit for AI coding sessions. The programme also
touches `popcre/shared-db` (the shared Supabase database structure) and the application repos
`u2giants/popdam3`, `u2giants/theoracle`, `u2giants/popcrm-web`, `u2giants/poppim-web`,
`u2giants/synology-monitor`. Albert owns POP Creations and is not a programmer.

## 2. What we set out to do this session, and why

Execute `plan_ci-process-repair.md` (merged earlier, issue #2367): repair CI so red and green
checks mean something and correct changes go live unaided. The instruction was to start at step
0.1 and run phases 1 to 5, one session per phase, dispatching subagents.

## 3. Current state — what is true right now

**Landed on main (ai-devops unless noted):**
- 0.1 `9b4a88b8` — stale fixer PRs retire themselves; 33 closed live.
- 1.1 `1df1947d` — an unfinished pull-request run reports "evidence pending", not a failure.
- 1.2 `e8673d06` — the four tests failing everywhere are fixed; first fully green run in months.
- 1.3 `1d371a1c` + `2f1a7127` — suites self-register by file pattern; the hand-maintained
  `path_suites` map in `config/ci-suite-manifest.json` is gone.
- 1.4 `bad96f82` — real failures open one `ci-red` owner issue per failing test.
- 1.5 `49061d38` + callers (shared-db `9cb5b070`, theoracle `ae6852d9`, popdam3 `cc8cef61`) —
  the fixer no longer runs on every push and branch delete, in any repo.
- 1.6 shared-db `4b9da311` — advisory gates say "advisory: would have ..." instead of REFUSED.
- 2.1 shared-db `aebec3ba` — paperwork refusals removed from rehearsal and promotion.
- 2.2 shared-db `b61e76ab` — the promotion trigger exits 0 for holds/waits/exhausted/acknowledged,
  with the reason in the step summary.
- 2.3 shared-db (merged 2026-11-05 5:39 PM EST) — a stuck change gets one owned issue with
  merged-not-live duration; later independent changes promote past it.
- 4.1 popdam3 `6d75ec71`, popcrm-web `f9fc0987`, synology-monitor `819ff4f4`, theoracle
  `113b2361`, shared skill `6249cdd8` — deploys prove the live version. poppim-web PR #24 is
  green but unmerged (see section 0).
- Installer-parity probe-state fix `c5eaeb1c` — a runner-dependent assertion no longer reddens
  unrelated PRs.

**In flight, owned by this handoff:**
- 2.4 shared-db PR **#5786** — catalog change-type tracking. `SQL migration guards`
  (`Validate hash-bound production verification sidecars`, exit 2) and `Tools offline tests`
  (3 throughput-guard failures) are RED. The subagent was stopped mid-fix; its worktree is
  `D:/repos/shared-db-worktrees/ci-2.4-catalog-check`. Fix those without weakening the
  hash-bound sidecar contract.

**Not started:** 2.5–2.10, 3.1–3.5, 4.2, 4.3, 5.1–5.3, 6.1.

**Live proof still open on #2367:** the one-week sample behind 1.6 (no advisory log says REFUSED
for a merged change), the one-week trigger-failure count behind 2.2, the 24-hour no-owner proof
behind 2.3, and the 60-day catalog replay behind 2.4.

## 4. Everything we tried that did NOT work

- **Subagents were over-used.** Hours went to polling them and writing status lists instead of
  landing work. One ran to ~400 turns; one (phase 3) produced nothing on disk after 62 turns and
  was cancelled. Prefer doing the step yourself unless it is genuinely parallel and isolated.
- **The same question was asked four times and never answered** (PopPIM review requirement).
  Asking once is enough; after that, take the reversible in-scope choice and record it.
- `bin/ai-gh` hangs on its machine-wide lock on this host. Plain `gh` is an acceptable fallback —
  say so in the report.
- `ai-pr-wait` false-positives on committed `.jsonl` test fixtures in the ai-devops checkout and
  refuses to start. Use `gh pr checks` one-shot probes instead, or `--repo OWNER/NAME`.
- GitHub's GraphQL write endpoint returned 502 for about 15 minutes (2026-11-05 4:10–4:15 PM
  EST), blocking every merge. It recovered; retry rather than working around it.
- The weekly MiMo usage quota exhausted once and stopped all subagents (`subscription_quota_exhausted`).
- PowerShell mangles `$VAR:$VAR` and nested quotes in inline `-c` commands. Put shell logic in a
  script file. Bare `bash` on this host resolves to WSL; use `C:\Program Files\Git\bin\bash.exe`.

## 5. Root causes and key findings worth keeping

- The throughput-guard truth-audit regex (`\bmissing\b|never created|not applied|NOT_DERIVABLE|_created_by_applied_dynamic_ddl`)
  scans **all workflow lines including comments**. Those words in a comment inflate the semantic
  inventory and break `Tools offline tests`. Reword comments.
- `Documents-only merge authorization` freezes with `REFUSED: production promotion is active`
  when another change holds the production lease. It is transient — rerun clears it. Do not
  treat it as a defect in the PR under test.
- shared-db pins the `review-fixer.yml` caller shape in `scripts/review-fixer-lifecycle.test.mjs`;
  any caller trigger change must update that test in the same PR.
- `resolveAdmittedIssueForPr` is called from three places in `shared-supabase-migrations.yml`
  (preview lock, governed review, production lock) — all needed null handling after 2.1.
- Two `CanonicalDependencyResolution` errors in `test_automatic_promotion_candidates.py` are
  pre-existing (missing fixtures), not caused by this work.
- `enforceAdmission` is `false` in production, so the admission gate is retired.

## 6. Exact next steps

1. Finish **2.4** (PR #5786): fix the sidecar hash-bound failure and the 3 throughput-guard
   tests, then merge through the queue. Its worktree is named in section 3.
2. Then **2.5 → 2.10** in order, one small PR each (plan section 9 has the full text and
   Done-when). 2.7 (ordering) and 2.1 are the highest-risk steps in the plan — carry the
   adversarial tests with them.
3. Then **3.1 → 3.5** (do 3.3 last; it shares `tools/ci/action-taxonomy.sh` with 5.1).
4. Then **4.2, 4.3**, then **5.1 → 5.3**, then **6.1** acceptance against section 13's targets.
5. **At the end of each phase, re-read every downstream phase through plan-end and report any
   drift** — anything learned that changes a later phase's assumptions.

## 7. Constraints and gotchas in force

From `AGENTS.md` and plan section 11: one small PR per step; never push to main; commit only as
`Albert Hazan <u2giants@users.noreply.github.com>`; sign GitHub posts
`Posted by MiMo chat <id> on <machine>`; quote times in EST; `bin/ai-pr-wait` for waits and
`bin/ai-gh` for GitHub calls (with the fallbacks in section 4); never `gh run watch`; never add a
required check or a review gate; never use the `review-finding` label for CI failures; shared-db
migrations reach production only through the promotion workflow — never a manual production
command; load `codex-shared-db-change` before shared-db work; never admin-merge a non-prose
change; both repos are public so never paste transcript text or secrets.

## 8. Access and environment

`gh` is authenticated as `u2giants` on edge-dev (Windows). Identity `u2giants` for app repos and
shared-db; `popcre` is DesignFlow-only. Secrets stay in 1Password vault `vibe_coding`. Worktrees
for this programme live in `D:/repos/<repo>-worktrees/` and `D:/repos/wt-*`; clean up the ones
you finish with. The tracker is issue #2367.

## 9. Open questions and risks

- The PopPIM review-approval question (section 0) is the only thing needing Albert.
- Steps 2.1 and 2.7 change what reaches production — that is the plan's highest risk. Land them
  with the adversarial tests and watch the first three promotions.
- Several Done-when lines need a one-week sample; they cannot be closed inside one session.

## Self-audit

A stranger can continue from sections 3, 4, 5 and 6 plus the plan's STATUS. Failed attempts are
in section 4; the reasoning is in section 5. Every phase through plan-end is named in section 6
with the reciprocal end-of-phase instruction present. Evidence: each landed step cites a commit
or PR; the one open PR names its exact failing checks.
