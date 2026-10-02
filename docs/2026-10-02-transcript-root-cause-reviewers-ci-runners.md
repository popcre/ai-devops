# 72-hour transcript root-cause — Reviewers, CI, Runners (2026-10-02)

**Window:** 2026-09-29 18:00 EDT through 2026-10-02 18:16 EDT.
**Baseline:** [`ci-failures-and-github-rate-limit-report-2026-09-29.md`](ci-failures-and-github-rate-limit-report-2026-09-29.md) (2026-09-15 – 2026-09-29). This report answers: after those root causes were named and some mitigations landed, what is **still** failing and why did the prior fixes not close the problem?
**Repository:** `popcre/ai-devops` (public recovery toolkit). Raw transcripts are private; this report paraphrases and cites only machine/engine/session identifiers.

---

## 1. Executive summary (plain English)

Over the last three days the same three families of problems kept slowing work down. The earlier report named five root causes and a few mitigations landed near the end of September. Looking at what actually happened since then, here is what is still broken and why.

**Top 5 root causes why problems persist:**

1. **Reviewer tools are not fully installed on every machine.** On al8960ofc, the Qwen reviewer cannot run because its folder permissions are broken (the operating system refuses to change them), and two launcher scripts that the reviewer lifecycle depends on are missing from PATH. The code in the repository is fine; the machines are not set up to use it. Nobody has closed the gap between "code merged" and "installed and working on each computer."

2. **Windows CI proof jobs still get stuck or cancelled, and sessions work around them instead of fixing them.** WarpBuild proof workflows were cancelled or stuck in the queue repeatedly. At least one session merged a pull request "rather than rerun" the stuck proof. That is a proof gap: the change landed without the evidence that was supposed to gate it.

3. **GitHub rate limiting is still biting, even after the "separate identity" and "staggered schedules" mitigations.** Sessions still describe secondary rate limits and quota pressure. The mitigations reduced the worst synchronized bursts but did not eliminate the underlying volume problem — too many background watchers and waiters still share the same API budget.

4. **The reviewer-reliability and BlockerWatch repair plans are still largely open.** `plan_reviewer-reliability-and-efficiency.md` has several rows still requiring evidence; `plan_blockerwatch-reliability-repair.md` has every deliverable row open. Until those land, the same stuck-reviewer and stuck-wait failures will keep recurring.

5. **Sessions still declare completion without live proof.** Multiple transcripts show the pattern of a repair being described as done while the actual live check (a green CI run, a working reviewer call, an installed launcher) was never observed. This is the same "presence is not capability" lesson from the 2026-07-16 Codex incident, still happening at a process level.

---

## 2. Method

| Dimension | Detail |
|---|---|
| Window | 2026-09-29 18:00 EDT – 2026-10-02 18:16 EDT (72 hours) |
| Source root | Private multi-machine chat transcript archive |
| Machines in window | edge-dev, edge-dev3, al8960ofc, plus lighter traffic from others |
| Engines | codex, claude, grok, mimo, qwen, zcode |
| File count (all types) | 825 files modified in window |
| JSONL transcripts | 397 |
| Density by machine/engine | al8960ofc/claude 346, edge-dev/codex 177, edge-dev/grok 97, edge-dev/mimo 60, edge-dev3/claude 60, edge-dev3/codex 28, edge-dev/qwen 25, edge-dev/claude 12, edge-dev/zcode 12, al8960ofc/codex 5 |
| Skimmed | File names, session directory names, project/worktree names, first-message prompts, keyword hit counts across the full window |
| Deep-sampled | ~15 sessions: reviewer-install-check (al8960ofc/claude, 10-02), reviewer-logs-analysis (al8960ofc/claude, 10-01), edge-dev/codex reviewer-run cluster (09-30 and 10-01), edge-dev/codex 10-02 failure-heavy sessions, edge-dev3/codex 09-29 evening cluster, grok review-sandbox session |
| Baseline prior art | 2026-09-29 CI/rate-limit report; plan STATUS tables for reviewer-reliability, workflow-efficiency, blockerwatch-reliability, split-ci-suite-manifest; task-router reviewer/CI/runner rows; reviewer-rotation-rules; reviewer-issues |

