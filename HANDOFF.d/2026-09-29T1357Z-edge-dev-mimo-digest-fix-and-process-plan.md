---
issue: 1060
status: OPEN
owner: mimo/sandbox-digest-full-index
---

# HANDOFF — digest fix PR, Jev skill, process-mining plan (2026-09-29)

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

Put this WHOLE list to Albert in ONE message before starting work.

**Blocking**
- None blocks the digest-fix PR itself. Independent exact-head review is required before merge (reviewer-safety path) — that is a process gate, not an owner decision.

**Wrong guess is recoverable**
1. **Re-cut the process-improvement plan or drop it?** GLM verdict was REVISE: keep three items (bounded preflights, pin-only qualification, CI queue/cost visibility); fold the rest into existing plans (#658, #650, #131, live-proof-session-sizing, BlockerWatch). **Recommendation: accept GLM's cut; do not add a 40th plan file.** Blocks: whether any new `plan_process-improvements.md` is written. Owner has not ruled yet.
2. **Land PR #1060 after independent review?** **Recommendation: yes.** Blocks: every future Muse/Grok/GLM packet build on machines with shallow snapshots.

**Not in this workstream, nobody on it**
3. **Muse/Grok packet failures on edge-dev** (incidents `20260929T125838Z-edge-dev-muse-1961321`, `20260929T130211Z-edge-dev-grok-1989270`) should be closed only after #1060 is installed and a live packet build is proven. **Recommendation: keep open until then.**

**Already settled — do NOT re-ask**
- Jev is advisory only; never opens gates (plan_typesafe-jev-decision-layer.md).
- Albert explicitly asked for GLM critique (2026-09-29) despite GLM being out of rotation — that one-off is done.
- TypeSafe key stays in 1Password `vibe_coding` / `typesafe.ai API` / field `credential`; never print.

## 1. What this application is

`popcre/ai-devops` is Albert's public recovery and operating toolkit for a multi-model AI workflow: wrappers (`ai-glm`, `ai-grok-review`, `ai-gemini`, `ai-muse`, …), reviewer evidence tools (`bin/ai-review-sandbox`, `bin/ai-review-packet`), task gates, skills, and install scripts. Not an app or database. GitHub `main` is protected; work lands via branch + PR + merge queue. Installation from this repo is deployment. This session ran on Windows host `edge-dev` from `C:\repos\ai-devops` (canonical, landing-only; task work in worktrees).

## 2. What we set out to do this session, and why

1. **Classify private chat transcripts** (last 3 weeks under `C:\Users\ahazan\Dropbox\ai\chat_transcripts`) with TypeSafe Jev, drop those clearly unrelated to AI DevOps failures/slowness, and mine the remainder for process improvements in this repo.
2. **Critique that improvement plan** with Muse, then (after Muse failed) Grok, then (after packet failures) GLM; update the `jev-transcript-classify` skill with what worked.
3. **Land the snapshot-digest fix** as a PR and get Gemini to review the plan + GLM cut from a clean worktree.

## 3. Current state — what is true right now

**Done and verified**
- Jev classified 1,346 unique session digests (from ~2,079 files). 40 discarded at confidence >90% not-related; 1,306 remainder. Scratch: `%TEMP%\jev_digests.jsonl`, `jev_classified.jsonl`, `jev_remainder.jsonl`.
- Subagent deep-read 22 transcripts and wrote 9 ranked process improvements. **Full substance is in §5a of this file** (TEMP copy may be gone).
- Skill `C:\Users\ahazan\.config\mimocode\skills\jev-transcript-classify\SKILL.md` rewritten with archive layout, batching, polarity, privacy, and what not to do. Locales already present.
- GLM critique completed (session `jev-plan-critique-20260929`, model glm-5.3). Verdict **REVISE**. Report: `C:/repos/ai-devops/.ai/reviews/glm-jev-plan-critique-20260929-b33a60737869a5b249f9e0c80ad81ab56a39d68e1c56f29c44b70dcb4701730b.md`.
- Root cause of `snapshot-digest-mismatch`: `source_inventory` hashed `git diff HEAD` text; shallow snapshots abbreviate the index line to a different width than the full ODB. Fix: `--full-index` in `bin/ai-review-sandbox`.
- **PR #1060** https://github.com/popcre/ai-devops/pull/1060 — commit `a8cc7964` on `mimo/sandbox-digest-full-index` (worktree `C:\repos\ai-devops-wt-sandbox-full-index`). Files: `bin/ai-review-sandbox`, `tests/test-ai-review-sandbox.sh` (new case `shallow_and_full_odb_agree_on_source_digest`).
- `bash tests/test-ai-review-sandbox.sh` in that worktree: **109 passed, 0 failed**.
- Reviewer incidents recorded on edge-dev (see §8).

**In progress / not done**
- `tests/test-ai-review-packet.sh` was still running (120 `ok` lines, no final summary) at wrap-up; log `/tmp/packet-tests.log` (Git Bash temp on edge-dev). Not a failure — incomplete run.
- **Independent exact-head review of #1060 not started** (required before merge).
- **Gemini review of the process plan + GLM cut NOT started.** Gemini is eligible (`ai-review-preflight usable gemini` true; doctor PASS `gemini-3.8-flash-high`; usage 47% weekly / 96% 5h at 13:30 UTC). Must run from a **clean worktree** (packet builder rejects dirty trees). Clean worktree already exists: `C:\repos\ai-devops-wt-sandbox-full-index` after the commit (or a fresh one from `origin/main` for a plan-only review).
- PR #1060 not merged. Branch kept.
- Plan re-cut (GLM's shape) not written.

**Committed / pushed**
- `a8cc7964` pushed to `origin/mimo/sandbox-digest-full-index`. Not on `main`.

## 4. Everything we tried that did NOT work

1. **Muse `ai-muse new jev-plan-critique-2026-09-29`** — process killed (`ChildProcess.kill`); session left unreconcilable (`reconcile` said no successful retained process). Lesson: do not reuse that name; a replacement session was started.
2. **Muse `jev-plan-critique-20260929-b`** — printed session start then `ai-review-packet: error: snapshot-digest-mismatch`.
3. **Grok `ai-grok-review new jev-plan-critique-grok-20260929`** — same `snapshot-digest-mismatch`. Not a Grok defect.
4. **GLM first attempt** — same packet error until the `--full-index` fix was applied **in the live checkout** (uncommitted). After the local fix, GLM completed.
5. **`bash -lc` from PowerShell** — resolves to WSL (no distro). Use `C:\Program Files\Git\bin\bash.exe -lc` for wrapper scripts.
6. **Packet test suite hang** — `tests/test-ai-review-packet.sh` exceeded 3–5 minute tool timeouts while still printing `ok`; do not treat timeout as failure without reading the log tail.
7. **Sending full transcript JSONL to Jev** — never done (privacy). Digests only. The 2026-09-15 ~19:00–19:45 canned burst is evaluation fixtures (~122 sessions); exclude from evidence.

## 5. Root causes and key findings

### 5a. Transcript-mined process findings (the substance — do not lose this)

Corpus: 1,306 sessions (2026-09-08→09-29; codex 877 / claude 400 / grok 29) after Jev dropped 40 clearly unrelated. 122 were the 2026-09-15 fixture burst (canned one-liners — ignore). 22 substantial transcripts deep-read; paraphrases only.

**Pattern (executive):** pain is the toolkit's own reviewer/CI machinery failing closed or hanging — not app bugs. All four rotation reviewers dead on one machine; review server hang/crash loop for days; doctor blew its own 60s preflight so every review failed; one bare PASS with empty report. CI is one funnel (flaky wall-clock tests re-ran ~6h suites ~25× in 24h; ~30 queued runs). Shared 5,000/hr GitHub quota. Sessions overshoot (multi-day, 3–5 compactions, 14h orphans, repeat loops). Registry/install drift.

| # | Finding (short) | Evidence (counts / named sessions) | Proposed change | GLM cut (2026-09-29) |
|---|---|---|---|---|
| 1 | Reviewer registry in two places rots; empty verdict → false green | ~116 reviewer-keyword sessions; #686 (4 preflights dead, 2 days), #285, #283 | One registry + drift CI; empty verdict = FAILURE; lease TTL | **Shrink to S residuals:** lease TTL/reclaim + empty-report → mark provider unavailable. Registry/empty-report fail-closed largely **already exist** (`bin/ai-reviewer-membership-drift`, `bin/ai-review-pool` empty-report). Verify whether the cited incident predates that merge. |
| 2 | Preflight/doctor does sweeps and times out — fleet-wide review outage | Deep reads: ai-glm doctor >60s; Muse 10s preflight; OpenCode crash loop | Cheap O(1) preflight only; sweeps to scheduled maintenance; wall-time regress check | **KEEP — do first (S not M).** Strongest item. Smallest first PR: remove prune/reconcile from doctor preflight + generous upper-bound regress check. |
| 3 | Pin bump after auto-update took two days / full re-qual | #686 Grok UNQUALIFIED after self-update; 7 preflight-friction sessions | Pin-only lane: hash + doctor + one smoke; auto-quarantine on mismatch | **KEEP (S).** Still needs independent exact-head review for reviewer-safety; lane does not replace it. |
| 4 | Wall-clock asserts flaked; 24h no-progress suite loops | ~42 CI sessions; flaky #89 tests; test-infra redesign | Ban wall-clock asserts; suite timeouts; no-progress detector | **Partial.** Overlaps #650 / `plan_workflow-efficiency` P3/P6/P7. New slice = no-progress detector + per-suite auto-cancel. **Contradiction with #2:** ban must exempt generous upper-bound regress checks (doctor). |
| 5 | Shared 5,000/hr GitHub quota; holds on rate-limit | ~29 quota sessions; rate-limit separation work; #658 data | Apps-per-workload; lint away direct `gh`; show remaining quota | **Re-scope, drop L multi-App.** Finish #658 P5 (BlockerWatch → existing App) first; then measure. Lint + quota display are cheap. |
| 6 | Multi-day sessions, orphans, cold BlockerWatch wakeups | 105 handoff/continuation; 21 loop/24h; Qwen 14h task; StepFun repeat loop | One unproven outcome/session (already a rule); task TTL+reap; resume-on-wake | **Mostly already shipped** (`plan_live-proof-session-sizing`). Residues: TTL/reap + wakeup resume (under BlockerWatch plan). Do not re-propose the locked sentence. |
| 7 | Collisions; superseded-head reviews; handoffs that block free work | 64 worktree/collision; owner "LOT of collisions"; #2026-09-28 blocked-sessions | Hard pre-edit claims + CI reject unclaimed diffs | **Wrong fix as specified.** #131 already chose **advisory-first** then measure. Do not hard-gate yet. Handoff rule: ban condition-free *technical* "do not" only — **owner rulings stay exempt**. |
| 8 | Install/MCP drift rediscovered by hand (PATH dupes, stale `op://`, SSH) | 57 install/MCP sessions; qwen 0.21 vs 0.23; "half of MCP failing" | `ai-fleet-doctor` at session start | **Reuse `ai-machine-tools-doctor`**, cached/scheduled — not a new full sweep in the check path (that repeats bug #2). |
| 9 | No single "why is nothing moving" for queue/cost | Deep reads: ENVY/Windows runner, merge queue, Blacksmith cost; 42 CI-queue | `ai-ci-status` + lane policy | **KEEP** (genuinely new, read-only). Auto-cancel of "superseded" queue entries is risky — needs a precise definition or it kills exact-head evidence (review-packet race plan). |

**GLM's missing adds:** (a) one-page loss ledger (incident class → hours lost → owning plan) so ranking is by cost not vividness; (b) explicit plan-backlog consolidation session (~40 `plan_*.md` already; this proposal would be #41).

**GLM verdict:** REVISE — do not add a new parallel programme. Keep 2, 3, 9; fold 1/4/5/6/7 into #658, #650, #131, live-proof-session-sizing, BlockerWatch. First proving PR = doctor sweep removal + wall-time regress check. Second = pin-only lane.

**Disregarded (do not re-mine as signal):**
- **2026-09-15 fixture burst (~122 sessions):** canned one-liners ("CI is still running…", "The Kimi reviewer wrapper crashed…") duplicated across Claude and Codex within minutes, tiny sizes, empty titles. Evaluation fixtures. Counted once as a note only.
- **Grok remainder (29):** almost all session-id stubs, empty excerpts.
- **p>0.8 tail:** Supabase, ColdLion, Disney/HTS, website work — outside toolkit process.
- **shared-db orchestrator mega-sessions (up to 54MB):** app/DB delivery; mined only for reviewer/rate-limit/CI-tooling failures.
- **Session size alone:** tool-result bloat inflates bytes; use wall-clock span from timestamps when judging waste.

**Corpus mechanics (how the numbers were made):**
- Root: `C:\Users\ahazan\Dropbox\ai\chat_transcripts\{edge-dev,edge-dev3}\…` (machines only those two in this window).
- Units: Claude UUID `*.jsonl` (not subagents/tool-results), Codex `rollout-*.jsonl`, Grok `summary.json`. ~2,079 files → 1,346 unique digests (`sha1(cwd|excerpt[:240])`).
- Jev Noul "this session does NOT primarily concern failures/slowness in AI DevOps…"; discard only at `p>0.90` → 40 discarded, 1,306 remainder. Theme hits on title+excerpt of remainder: CI 99, reviewer 83, wait 60, blocker 44, fail 43, merge 43, runner 25, queue 16, install 15, wrapper 12, rate-limit 5. Keyword counts undercount (excerpt only).
- Deep-read 22 substantial sessions (not 22 of 1,306 linearly). Size>1MB: 735 files.

**Deep-read index (session digest → theme; paths are under the Dropbox transcript root):**

| Digest | Theme |
|---|---|
| 552e8c11532c | All four reviewers fail preflight (#686, ~2 days) |
| a401cb275650 | ai-glm OpenCode crash loop (6 days; CloseWait hang) |
| 304c7949d9f1 | doctor >60s preflight (per-record process spawns ~0.1s on Windows) |
| 5c73f1d4a1ff | Gemini bare PASS / registry drift (#285) |
| a7991fe608ca | Muse model_not_found (#683) |
| 2f4ce1b84511 | Dead reviewer lease (#283) |
| cd232fff9152 | Qwen reviewer logs; 8 mistake rounds found one at a time; 14h orphan task |
| d504cdb07574 | Muse live preflight timeout default 10s |
| b30403745856 | Flaky wall-clock tests (#89) |
| 19727c2f4a1a | Test infra redesign after 24h loops |
| 432e1fad1fbd | Runner-safety over-blocking |
| 97d14683d623 | Windows runner / ENVY / ~30 queued runs |
| 509116c2b044 | Merge queue funnel + preview DB |
| eaa68b8be9ef | Blacksmith cost shock |
| eaec492c8948 | GitHub rate-limit separation (Apps) |
| c996d7ec5a9b | API-hit reduction plan implementation |
| aff0b3a070f1 | Half of MCP servers failing |
| a9cf7a2a0391 | Duplicate qwen installs / PATH shadowing |
| a324e4d4a683 | Qwen vault / 1Password connection |
| 8cae63550af6 | Superseded-head failure code |
| cfcf33b6fcd5 | Blocked sessions / stuck CI queue ("alternative to github?") |
| ad61d3296df1 | StepFun reviewer + repeat loop |
| 88350b3b04e5 | Handoff wording caused idle waiting (condition-free "do not") |
| c31b6ce5eb3a | BlockerWatch cold-start pickup (lost context) |

**Per-item detail (fuller than the table):**

1. **Reviewer registry + empty verdicts.** Membership in at least two places (ai-devops mirror vs shared-db allocator) rots: retired providers still listed, out-of-credit still assigned, ~1 hour spent reaching a removed reviewer. One provider "available" but no verdict + bare PASS (false green). ~116 sessions / 48 substantial. Qwen log session found 8 mistakes one at a time. Change (original): one registry + CI fail on mirror disagreement; empty/no-verdict = FAILURE never PASS; lease TTL/reclaim. GLM: membership-drift check already exists (`bin/ai-reviewer-membership-drift`); empty-report fail-closed already at `bin/ai-review-pool` (reject empty report; lifecycle tests `tests/test-ai-review-lifecycle.sh` cover approval-with-empty-report → BLOCKED). Residuals only: lease TTL; empty-report should mark provider unavailable in capacity record (`bin/ai-review-preflight` already has `malformed-response` vocabulary to extend).

2. **Bounded preflight (do first).** `ai-glm doctor` ran prune/reconcile inline (per-record spawns); at ~150 records blew 60s governed preflight → every GLM review failed "doctor did not answer within 60s". Separate preflight 10s default too short for legitimate starts. Fixes took 5–6 days + several compactions. Preflight already wraps probes in `timeout` and caps capacity at 5s — the incident is doctor sweeping in the check path. Surgical fix is S: move sweeps to scheduled maintenance; regress-check doctor wall-time (generous upper bound only).

3. **Pin-only qualification.** Provider auto-updated past pin → whole pool down; Grok UNQUALIFIED; two days repair; owner asked why a version bump needs "a whole check, windows run, etc." Pin-only lane: hash binary + doctor + one live smoke; auto-quarantine on mismatch, auto-restore when pin updates in the same change. Still a reviewer-safety path (independent exact-head review required).

4. **Wall-clock tests / suite budgets.** Timing asserts flaked under load; one session re-ran a ~6-hour suite ~25 times in 24h; sibling did the same; owner: checks "go on for 48 hours and then fail." Ban exact timing asserts + sleep-sync; deterministic fixtures; per-suite timeout + auto-cancel; no-progress detector (N identical failures ⇒ stop and file). Scope ban carefully so #2's doctor wall-time upper-bound check remains legal. `docs/development.md` already warns wall-clock budget failures mislead.

5. **GitHub quota.** All helpers shared one 5,000/hr allowance; holds ("hold off until…"); sessions still ask whether the reduction plan landed (~29 sessions). `bin/ai-gh` already has quota thresholds, spacing, back-off. #658/#660 measure BlockerWatch ≈95% of traffic; P5 = move BlockerWatch to the existing pop-ai-watchers App (`bin/ai-gh-app-auth` exists). Then lint direct `gh`, publish remaining quota in `ai-gh` output. Defer multi-App split until post-P5 measurement.

6. **Session sizing.** Multi-day runs, 3–5 compactions, 14h orphan background tasks, loops with no change (owner: "what did I do that made you repeat the same thing over and over?"); owner intervened at 80/142 minutes to kill stalled tasks; BlockerWatch wakeups start a cold session (105 continuation/handoff hits; 21 explicit loop/24h language). "One unproven outcome per session" is already locked + phrase-guarded (`plan_live-proof-session-sizing`, `tests/test-client-globals-required-phrases.sh`). Residues only: task TTL+reap with summary; wake = resume parked session or machine-readable state file (see `plan_blockerwatch-reliability-repair.md`).

7. **Collisions / work-claims.** Owner: "we've had a LOT of collisions in ai-devops." Parallel sessions on same wrappers; one commit broke another; superseded-head reviews; a handoff forbade work while a runner was idle → session waited though a slot was free (condition-free prohibition). 64 collision/worktree-keyword sessions. #131 `plan_ai-devops-work-claims.md` already specifies advisory PR guard + frozen schema; hard CI rejection only after 30-day measurement. Handoff template: technical prohibitions need a machine-checkable condition or expiry; **owner-ruling blocks stay condition-free**.

8. **Install drift.** Duplicate CLIs shadow PATH (qwen 0.21.15 vs 0.23.0); stale 1Password names break MCP ("half the MCP servers are now failing"); SSH host-key failures; `op` missing so wrapper preflight fails. 57 sessions. Prefer extending `ai-machine-tools-doctor` (reuse rule) with versions-vs-pins, duplicate PATH, `op://` resolution, MCP health, known_hosts — **cached/scheduled**, cheap staleness check at session start only (else repeats bug #2).

9. **CI/queue visibility.** ~30 queued runs; adding a runner felt like "30 wasted minutes before the slow backup lane"; unclear merge ownership; "checks never pass"; Blacksmith judged extremely expensive mid-investigation; "alternative to github?" asked in frustration. No existing queue-depth/cost tool in `bin/`. Keep `ai-ci-status` (queue depth, lane wait, tip-PR owner, cost/day) + published lane-capacity policy. Auto-cancel superseded queue entries needs a precise supersession definition (review-packet race plan keeps HEAD/digest/merge-base strict).

**GLM's missing adds (keep these):**
- **One-page loss ledger** (incident class → date → hours lost → owning plan), seeded from the three transcript weeks — ranking by expected hours saved, not anecdote vividness. `plan_workflow-efficiency.md` forbids making a measurement *platform* a prerequisite; a one-page table is enough.
- **Plan-backlog consolidation session** — ~40 `plan_*.md` at root; this proposal would be #41 and overlaps five. Mark superseded/complete as decision records; fold live remainders into parents (AGENTS.md reuse rule; #168 under #159).

**GLM risks called out (do not reintroduce):**
- Hard gates for a non-programmer owner (items 6/7 as written) repeat the "condition-free rule blocked free work" failure.
- Item 2 vs 4 contradiction (wall-clock ban vs doctor regress check).
- Item 9 auto-cancel can destroy exact-head evidence if "superseded" is vague.
- Item 8 "at session start" full fleet doctor re-creates the preflight sweep bug.
- Parallel-programme proliferation = self-inflicted registry rot.

**GLM evidence caveats:** packet for that critique was mismatched (unrelated handoff in patch.diff; plan not in packet). Magnitudes (~25 suite reruns, ~30 queue, "LOT of collisions", 14h orphans) are single-source uncounted — use for ranking only. Empty-report incident may predate merged empty-report handling — verify before item-1 work. Effort labels ignore independent-review cost on reviewer-safety paths.

**Gaps / uncertainty in the mining itself:**
- Some Codex rollouts yield 0 extractable user prompts (wrapper-only; e.g. 13MB runner-safety session) — represented via excerpts/cross-refs only.
- Title+excerpt keyword counts undercount; claim rankings, not exact totals.
- Remainder is selection-biased toward failure/slowness (Jev kept 1306/1346); frequencies are within-corpus, not fleet rates.
- Clusters overlap; 74 sessions match ≥3 patterns.
- No transcript dates before 2026-09-08 in this set.
- TEMP copies (`jev_process_improvements.md`, `jev_remainder.jsonl`) may be gone — this §5a is the durable public-safe copy.

### 5b. Tooling findings

- **`snapshot-digest-mismatch` root cause** (`bin/ai-review-sandbox` `source_inventory`): `git diff --binary HEAD` embeds an `index 001754a1..404441ad` line whose abbreviation width depends on ODB size. Shallow review snapshot vs full source → different bytes → different sha256 → packet validation dies. `--full-index` forces 40-hex SHAs. Verified: source digest == snapshot digest after the change (live diag on edge-dev).
- **Second contributor:** untracked files that change during snapshot build (e.g. another session writing `plan_shared-db-coordination-deletion.md`) also break equality. `create_or_refresh` retries twice; continuous writers still fail. Keep the tree quiet during packet builds.
- **Claude transcript shape:** `type=="user"` / `message.role=="user"`, title in `<uuid>/custom-title.json` (`customTitle`). **Codex:** `session_meta.payload.cwd`; user text under `payload.role=="user"` or `UserMessage`; strip READ-ONLY boilerplate. **Grok:** often session-id stubs.
- **Jev API:** `POST https://api.typesafe.ai/v1/systemone`, `answers.<id>.noul` is P(yes). Batch ~12. Polarity of the question decides the discard threshold. `jev-latest` is a moving alias.
- **GLM** (and every other reviewer) shares `bin/ai-review-packet` / `ai-review-sandbox`; the digest bug blocked all of them the same way.

## 6. Exact next steps

1. **Finish packet tests** on the #1060 worktree if still running: `tail /tmp/packet-tests.log` or re-run `bash tests/test-ai-review-packet.sh` from `C:\repos\ai-devops-wt-sandbox-full-index`. **Success:** `N passed, 0 failed` (or an explained failure).
2. **Independent exact-head review of PR #1060** (reviewer-safety). Use a governed reviewer (Gemini is usable) from a **clean** worktree at `a8cc7964`. **Success:** a durable APPROVE report naming that SHA, stored under `.ai/reviews/`.
3. **Gemini review of the process plan + GLM cut** (authorized, not done). Brief content is **this handoff §5a** (nine items + GLM cut) + the question "is GLM's re-cut right (keep 2/3/9; fold the rest)?" Prompt-file; clean worktree; `AI_GEMINI_CALLER=mimo ai-gemini new …`. **Success:** Gemini verdict on that question with a durable report.
4. **Merge #1060** through the queue after review + green checks (`bin/ai-pr-wait 1060`). **Success:** commit on `origin/main`; then prove one live packet build (Muse or Grok) and resolve the two reviewer-issue records with that evidence.
5. **Ask Albert §0 item 1** (plan re-cut). If he accepts GLM's cut, fold deltas into the named existing plans — do not create a 40th plan file.
6. Delete this handoff only after #1060 is merged and the two incidents are resolved (successor rule).

## 7. Constraints and gotchas in force

- Never push to `main`. Feature branch + PR + merge queue. `git var GIT_COMMITTER_IDENT` must be Albert Hazan.
- Stage only task-owned files. Canonical `C:\repos\ai-devops` is landing-only; task edits belong in worktrees (this session briefly edited canonical `bin/ai-review-sandbox` to unblock GLM — do not repeat).
- Reviewer-safety changes need independent exact-head review before merge.
- All GitHub calls through `bin/ai-gh`. Waits via `bin/ai-pr-wait` / `ai-blocker-watch` — no open-ended polling.
- Private transcripts never enter this public repo or reviewer packets. Jev gets digests only.
- TypeSafe / Z.ai keys via `op://` + `op run` only.
- Gemini reviews: clean worktree only; check `ai-gemini-usage --min-percent 15` before a long review.
- On Windows, wrappers need Git Bash (`C:\Program Files\Git\bin\bash.exe`), not WSL `bash`.
- One unproven live outcome per session (live-proof-session-sizing).

## 8. Access and environment

- Host: `edge-dev` (Windows). Repo: `C:\repos\ai-devops` (origin `https://github.com/popcre/ai-devops.git`).
- Task worktree: `C:\repos\ai-devops-wt-sandbox-full-index` branch `mimo/sandbox-digest-full-index` @ `a8cc7964`.
- Reviewer incidents: `C:\repos\ai-devops-reviewer-install\.ai\reviewer-issues\20260929T125838Z-edge-dev-muse-1961321` and `…\20260929T130211Z-edge-dev-grok-1989270`.
- GLM report: `C:/repos/ai-devops/.ai/reviews/glm-jev-plan-critique-20260929-….md`. GLM session name `jev-plan-critique-20260929` (caller `mimo`).
- Secrets: 1Password vault `vibe_coding`, item `typesafe.ai API`, field `credential` (TypeSafe). `op-service-account` under `~/.config/ai-devops/`. Never print values.
- MiMo session id: `ses_ffe5f13530d23ffe3EeiH2Gm04`.
- Scratch (may vanish): `%TEMP%\jev_*.jsonl`, `jev_classify.py`, `jev_process_improvements.md`, `/tmp/sandbox-tests.log`, `/tmp/packet-tests.log`.

## 9. Open questions and risks

- (2026-09-29) Packet test suite duration is unknown; a timeout may be a hang (fork resource errors appeared: `Resource temporarily unavailable`). If hung, kill and re-run focused cases only.
- (2026-09-29) Whether the bare-PASS / empty-report reviewer incident is already fixed by `empty-report` handling (GLM) is unverified — do not rebuild a registry until that is checked.
- (2026-09-29) `plan_shared-db-coordination-deletion.md` in the canonical checkout is another session's untracked work — do not delete or commit it here.
- (2026-09-29) Canonical `C:\repos\ai-devops` still has this session's uncommitted `bin/ai-review-sandbox` one-hunk mirror of the fix plus unrelated dirty files (AGENTS.md, move-bulk script, HANDOFF.d/*). Leave other sessions' files alone; after #1060 merges, `git checkout -- bin/ai-review-sandbox` only if identical to the landed commit.
- (2026-09-29) Jev `not_related_p` distribution was conservative (only 40/1346 discarded). If a tighter remainder is needed, re-ask with positive-topic polarity ("is about failures…") and discard at `noul < 0.10`.
