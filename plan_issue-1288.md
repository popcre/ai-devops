# Implementation plan — popcre/ai-devops#1288 (`local-watch-leader`: the watchdog duty-pool claim issue)

## Verdict (read first)

**Not a defect; a standing fixture. Do not close it (checked 2026-11-04 9:42 PM EST).**
#1288 is the issue whose body carries the `<!-- local-watch-claim -->` lease
marker that `bin/ai-local-watch` reads and rewrites every tick. It is pinned by
number in `config/local-watch.json` (`"claim_issue": 1288`). Closing it would
make the next `claim` create a replacement issue (the tool looks up an OPEN
issue by title, then creates one), and the config would still point at the
closed number. Current body: leader `hetz`, lease renewed 2026-11-04 21:40 UTC,
so the pool is alive. The only work this issue needs is to make its purpose
obvious to the next person who sees it in the open-issue list, and to keep it
out of "every open issue" sweeps.

## STATUS

| Step | State | Evidence |
|---|---|---|
| 1 Confirm the pool is healthy (`ai-local-watch status`) | ⬜ open (2026-11-04) | body shows hetz lease fresh |
| 2 Label #1288 `fixture` and put a one-line explanation above the marker | ⬜ open | — |
| 3 Make `ai-local-watch` preserve that explanation when it rewrites the body | ⬜ open | — |
| 4 Document in `docs/watchdog-duty-pool.md` that #1288 is permanent | ⬜ open | — |

A fresh session starts at Step 1. Handoff registration:
[HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md](HANDOFF.d/2026-11-04T2142Z-al8960ofc-claude-open-issue-plans-batch2.md).

---

## 1. Ultimate goal

Albert's routine CI watchdogs (Windows queue watch, runner-pool watch,
merge-queue drift) run as local timers on machines that are not always on.
So one machine at a time holds a short lease recorded on a GitHub issue, and
only the lease holder posts public alarms. That issue is #1288. The goal is
simply that **the duty pool keeps working and nobody "cleans up" its claim
issue by mistake**. **If a step conflicts with this goal, the goal wins — stop
and flag it on #1288's owner issue #1287.**

## 2. What this application is