Keyword counts below include some boilerplate (instruction text inside reviewer templates). Where that matters, the report says so and cites sessions where the phrase appears as an observed failure rather than a rule.

---

## 3. Findings by theme

### 3A. Reviewers

**Compared to the 2026-09-29 baseline — still open / newly open / appears fixed:**

| Pattern | Baseline status | 72h status |
|---|---|---|
| Reviewer stuck / cannot get a review | Open | **Still open.** Owner voice in a 10-02 session: work is "broken" and must be moved forward "without a review" rather than accepting stuck things. |
| Provider out-of-credit / quota refusal | Known | **Still open.** 106 precise hits across 55 files (operational phrases like out-of-credit, insufficient quota). |
| Qwen permissions on al8960ofc | Not in baseline | **Newly open.** Folder ACL change fails with access denied; Qwen wrapper cannot enforce its security boundary. |
| Missing lifecycle launchers | Not in baseline | **Newly open.** `ai-reviewer-start-watch` and at least one post-merge hook launcher reported missing from PATH on al8960ofc. |
| Reviewer timeout masquerading as bad review | Known (plan P7 open) | **Still open.** Transient health timeouts still indistinguishable from real reviewer failures; plan row P7 explicitly open. |
| Reviewer rotation / membership drift | Mitigated | **Appears quiet** in this window — no live drift incidents sampled. |

**Concrete failure patterns and frequency:**

- **Qwen folder permissions broken (al8960ofc, 10-02).** The installer/check session ran a folder ACL change on the Qwen state directory and the operating system returned access denied / exit code 5. The wrapper then refuses to run because it cannot enforce its security boundary. This is a machine-local install defect, not a code defect. Earliest and latest in window: 2026-10-02.
- **Missing launchers (al8960ofc, 10-01 and 10-02).** Doctor output listed missing `ai-reviewer-start-watch` launcher (both extensionless and `.cmd` forms) and a missing post-merge hook launcher. These are the tools that detect a reviewer that was drawn but never started, and that install post-merge behavior. Without them the reviewer lifecycle silently degrades. Earliest: 2026-10-01 (sync-dotfiles session); latest: 2026-10-02.
- **Out-of-credit / quota refusals (multiple machines, whole window).** 106 operational hits in 55 files. Wrappers correctly stop and tell the owner, but the underlying credit/quota supply still runs out mid-work.
- **Stuck reviews forcing bypass (al8960ofc, 10-02).** Owner-directed instruction in session: when a review is stuck, move the work forward rather than sit and accept stuck things. That is a process workaround for a reliability gap, and it creates proof gaps (see §6).
- **Reviewer runs themselves are high-volume.** The edge-dev/codex directory contains a dense burst of READ-ONLY plan-review and final-check runs on 09-30 and 10-01 (roughly 20+ sessions in ~24 hours). Many keyword hits in those files are the review template language, not failures — but the volume itself burns quota and queue capacity.

**Machines/engines:** al8960ofc (claude + codex) for install/permission defects; edge-dev (codex) for review-run volume; edge-dev3 (codex) for wrapper-contract test sessions; grok for review-sandbox runs.

### 3B. CI

**Compared to baseline:**

| Pattern | Baseline FM | 72h status |
|---|---|---|
| Superseded CI pileup / merge-queue Windows re-runs | FM-1 | **Appears improved.** `plan_split-ci-suite-manifest` is complete (steps 0–5 done 2026-09-30). Not re-proposed here. |
| Windows CI timeouts looking like product bugs | FM-2 | **Still open, new form.** WarpBuild proof jobs now show as cancelled/stuck rather than timeout-as-failure, but the effect is the same: missing or unusable CI evidence. |
| Secondary rate limits from synchronized bursts | FM-3 | **Still open.** 344 precise hits in 142 files. Staggering and identity separation reduced but did not eliminate it. |
| Background automation on personal quota | FM-4 | **Appears improved** (separate GitHub App identity landed). Residual volume still high. |
| Flaky timing tests under load | FM-5 | **Appears quiet** in this 72h sample. |

