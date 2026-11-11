---
summary: Plan for issue 2338 giving unowned shared-db blockers in the blocker-watch digest an owner or closing them.
kind: plan
status: open
read-when: Handling the ai-blocker-watch digest blockers (issue 2338)
---

# Implementation plan — popcre/ai-devops#2338 (ai-blocker-watch digest 2026-11-04: give the unowned shared-db blockers an owner, then stop digests piling up)

## Verdict (read first)

**Real, two parts (checked 2026-11-04 9:42 PM EST).** #2338 is the automatic
daily digest that `bin/ai-blocker-watch` posts listing OPEN issues that block
other OPEN issues yet have nobody owning them. It is not a bug report; it is a
to-do list. It lists eight `popcre/shared-db` issues (three holding up chains
three levels deep). The digest issue itself never closes by itself: the five
previous digests (#2105, #2209, #2217, #2299, #2316) were all closed by hand at
the same minute on 2026-11-04 (20:31 UTC), which shows the watcher leaves
yesterday's digest open forever. So: (A) assign the eight blockers, (B) make the
watcher close the previous day's digest when it opens a new one, so this issue
class stops accumulating.

## STATUS

| Step | State | Evidence |
|---|---|---|
| A1 Triage the three priority blockers (shared-db #4705, #4706, #4428) | ⬜ open (2026-11-04) | — |
| A2 Triage the five "also unowned" (shared-db #1941, #3595, #4429, #4707, #4708) | ⬜ open | — |
| B1 Watcher closes the prior digest on the next digest write | ⬜ open | — |
| B2 Test for B1 in `tests/test-ai-blocker-watch.sh` | ⬜ open | — |
| C Close #2338 once every listed issue has an owner or is closed | ⬜ open | — |

A fresh session starts at A1 and B1 in parallel (different repos, no shared
files). Handoff registration:
[HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md](HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md).

---

## 1. Ultimate goal

Albert's shared database work is a chain of issues: an application need waits
on a canonical-move issue, which waits on a load, which waits on a policy. When
the issue at the bottom has no owner, every session above it sits idle. The
digest exists to surface those. The goal is **no shared-db issue that blocks
other work sits unowned for a day**, and **the digest mechanism costs nothing
to keep running** (no hand-closing a stale issue every day).
**If a step conflicts with this goal, the goal wins — stop and flag it on #2338.**

## 2. What this application is

- `popcre/ai-devops` holds `bin/ai-blocker-watch` (1,738-line bash tool;
  design notes in its header, lines 1–60) and its settings
  `config/blocker-watch.json`. The alarm part (mechanism 3 in the header)
  runs every `alarm_interval_minutes` (60) on the one machine named by
  `propagate_on_host`, flags issues with no assignee, no `owner:` line in the
  body, no open linked PR and no non-watcher activity for `alarm_stall_hours`
  (24), leaves one request-for-owner comment, and writes a daily digest issue in
  `alarm_digest_repo` (`popcre/ai-devops`) titled `ai-blocker-watch digest <UTC day>`.
- `popcre/shared-db` is the shared Supabase database repository where the
  listed blockers live. Structural changes there follow the `shared-db-change`
  skill: claim exact objects on the existing issue, then start; migrations reach
  production only through the automatic promotion workflow.

## 3. Trigger

Digest #2338 for 2026-11-04 (UTC), body marker `<!-- ai-blocker-watch:digest:2026-11-04 -->`:

| shared-db issue | Title | Idle | Blocks |
|---|---|---|---|
| #4705 | DesignFlow canonical move: license agreements (#4248) | 286 h | #4707 (chain 3) |
| #4706 | DesignFlow canonical move: core.merch_group load (#4248) | 286 h | #4707 (chain 3) |
| #4428 | RLS phase 4: optimize 17 ownership policies through production and live proof | 157 h | #4429 (chain 3) |
| #1941 | Laura and Ilona: review all licensed Properties and reconcile ColdLion | 644 h | #2541 |
| #3595 | Complete final-home item ownership structure before DesignFlow row cutover | 572 h | #4217 |
| #4429 | RLS phase 5: optimize four style-guide access policies through production and live proof | 293 h | #4430 |
| #4707 | DesignFlow canonical move: items and child tables (#4248) | 286 h | #4709 |
| #4708 | DesignFlow canonical move: factories (#4248) | 157 h | #4709, #4710 |

## 4. Scope

In scope: giving each listed issue an owner (assignee or `owner:` line) or
closing it with a reason; the digest-closing change in the watcher; closing
#2338.
**NOT in this plan:** doing the shared-db work itself (each issue has its own
plan or parent #4248; see the `shared-db-change` skill); changing alarm
thresholds; the propagation, wake or link-maintenance mechanisms; the
stuck-work watchdog.

## 5. Current state

- `bin/ai-blocker-watch:1092-1320`: alarm scan and digest write. Lines
  1266–1312: today's digest is found in the open-issue snapshot or by search,
  edited if the body changed, else created. Nothing reads or closes a digest
  for a previous day. `HOME_DIR/digest-<day>.done` / `.prev` are per-day
  local state files.
- Previous digests #2105 (10-30), #2209 (10-31), #2217 (11-01), #2299 (11-02),
  #2316 (11-03) all closed 2026-11-04 20:31 UTC by hand.
- `tests/test-ai-blocker-watch.sh` exercises the alarm with a stubbed `gh`
  (see its `gh` shim pattern); `tests/verification/blocker-watch/` holds live
  proofs.

## 6. Key findings

- An issue leaves the digest when it gains an assignee, an `owner:` line, an
  open linked PR, or fresh activity (digest footer; code at
  `bin/ai-blocker-watch:1092-1096`). An `owner:` line is the cheapest durable
  fix for issues that are deliberately parked (e.g. #1941 is a human review by
  Laura and Ilona).
- The "chain 3 deep" trio is the #4248 DesignFlow canonical-move programme
  (#4705, #4706 → #4707 → #4709/#4710) and the RLS programme (#4428 → #4429 →
  #4430). Those are sequential structural work; one session owning the whole
  chain is the right shape.
- The watcher already keys state per day (`digest-$day.done`), so "yesterday's
  digest" is simply the issue with title `ai-blocker-watch digest <day-1>`;
  but a safer rule is "every OPEN issue in `alarm_digest_repo` whose title
  starts with `ai-blocker-watch digest ` and is not today's", which handles
  multi-day outages.

## 7. Rejected approaches

- Closing the digest and ignoring the list: rejected. The chain stays idle; the
  watcher re-lists the same issues tomorrow.
- Raising `alarm_stall_hours` so the digest goes quiet: rejected. Symptom
  suppression; the issues are genuinely stalled.
- Turning the digest into a single pinned issue edited daily: rejected for now.
  It changes the issue identity every tool, doc and test refers to; closing
  the prior digest achieves the same tidiness with a few lines.

## 8. Decisions

Locked:
- No one is "assigned" by writing someone else's name; the AI session that takes
  a chain assigns itself (the `u2giants` account) or writes `owner: <session>`
  on the issue and starts the work per the `shared-db-change` claim-first rule.
- The watcher change is small, inside the existing tool, and advisory-tested;
  no new tool, no new check (owner ruling 2026-10-21 "add NO new tooling").

Open (implementer judgment):
- Whether #1941 (a human review by Laura and Ilona) should be closed as
  "not actionable by AI" with the dependent #2541 re-pointed, or given an
  `owner: Albert` line. Criterion: ask Albert only if #2541 is itself active;
  otherwise write `owner: Albert (human review; not AI work)` and move on.

## 9. Steps

**A1 — Priority trio.** For each of shared-db #4705, #4706, #4428: read the
issue and its parent (#4248 / the RLS plan in shared-db). If the work is ready,
claim it per the `shared-db-change` skill (assign `u2giants`, post a signed
claim comment naming the exact objects) and start a session for it; if it waits
on a decision, add an `owner:` line naming who decides and post one signed
comment stating the blocker. Gate: `gh issue view <n> -R popcre/shared-db --json assignees,body` shows an assignee or an `owner:` line.

**A2 — The other five.** Same procedure for #1941, #3595, #4429, #4707, #4708.
#4707/#4708/#4429 are downstream of A1's trio; the same owner should take them.
Gate: same as A1 for each.

**B1 — Watcher closes stale digests.** In `bin/ai-blocker-watch`, inside the
alarm block right after today's digest is created or confirmed (after line
~1309 "opened digest …" / ~1300 "updated digest …"), add: list OPEN issues in
`$drepo` whose title matches `^ai-blocker-watch digest [0-9-]+$` and whose
title is not `$title`, and close each with `gh_call issue close <n> -R "$drepo" --comment "Superseded by today's digest. (ai-blocker-watch)"`. Prefer the snapshot (`SNAPIDX` keys for `$drepo`) over a search request, following the
#658 P5 pattern already used to find today's digest. Honour `--dry-run`
(`note "would close stale digest …"`). Count through `bw_active_count`. Gate:
`bin/ai-blocker-watch alarm --dry-run` on the propagate host prints one "would
close stale digest" line per older open digest.

**B2 — Test.** In `tests/test-ai-blocker-watch.sh`, add a case
`alarm closes the previous day's digest`: stub `gh` so the snapshot contains
an open issue titled `ai-blocker-watch digest 2026-01-01` plus one stalled
blocker, run `alarm`, assert the stub recorded `issue close` for that number
and not for today's. Add the negative: no stale digest → no close call. Gate:
`bash tests/test-ai-blocker-watch.sh` passes on Linux and Git Bash.

**C — Close.** When every §3 row has an owner or is closed, run `alarm --dry-run`
and confirm the 2026-11-04 list would be empty, then close #2338 with a signed
comment summarising owners per issue. If B1 has landed, the next day's tick
closes it anyway; close it explicitly regardless so the evidence is on the issue.

## 10. Tests required

- New: the two B2 cases above, by name.
- Existing green: `tests/test-ai-blocker-watch.sh`,
  `tests/test-ai-blocker-watch-reap.sh`, `tests/test-blocker-watch-active-receipts.py`.
- Live proof: one real tick on the propagate host after B1 merges and installs,
  recorded under `tests/verification/blocker-watch/` with the tick log excerpt.

## 11. Constraints and gotchas

- The alarm POSTS; only the `propagate_on_host` machine runs it. Test with
  `--dry-run` elsewhere.
- `gh_call` wraps `bin/ai-gh` with request accounting (#658); never call raw
  `gh` inside the tool.
- Shared-db claims are claim-first on the existing issue; no orchestrator chat.
- Sign every comment with `$AI_GH_SIGNATURE`.
- Installed copies update through `update.sh` on each machine; the propagate
  host must reinstall before live proof.

## 12. Access and environment

`gh` as `u2giants` with write on `popcre/shared-db` and `popcre/ai-devops`;
read-only database inspection is allowed from any repo; no secrets needed for
this plan. Propagate host per `config/blocker-watch.json` `propagate_on_host`.

## 13. Definition of done, risks, open questions

Done: eight issues owned or closed with reasons; B1 merged, installed on the
propagate host, one live tick closed a stale digest; #2338 closed. Risk: B1
closes a digest someone is reading — acceptable, the newest digest supersedes
it. Rollback: revert the commit. Open: §8 #1941 handling.

## Self-audit

1. Executable without questions: yes — §3 table, §9 line anchors and stub
   pattern, gates as commands.
2. Background carried: yes — §5 explains why digests pile up, §7 the rejected
   threshold change.
3. Goal for judgment: yes — §1 "no blocker unowned for a day; the mechanism is
   free to run".
