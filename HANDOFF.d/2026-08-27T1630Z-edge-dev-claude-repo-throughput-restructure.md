# HANDOFF — repository throughput restructure (plan authored, nothing implemented)

**Machine:** `edge-dev` · **Agent:** Claude (Opus 5) · **Written:** 2026-08-27T16:30Z
**Repository:** `popcre/ai-devops`
**Branch:** `claude/test-infrastructure-redesign-74eb99`
**Worktree:** `C:\repos\ai-devops\.claude\worktrees\github-org-move-handoff-d576f2`
**Base commit:** `789d92299110d804e1e246750d7c2ce021695ffd`

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

- `plan_repo-throughput-restructure.md` — a 13-section implementation plan
  covering six phases: make red trustworthy, build one test foundation, verify
  only what changed, unify the duplicated wrapper infrastructure, and close the
  plan backlog. It passed the plan-standard self-audit.

## What was NOT produced

**No code changes. Nothing was implemented, committed, or pushed** beyond the
plan and this handoff. The STATUS table in the plan is correct: every row is open.

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
- The quarantine list named 4 checks; the same race affects 9.
- `gh api repos/popcre/ai-devops/branches/main/protection` returns **404 — the
  main branch has no protection at all**, so the proposed "single required check"
  would have gated nothing.

Full reasoning is in § 7 of the plan. **Do not resurrect either approach**
without reading it.

The drafted files were written into this worktree and have since been reverted
with `git checkout --`. If any trace of `tests/quarantine.txt` or a sharded
`verify.yml` reappears, it is the rejected design.

## Verified facts worth not re-deriving

- CI has no path filtering; a one-line Markdown edit runs the full ~62-minute
  Windows matrix.
- `lock_acquire` is independently implemented four times across `bin/ai-glm`,
  `bin/ai-kimi`, `bin/ai-qwen`, and `bin/ai-grok-review`. Kimi's and Qwen's are
  byte-identical; **only Grok's carries the paid-work `remote-uncertain`
  protection.**
- ~25 helper functions are reimplemented across those four wrappers. There is no
  `bin/lib/` and no shared sourced file anywhere in `bin/`.
- `ok`/`bad`/`skip`/`check` are copy-pasted into ~24 test suites in divergent forms.
- 34 `plan_*.md` files at the repo root; 8 of them are per-provider reviewer
  repair plans for the same class of problem.
- 243 of 492 tracked files are Markdown. 197 commits in the trailing 7 days.
- Test suite isolation is **fine** — no shared `$HOME`, no live ports, no fixture
  writes. Isolation is not the problem; do not go looking there.

## Open question that needs Albert

**Whether to take over PR [#123](https://github.com/popcre/ai-devops/pull/123)**
("derive reviewer test timing budgets from a measured baseline"). It touches the
same file as the plan's Phase 1 step 1.1. Its session
(`local_14c80f71-1a31-4abc-9135-02978d80f87e`) has been idle since
2026-08-27T15:44Z after 24 hours without progress.

The plan gives decision criteria so an implementer can proceed without him
(plan § 13, open question 1), but Albert's call is preferred.

## Where a fresh session starts

`plan_repo-throughput-restructure.md`, **Phase 0, step 1**.
