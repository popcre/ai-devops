---
issue: 210
status: OPEN
owner: codex/blacksmith-throughput-plan-210
---

# HANDOFF — Blacksmith Windows throughput plan (2026-09-10T0117Z, edge-dev/codex)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

None. Albert settled the design priority on 2026-09-10: drastic throughput,
Blacksmith carrying real exclusive shards, GitHub/local capacity preserved, and
no test removal. The implementer may make only the measured choices explicitly
bounded in plan §8. If evidence challenges a locked decision, present the whole
tradeoff to Albert in one message before changing it.

## 1. What this application is

`popcre/ai-devops` is POP Creations' public AI recovery and verification toolkit.
GitHub Actions validates Windows, Linux, and reviewer safety behavior. The work
is owned by issue #210 and revises open PR #355.

## 2. What we set out to do this session, and why

Convert the agreed 3-GitHub + 3-Blacksmith Windows-shard design into a complete
implementation plan. Albert rejected a small Blacksmith sentinel because it did
not add meaningful capacity or solve 90–120 minute delivery stalls.

## 3. Current state — what is true right now

The complete build specification is
[`../plan_blacksmith-windows-throughput.md`](../plan_blacksmith-windows-throughput.md).
All eight steps are open. PR #355 head is documentation commit `762f3105`;
the preceding code head `92ba1e9a` contains useful qualification repairs but
still duplicates the full Windows pack. PR #355 remains OPEN and DIRTY against
current `main`. The plan, this handoff, and earlier session docs were committed
and pushed in `762f3105`.

Exact code-head run `34418585172` completed after the plan was written. Linux,
GitHub-hosted Windows, and qualified local reviewer jobs passed; Blacksmith job
`102688877305` failed after about 50 minutes. Its logs still report three
`test-ai-facts.sh` fallback-search failures and the `test-ai-gemini.sh`
private-ACL failure despite `92ba1e9a` containing `grep -h` and the guarded
name-or-SID assertion. Those repairs are not proven on Blacksmith.

## 4. Everything we tried that did NOT work

The plan §7 records all rejected approaches: duplicate full packs, tiny sentinel
as the throughput answer, GitHub-only despite owner intent, Blacksmith-exclusive
work without recovery, queued-job timeouts/`needs` fallback, ephemeral runner
probing, rerouting red tests, substring shard selection, premature required
checks, and a dishonest 15-minute target.

The final qualification disproved the assumption that `grep -h` and the
name-or-SID ACL assertion fully repaired Blacksmith. Do not repeat the unchanged
50-minute run. First reproduce or instrument those commands in a short
Blacksmith diagnostic shard, then repair the root cause.

## 5. Root causes and key findings

Serial execution causes the long wall clock. Six shards solve it. A queued
Blacksmith job cannot time out before pickup and cannot be individually cancelled
inside the parent run, so safe recovery requires a separately cancellable sibling
workflow already present on `main`. Exact details and evidence are in plan §6 and
the Grok review artifact named in plan §3.

## 6. Exact next steps

Execute plan Steps 1–8 in order. Step 4 must land the sibling workflow before
Step 5 rebases and revises PR #355. Each plan step includes its own observable
verification gate; update the STATUS table as each gate passes. Use the specified
fresh-session cuts after Steps 3 and 6.

## 7. Constraints and gotchas in force

Use isolated worktrees, preserve every suite, never reroute a real red test,
never use queued `timeout-minutes` as fallback, keep forks GitHub-only, keep
Windows off `merge_group`/required contexts in this change, and refresh every
live provider/PR/runner fact. Full constraints are in plan §11.

## 8. Access and environment

Planning worktree:
`C:\repos\ai-devops-worktrees\blacksmith-additive-355`; repository:
<https://github.com/popcre/ai-devops>; delivery PR:
<https://github.com/popcre/ai-devops/pull/355>. GitHub CLI and both review
harnesses worked. No secrets were used; future credentials belong in 1Password
vault `vibe_coding`, never in logs or commits.

## 9. Open questions and risks

No owner question is open. Measured implementation choices are shard membership,
pickup deadline, per-shard timeout, and Blacksmith backstop cadence; plan §13
gives the evidence criterion for each. Principal risks are silent Blacksmith
queueing, green-washing provider failures, fork coverage loss, shard imbalance,
and premature merge-queue requirements; the plan specifies recovery/rollback.
The immediate technical risk is that two Blacksmith portability failures remain
unexplained on code head `92ba1e9a`; treat them as Step 1 diagnostic inputs, not
accepted flakes.

## Self-audit

1. **Yes, a newcomer can continue without guessing:** §§1–3 identify the repo,
   goal, issue, PR, current state, and authoritative plan; §6 gives the exact
   execution order and gates.
2. **Yes, this carries the session's full implementation knowledge:** §§4–5
   preserve the dead ends and root cause and point to the plan sections containing
   complete evidence and design detail.
3. **Yes, every execution detail is present:** the linked 13-section plan covers
   files, tests, constraints, access, risks, rollback, landing, and definition of
   done; §§6–9 route directly to those details.
4. **Yes, section 0 contains every owner decision:** a line-by-line sweep of
   §§1–9 found no unresolved owner decision. The settled owner priorities are
   stated in §0; bounded evidence choices are not silently promoted to owner
   questions.
