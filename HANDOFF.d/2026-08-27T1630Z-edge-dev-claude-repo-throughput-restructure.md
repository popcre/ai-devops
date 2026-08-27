# HANDOFF — repository throughput restructure (plan authored, nothing implemented)

**Machine:** `edge-dev` · **Agent:** Claude (Opus 5) · **Written:** 2026-08-27T16:30Z
**Repository:** `popcre/ai-devops`
**Branch:** `claude/test-infrastructure-redesign-74eb99`
**Worktree:** `C:\repos\ai-devops\.claude\worktrees\github-org-move-handoff-d576f2`
**Base commit:** `b9734ca` (rebased onto `main` 2026-08-27; the plan was authored
against `789d922`, whose Disney commit was already on `main` under SHA `724a306`)

---

## The one thing to read

**→ [`plan_repo-throughput-restructure.md`](../plan_repo-throughput-restructure.md)**

That plan is the deliverable of this session. It is self-contained: a fresh
session can execute it without reading this handoff or the originating chat.
Read its STATUS table first. **Do not re-plan or re-derive it.**

---

## Why this session existed

Albert reported on 2026-08-27 that two AI sessions had run for 24 hours against
this repository and produced nothing — one re-running the same hour-long test
suite repeatedly, the other polling CI in ten-minute increments all day. His
instruction: *"Take a step back, take a broader look at how this whole repo is
structured. we have to rework how it works, this is not sustainable. nothing is
getting done."*

He later clarified the scope: **this is about the grander scheme, not about
fixing one session's bug.**

## What was produced

`plan_repo-throughput-restructure.md` — an implementation plan taken through
**two adversarial reviews**, both by independent models, both incorporated:

| Reviewer | Verdict | Cost | Report |
|---|---|---|---|
| Grok 4.6 | **REJECT** (of the pre-plan design) | $0.14 | `.ai/reviews/grok-test-infra-redesign-20260827T161400Z-1644185.md` |
| GLM 5.3 | **ACCEPT WITH CHANGES** (7 required) | not reported by provider | `.ai/reviews/glm-repo-throughput-restructure-20260827T164602Z.md` |

All seven of GLM's required changes are applied and recorded in § 7.F of the
plan. The two that most change the shape of the work:

1. **Branch protection was scheduled before the flake fix.** GLM called this the
   one actively harmful item: the required Windows job runs the flaky suite, so
   it would have gated every merge in the repo on a 1-in-3 coin flip. Reordered.
2. **The plan was ~3× its own minimum viable subset**, with nothing user-visible
   landing until well into it. **Split**: this plan now ends at Phase 3′ (~3–4
   sessions, every step shipping value on its own), and the three expensive
   pieces became named follow-on plans in § 14, gated on it landing.

The plan's self-audit was re-run against the revised document and passes.

## What was produced after this handoff was first written

**Correction, 2026-08-27.** This section originally read "No code changes.
Nothing was implemented, committed, or pushed." That was true when written and is
now false. The session continued past the plan and shipped:

