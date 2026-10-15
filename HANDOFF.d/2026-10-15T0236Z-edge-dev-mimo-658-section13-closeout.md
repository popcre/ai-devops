---
issue: 658
status: OPEN
owner: mimo/658-section13-closeout
---

# #658 section 13 closeout: what is proven, what is still open

Coordinator: MiMo chat on edge-dev. Continues
https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-11T1503Z-edge-dev-mimo-request-reduction-native-fleet.md
and the Oct 8 closeout. No shared database was changed. Owner scope locked
2026-10-12: install only edge-dev3, 916, 4837, edge-dev; skip edge-alien and
envy (keep lean for GitHub runs); toolkit installs Albert will also do later
via sync-dotfiles.

## 0. Business decisions only the owner can make

None — nothing in this workstream needs the owner.

Already settled — do NOT re-ask:

- 2026-10-12 (verbatim): "skip edge-alien and envy for fleet install".
- 2026-10-12 (verbatim): "forget about anything that will be handled by a
  'sync my dotfiles' - i'll do that in the near future."
- 2026-10-12 (verbatim): "so you remotely install on edge-dev3 and 916 and
  4837 and run the actual request-reduction proofs" (edge-dev added same day).
- 2026-10-12 (verbatim): "don't stop any active subagents but as they complete
  work don't start new subagents until you have less than 3. run no more than
  3 subagents at a time".
- 2026-10-13 (verbatim): "don't wait. don't pause. don't stop until this
  entire issue is 100% complete."
- 2026-10-07 owner ruling on #658: never stop after one child or phase.
- 2026-09-28: "never ask a human to approve" — technical gates go to an
  assigned AI reviewer.

## 1. What this application is

https://github.com/popcre/ai-devops is Albert's public recovery toolkit for a
multi-model AI workflow. Not an app or a service. Issue #658 reduces GitHub
reads and duplicate calls and repairs quota coverage, then proves it with
measured section 13 acceptance. GitHub is the source of truth. Installation is
deployment.

Fleet in scope (owner-locked): edge-dev3 (Linux), 916, 4837, edge-dev
(Windows). Out of scope: edge-alien, envy, t16, hetz, synology.

## 2. What we set out to do this session, and why

Finish #658 to 100%: install the four in-scope hosts, then run the actual
request-reduction proofs (section 13) and close every checklist child.

## 3. Current state — what is true right now

### Installs — DONE on the four in-scope hosts

| host | receipt / identity | notes |
|---|---|---|
| edge-dev3 | full receipt `c5df4dfa` Secrets PASS; also `51905b73`, `1840f783` | managed launchers work |
| 916 | Windows launcher `ebaacc11` / source-hash `0b14c838`; checkout `b7c8ec80` | counter stage preserved |
| 4837 | launcher `898e6209` | GitHub token invalid (HTTP 401); routing proven |
| edge-dev | launcher `898e6209`; checkout drifted to `4ae0f464` | receipt authoritative |

Proofs: https://github.com/popcre/ai-devops/blob/main/tests/verification/github-requests/p3-installed-proof-edge-dev-2026-10-13.md
Private: `658-windows-install-{916,4837,edge-dev}-20261012.private.md` on edge-dev3.

### Section 13 scoreboard

