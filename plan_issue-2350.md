---
summary: Plan for issue 2350 indexing the plan_issue-*.md files and doc-safety reachability checks via PR 2349; merge and close remain.
kind: plan
status: open
read-when: Landing the plan index and reachability checks (issue 2350)
---

# Implementation plan — popcre/ai-devops#2350 (make the issue plans reachable so PR #2349 passes doc-safety)

## Verdict (read first)

**Mostly done on this branch (checked 2026-11-04 9:42 PM EST).** PR #2349
added 24 root `plan_issue-*.md` files with no inbound link, so the CI
`doc-safety` job (`bin/ai-doc-reachability`) failed. The automatic fixer opened
PR #2351 (`review-fix/2350` → `claude/open-issue-plans`) adding an "Issue
implementation plans" index to `docs/pending-work.md`. That fix is merged into
the `claude/open-issue-plans` branch by the planning session that wrote this
file. What remains: the six plans added in the second batch (this file and its
siblings) must be indexed the same way, the handoff registration the
`implementation-plan-writer` standard demands must exist, CI must go green, and
#2349 must merge. Then #2350 closes.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Index the first 24 plans in `docs/pending-work.md` | ✅ done (2026-11-04) | commit `33fae053` (PR #2351), merged into `claude/open-issue-plans` |
| 2 Index the batch-2 plans (#1288, #1881, #2172, #2338, #2350, #2354) | ⬜ open | — |
| 3 Register all plans in a `HANDOFF.d/` file | ⬜ open | — |
| 4 `bin/ai-doc-reachability --base origin/main` passes locally | ⬜ open | — |
| 5 Push, CI green, merge #2349, close #2350 and #2351 | ⬜ open | — |

A fresh session starts at Step 2 (the planning session attempts Steps 2–4 in
the same commit as this file; re-check with the gates). Handoff registration:
[HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md](HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md).

---

## 1. Ultimate goal

Albert asked for a written, executable plan for every open issue in this
repository so any fresh AI session can pick one up without rediscovery. The
plans exist, but a document nobody can navigate to is lost: this repository
enforces that every Markdown file is reachable from `README.md`, `AGENTS.md`,
`CLAUDE.md` or `HANDOFF.md`. The goal is that **every issue plan is one click
from the router and the PR carrying them merges**.
**If a step conflicts with this goal, the goal wins — stop and flag it on #2350.**

## 2. What this application is

`popcre/ai-devops`: Albert's public AI toolkit repository (instructions,
skills, gates, CI). Protected `main`; PR + merge queue; the AI merges.
Documentation reachability contract: `docs/doc-reachability.md`; tool
`bin/ai-doc-reachability`; configuration `.doc-reachability.json` (roots
README/AGENTS/CLAUDE/HANDOFF; excludes `HANDOFF.d/**`, `archive/**`, changelogs,
licences, `.github/**`). The CI job is `doc-safety` in
`.github/workflows/verify.yml` (advisory under the lean-checks ruling, but a
red advisory job is still a defect to fix).

## 3. Trigger

Issue #2350: GLM advisory review of PR #2349 (head `7b3de5d0`), finding 1
(blocking): 24 unreachable added Markdown files. Fixer run 41912423592 opened
PR #2351. Reproduce on the original head: `git checkout 7b3de5d0 && bin/ai-doc-reachability --base origin/main` lists all 24 files.

## 4. Scope

In scope: reachability of every `plan_issue-*.md`, the handoff registration,
landing #2349.
**NOT in this plan:** editing the content of the other plans (each has its own
issue); adding root `plan_*.md` to the exclude list (see §7); changing the
reachability tool.

## 5. Current state