- **PR [#123](https://github.com/popcre/ai-devops/pull/123)** — taken over from
  the stalled session. Timing budgets now derive from a measured baseline, and
  the last two silent waits became loud `poll_until` calls. Its `fix_test_ai.md`
  heading was corrected from "FIXED" to "PARTIALLY FIXED", because six local runs
  contradicted it.
- **PR [#129](https://github.com/popcre/ai-devops/pull/129)** — the
  public-boundary gate now names the file and line it rejected and points at a
  documented allowlist, instead of failing anonymously. Detection is unchanged.
- **PR [#130](https://github.com/popcre/ai-devops/pull/130)** — two evidence
  files under `tests/verification/reviewer-flake-89/`: the flake failing a
  merge-queue run on unrelated work, and the six-run post-fix series.

**Read the plan's STATUS table, not this list.** Step 1.1 is partial and step 1.2
is **not satisfied**: the reviewer suite still fails roughly one run in six. The
remaining work is handed back to issue
[#89](https://github.com/popcre/ai-devops/issues/89) as one specific change —
make the concurrency wait progress-sensitive rather than deadline-sensitive — not
as an open investigation.

**Iteration on the flake stopped by owner decision** after it had consumed two
sessions for roughly 24 hours. A successor should implement that one change and
re-run the series; it should not resume iterating.

## Dead ends — do not repeat these

A first design was drafted **and rejected** during this session. Its two central
ideas were:

1. A `tests/quarantine.txt` plus output-parsing in `tests/test-all.sh` that would
   excuse known-flaky checks so they stopped blocking merges.
2. Sharding the suites across 6 + 6 + 3 parallel CI runners.

Both were rejected on evidence after an adversarial review by **Grok 4.6**
(session `test-infra-redesign`, cost **$0.14**, 2026-08-27). The review is saved
at `.ai/reviews/grok-test-infra-redesign-20260827T161400Z-1644185.md`. Its
verdict was REJECT, and three of its sharpest claims were independently verified
before acceptance:

- 24 test suites print failures as `FAIL: <message>`, a format the proposed
  parser could not see — so it could have silently excused a real regression.
- The quarantine list named 4 checks; the same class of race runs through **seven
  poll loops** in that suite (lines 148, 202, 213, 219, 295, 642, 649), affecting
  more than a dozen checks. Verified with
  `grep -n 'for _i in $(seq' tests/test-ai-grok-review.sh`.
- The third claim — that `main` has no protection, from a 404 on
  `gh api .../branches/main/protection` — **was itself wrong, and both reviewers
  repeated it.** See the correction below.

Full reasoning is in § 7 of the plan. **Do not resurrect either approach**
without reading it.

The drafted files were written into this worktree and have since been reverted
with `git checkout --`. If any trace of `tests/quarantine.txt` or a sharded
`verify.yml` reappears, it is the rejected design.

## Also rejected — by GLM, on the plan itself

Do not restore any of these; § 7.F of the plan carries the full record.

- Branch protection before the flake fix (harmful — see above).
- The shared test harness before change-scoped CI. GLM established that suite
  *selection* never reads suite *output*, so the stated dependency was false —
  and the harness migration's own gate would have cost 16–24 hours of Windows
  runtime, in a plan triggered by a session re-running the full suite for a day.
- "Adopt Grok's `lock_acquire` everywhere." **This would have broken
  `bin/ai-glm`**: GLM's lock *waits* with a timeout, Grok's *refuses
  immediately*, the signatures differ, and `bin/ai-glm` has three lock functions
  with three deliberate policies (`:265`, `:284`, `:343`). Verified.
- "Stalled open PRs go to zero" as the success measure — gameable, since this
  repo works directly on `main` and the plan mandates self-merge.

## The one thing both reviewers got wrong — read this before Phase 1

`main` **is** protected. The 404 from
`gh api repos/popcre/ai-devops/branches/main/protection` only means there is no
*classic* branch-protection object; `main` is governed by **rulesets**, which
that endpoint does not report. `bugs.md:203` records the same wrong conclusion.
Check rulesets instead:

```bash
gh api repos/popcre/ai-devops/rulesets
```

Verified 2026-08-27 — two active rulesets on `main`:

- **Required status checks: `linux-offline` and `windows-offline`.**
- **Merge queue:** SQUASH, `grouping_strategy: ALLGREEN`, up to 5 entries,
  120-minute check timeout.
- **Bypass actor:** `OrganizationAdmin`, always. Already present — do not remove.

**Why this matters more than the correction itself:** `windows-offline` runs the
flaky grok suite. So every merge in this repository is *already* gated on a
1-in-3 coin flip, and `ALLGREEN` grouping means one flaky entry ejects a batch of
up to five — including pull requests that did nothing wrong, each then re-running
the ~62-minute matrix. That is a better explanation of the 24-hour sessions and
the five stalled PRs than the one the plan was originally built on, and it makes
Phase 1 the priority rather than any CI restructuring.

Step 0.2 shrank accordingly: from "turn protection on" to "re-point required
check contexts after Phase 3′ renames jobs" — with a new high-likelihood risk,
since a required context naming a job that no longer reports blocks every merge
forever.

## Verified facts worth not re-deriving

- CI has no path filtering; a one-line Markdown edit runs the full ~62-minute
  Windows matrix.
- `lock_acquire` is independently implemented four times and the copies have
  **incompatible policies**, not merely different lengths: Grok refuses
  immediately (nine-arg signature, honours `remote-uncertain`), GLM waits with a
  timeout (two-arg signature, user-visible "busy" error) and has two more lock
  functions besides, Kimi and Qwen are byte-identical to each other.
  **Only Grok carries the paid-work `remote-uncertain` protection** —
  `grep remote-uncertain bin/*` hits Grok alone. Whether the other three can
  double-bill today is an open money question, plan § 13 question 2.
- ~25 helper functions are reimplemented across those four wrappers. There is no
  `bin/lib/` and no shared sourced file anywhere in `bin/`.
- `ok`/`bad`/`skip`/`check` are copy-pasted into ~24 test suites in divergent forms.
- 34 `plan_*.md` files at the repo root; 8 of them are per-provider reviewer
  repair plans for the same class of problem.
- 243 of 492 tracked files are Markdown. 197 commits in the trailing 7 days.
- Test suite isolation is **fine** — no shared `$HOME`, no live ports, no fixture
  writes. Isolation is not the problem; do not go looking there.

## RESOLVED — PR #123 was taken over, and adopted

Albert said "take it over" on 2026-08-27. Applying the plan's own decision
criteria (§ 13, question 1) to its diff: **adopt, do not supersede.** It does not
inflate timeouts. It:

- adds `tests/lib-test-timing.sh`, whose `poll_until` prints a distinct
  `fixture:` line naming what never became ready — the exact "a timeout must not
  masquerade as a defect" requirement of step 1.1;
- derives ceilings from a measured baseline that **never returns below the old
  floor**, so no assertion is weaker on an idle CI runner;
- waits on specific session locks by label rather than counting anonymous locks;
- found four real defects, including `concurrent refusal starts no second
  provider turn`, which searched for `*/same-name/owner.json` while the wrapper
  names that directory `kimi.<rid>-<caller>-<name>` — **it had never tested
  anything** and passed only because its wait was shorter than the stub's sleep.

**What this session added on top** (commit `9aec837`): it had left two bare
waits that still gave up silently. One guards a deliberate `TERM` — if it
expired, the test killed a process holding no lock and the two retries then
reported `uncertain_ask_blocks_its_exact_retry` and
`uncertain_ask_blocks_changed_prompt_for_same_next_turn` as wrapper defects that
did not exist. Those are two of the four checks #89 was opened about. Both now
use `poll_until`. No assertion changed; no ceiling moved.

**Local proof:** `tests/test-ai-grok-review.sh` → **191 passed, 0 failed** on
`edge-dev`, measured baseline 12s. (An earlier 188/3 run was self-inflicted — a
second full suite was running concurrently on the same box. Do not read a run
taken under another suite's load as evidence.)

**Still open:** plan step 1.2, the ten-consecutive-green proof on Windows CI.
That is what actually closes issue #89.

## Where a fresh session starts

`plan_repo-throughput-restructure.md`, **Phase 0, step 0.1** — then straight to
Phase 1. Do NOT stop at step 0.2; it now runs after 1.2.