`bin/ai-local-watch` (bash, 274 lines; header lines 1–35 explain the design)
with `config/local-watch.json`: `watch_hosts` = edge-dev, edge-dev3, hetz;
`lease_ttl_minutes` 15; tools ticked when leader: `ai-windows-queue-watch`
(2 min), `ai-runner-pool-watch` (60 min), `ai-merge-queue-drift` (daily).
Docs: `docs/watchdog-duty-pool.md` (failover drill proven 2026-10-05 on
edge-dev ↔ edge-dev3; claim issue #1288; owner issue #1287). Tests:
`tests/test-local-watch-claim.sh`.

## 3. Trigger

#1288 appears in the open-issue list with the label `bug` and no description
beyond the marker, so every "resolve all open issues" sweep (including the one
that produced this plan) has to rediscover that it is infrastructure.

## 4. Scope

In scope: labelling, a human-readable preamble that survives rewrites, a doc
sentence. **NOT in this plan:** changing lease semantics, hosts, TTLs; closing
or renumbering the issue; the duty tools themselves.

## 5. Current state

- `bin/ai-local-watch:63-71` `claim_issue_number`: uses the configured number
  when non-zero, else searches OPEN issues by title.
- `:73-85` `ensure_claim_issue`: creates a new issue with the bare marker when
  none is found.
- `:88-100` `read_claim`: awk from the marker line; stops at the first blank
  line after `leader=`.
- `:103-110` `write_claim`: rewrites the ENTIRE body as marker + three lines
  (`gh issue edit --body`), so any preamble added by hand is lost on the next
  renewal (every successful tick, i.e. every few minutes).
- Issue body now: `leader=hetz`, `lease_until=2026-11-04T21:55:15Z`,
  `renewed_at=2026-11-04T21:40:15Z`. Label: `bug` (wrong).

## 6. Key findings

- Because `write_claim` replaces the whole body, Step 2's explanation needs
  Step 3 or it vanishes within minutes. Order: land Step 3 first, install on
  the leader host, then do Step 2.
- `read_claim` already tolerates text before the marker (it starts grabbing at
  the marker line), so a preamble above the marker is safe for reads.

## 7. Rejected approaches

- Closing #1288 to "resolve" it: rejected; breaks the pool and strands the
  config pointer.
- Moving the marker to a repository file: rejected; the lease must be
  cross-machine and atomic-ish via one API write; the issue is the right place
  and the design is proven.
- Putting the explanation in the issue title: rejected; the title is matched
  exactly by the fallback lookup and by `tests/test-local-watch-claim.sh`.

## 8. Decisions

Locked: issue number stays; marker format stays; title stays
`local-watch-leader`. Label: use the existing `capacity/infra` (checked
2026-11-04: no `fixture` or `infrastructure` label exists; do not create one).

## 9. Steps

**Step 1 — Health.** On any pool host: `bin/ai-local-watch status`. Gate:
prints the leader and a lease age under 15 minutes. If the lease is stale,
that is a pool outage — handle via `docs/watchdog-duty-pool.md` before
continuing.

**Step 3 (first) — Preserve preamble.** In `write_claim`
(`bin/ai-local-watch:103-110`): read the current body, keep everything before
the marker line, then write preamble + marker + three fields. If no marker
exists, write the default preamble: "Standing fixture for the watchdog duty
pool (`bin/ai-local-watch`, `docs/watchdog-duty-pool.md`). Do not close; the
block below is machine-written every tick." Use the same default in
`ensure_claim_issue`. Add to `tests/test-local-watch-claim.sh`: case
`renewal preserves text above the marker` (stub body with a preamble; after
`claim`, the stub's recorded edit body still starts with the preamble and has
exactly one marker). Gate: test green on Git Bash and Linux; `shellcheck
bin/ai-local-watch` clean.

**Step 2 — Label and preamble.** After Step 3 is merged and installed on the
current leader (`update.sh` there): remove label `bug`, add the chosen
fixture label, and edit the body to the default preamble + current marker
block (read it first; do not change the lease values). Gate: after the next
tick, `gh issue view 1288 -R popcre/ai-devops --json body` still shows the
preamble.

**Step 4 — Doc.** In `docs/watchdog-duty-pool.md` near line 117, add: "#1288
is permanent; closing it breaks the pool. Open-issue sweeps skip it." Gate:
`bin/ai-doc-reachability --base origin/main` passes.

## 10. Tests required

New: `renewal preserves text above the marker` and `create writes the default
preamble` in `tests/test-local-watch-claim.sh`. Existing green: that file and
`tests/test-ai-blocker-watch.sh` (shares `tools/lib/local-watch.sh`).

## 11. Constraints and gotchas

- The tool runs every two minutes on the leader; a bug in `write_claim` can
  wipe the lease. Test with `AI_LOCAL_WATCH_REPO`/`AI_LOCAL_WATCH_GH` stubs
  before installing.
- Never a paid runner; GitHub Actions remain backup only (header rule).
- Protected `main`, PR, background `bin/ai-pr-wait`, signed comments.

## 12. Access and environment

`gh` as `u2giants`; SSH to hetz (user `ai`, key per memory note) or edge-dev3
for the install; no secrets.

## 13. Definition of done, risks, open questions

Done: Steps 1–4 with the preamble surviving at least one tick; #1288 stays
OPEN with the fixture label; this plan's STATUS marked done. Risk: body rewrite
race with a tick — do Step 2 immediately after `status` shows a fresh renewal.
Open: label name (§8).

## Self-audit

1. Executable without questions: yes — §5 line anchors, §9 ordering and
   gates.
2. Background carried: yes — §6 explains the rewrite trap, §7 why not close.
3. Goal for judgment: yes — §1.