**Concrete failure patterns:**

- **WarpBuild proof jobs cancelled or stuck (17 files, 76 precise hits).** Windows offline WarpBuild proof workflows were observed in CANCELLED / FAILURE states. Sessions then had to decide whether to rerun, merge without proof, or route elsewhere. One session explicitly merged "rather than rerun" the stuck WarpBuild proof — a proof gap. Earliest in window: 2026-09-30; latest: 2026-10-02.
- **Windows checks queued on the free lane (edge-dev, 10-02).** Subagent guidance in the install-check session: work is "stuck with Windows checks queued on the free lane" and should be routed to the Blacksmith paid lane. That means the free Windows lane is still a bottleneck and the routing decision is still manual.
- **Merge-queue waits still complex (edge-dev3, 09-28 – 09-29).** Sessions track PR state through bounded waiters, note OPEN/queued transitions, and handle ejections. The machinery works but requires constant attention; ejection still leaves a PR OPEN and needs diagnosis rather than a blind rerun.
- **Required-check name traps and queue CLI traps** still appear in session context (merge-queue required-check name trap, queue CLI traps doc references). These are known sharp edges that keep catching sessions.

### 3C. Runners

**Compared to baseline:** the baseline treated runners mainly as a CI-capacity problem (FM-1/FM-2). In this window the runner story is narrower and more operational.

- **WarpBuild proofs stuck in queue (66 files, 395 broad hits; concentrated in the 10-01 – 10-02 sessions).** The recurring shape is: a WarpBuild Windows proof is dispatched, it sits in the queue or gets cancelled, and the session has to choose a workaround. This is the single most common runner-related failure in the window.
- **Windows runner routing config being adjusted.** Sessions edit `runner-routing.json` (e.g. changing `windows_sections`) and dispatch `windows-offline-blacksmith.yml` manually. That is live tuning of a system that is not yet stable enough to run unattended.
- **Runner "offline / not picking up" as a literal state is rare** (9 hits in 4 files). The dominant problem is not runners being down; it is the proof/queue lane around them being slow or stuck.
- **Qualification/canary:** WarpBuild canary and Windows runner qualification workflows exist and are referenced, but no fresh qualification failure was deep-sampled in this window. Prior work on `plan_windows-runner-maintenance-elevation` remains gated on live proof.

---

## 4. Root-cause analysis — why these keep recurring

1. **The install gap.** The repository ships code, wrappers, and launchers, but there is no single enforced "every machine has every launcher and every provider folder is healthy" acceptance. `ai-devops doctor` exists and was used on 10-02, which is how the Qwen and launcher defects were found — but they were found *after* work had already been blocked, not prevented. Missing launchers and broken folder ACLs are machine-local state that repo merges do not fix.

2. **Proof gaps get accepted under time pressure.** When a WarpBuild proof is stuck, the path of least resistance is to merge anyway or skip the rerun. That converts a CI/runner problem into a silent quality gap. The standing rule says a repair is complete only with live proof, but there is no gate that *stops* a merge when the proof was skipped — only instructions.

3. **Capacity and quota are still shared.** Even after staggering watchers and splitting identities, the total volume of reviewer runs, waiters, and background jobs is high enough to hit secondary limits. The 09-30 – 10-01 review-run burst alone is dozens of sessions in a day. Without a hard budget on concurrent review runs and waiter polling, the rate-limit problem will recur whenever work clusters.

4. **Repair plans that are "code landed" but not "installed and proven."** Several plan rows are complete in source but their acceptance evidence (installed proof, live proof, maintenance-round closure) is still open. `plan_reviewer-reliability-and-efficiency` explicitly warns that treating docs or a demo as live repair closure is a failure mode. The same pattern shows up in the transcripts: sessions describe fixes while the live capability is still broken on a machine.