| # | Requirement | State | Evidence |
|---|---|---|---|
| 1 | Disposition + host/client coverage | Ledger refreshed: 16 true / 7 false / 0 unknown (PR-ready JSON on edge-dev3). HTTP/GraphQL still null on old rows. | `658-disposition-ledger-refresh-20261012.private.md` |
| 2 | 50% fewer redundant reads; zero duplicate writes | Adapter merged `818f8a1b` (PR #1685) with schema-6 counters. **Reviews REJECTED that head** (orphaned counters suite; identical-write skip breaks waiter coalescing). Controlled replay 3/3 cache, reduction 1.0. Do not install until defects fixed. | `658-section13-item2-20261012.private.md` |
| 3 | 30% fewer HTTP and GraphQL per ECO | **UNKNOWN** — no comparable before/after pair. Formulas and P1 rates recorded. | `658-section13-item3-savings-20261012.private.md` |
| 4 | Two busy reset windows, 20% headroom | **PASS** — 2026-10-07T14:55:57Z (min 2505/5000, 50.10%, 0 refusals) and 2026-10-11T20:18:39Z (min 2564/5000, 51.28%, 0 refusals). PR #1706 `35e1d63d`. | https://github.com/popcre/ai-devops/blob/main/tests/verification/github-requests/p1-baseline.md |
| 5 | ≥20 comparable workflows, p95 ≤5% | **n_useful=0** live. Duration adapter merged `4e172768` (PR #1687) but **not installed on edge-dev3**. 48h collection window declared 2026-10-14T13:00Z–2026-10-15T22:00Z. | `658-section13-item5-workflows-20261012.private.md` |
| 6 | Observer overhead ≤5% | **PASS** (N=40 cold re-measure, PR 1561 amended gate). | `658-916-native-cold-remeasure-40.private.json` |
| 7 | 5-min waiter / 10-min BlockerWatch | **FAIL then fixed** — timer/race merged `d9a1b3f9` (PR #1686). Re-verify after install. | `658-section13-items47-20261012.private.md` |

### Checklist children on #658

- P1 #660: baseline frozen and merged (PR #1683 `bf88e64f`). Stays OPEN for
  dispatch/privacy receipts (now largely satisfied by P3), multi-host, and
  after-workload comparison (P8).
- P3 #931 #933 #936: **CLOSED** (PR #1688 `3deb99a5`).
- P5: checked (live proof on #658).
- P6: checked; scoped child #1682 opened (demand decision: retain local
  admission, non-global, no coordinator).
- P7: checked with per-host outcomes.
- P8: **OPEN** — measured acceptance and closeout.
- #1212: **CLOSED** (already fixed by #1401 `a5636006`).

### Native 916 stage

`C:\Program Files\ai-devops-gh-counter-d9de3387eebc4f5896cd89897723af5f`
intact. Helper ran. Telemetry parity UNKNOWN (127.0.0.1 suppresses gh
telemetry by design). Cold gate amended under locked rules (PR 1561).

## 4. Everything we tried that did NOT work

1. **Lower-bound amendment for busy windows was REJECTED** (DeepSeek). The
   two-series mix-up was the bug: `quota-measurements` server bucket snapshots
   stay ~94%+ headroom; the busy-window series is `measurements`
   `observed_graphql_cost` `graphql_remaining`, which dips to 2505/5000. The
   P1 baseline already proved two windows. Do not re-argue the amendment —
   item 4 is PASS from those windows (PR #1706).
2. **Item 2 adapter at 818f8a1b is not shippable** — independent reviews
   REJECT it (orphaned counters suite; identical-write skip breaks waiter
   coalescing). Controlled 3/3 cache math is real but the head is not.
3. **Duration adapter install subagents died** (APIError, then process restart
   abandon). edge-dev3 is still on `1840f783`; live schema-5 rows stay
   `acceptance=unknown` until `4e172768` is installed.
4. **HTTP `http_requests` field stays null by design** in the counter protocol;
   the real count is `observed_completed_writes`. Do not treat null as zero.
5. **Windows cohort tagging** is `metadata_untrusted` by design (`O_NOFOLLOW`
   posix requirement). Only edge-dev3 can populate `cohort_id`.
6. **No manufactured demand.** Busy windows and ≥20 workflows must come from
   real authorized work.

## 5. Root causes and key findings

- Two quota series are not interchangeable (see §4.1).
- Schema-1 `cache_hit` is structurally always false (cache serves never launch
  the CLI). Schema-6 `saved_upstream_read` is the real counter.
- Git Bash/MINGW `/proc/uptime` is a valid monotonic clock; platform detection
  should test procfs readability, not `uname -s = Linux` (fixed in #1687).
- Windows managed launcher set is only: ai-gh, ai-gh-wait, ai-blocker-watch,
  ai-transcript-destination-check, ai-private-config. Other bin/* are
  Linux-managed by design.
- Windows has no install-manifest.tsv; launcher `source-sha`/`source-hash` are
  the receipt.
- `bin/ai-gh` is also git's credential helper — throttle lock stalls `git push`.
- Full required Linux receipt: `task-gates/install-stage-reports/<sha>.tsv` on
  edge-dev3 under `~/.local/state/ai-devops/task-gates/`.

## 6. Exact next steps

1. **Install duration adapter `4e172768` on edge-dev3** (installation class +
   assigned AI reviewer APPROVE). Do NOT install `818f8a1b`.
   Gate: live schema-5 rows emit `acceptance=qualified` with real latency.
2. **Fix item-2 adapter defects** (orphaned counters suite; identical-write
   skip vs waiter coalescing), then fresh independent APPROVE, then install.
   Gate: schema-6 rows record on live traffic; controlled replay reproduces.
3. **Collect ≥20 comparable useful workflows** after step 1 (declared window
   2026-10-14T13:00Z–2026-10-15T22:00Z, or the next equivalent). Gate: n≥20,
   p95 vs amended gate from https://github.com/popcre/ai-devops/blob/main/plan_github-request-reduction.md
4. **Item 3 savings**: freeze a `phase:baseline` cohort before the next
   optimization, then pair HTTP/GraphQL per ECO. Gate: R_candidate ≤ 0.70 ×
   R_baseline for both, or a precise unknown with reasons.
5. **Re-verify item 7** after PR #1686 install (detection ceiling).
6. **Close #660** remaining checklist (multi-host, after-workload) as those
   land; then P8; then close #658.

## 7. Constraints and gotchas in force

- Max 3 concurrent subagents; do not start a new one until fewer than 3 are
  active (owner 2026-10-12).
- Never manufacture demand or treat UNKNOWN as zero.
- Skip edge-alien and envy. Do not fight sync-dotfiles installs.
- `bin/ai-gh` for every GitHub call. Bounded waits. No admin merges.
- Installation class forbids `deploy`; use `ship` / `authorize-install`.
- Preserve the 916 counter stage and all private receipts on edge-dev3.
- Sign GitHub posts with `Posted by MiMo chat <id> on <machine>`.

## 8. Access and environment

- GitHub via managed caller (`bin/ai-gh` / `bin/ai-gh-app-auth`). Secrets only
  in 1Password vault `vibe_coding`.
- SSH from edge-dev3: `916`, `4837`, `edge-dev`, `edge-alien`, `edge-runn-envy`,
  `hetz`, `edgesynology1/2` in `~/.ssh/ai-devops.conf`. No `t16` alias.
- Private evidence: `/home/ahazan/.local/state/ai-devops/` on edge-dev3
  (`658-section13-*.private.md`, `658-*-20261012.private.md`, install proofs,
  measurement ledger, cohort receipts). Windows peers under
  `C:\Users\*\.local\state\ai-devops\`.
- Measurements: `~/.ai-devops/gh-throttle/measurements/*.jsonl` per host.

## 9. Open questions and risks

- **P8 cannot close** until items 2, 3, and 5 have qualified numbers.
- **4837 GitHub token is invalid** (HTTP 401) — routing proven, auth refresh
  needed before that host can contribute real traffic.
- **916 launcher `ebaacc11`** is not the `898e6209` pin used by 4837/edge-dev;
  treat as named drift, not silent.
- **t16** remains an external blocker (no trusted channel). Do not invent one.
- **Subagent deaths** (APIError / process restart) can abandon mid-task; check
  what landed before redoing work.

## Part B. Subagent closeout records (this session)

| id | task | outcome |
|---|---|---|
| general-14 | Windows install 916/4837/edge-dev | success — all at `898e6209` family with receipts |
| general-15 | Section 13 first pass | partial — 1 FAIL, 5 UNKNOWN, 1 PASS |
| general-16 | HTTP counter on managed paths | success — all 4 hosts non-null writes |
| general-17 | Duration clock adapter | success — PR #1687 merged `4e172768` |
| general-18 | Disposition ledger | success — 16/7/0 |
| general-19 | Cohort activation | success — `25e0f44f` live on 4 hosts |
| general-20 | Items 4+7 | success — 7 FAIL+fix `d9a1b3f9`; 4 later PASS |
| general-21/26 | Item 2 adapter | success code / reviews REJECT head `818f8a1b` |
| general-22 | #1212 | success — closed |
| general-23 | #660 | partial — baseline merged `bf88e64f`; checklist remains |
| general-24 | P3 #931/#933/#936 | success — all closed `3deb99a5` |
| general-25 | P5 P6 P7 | success — checked; child #1682 |
| general-27 | Item 4 amendment | success — REJECT then PASS from P1 windows `35e1d63d` |
| general-28/33 | Item 2 review/fix | failed — process restart abandon |
| general-29 | Item 5 workflows | partial — n_useful=0; window declared |
| general-30 | Item 4 PASS | success — two windows named |
| general-31 | Item 3 savings | success — UNKNOWN with real arithmetic |
| general-32/34 | Duration adapter install | failed — APIError / restart abandon |

## Completeness self-audit

1. Newcomer continuation: YES — §1–3 define scope, installs, scoreboard;
   §6 is ordered with gates and GitHub URLs.
2. Same effectiveness: YES — §4 records the rejected amendment, rejected
   adapter head, dead subagents, and the two-series trap.
3. Relevant details: YES — §3/§6–9 cover receipts, SHAs, unknowns, access.
4. Owner decisions: YES — sweep found none; §0 lists settled rulings only.

## Next-session prompt

Resume popcre/ai-devops issue #658 as coordinator. Read
https://github.com/popcre/ai-devops/blob/main/HANDOFF.d/2026-10-15T0236Z-edge-dev-mimo-658-section13-closeout.md
and https://github.com/popcre/ai-devops/blob/main/plan_github-request-reduction.md
STATUS. Goal: close section 13 and #658. Already done: four-host installs,
HTTP counter on all hosts, cohort live, item 4 PASS (two busy windows), item 6
PASS, item 7 fixed, P3 children closed, #1212 closed, #660 baseline merged.
Next action in order: (1) install duration adapter 4e172768 on edge-dev3 — do
NOT install 818f8a1b; (2) fix item-2 adapter defects then review and install;
(3) collect ≥20 qualified useful workflows (window declared in the handoff);
(4) item 3 needs a baseline cohort freeze before the next reduction. Verify
success via plan STATUS + live schema-5/schema-6 samples. Skip edge-alien and
envy. Max 3 subagents. Do not ask Albert for technical approval.

Posted by MiMo chat on edge-dev.
