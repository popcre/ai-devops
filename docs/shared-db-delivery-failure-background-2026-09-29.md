# What went wrong with shared-db delivery — full background (2026-09-29)

This is the complete narrative behind `plan_shared-db-coordination-deletion.md`. It exists so a future session (or reviewer) does not have to reconstruct the story from chat, and so nobody “fixes” the plan by adding process back without knowing what that process cost.

**Sources (private, not in this repo):** last-week chat transcripts under Albert’s Dropbox archive, TypeSafe Jev classification, local diagnosis files under `.ai/tmp/` (process diagnosis, issue churn, ground-up modify-vs-rebuild, diagnostic excerpts). **This document restates findings without raw private transcript text or secrets.**

---

## 1. The business problem, in Albert’s words

The shared-db orchestrator process was instituted to prevent collisions in database structure changes. Since then delivery has gotten **progressively worse**, until **almost no work gets done**. Every fix made it worse — “band-aid upon band-aid.” Albert asked whether to scrap the system and start from scratch.

A later operational fact (2026-09-29), from Albert: **“blockerwatch hasn't been working. despite repeated attempts to fix it, sessions were never registering anything with blockerwatch.”**

## 2. What was measured

### 2.1 One week of chat (TypeSafe Jev)

- **942** distinct session transcripts in 7 days (Claude / Codex / Grok across machines).
- Compact summaries (path + first user messages only) were classified with Jev `Noul` questions. **150** discarded at >90% confidence as **not** about shared-db failures/slowness. **792** remainder; **~72** strong signals for stalls, reviewers, CI, orchestrator handovers.
- Strong remainder themes (keyword tags): orchestrator/handover 54, reviewer-fail 29, merge-delivery 21, ci-slow 16, gates 16, stuck-waiting 15, process-broken 10.

### 2.2 24-hour issue churn

- Roughly **48 issue opens vs 26 closes** in shared-db-related transcripts; many closes were **old backlog**, not the new work.
- **155** “leftover-proof” and **308** “unproven step” mentions in 24h.
- **57** `gh issue create` vs **25** close-style command mentions.

### 2.3 Lived stall (from transcripts)