Branch `claude/open-issue-plans` (PR #2349, base `main`):
- `7b3de5d0` — 24 plans.
- `33fae053` — fixer: `docs/pending-work.md` gains three grouped lists linking
  all 24 plans (including `plan_issue-2248.md`, whose issue has since closed).
- The planning session that wrote this file adds `plan_issue-1288.md`,
  `plan_issue-1881.md`, `plan_issue-2172.md`, `plan_issue-2338.md`,
  `plan_issue-2350.md`, `plan_issue-2354.md`, a `HANDOFF.d` file, and the
  corresponding index lines.

## 6. Key findings

- `docs/pending-work.md` is linked from `AGENTS.md` ("Active plans and pending
  work"), so a link there satisfies reachability.
- The 24 existing plans each carry a note that the plan "lives in the planner's
  scratchpad" and that the implementer should create the handoff. That note is
  stale now that the files are in the repo; the handoff created in Step 3
  covers all of them. Do not rewrite 24 files for the note; the handoff is the
  registration.
- `plan_issue-2248.md` describes a closed issue (#2248). Leave it; it records a
  closeout and is harmless.

## 7. Rejected approaches

- Excluding `plan_*.md` from `.doc-reachability.json`: rejected. The contract
  exists precisely so plans do not vanish; `AGENTS.md:243` already treats root
  plans as the live plan index.
- Linking every plan from `AGENTS.md`: rejected. `AGENTS.md` is held under
  2,000 words (#1881 phase 4); `docs/pending-work.md` is the designated index.
- One mega-plan file: rejected. One issue, one plan, one card.

## 8. Decisions

Locked: index in `docs/pending-work.md`; one handoff file registers the batch;
no config exclusion. Open: grouping headings for the six new entries (keep the
three existing groups; add "Programme and watcher issues" for #1288, #1881,
#2172, #2338 if that reads better).

## 9. Steps

**Step 2 — Index batch 2.** Add six list lines under the existing "Issue
implementation plans" section of `docs/pending-work.md`, same link format
(`../plan_issue-N.md`). Gate: `grep -c "plan_issue-" docs/pending-work.md` prints 30.

**Step 3 — Handoff.** Create
`HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md` with
the standard header, linking all 30 plans and PR #2349. Gate: file exists and
`HANDOFF.md` is untouched (`git diff --stat origin/main -- HANDOFF.md` empty).

**Step 4 — Local reachability.** `bin/ai-doc-reachability --base origin/main`
→ PASS with zero unreachable files. If it reports the new plans, the index line
is missing or mis-pathed.

**Step 5 — Land.** Commit as Albert's verified identity, push
`claude/open-issue-plans`, run `bin/ai-pr-wait 2349` in the background. When
`doc-safety` and `verification-closure` are green, merge #2349 (squash is the
repo default), close #2351 as superseded (its commit is already in the branch)
and close #2350 with a signed comment naming the merge SHA.

## 10. Tests required

Existing: `bin/ai-doc-reachability --base origin/main`; CI `doc-safety`,
`verification-closure`. New: none (documentation only).

## 11. Constraints and gotchas

- LF endings; sign comments with `$AI_GH_SIGNATURE`; never a sleep loop.
- `docs/pending-work.md` is also edited by plan #2354 Step 1 (ended-trial
  pointer). Land #2349 first; #2354's PR rebases.
- PR #2351's branch targets `claude/open-issue-plans`, not `main`; do not
  merge it through the GitHub UI after its commit is already on the branch —
  just close it.

## 12. Access and environment

`gh` as `u2giants`; Git Bash on Windows (host al8960ofc) or bash on edge-dev3;
no secrets.

## 13. Definition of done, risks, open questions

Done when #2349 is merged, `doc-safety` green on the merged head, #2350 and
#2351 closed. Risk: a concurrent change to `docs/pending-work.md` on `main`
(e.g. #2353's follow-ups) causes a conflict; resolve by keeping both sections.
Open questions: none.

## Self-audit

1. Executable without questions: yes (§9 gates are exact commands and counts).
2. Background carried: yes (§5–§7 explain the fixer PR, the stale scratchpad
   notes, and why exclusion is rejected).
3. Goal usable for judgment: yes (§1).
