# Issue #210 / Blacksmith throughput — live baseline, 2026-09-10

Recorded from `claude/blacksmith-windows-throughput-453812`, a fresh
current-upstream worktree at `origin/main` commit `b53ac2ba`.

## Live PR state (checked via `gh pr view`, 2026-09-10 ~01:55Z)

- **PR #355** "Add Blacksmith as an extra Windows CI lane" — `OPEN`,
  head `762f3105b15adb6d6d8b8bea4c4c653ed0e26926` on branch
  `blacksmith-migration-9a7f974`, base `main`.
  `mergeStateStatus: DIRTY`, `mergeable: CONFLICTING`. Adds a duplicate
  full-pack Blacksmith job; does not shard.
- **PR #357** "Split ordinary Windows verification into balanced independent
  sections (#210)" — `OPEN`, head `0178be4a9fe6ac17c454fc0e63685f49a20c4813`
  on branch `claude/issue-210-windows-sharding`, base `main`.
  `mergeStateStatus: UNSTABLE` (one non-required check,
  `windows-reviewer-fallback`, still in progress at last check), `mergeable:
  MERGEABLE`. Not yet merged as of this recording.
  **A separate, currently active Claude session ("#159 ai-devops throughput",
  running ~2h) owns this PR.** This worktree/session must not push, rebase,
  or merge it.
- PR #357 already closes #210 with a 4-way GitHub-hosted-only split
  (`windows-offline-section (1..4)`), measured worst section 18.3 minutes,
  packed from three sampled runs (34394706703, 34377910065, 34366159903).
  It does not use Blacksmith.

## Decision (Albert, 2026-09-10)

Two independent sessions built two different fixes for #210 concurrently.
Albert chose: let #357 land first as the GitHub-only speed fix, then rework
this plan's Blacksmith work to add Blacksmith capacity **on top of #357's
4-section layout** instead of the original 3+3 design in
`plan_blacksmith-windows-throughput.md`. This plan file's Phase A/B design
(exact 3+3 shard split, from-scratch manifest schema) is superseded by that
choice; the shard *contract* (manifest-driven, exact-once, mutation-tested)
carries forward, but the concrete section boundaries must be re-derived from
whatever `config/ci-suite-manifest.json` looks like after #357 lands, not from
this document's original six-shard numbers.

## Runner inventory (`gh api actions/runners`, 2026-09-10)

| Runner | Status | Busy | Labels |
|---|---|---|---|
| EDGE-ALIEN | online | false | self-hosted, Windows, X64, ai-devops-windows-paused |
| edge-dev-win | online | false | self-hosted, Windows, X64, edge-dev, ai-devops-windows |
| EDGE-RUNN-ENVY | online | true | self-hosted, Windows, X64, ai-devops-windows, ai-devops-windows-qualified |

## Required contexts (`gh api repos/.../rulesets/21564317`)

Ruleset "main: pull request + merge queue" required_status_checks: exactly
`linux-offline`. No Windows context is required. Matches the plan's claim.

## Per-suite timing evidence (from a background research pass over live runs)

Source runs: `34237405958` (windows-2025, PR `claude/issue-163-test-selection`)
and `34418585172` (branch `claude/issue-210-windows-sharding`, before it was
split into sections — jobs `windows-offline` on windows-2025 and a since-removed
`windows-blacksmith` job on `blacksmith-4vcpu-windows-2025` running the full
69+18 suite pack).

Slowest Bash suites, seconds (windows-2025 vs blacksmith-4vcpu-windows-2025,
same suite set):

| Suite | windows-2025 (run A) | windows-2025 (run B) | blacksmith-4vcpu (run B) |
|---|---|---|---|
| test-ai-grok-review.sh | 1149 | 1120 | 591 |
| test-ai-kimi.sh | 1063 | 1055 | 539 |
| test-ai-muse.sh | 610 | 596 | 322 |
| test-ai-glm.sh | 522 | 494 | 259 |
| test-ai-qwen.sh | 468 | 472 | 249 |
| test-ai-claude-review.sh | 335 | 393 | 176 |
| test-ai-gemini.sh | 335 | 352 | 152 |
| test-ai-codex-review.sh | 318 | 360 | 169 |
| test-ai-task-gates.sh | n/a | 144 | 91 |
| test-ai-review-preflight.sh | 102 | 93 | 50 |
| test-ai-review-packet.sh | 98 | 92 | 52 |
| test-ai-deepseek-agent.sh | 60 | 63 | 37 |
| Full Bash suite total | 5637s | 5845s | 2997s |

Blacksmith ran the identical suite roughly 1.9-2x faster per suite than
windows-2025, consistent with Blacksmith's published "2x faster" hosted
hardware claim. PowerShell suites are all cheap (0-21s each) on every run;
total PowerShell time is well under 30s regardless of provider.

Job-level totals: `windows-offline` (full monolith, windows-2025) ~95-98 min
wall time per run; `windows-reviewer-safety` (self-hosted qualified,
Codex+Grok only, run in isolation) ~18-19 min; the prior full-pack
`windows-blacksmith` job on `blacksmith-4vcpu-windows-2025` failed after ~50
min on a suite defect, not a timeout — it was never a clean full-pack
completion, so it is evidence of per-suite speed only, not of full-pack
wall time on that provider.

Blacksmith runner pickup latency observed in that same run:
`BLACKSMITH_RUNNER_ACQUIRE_JOB_MS` ≈ 839ms — nearly instant, one clean data
point. Blacksmith's own claim is "unlimited concurrency, no queuing"; one
unrelated third-party report describes multi-hour queuing as an exception
case. No official Blacksmith documentation was found describing behavior when
an account's own plan allowance (as opposed to concurrency) is exhausted —
this remains unconfirmed and must be reverified against the live account
before relying on any queue/fail assumption in the orchestrator design.

Blacksmith pricing (public docs, not verified against this account's live
billing): Windows runners bill from roughly $0.008/vCPU-minute; a 4vCPU
Windows minute bills at roughly double the 2vCPU x64 rate under Blacksmith's
per-vCPU-minute model.

## Manifest facts (`config/ci-suite-manifest.json` at `main` b53ac2ba)

69 Bash suites, 18 PowerShell suites (87 total). `windows_sensitive_bash` and
`windows_offline_bash` both list the same 23 suites; `windows_reviewer_safety_bash`
is the 2-suite subset (`test-ai-codex-review.sh`, `test-ai-grok-review.sh`)
already carved out for the qualified self-hosted lane. This exactly matches
the plan's stated counts. PR #357 replaces this manifest shape with its own
4-section schema; the post-merge shape must be re-read before designing
Blacksmith sections on top of it.

## Next step (superseded — see below)

~~Hold. Do not touch `claude/issue-210-windows-sharding` / PR #357 while
"#159 ai-devops throughput" is actively driving it. Once #357 merges,
re-read `config/ci-suite-manifest.json` and `.github/workflows/verify.yml`
on `origin/main`, and redesign the Blacksmith addition (sibling dispatchable
workflow + orchestrator + cannot-start recovery, from
`plan_blacksmith-windows-throughput.md` §9 Phase B onward) against that
landed 4-section layout instead of this document's original 3+3 split.~~

**Update, 2026-09-10:** the orchestrator/automatic-routing design described
above was abandoned. Albert decided Blacksmith stays strictly manual and
paid — never auto-routed. What actually shipped instead: PR #367 added
`.github/workflows/windows-offline-blacksmith.yml` (`workflow_dispatch`-only,
mirrors #357's 4-section split, `-ExcludeReviewerSafety`) plus
`.github/workflows/windows-queue-watchdog.yml` (comments on a PR asking
Albert to tell Claude to route it to Blacksmith if the free lane is slow to
start — Albert has no runner-queue visibility himself). Both workflows were
proven live: two real `workflow_dispatch` runs against `origin/main`
(`34449903830`, `34453239757`) confirmed Blacksmith runners genuinely pick up
and execute jobs. One real bug found and fixed in PR #372 (Blacksmith's
deeper default TEMP path tripped the Windows 260-char path limit — see
`windows-offline-blacksmith.yml`'s TEMP-shortening step). One real bug found
and NOT fixed — `tests/test-ai-gemini.sh`'s Windows ACL check fails on
Blacksmith only; it touches evidence-protection code gated behind
independent review by this repo's `AGENTS.md`. Tracked in
[popcre/ai-devops#373](https://github.com/popcre/ai-devops/issues/373); see
that issue and `HANDOFF.d/` for the current handoff. This baseline document
is now historical — no further action needed against it.