5. **State that lives outside Git.** Reviewer credentials, folder ACLs, launcher installs, runner routing config on disk, and BlockerWatch state are all machine-local. A merged PR does not touch them. Cross-machine memory sync and dotfile sync sessions appear in the window precisely because this state keeps drifting, and the sync itself has been a source of loss in the past (per `docs/critical-incidents.md`).

---

## 5. What previous repairs got wrong or were incomplete

| Prior repair | What it fixed | What it missed (evidence in window) |
|---|---|---|
| `plan_split-ci-suite-manifest` (COMPLETE 2026-09-30) | CI suite splitting; reduced merge-queue Windows re-runs | Did not address WarpBuild proof lane stalls. Proofs still cancelled/stuck on 10-01 – 10-02. |
| Staggered watcher schedules + separate GitHub App identity (late Sept) | Reduced synchronized secondary-limit bursts | Residual rate-limit and quota pressure still observed (344 precise hits). Volume, not just synchronization, is the remaining driver. |
| `plan_reviewer-reliability-and-efficiency` (STATUS) | Many component rows complete (source identity, terminal outcomes, evidence, availability, Codex Windows read-only) | Rows on integrated qualification closure and live acceptance still require evidence. P7-style timeout/identity confusion persists. |
| `plan_blockerwatch-reliability-repair` (STATUS) | — | **All seven deliverable rows open.** Registration, resume, recovery lifecycle, dependency scanning, enforced registration, staged rollout, and reconciliation are unimplemented. Waits over ~10 minutes therefore still depend on behavior the plan says is unreliable. |
| `plan_workflow-efficiency` (STATUS) | Selector activation, some parallel-reviewer work (P3–P6 partial) | P7 (timeouts masquerading as bad reviewers) open; P0/P1/P2/P8–P10 open. Known-fast-failure stop is only partially live. |
| `plan_windows-runner-maintenance-elevation` (STATUS) | One allowlisted refresh operation | Live host proof and installation proof remain separate gated outcomes; window shows no completed live proof. |
| Provider credit/quota handling (wrappers exit 92 and tell owner) | Correct, honest failure signaling | Does not prevent the outage. Credits still run out; work still stalls. |

---

## 6. Cross-cutting failure modes

- **False completion / proof gaps.** The most dangerous cross-cutting pattern. "Merged rather than rerun" when WarpBuild proofs were stuck; repairs described as done without installed or live proof; owner instruction to push work forward without a review when reviews are stuck. Each of these creates a change that landed without the evidence the process requires. The 2026-07-16 lesson ("presence is not capability") applies at the process level now, not just the tool level.
- **GitHub rate limits.** Still present after mitigation. Secondary limits from bursts and quota pressure from volume. Any new CI remediation plan must budget API traffic as a first-class constraint, not an afterthought.
- **Worktrees.** Ubiquitous in the corpus (every session runs in a worktree). No new worktree-corruption incident was deep-sampled, but the sheer number of concurrent worktrees across machines is a standing risk for state drift and cleanup mistakes (see `cleanup-worktree` and `docs/critical-incidents.md`).
- **Locks.** `bin/ai-gh` machine-wide lock is in use. No lock-deadlock incident was sampled in this window; treat as quiet but unverified at fleet scale.
- **Private/public boundary.** No new leak found in this window. The standing risk (historical transcript blobs in public history, per `bugs.md` finding 1) remains open and is unrelated to these 72 hours.

---

## 7. Evidence table