- Albert: **five** active Claude sessions each waiting on **3–5** things; “nothing is getting done”; **31** background helpers/waiters running on work the process itself created; the things they waited on **had already stopped**.
- A merge helper lived in a **chat session**; on restart: “The queue is not drained. Nothing has merged.”
- **~937–957 GitHub Actions runs in one hour** (~20 workflows per PR push).
- Exact-head APPROVE still failed merge on **API rate limit**.
- Windows runner **EDGE-RUNN-ENVY**: unchanged suites 13s → 18 min; 40-minute timeouts.
- Reviewer wrappers broke (Qwen sandbox `NODE_OPTIONS`; Gemini headless blocks commands → empty verdicts) and spawned their own incident/PR loops.
- False “collision” when a branch was merely behind main; protected-file allocator lock deadlocks (four PRs marked draft to break one).
- Orchestrator **marker succession** (#3570 → #3653 → …), ephemeral `/tmp` briefs wiped/overwritten, session restarts killing helpers.

## 3. What is NOT broken (keep)

The **safety engine** in `popcre/shared-db`:

- Exact-object **claims** + **permanent 14-digit version reservation** in GitHub refs (`refs/db-claims/<version>`, `refs/db-coordination/author-acquisition`).
- **Stage leases** for preview / merge / production (one writer at a time).
- Forward-only migrations, dependency closure, target-database proof.
- **Independent exact-head review** of the PR head.
- **Live behavior verification** before close; claim close requires an **exact stated reason**.
- Change log already exists **without** the orchestrator: `db-claim` issue (objects + version), migration SQL in the repo, PR (why), close reason.

Cross-machine: state is GitHub, not per-PC files. Overlap **fails closed** before SQL runs.

**Residual risk (accepted):** two tickets for the same *idea* with different object names. Caught by review + live proof; 30-day measure; stop rule = named assignee on that issue — never a new orchestrator.

## 4. What is broken (delete)

The **coordination layer**:

1. **Leftover-proof / “one unproven live-behavior outcome” as a ticket mill** — opening is cheap; closing needs review → checks → merge → preview → production → live proof. Queue grows while people are busy.
2. **Orchestrator as a required role** — markers, route_ids, succession, fan-out of “fixer” helpers, 31 self-created waiters.
3. **Chat merge conductor** — not a lock; dies on restart.
4. **Handoff ceremony** as required process (briefs in `/tmp` get wiped).
5. **Protected-file serialization** and **false collision checks** — not database-object collisions.
6. **~20 CI workflows per push**; unskippable unrelated required checks (path filters are **forbidden** by merge-queue guard; use aggregate `verification-closure`).
7. **Required BlockerWatch registration** — never adopted in practice (Albert’s fact; reliability plan STATUS still open). Keep only the **automatic** stuck-PR janitor (it is driven by the BlockerWatch tick after GitHub dropped `schedule:`).

## 5. Why every previous fix failed

`plan_shared-db-complete-throughput-repair.md` (#401) closed **complete** 2026-09-20 after live-proving trains, ledgers, alarms, fast lane, reviewer reroutes. **Same stall classes returned within days.** Reason: the **process shape** stayed (required orchestrator + ticket minting). This system converts every fix into a new rule, issue, or monitor.

## 6. Decision (LOCKED 2026-09-29)

**C by deletion** — keep the safety engine; delete the coordination layer; do **not** replace the coordinator with a new lock, scheduler, watchdog, or issue type.

| Keep | Delete |
|---|---|
| Claims, versions, stage leases | Required orchestrator role / markers |
| Exact-head review, live proof | Leftover-proof ticket mill |
| Train machinery (finish exclusivity as deletion of chat merges) | Chat merge conductor |
| Automatic stuck-PR janitor (re-pointed) | BlockerWatch registration / `has-wait` / `--park` |
| In-session `ai-pr-wait` | Path-filtered required checks; false collisions |

**Rejected:** A (keep orchestrator bones — #401 already failed that way); B (rebuild safety engine — weeks of zero delivery, transition is where collisions happen); single-flight lock; “duplicate need?” review question (new process); force BlockerWatch registration.

## 7. Reviewer context levels (why Opus disagreed)

| Reviewer | Background they actually had |
|---|---|
| **Grok** | Most: long debate brief + diagnosis files (churn, process, rebuild-vs-modify). Pushed **deletion**. |
| **StepFun** | Medium: tighter briefs + **live code verification**; Albert’s BlockerWatch fact in-turn. Verdicts REVISE / SHRINK. |
| **Claude Opus (`ai-claude-review`)** | Least: **plan + sealed repo snapshot only**. Private `.ai/tmp` diagnosis files are **not** in that snapshot. Protects existing tests/skills when it sees deletions. |

None of them had this chat. Opus’s first REJECT was correct about *execution* gaps (path filters, watchdog coupling, missing file names). Later REJECTs also defended keeping rules whose **cost** Opus never saw. **Do not re-add leftover-proof, required orchestrator, or wait registration to satisfy a reviewer that lacks this history.**

## 8. What must not come back

- Required orchestrator chat or marker as a condition to start work.
- Opening a new issue because live proof is missing (checklist on the **same** issue).
- Mandatory `ai-blocker-watch wait` / `--park`.
- New locks, map-watchers, issue types, or “duplicate need” review questions.
- Path filters on required checks.
- Reopening #401 as a programme.

## 9. Where things stand (2026-09-29)

- Implementation plan: `plan_shared-db-coordination-deletion.md` (merged, then hardened for Opus C1–C4).
- GitHub: parent **#1061**, children **#1065–#1077**.
- Jev skill: `jev-transcript-classify` under the MiMo skills root.
- Reviewer issues logged (Muse prep failure; Qwen quota).
- Claude review wrapper pin `--effort low`: PR **#1095** (independent review required — dispatch AI reviewer; **Albert does not review**).
- Open shared-db “parked” issues (waiting on conductor / after X merges / dead sessions) need a **one-time tidy** with implementation — not a new programme.

---

*Posted by MiMo. Private transcript excerpts and secrets stay out of this file.*
