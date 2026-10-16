# Implementation plan — keep maintained reviewers green for ≥24 hours

## STATUS — read first; do not re-derive completed programmes

Step IDs below match §9 exactly. Do not invent parallel numbering.

| Step | Status | Evidence / where a fresh session starts |
|---|---|---|
| 0. Register issue + this plan + handoff | ✅ done 2026-10-16 | [#1822](https://github.com/popcre/ai-devops/issues/1822); this file; [handoff](HANDOFF.d/2026-10-16T1835Z-edge-dev-mimo-reviewer-stability-24h.md) |
| 1. Freeze requalification storms (pin-digest identity) | ⬜ open | Start here if implementing |
| 2. Single terminal-verdict contract + parser proofs | ⬜ open | |
| 3. Wire contract into doors + registry | ⬜ open | |
| 4. Receipt/sandbox path identity | ⬜ open | Shared with recurrence-repair — see §4.3 matrix |
| 5. Freeze provider CLIs (pins + digests) | ⬜ open | Muse Linux re-pin stays with recurrence-repair |
| 6. Windows spawn/env (edge-dev) | ⬜ open | Protected files only per §4.3; default is door/common |
| 7. Timeout/hang owned-process recovery | ⬜ open | |
| 8. Secrets/1Password out of review path | ⬜ open | |
| 9. Incident backlog disposition by class | ⬜ open | |
| 10. 24-hour live observation matrix | ⬜ open | Live proof checklist item on #1822 |
| 11. Closeout | ⬜ open | |

**Owner:** issue #1822. **First-writer rule:** §4.3. Do not edit a shared file until its row says you may.

**Fresh session starts at** the first ⬜ row, after reading §4.3 (ownership) and §5–§8.

**Handoff:** [execution brief](HANDOFF.d/2026-10-16T1835Z-edge-dev-mimo-reviewer-stability-24h.md).

**Muse critique (2026-10-16):** ACCEPT WITH CHANGES — those changes are integrated in this revision (numbering, ownership matrix, runnable gates, no temp-file evidence, concrete requal default).

---

## 1. The ultimate goal — what we are actually trying to achieve

**Business goal:** Albert can ask for an independent review on edge-dev or edge-dev3 and get a finished decision the same day — and that capability **keeps working for at least 24 hours** without a new incident, a reinstall, or a requalification storm. After eight months of stop-and-go, the outcome that matters is **stability over time**, not one green run.

If a step conflicts with this goal, **the goal wins** — stop and flag it. Do not buy a green metric by removing a reviewer, skipping a safety gate, or accepting a non-verdict.

## 2. What this application is

- **Repository:** `popcre/ai-devops` (public recovery toolkit for a multi-model AI workflow). Not an app or service; "deployment" is `install.sh` / candidate-worktree `update.sh`.
- **What it does:** CLI tools in `bin/` orchestrate plan → review → implement → test → review across providers (Muse, DeepSeek, GLM, StepFun in rotation; others retained callable).
- **Who uses it:** Albert and AI coding sessions on Windows (`edge-dev`) and Linux (`edge-dev3`).
- **Related repos:** `popcre/shared-db` (consumes governed reviews); private `u2giants/ai-devops-transcripts`.
- **Stack:** Bash + Python + Node/PowerShell wrappers; doors under `tools/lib/review-doors/`; shared core `tools/lib/review-lifecycle-core.sh`, `tools/reviewer_events.py`.
- **Branch policy:** never push to `main`; feature branch + PR + merge queue. Installed checkout is landing-only (no `git pull` there).

## 3. What triggered this work

Albert asked why reviewers still fail on edge-dev / edge-dev3 after ~8 months and why the system cannot stay working more than ~24 hours. A 2026-10-16 diagnosis over **93 `ai-reviewer-issue` packages** (31 edge-dev, 92 edge-dev3) produced six failure classes (§6). A bulk raw-transcript ScaleDown extract was **stopped for cost** and is **not** evidence of record.

**Authoritative evidence (committed or host-local tooling — never session temp):**

```bash
ai-reviewer-issue list          # per host
ai-reviewer-issue path          # package root (private; do not commit bodies)
```

Class counts in §6 are re-derivable by bucketing `issue.json` `summary` fields with the rules in §6.1. A planning-session `DIAGNOSIS.md` under temp is **not** required and must not be cited as a source.

## 4. Scope

### 4.1 In

- Class-level fixes for C1–C6 (§6).
- Pin-digest requalification identity (Step 1 default design).
- Terminal-verdict contract and parser proof tests (Steps 2–3).
- Provider CLI freeze (pins + digests) for maintained reviewers (Step 5).
- Receipt/sandbox path identity (Step 4) under the first-writer rule.
- Windows spawn/env smoke for edge-dev (Step 6).
- Disposition of the **local** incident backlog by class on each host (Step 9).
- 24-hour live observation with the sample math in Step 10 (Step 10).
- Process rule: **no bulk raw-transcript third-party extract** without an explicit token budget on #1822.

### 4.2 NOT in this plan

- Removing or disabling any reviewer to make metrics pass.
- Weakening `reviewer-safety`, merge-queue checks, or exact-head independent review.
- Rebuilding a second lifecycle/recorder ([plan_reviewer-pipeline-core.md](plan_reviewer-pipeline-core.md)).
- Fleet-wide install on networking-only machines (`edge-alien`, `edge-runn-envy`, `edge-runn-xps`).
- Provider credit purchases, paid-key policy changes, or model roster changes.
- Shared-db structure changes.
- Re-doing completed programmes named in sibling STATUS tables.
- Muse Code Linux **re-pin PR** (owned by [plan_reviewer-recurrence-repair.md](plan_reviewer-recurrence-repair.md) steps 3–5) — this plan only consumes its result.
- Full transcript mining or ScaleDown history-compaction pilots.

### 4.3 Ownership and first-writer rule (LOCKED)

Two open sibling programmes share infrastructure with this plan. **A file may be edited only by the owner named below until that owner marks the row transferred on #1822.** "Serialize" without this table is not sufficient.

| Shared target | First writer | Follower rule | Notes |
|---|---|---|---|
| `bin/ai-review-packet`, `bin/ai-review-sandbox`, `tools/reviewer_events.py` (C3) | **recurrence-repair** Step 4 | This plan's Step 4 waits or adds only tests + evidence | Do not land two packet/sandbox patches |
| `tools/lib/review-lifecycle-core.sh` terminal-verdict helper | **this plan** Step 2 | Sibling steps must call the helper, not fork the rule | Declare `reviewer-safety` |
| `tools/lib/review-doors/*.sh` `extract_report` / credential load | **this plan** Steps 3, 7, 8 | recurrence-repair may fix provider-local bugs after | Declare `reviewer-safety` |
| `install.sh`, `update.sh`, `bin/ai-review-preflight` requal identity | **this plan** Step 1 | recurrence-repair does not change requal triggers | Declare `reviewer-safety` |
| `config/muse-code/*` Linux pins | **recurrence-repair** | This plan reads only | |
| Windows spawn entrypoints `bin/ai-stepfun`, `bin/ai-stepfun-windows-shell`, `bin/ai-glm`, `bin/ai-muse`, `bin/ai-codex-review`, `bin/ai-review*`, `tools/reviewer_*.py`, `config/task-gates.json` | **edge-dev-no-review** for defect fixes that live only there | This plan Step 6 default is **door/common only** | If the defect exists only in these files, Step 6 stops and names it on #1822; do **not** edit under a "this plan may escalate" fiction |
| `tests/test-ai-review-lifecycle.sh`, `tests/test-ai-review-engine.sh` | **this plan** | Siblings add cases via PR review, not parallel rewrites | |
| `tests/verification/reviewer-stability-24h/` | **this plan** | Siblings keep `tests/verification/reviewer-recurrence/` and `tests/verification/edge-dev-reviewer-repair/` | Three ledgers stay separate |

**edge-dev constraint (LOCKED, owner 2026-10-15):** implementation of edge-dev repairs must not use an AI reviewer as a gate. That constraint wins over any generic "escalate to reviewer-safety and get a review" sentence in other docs.

## 5. Current state of the code

| Area | State | Where |
|---|---|---|
| Incident store | 93 packages on the two hosts; many open | `ai-reviewer-issue path` per host |
| Sibling edge-dev3 | Open | [plan_reviewer-recurrence-repair.md](plan_reviewer-recurrence-repair.md) STATUS first (updated 2026-10-16) |
| Sibling edge-dev | Open; no AI-reviewer gate | [plan_edge-dev-reviewer-repair-no-review.md](plan_edge-dev-reviewer-repair-no-review.md) STATUS first |
| Shared lifecycle | Exists; some per-wrapper forks remain | `tools/lib/review-lifecycle-core.sh`, `tools/reviewer_events.py` |
| Doors | Per-provider `extract_report` | `tools/lib/review-doors/*.sh` |
| Registry / doors table | Committed | `config/reviewer-registry.json`, `config/review-runner-doors.json` |
| Test suites for this work | Exist on `origin/main` | Names in §10 — re-check they still exist before editing |
| This plan | Merged | `plan_reviewer-stability-24h.md` on `main` |

Nothing in Steps 1–11 is implemented yet. Work uses **fresh worktrees** from `origin/main`.

## 6. Key findings and root cause

### 6.1 Class table (authoritative; re-derivable)

Bucket rule for `issue.json` `summary` (lowercase contains):  
`requalification`→C1; `no verdict|without verdict|no valid|no response|empty response|ended without|tool-calls`→C2; `receipt|snapshot|sandbox|packet`→C3; `timeout|timed out|hang|poll|stall|sigterm`→C4; `spawn|e2big|command not found|shell`→C5; `1password|credential` or pin/self-update/drift→C6; else other.

| Class | Share (93 pkgs) | Representative summary | Root cause |
|---|---:|---|---|
| **C1 Auto-requalification loop** | 47 | `automatic qwen/gemini requalification failed after a pulled wrapper, runtime, or preloader change` | Install/update invalidates provider identity under live traffic |
| **C2 Missing/invalid terminal verdict** | 8 | `ended without verdict`, Muse `reason: tool-calls`, GLM provisional | No guaranteed single APPROVE/REJECT/BLOCKED |
| **C3 Receipt/sandbox/packet** | 6 | snapshot path resolution + access denied; receipt conflict | Paths/heads disagree across packet, sandbox, consumer |
| **C4 Timeout/hang** | 5 | GLM 429 then 25m poll to SIGTERM; suite ran hours | Non-terminal errors; unbounded poll |
| **C5 Spawn/env** | 4 | `ChildProcess.spawn NotFound`, `spawn E2BIG`, `Codex command not found` | Windows shell/path/ACL vs Linux |
| **C6 Drift + secrets + parse** | 9 | agy self-update; Muse pin mismatch; BLOCKED appended; 1Password in review path | Mutating CLIs; fragile extract; secrets reachable |

Provider mix: Qwen 49 · Gemini 12 · DeepSeek 10 · StepFun 7 · GLM 5 · Muse 5 · Grok 3 · Codex 2.

**Why 24h of green is structurally hard:** live traffic + frequent installs + fail-closed multi-joint reviews (packet → receipt → sandbox → door → wrapper → parse → verdict) + mutating provider CLIs. Any joint can refuse; installs re-arm C1. (Live proof of this class: `ai-muse new` on a full checkout hangs in `ai-review-sandbox assert-public` → `ai-task-gates explain` on a 1500+ path inventory, 2026-10-16.)

## 7. Approaches considered and REJECTED

| Approach | Why rejected |
|---|---|
| Remove/disable Qwen or any provider | Locked: never remove capability to make metrics pass |
| Shorter turn budgets / generic retry loops | Dropped in prior system-repair plan; healthy reviews exceed them |
| Second lifecycle/recorder | pipeline-core / harness consolidation own it |
| Broad host-wide process kills | DeepSeek broad stop hit concurrent CI |
| Weaken `reviewer-safety` or skip exact-head review | Protected class |
| Bulk ScaleDown extract of all raw transcripts | **Tried 2026-10-16, stopped for cost**; incident packages already enumerate failures |
| Reuse this plan as substitute for sibling plans | They own host-scoped execution; this plan owns class closure + 24h gate |
| Auto-update provider CLIs to "latest" | Unbounded motion; pins + provenance instead |
| Close all historical incidents as "one cause" | Many IDs, one loop — each needs disposition |
| Step 6 edits protected Windows entrypoints "under this programme" | Contradicts edge-dev-no-review; use §4.3 transfer only |
| Cite session-temp `DIAGNOSIS.md` | Not in a fresh checkout; §6 is the record |

## 8. Design decisions already made

**Locked:**

| Decision | Reason |
|---|---|
| Four maintained reviewers: Muse, DeepSeek, GLM, StepFun | rotation rules; others retained callable |
| Exactly one terminal verdict: APPROVE / REJECT / BLOCKED | Empty/provisional/duplicate = failure |
| Immutable source/receipt binding; read-only formal review | Existing safety design |
| edge-dev repairs without AI reviewers as a gate | Owner 2026-10-15 |
| No human approval for technical actions | Owner 2026-09-28 |
| Database writes skip second-AI review; other gates stay | Owner 2026-10-14 |
| ScaleDown is not independent review | `docs/compression-and-process-fixes.md` |
| Incidents resolve with evidence; resolved stay in place | `docs/reviewer-issues.md` |
| **Requal trigger = pin-digest change** (Step 1 default) | Smallest identity rule that stops install storms; see Step 1 |
| **§4.3 first-writer rule** | Prevents three programmes colliding |
| **Step 10 sample math** (Step 10 gate) | Quiet 24h is not proof |

**Open (bounded):** none for mechanism. Residual judgment only where a step says so (e.g. which door/common surface fixes C5 if not the protected entrypoints).

## 9. The plan — numbered, ordered, executable steps

> Fresh worktree from `origin/main`. Declare `ai-task-gates start --class` per step. §4.3 says who may touch which file.

### Phase A — Stop the bleeding (C1 + C2)

#### Step 1 — Freeze requalification storms (C1) — pin-digest identity

- **What (LOCKED default):** Provider identity for requalification is the digest of that provider's **declared pin set** (model/CLI pin files + `config/reviewer-registry.json` provider entry + resolved wrapper path). Ordinary `update.sh` that copies wrappers **without changing those digests** must **not** mark the provider unqualified. Requalification runs when and only when a pin-set digest changes (deliberate bump) or preflight cannot resolve the wrapper.
- **Files:** `install.sh`, `update.sh`, `bin/ai-review-preflight`, `config/reviewer-registry.json`, `tests/test-ai-review-preflight.sh`, `tests/test-ai-preflight-pinbump.sh`.
- **Done behavior:** Same pins → no requal event. Changed pin → requal required.
- **Depends on:** §4.3 (this plan owns these files).
- **Verification gate (runnable):**
  1. `bash tests/test-ai-review-preflight.sh` — includes new cases `requal_skipped_when_pin_digest_unchanged`, `requal_required_when_pin_digest_changes`.
  2. `bash tests/test-ai-preflight-pinbump.sh` — still green (deliberate bump still requals).
  3. On a candidate worktree: `ai-review-preflight usable qwen` exits 0 before and after a no-pin `update.sh` with the same `wrapper_command` in output.

#### Step 2 — Single terminal-verdict contract (C2)

- **What:** Shared helper in `tools/lib/review-lifecycle-core.sh` requires exactly one terminal verdict. Force `BLOCKED` (or recorded failure) on: zero verdicts, >1 verdict, provisional-only, `tool-calls` incomplete. Never invent APPROVE/REJECT.
- **Files:** `tools/lib/review-lifecycle-core.sh`, `tests/test-ai-review-lifecycle.sh`, `tests/test-ai-review-engine.sh`.
- **Depends on:** none (this plan first-writer).
- **Verification gate (runnable):** `bash tests/test-ai-review-lifecycle.sh` all green, including cases: `no-verdict`, `duplicate-verdict`, `provisional-only`, `tool-calls-incomplete`, `verdict-in-log-noise`.

**Adversarial cases (trust boundary — provider stdout):**

| External input | Hostile case | Test name |
|---|---|---|
| Provider stdout | No verdict token | `no-verdict` → BLOCKED |
| Provider stdout | APPROVE then REJECT | `duplicate-verdict` → BLOCKED, never mixed accept |
| Provider stdout | "looks good" without `VERDICT:` | `provisional-only` → BLOCKED |
| Provider stdout | Findings + `tool-calls` stop | `tool-calls-incomplete` → BLOCKED |
| Provider stdout | Verdict buried in log noise | `verdict-in-log-noise` |
| Report paths | `../` or absolute outside packet | existing `tests/test-ai-review-sandbox.sh` stays green |
| Receipt head | Wrong head vs receipt | existing `tests/test-ai-review-packet.sh` stays green |

#### Step 3 — Wire contract into doors + registry

- **What:** Every `tools/lib/review-doors/*.sh` `extract_report` calls the shared helper (no fork). Registry unchanged except if a helper version field is required.
- **Files:** `tools/lib/review-doors/*.sh`, `tests/test-ai-review-engine.sh`.
- **Depends on:** Step 2.
- **Verification gate:** `bash tests/test-ai-review-engine.sh` — keep existing `extract_report` adapter assertions; add `door_calls_shared_terminal_helper` (same style as `adapter_*_keeps_provider_bits`).

### Phase B — Identity and paths (C3 + C6 pins)

#### Step 4 — Receipt/sandbox path identity (C3)

- **What:** Add failing fixtures for receipt conflict and snapshot path resolution, then fix **common** path normalization. If recurrence-repair already landed the fix, add evidence rows only.
- **Files (first-writer: recurrence-repair):** `bin/ai-review-packet`, `bin/ai-review-sandbox`, `tools/reviewer_events.py`, `tests/test-ai-review-packet.sh`, `tests/test-ai-review-sandbox.sh`.
- **Depends on:** recurrence-repair ownership — transfer on #1822 before editing their files.
- **Verification gate:** `bash tests/test-ai-review-packet.sh` and `bash tests/test-ai-review-sandbox.sh` green including new cases `receipt_conflict_fixture`, `snapshot_path_resolution_fixture`.

#### Step 5 — Freeze provider CLIs (C6 drift)

- **What:** Pins + SHA-256 for maintained runtimes (including `config/muse-code/version` and `config/muse-code/sha256` where present). Preflight refuses on digest mismatch. Deliberate bump = change pin file + requal (Step 1).
- **Files:** pin files as on current source; `bin/ai-review-preflight`; docs `docs/configuration.md` / `docs/model-setup.md` if they document pins.
- **Depends on:** Muse Linux re-pin PR from recurrence-repair (do not duplicate).
- **Verification gate (runnable):**
  1. `bash tests/test-ai-review-preflight.sh` case `pin_digest_mismatch_refuses`.
  2. `bash tests/test-ai-preflight-pinbump.sh` green.
  3. Command: `ai-review-preflight usable muse` exits 0 when digests match; exits non-zero with a message containing `pin` when `config/muse-code/sha256` (or provider equivalent) is corrupted in a test fixture.

#### Step 6 — Windows spawn/env (C5) — door/common only by default

- **What:** Fix spawn/env **only** in door/common surfaces (§4.3). Do **not** edit protected Windows entrypoints (`bin/ai-stepfun*`, `bin/ai-glm`, `bin/ai-muse`, `bin/ai-codex-review`, `bin/ai-review*`, `tools/reviewer_*.py`, `config/task-gates.json`) unless that row is transferred on #1822 from edge-dev-no-review. If the defect exists only in those files: record the exact file:line on #1822, leave the row to that programme, and mark Step 6 `blocked` on transfer — do not invent a parallel fix.
- **Files (allowed now):** `tools/lib/review-doors/*.sh`, common env/shell helpers under `tools/lib/` if any, `tests/` focused cases.
- **Depends on:** §4.3.
- **Verification gate (runnable):**
  1. New test `bash tests/test-ai-review-preflight.sh` case `windows_spawn_path_resolves` **or** a named door unit test in `tests/test-ai-review-engine.sh` if preflight cannot observe spawn — pick the surface that already owns spawn errors and name the case in STATUS.
  2. On edge-dev (no AI-reviewer gate): command `ai-stepfun` / `ai-glm` **starts** and exits with a structured error or a real review — **not** `ChildProcess.spawn` NotFound / `command not found`. Record exit codes on #1822 checklist.

#### Step 7 — Timeout/hang owned-process recovery (C4)

- **What:** Provider `finish=error` / 429 is terminal within a bounded window (target ≤120s in offline tests; production budgets stay provider-real). Reap only owned children. Do not shorten real review budgets to hide latency.
- **Files:** wait/poll in `tools/lib/review-doors/*.sh`, `tests/test-ai-review-engine.sh`.
- **Verification gate:** `bash tests/test-ai-review-engine.sh` cases `provider_error_finish_is_terminal`, `reap_owned_children_only` (sibling mock remains alive).

**Adversarial cases:**

| External input | Hostile case | Test |
|---|---|---|
| Provider API | 429 then silence | `provider_error_finish_is_terminal` |
| Child process | Hangs forever | `reap_owned_children_only` |
| Shared machine | Concurrent CI | no broad kill (regression named in recurrence-repair; do not weaken) |

#### Step 8 — Secrets/1Password out of review path (C6)

- **What:** Formal review must not invoke `op` / 1Password. Credentials from file/env preload only; otherwise refuse.
- **Files:** credential load in `tools/lib/review-doors/*`, matching tests.
- **Verification gate:** `bash tests/test-ai-review-engine.sh` (or door suite) case `review_refuses_without_cred_file_and_does_not_call_op` — assert `op` is not executed (PATH stub or counter).

### Phase C — Hangs, backlog, proof

#### Step 9 — Disposition backlog by class (C1–C6)

- **What:** Per host, `ai-reviewer-issue list` + `show`; map each open ID to C1–C6 using §6.1; resolve/partially-resolve with evidence when the class fix lands; else carry-forward with owner. Duplicates of one loop link to the class fix.
- **Verification gate (runnable):**
  1. Command on each host: `ai-reviewer-issue list` filtered to open maintained providers.
  2. File `tests/verification/reviewer-stability-24h/backlog-<host>.md` lists every such ID with class + disposition + evidence pointer.
  3. Pass when **zero** open maintained-provider IDs lack a row (not when the raw count is zero — unknown history stays explicit).

#### Step 10 — 24-hour live observation matrix

- **What:** After Steps 1–8 are **installed** on edge-dev3 (and Step 6 smoke on edge-dev), observe **≥24 real hours** wall clock (EST timestamps in the ledger).
- **Sample math (LOCKED):**
  - ≥ **3** completed terminal-verdict reviews per maintained provider (Muse, DeepSeek, GLM, StepFun) through the supported entrypoint;
  - plus ≥ **10** ordinary eligible review attempts (pass or fail) in the window;
  - a window with fewer samples **fails** the gate (quiet ≠ green);
  - provider outage / quota is an **availability** limitation with evidence, not a code-failure rate and not a silent pass.
- **Verification gate (runnable):** `tests/verification/reviewer-stability-24h/observation-2026-10-XX.md` contains: start/end timestamps (EST), per-provider counts meeting the math, every failure with class C1–C6 or `provider-outage`, and the install SHA. Checklist `- [ ] live proof` on **#1822** until that file exists.

#### Step 11 — Closeout

- Update STATUS with artifacts (not bare counts). Finish #1822 checklist. Retire the handoff only when nothing is carried. No leftover-proof issue.

## 10. Tests required

| Suite (exists on `origin/main` 2026-10-16) | Used for |
|---|---|
| `bash tests/test-ai-review-preflight.sh` | Steps 1, 5, 6 |
| `bash tests/test-ai-preflight-pinbump.sh` | Steps 1, 5 |
| `bash tests/test-ai-review-lifecycle.sh` | Step 2 adversarial table |
| `bash tests/test-ai-review-engine.sh` | Steps 3, 7, 8 |
| `bash tests/test-ai-review-packet.sh` | Step 4 |
| `bash tests/test-ai-review-sandbox.sh` | Step 4 |
| `bash tests/test-ai-review-sandbox-delete-guard.sh` | stay green |
| `bash tests/test-ai-review-sandbox-self-cleanup.sh` | stay green |
| `bash tests/test-reviewer-events-isolation.sh` | synthetic tests never write live outcomes |

Before editing, re-check the file exists. Run `bin/ai-test-local --check-collision` before a full local series. Never invent a pass for a missing suite.

## 11. Constraints, standing rules, and gotchas

- **Branch:** feature branch + PR; never push `main`; merge queue. Installed checkout: never `git pull`/merge.
- **Task class:** declare before work. Wrappers/doors/lifecycle/safety tests = `reviewer-safety`.
- **edge-dev:** no AI reviewer as a gate (LOCKED).
- **§4.3 first-writer** for every shared file.
- **No capability removal**, no weakened CI, no silent failures, no symptom band-aids.
- **Secrets:** vault `vibe_coding` by title only; review path must not call `op`.
- **Incidents:** computer name in records; resolve with evidence; no Markdown archive of resolved IDs.
- **No bulk ScaleDown raw-transcript extract** without a token budget on #1822.
- **Times in EST (America/New_York)** in human-facing notes.
- **Sign GitHub posts** with `Posted by MiMo chat <id> on <machine>`.
- **`ai-task-gates explain` / `ai-review-sandbox assert-public` can hang** on large path inventories on Windows (observed 2026-10-16). Do not treat a multi-minute hang as progress; isolate with a tiny `--paths-from` file first.

## 12. Access and environment

| Need | Where |
|---|---|
| Hosts | `edge-dev` (Windows, Git Bash), `edge-dev3` (Linux, SSH `edge-dev3`) |
| Repo | `popcre/ai-devops`; worktrees from `origin/main` |
| Issue | [#1822](https://github.com/popcre/ai-devops/issues/1822) |
| Incident store | `ai-reviewer-issue path` per host (private) |
| Secrets | 1Password vault `vibe_coding` by item title only |
| GitHub | `bin/ai-gh`; `bin/ai-pr-wait` with explicit timeout |
| Tests | `bash tests/<name>.sh` via Git Bash on Windows |
| Ledger dir | `tests/verification/reviewer-stability-24h/` (create when Step 9 runs) |

## 13. Definition of done + risks and open questions

### Definition of done

- [ ] Step 1: pin-digest tests green; unrelated update does not requal.
- [ ] Step 2: all named adversarial cases green.
- [ ] Step 3: doors call shared helper (test name recorded).
- [ ] Step 4: fixtures green or recurrence-repair evidence linked.
- [ ] Step 5: pin mismatch refuses (test + command).
- [ ] Step 6: spawn smoke on edge-dev without reviewer gate; protected-file work only if §4.3 transferred.
- [ ] Step 7: bounded error + owned reap tests green.
- [ ] Step 8: no-`op` test green.
- [ ] Step 9: backlog ledgers complete per host.
- [ ] Step 10: observation file meets sample math; live proof checked on #1822.
- [ ] Step 11: STATUS cites artifacts; handoff retired; PR merged.

### Risks

| Risk | Mitigation |
|---|---|
| Sibling collision on shared files | §4.3 first-writer; transfer on #1822 |
| Requal freeze hides real identity change | Pin-digest change still requals; pinbump suite |
| Verdict contract → false BLOCKED stalls 24h clock | Prefer honest BLOCKED; Step 10 counts refusals separately |
| Windows C5 only fixable in protected files | Step 6 stops and transfers; do not violate no-review plan |
| Quiet 24h | Step 10 sample math (LOCKED) |
| Token waste recurrence | §4.2 / §11 hard budget |
| `ai-task-gates` hang on large inventories | §11 gotcha; tiny paths file first |

### Open questions

- None on mechanism (requal default is locked).  
- If Step 6 hits protected files only, that is a **transfer request** on #1822, not a design debate.

---

## Self-audit (Mode A) — 2026-10-16 revision after Muse critique

1. **Fresh session, no questions?**  
   **Yes.** §4.3 names first writers; §9 gates are named suites/commands; evidence is `ai-reviewer-issue` + committed §6, not temp files. Gap from Muse (suite names TBD) closed with the §10 table.

2. **Background, nuance, rejected approaches?**  
   **Yes.** §3 evidence rule; §6.1 bucket rule; §7 includes Muse’s rejected ownership/temp-evidence patterns; §8 locks requal default and sample math.

3. **Goal clear for judgment calls?**  
   **Yes.** §1 goal-wins; Step 6 transfer rule is the judgment path when a step is wrong.

**Muse findings addressed:** numbering (STATUS=§9) · protected-file contradiction (Step 6 + §4.3) · first-writer matrix (§4.3) · runnable gates (Steps 1, 5, 9, 10) · no temp DIAGNOSIS (§3, §7) · concrete requal default (§8, Step 1) · sample math (Step 10) · risks (§13).

**Self-audit passed.** Comprehensive because every class, ownership edge, and gate is named and testable without this chat.