| Pattern | Example session (machine / engine / session id) | What it proves |
|---|---|---|
| Qwen folder permissions broken | al8960ofc / claude / `C--repos-ai-devops-worktrees-reviewer-install-check-b79425` → `4eb419bf-f2e8-4145-a843-cdff7bf88f3c` | ACL change on Qwen state dir fails with access denied; wrapper cannot enforce security boundary. |
| Missing lifecycle launchers | al8960ofc / claude / same session + subagent `agent-a3a344bfae1ff35b5` | Doctor reports missing `ai-reviewer-start-watch` and post-merge hook launchers. |
| Reviewer logs being audited for problems | al8960ofc / claude / `reviewer-logs-analysis-af70b5` → `e6011eff-5d39-4606-8884-c9b4cae24a76` (10-01) | Owner asked directly whether there is a reviewer problem; logs were being read as evidence. |
| Stuck review forcing bypass | al8960ofc / claude / `4eb419bf-…` (10-02) | Owner instruction to move work forward without a review rather than accept stuck things. |
| WarpBuild proof cancelled / stuck | edge-dev / codex / `rollout-2026-10-02T15-14-41-…` and `rollout-2026-10-02T15-23-58-…` | Proof workflows in CANCELLED/FAILURE states; sessions decide whether to rerun or merge without them. |
| Merged rather than rerun stuck proof | al8960ofc / claude / `4eb419bf-…` subagent context | Explicit proof gap: landed without the gating WarpBuild proof. |
| Windows checks stuck on free lane | al8960ofc / claude / `4eb419bf-…` subagent `agent-a3a344bfae1ff35b5` | Guidance to route to Blacksmith paid lane; free lane still a bottleneck. |
| High-volume review-run burst | edge-dev / codex / `sessions/2026/09/30/rollout-2026-09-30T19-*-…` through `2026/10/01/rollout-2026-10-01T13-*-…` (20+ runs) | Reviewer demand itself is a capacity and quota driver. |
| Merge-queue OPEN/queued tracking | edge-dev3 / codex / `rollout-2026-09-28T09-09-02-…` and 09-29 evening cluster | Queue ejection leaves PR OPEN; bounded waiters required; reruns must be diagnosed not blind. |
| Out-of-credit / quota refusals | al8960ofc / codex / `rollout-2026-10-02T15-39-33-…` and others (55 files) | Provider wrappers correctly stop on credit exhaustion; work still stalls. |
| Rate-limit / secondary-limit pressure | edge-dev / codex / `rollout-2026-10-02T15-14-41-…` (quota/rate-limit tooling text) and 142 files with precise hits | Volume and burst problems persist after staggering/identity mitigations. |
| Reviewer wrapper contract tests | edge-dev3 / codex / `rollout-2026-09-29T22-14-42-…` | Reject/refuse paths being tested (content-filter, model mismatch, same-turn re-verification) — lifecycle is exercised but fragile. |
| Grok review verdict REJECT | edge-dev / grok / `rlc-grok-aa34603c7bb0-…` → `01a0fd88-…` | Reviews do run end-to-end on Grok; rejections with safety reasons are a real terminal outcome, not an infra failure. |

---

## 8. Recommended fix priorities (ranked, no implementation)

1. **Close the machine-install gap.** Make "every machine has every launcher, every provider folder is healthy, doctor passes" a single enforced acceptance before any reviewer or CI work is considered done on that machine. Fix the Qwen ACL defect and the missing launchers first — they are small, local, and currently blocking a whole reviewer.
2. **Stop accepting merges without their gating proof.** When a WarpBuild (or any required) proof is stuck or cancelled, the default must be to fix or rerun the proof, not to merge around it. If a bypass is truly necessary, it needs a named, tracked proof debt item — not silence.
3. **Budget GitHub API traffic as a hard constraint.** Cap concurrent review runs and waiter polling per machine and per identity. The 09-30 – 10-01 review burst shows demand can still overwhelm the mitigations. Consider a single fleet-wide review-run scheduler.
4. **Land the open BlockerWatch and reviewer-reliability rows.** `plan_blockerwatch-reliability-repair` (all rows open) and the remaining `plan_reviewer-reliability-and-efficiency` acceptance rows are the structural fix for stuck waits and stuck reviews. Until they land, every session re-invents the same workaround.
5. **Separate timeout from failure in reviewer/CI signals.** Plan row P7 is the named owner. A transient health timeout must not look like a bad review or a bad product; it needs its own terminal state and its own bounded retry, distinct from identity drift or authentication failure.

---

*Prepared from private multi-machine chat transcripts (72-hour window) and public repository documentation. No raw transcript content, secrets, or private business data are included. Session references are machine + engine + session identifier only.*
