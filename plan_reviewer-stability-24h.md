# Implementation plan — keep maintained reviewers green for ≥24 hours

## STATUS — read first; do not re-derive completed programmes

| Step | Status | Evidence / where a fresh session starts |
|---|---|---|
| 0. Register issue + this plan + handoff | ✅ done 2026-10-16 | [#1822](https://github.com/popcre/ai-devops/issues/1822); this file; [handoff](HANDOFF.d/2026-10-16T1835Z-edge-dev-mimo-reviewer-stability-24h.md) |
| 1. Freeze requalification storms (install/update policy) | ⬜ open | Start here if you are implementing |
| 2. Single terminal-verdict contract + parser proofs | ⬜ open | |
| 3. Freeze provider CLIs (pins + digests) | ⬜ open | |
| 4. Receipt/sandbox path identity repair | ⬜ open | Partially owned by [plan_reviewer-recurrence-repair.md](plan_reviewer-recurrence-repair.md) |
| 5. Spawn/env + Windows host gate | ⬜ open | Partially owned by [plan_edge-dev-reviewer-repair-no-review.md](plan_edge-dev-reviewer-repair-no-review.md) |
| 6. Timeout/hang owned-process recovery | ⬜ open | Do not cancel concurrent CI |
| 7. Secrets/1Password out of review path | ⬜ open | |
| 8. Incident backlog disposition by class (not by ID) | ⬜ open | |
| 9. 24h live observation matrix on edge-dev3 + edge-dev smoke | ⬜ open | Live proof on the same issue |
| 10. Closeout: docs, STATUS, checklist on #1822 | ⬜ open | |

**Owner:** issue #1822. Coordinate with existing owners before touching shared lifecycle files.

**Fresh session starts at** the first ⬜ row above, after re-reading §5–§8 of this plan and the two sibling plans' STATUS tables.

**Handoff:** [execution brief](HANDOFF.d/2026-10-16T1835Z-edge-dev-mimo-reviewer-stability-24h.md).

---

## 1. The ultimate goal — what we are actually trying to achieve

**Business goal:** Albert can ask for an independent review on edge-dev or edge-dev3 and get a finished decision the same day — and that capability **keeps working for at least 24 hours** without a new incident, a reinstall, or a requalification storm. After eight months of stop-and-go, the outcome that matters is **stability over time**, not one green run.

If a step conflicts with this goal, **the goal wins** — stop and flag it. Do not buy a green metric by removing a reviewer, skipping a safety gate, or accepting a non-verdict.

## 2. What this application is

- **Repository:** `popcre/ai-devops` (public recovery toolkit for a multi-model AI workflow). It is **not** an app or service; "deployment" is `install.sh` / candidate-worktree `update.sh`.
- **What it does:** CLI tools in `bin/` orchestrate plan → review → implement → test → review across providers (Muse, DeepSeek, GLM, StepFun in rotation; others retained callable).
- **Who uses it:** Albert and AI coding sessions on Windows (`edge-dev`) and Linux (`edge-dev3`).
- **Related repos:** `popcre/shared-db` (consumes governed reviews); private `u2giants/ai-devops-transcripts`.
- **Stack:** Bash + Python + Node/PowerShell wrappers; doors under `tools/lib/review-doors/`; shared core `tools/lib/review-lifecycle-core.sh`, `tools/reviewer_events.py`.
- **Branch policy:** never push to `main`; feature branch + PR + merge queue. Installed checkout is landing-only (no `git pull` there).

## 3. What triggered this work

Albert asked why reviewers still fail on edge-dev / edge-dev3 after ~8 months and why the system cannot stay working more than ~24 hours. A 2026-10-16 diagnosis over 93 `ai-reviewer-issue` packages (31 edge-dev, 92 edge-dev3), partial ScaleDown extract of last-8-day Codex rollouts, and the existing repair plans produced six failure classes (see §6). A bulk raw-transcript ScaleDown extract was **stopped** for cost (~210M+ tokens); **incident packages remain the source of truth**. This plan is the class-level programme to fix every class found.

**Reproduce the diagnosis evidence (read-only):**

```bash
ai-reviewer-issue list
# packages under the path from: ai-reviewer-issue path
```

## 4. Scope

### In

- Class-level fixes for all six failure classes in §6.
- Install/update **policy** that stops requalification storms (not a redesign of the whole installer).
- Terminal-verdict contract and parser proof tests.
- Provider CLI freeze (pins + digests) for the four maintained reviewers.
- Receipt/sandbox path identity repairs only as needed for class 3 (reuse sibling plan ownership).
- Windows spawn/env smoke for edge-dev; Linux pin/Muse smoke for edge-dev3.
- Disposition of the **local** incident backlog by class on each host.
- 24-hour live observation with honest denominators.
- Process rule: **no bulk raw-transcript third-party extract** without an explicit token budget.

### NOT in this plan

- Removing or disabling any reviewer to make metrics pass.
- Weakening `reviewer-safety`, merge-queue checks, or exact-head independent review.
- Rebuilding a second lifecycle/recorder (owned by [plan_reviewer-pipeline-core.md](plan_reviewer-pipeline-core.md)).
- Fleet-wide install on networking-only machines (`edge-alien`, `edge-runn-envy`, `edge-runn-xps`).
- Provider credit purchases, paid-key policy changes, or model roster changes.
- Shared-db structure changes.
- Re-doing completed programmes named in sibling plans' STATUS tables.
- Full transcript mining or ScaleDown history-compaction pilots (separate: [plan via SLM compaction handoff](HANDOFF.d/2026-10-14T1710Z-edge-dev-mimo-slm-compaction-pilot.md)).

## 5. Current state of the code

| Area | State | Where |
|---|---|---|
| Diagnosis | Written 2026-10-16 | Session artifact `DIAGNOSIS.md` under the planning session temp; class table is in §6 of this plan (authoritative for this programme) |
| Incident store | 93 packages on the two hosts; many open | `ai-reviewer-issue path` on each host; do not copy raw bodies into this public repo |
| Sibling plan edge-dev3 | Open programme | [plan_reviewer-recurrence-repair.md](plan_reviewer-recurrence-repair.md) STATUS first |
| Sibling plan edge-dev | Open; **implementation must not need AI reviewers as a gate** | [plan_edge-dev-reviewer-repair-no-review.md](plan_edge-dev-reviewer-repair-no-review.md) STATUS first |
| Shared lifecycle | Exists; wrappers still copy-paste some logic | `tools/lib/review-lifecycle-core.sh`, `tools/reviewer_events.py` |
| Doors | Per-provider adapters with `extract_report` | `tools/lib/review-doors/*.sh` |
| Registry / doors table | Committed | `config/reviewer-registry.json`, `config/review-runner-doors.json` |
| ScaleDown cost | Refilled after 402; bulk extract stopped | Do not resume raw-jsonl extract without a budget |

Nothing in this plan is implemented yet. Committed code on `origin/main` is the baseline; work uses **fresh worktrees** from `origin/main`, never the installed checkout.

## 6. Key findings and root cause

From 93 incident packages (all hosts) and diagnosis buckets:

| Class | Share of incidents | Representative evidence | Root cause |
|---|---:|---|---|
| **C1 Auto-requalification loop** | 47/93 (21/48 recent) | `automatic qwen/gemini requalification failed after a pulled wrapper, runtime, or preloader change` | Install/update of wrapper/runtime/preloader invalidates provider identity under live traffic; requal fails and every dependent review fails |
| **C2 Missing/invalid terminal verdict** | 8/93 | `ended without verdict`, `empty response`, Muse `reason: tool-calls`, GLM provisional decision | Providers/wrappers can finish without exactly one APPROVE/REJECT/BLOCKED |
| **C3 Receipt/sandbox/packet** | 6/93 | snapshot path resolution + access denied; receipt conflict on Muse and DeepSeek | Paths/heads/snapshots disagree across packet build, sandbox, and consumer |
| **C4 Timeout/hang** | 5/93 | GLM 429 at 4s then wrapper polled 25m to SIGTERM; StepFun timed out; `windows-reviewer-fallback-grok` suite ran for hours | Error finish not terminal; unbounded poll; suite/process ownership unclear |
| **C5 Spawn/env** | 4/93 + ScaleDown entities | `ChildProcess.spawn NotFound`, `spawn E2BIG`, `Codex command not found`, wscript `/c/...` path | Windows shell/path/ACL/env differences vs Linux |
| **C6 Drift + parse + secrets** | 2+4+3 | agy 1.2.12→1.2.13 self-update; Muse pin 1.4.7-R6101.1 mismatch; BLOCKED appended; 1Password in review path | Mutating CLIs; fragile report extract; secrets reachable during review |

Provider mix: Qwen 49 · Gemini 12 · DeepSeek 10 · StepFun 7 · GLM 5 · Muse 5 · Grok 3 · Codex 2.

**Why 24h of green is structurally hard:** live traffic + frequent installs + fail-closed multi-joint reviews (packet → receipt → sandbox → door → wrapper → parse → verdict) + mutating provider CLIs. Any joint can refuse; installs re-arm C1.

## 7. Approaches considered and REJECTED

| Approach | Why rejected |
|---|---|
| Remove/disable Qwen or any provider to stop requal noise | Locked: never remove capability to make metrics pass |
| Shorter turn budgets / generic retry loops | Prior system-repair plan dropped short budgets; healthy reviews exceed them |
| Second lifecycle/recorder | [plan_reviewer-pipeline-core.md](plan_reviewer-pipeline-core.md) / harness consolidation already own the common engine |
| Broad host-wide process kills to stop a hang | Recorded DeepSeek broad stop hit concurrent CI; only exact owned-process ancestry |
| Weaken `reviewer-safety` or skip exact-head review to land repairs | Protected class; honest path is redeclare and satisfy the class |
| Bulk ScaleDown extract of all raw transcripts as the fix | **Tried 2026-10-16 and stopped** for cost (100M+ tokens); incident packages already enumerate failures. Never resume without a hard token budget |
| Reuse this plan as a substitute for the two sibling plans | They own host-scoped execution and owner constraints; this plan owns **class** closure and the 24h gate |
| Auto-update provider CLIs to "latest" to fix spawn/pin bugs | Turns official installer drift into unbounded motion; pins + provenance instead |
| Close all historical incidents as "one cause" | Same loop is many IDs but each needs disposition; cannot reclassify to hide defects |

## 8. Design decisions already made

**Locked (do not relitigate):**

| Decision | Reason |
|---|---|
| Four maintained reviewers: Muse, DeepSeek, GLM, StepFun | [docs/reviewer-rotation-rules.md](docs/reviewer-rotation-rules.md); others retained callable |
| Exactly one terminal verdict per run: APPROVE / REJECT / BLOCKED | Empty, provisional, or duplicate decision text is a **failure**, never a silent success |
| Immutable source/receipt binding; read-only formal review | Existing safety design |
| edge-dev repairs must land **without AI reviewers as a gate** | Owner 2026-10-15: "knowing that the reviewers don't work, make sure implementing it doesn't need reviewers" |
| No human approval requests for technical actions | Owner 2026-09-28: "never ask a human to approve" |
| Database writes skip second-AI review; other gates stay | Owner 2026-10-14 |
| ScaleDown extract is not a substitute for independent review | [docs/compression-and-process-fixes.md](docs/compression-and-process-fixes.md) |
| Incidents resolve with evidence; resolved stay in place | `log-reviewer-issue` / [docs/reviewer-issues.md](docs/reviewer-issues.md) |

**Open (implementer judgment):**

- Exact mechanism to freeze requal (gate in `update.sh` vs registry hash vs maintenance window) — pick the smallest change that makes identity stable across ordinary installs.
- Whether C3 fixes live mostly in packet/sandbox code or in door path normalization — prove with a failing fixture before choosing.
- How to represent "provider outage" in the 24h matrix without inventing code-failure rates (explicit availability limit, not a fake green).

## 9. The plan — numbered, ordered, executable steps

> Implementer: work in a **fresh worktree** from current `origin/main`. Declare `ai-task-gates start --class` per step (`reviewer-safety` where wrappers/doors/lifecycle/safety tests change). Never edit the installed checkout except via the documented candidate `update.sh` path.

### Phase A — Stop the bleeding (C1 + C2 contract)

#### Step 1 — Freeze requalification storms (C1)

- **What:** Identify every install/update path that mutates wrapper, runtime, or preloader identity (`install.sh`, `update.sh`, `bin/ai-*` launcher resolution, Node/Python preloader pins, `config/reviewer-registry.json`). Add a **stable provider identity**: requalification runs only when a **deliberate** pin/registry change is declared (explicit file or env + gate), not on every wrapper copy. Ordinary `update.sh` must not invalidate a qualified provider unless its pin actually changed.
- **Files:** `install.sh`, `update.sh`, `bin/ai-review-preflight`, `config/reviewer-registry.json`, matching tests under `tests/` (name from existing preflight/requal tests — verify they exist on current source before editing).
- **Done behavior:** After an unrelated wrapper code update, Qwen/Gemini do **not** enter automatic requalification; after an intentional model/CLI pin bump, they do.
- **Depends on:** none. **Parallel with:** Step 2.
- **Verification gate:** Offline test that simulates two installs (same pins vs changed pin) and asserts requal is skipped vs required. Command: the new/extended suite name recorded in STATUS (e.g. `bash tests/test-ai-review-preflight.sh` or successor). Plus: `ai-review-preflight usable qwen` before/after an unrelated update on a candidate worktree shows the same resolved wrapper and no requal event.

#### Step 2 — Single terminal-verdict contract (C2)

- **What:** In shared report extraction (`tools/lib/review-lifecycle-core.sh`, door `extract_report` functions), require **exactly one** terminal verdict token. Reject or force `BLOCKED` when: zero verdicts, >1 verdict, provisional-only text, or Muse-style `reason: tool-calls` without a decision. Do not invent APPROVE/REJECT.
- **Files:** `tools/lib/review-lifecycle-core.sh`, `tools/lib/review-doors/{muse,stepfun,glm,deepseek,grok,gemini,qwen,codex,mimo}.sh` (only the extract/terminal paths), tests `tests/test-ai-review-lifecycle.sh`, `tests/test-ai-review-engine.sh`.
- **Done behavior:** A provider stream with empty text, double decision, or `tool-calls` stop yields `BLOCKED` (or recorded failure) with a stable error code — never a silent success and never a spurious APPROVE.
- **Depends on:** none.
- **Verification gate:** New cases in `test-ai-review-lifecycle.sh` / `test-ai-review-engine.sh` named for: `no-verdict`, `duplicate-verdict`, `provisional-only`, `tool-calls-incomplete`. All green.

**Adversarial cases (trust boundary — report text from outside the repo):**

| External input | Hostile case | Test that proves it |
|---|---|---|
| Provider stdout | No verdict token | `test-ai-review-lifecycle.sh` `no-verdict` → BLOCKED |
| Provider stdout | `APPROVE` then `REJECT` | `duplicate-verdict` → BLOCKED / failure, no mixed accept |
| Provider stdout | "looks good" provisional without `VERDICT:` | `provisional-only` → BLOCKED |
| Provider stdout | Findings + `tool-calls` stop | `tool-calls-incomplete` → BLOCKED |
| Provider stdout | Verdict in trailing garbage / log noise | Parser keeps only structured verdict line (existing extractor bug class; add regression) |
| File path in report | `../` or absolute host path outside packet | Existing sandbox path tests must stay green |
| Timestamp/head in report | Wrong head vs receipt | Receipt bind tests in `test-ai-review-packet.sh` stay green |

#### Step 3 — Wire contract into doors + registry

- **What:** Ensure every door uses the shared terminal-verdict helper (no per-wrapper fork of the rule). Registry may map providers to helper version.
- **Files:** `tools/lib/review-doors/*.sh`, `config/reviewer-registry.json`, `tests/test-ai-review-engine.sh` adapter checks.
- **Depends on:** Step 2.
- **Verification gate:** `tests/test-ai-review-engine.sh` adapter checks still require `extract_report` presence; add assertion that each door calls the shared terminal helper (grep/test as already done for `extract_report`).

### Phase B — Identity and paths (C3 + C6 pins)

#### Step 4 — Receipt/sandbox path identity (C3)

- **What:** Fail a fixture where packet receipt, sandbox root, and consumer paths disagree; fix the **common** path normalization (not per-provider hacks). Reuse [plan_reviewer-recurrence-repair.md](plan_reviewer-recurrence-repair.md) step work if already implemented — add evidence, do not rewrite.
- **Files:** `bin/ai-review-packet`, `bin/ai-review-sandbox`, `tools/reviewer_events.py`, `tests/test-ai-review-packet.sh`, `tests/test-ai-review-sandbox*.sh`.
- **Depends on:** coordinate with recurrence-repair owner on shared files; serialize edits.
- **Verification gate:** Failing-then-passing fixture for "receipt conflict" and "snapshot path resolution"; suites above green.

#### Step 5 — Freeze provider CLIs (C6 drift)

- **What:** Pins + SHA-256 for maintained provider runtimes (including Muse Code version pin files `config/muse-code/version`, `config/muse-code/sha256` and agy/gemini CLI). Document how to **deliberately** bump a pin (provenance + digest). Refuse review start on digest mismatch (already partially designed in recurrence-repair Muse re-pin steps — do not duplicate that PR; implement only what is missing).
- **Files:** `config/*` pin files as present on current source; preflight; docs [`docs/configuration.md`](docs/configuration.md) or model-setup as applicable.
- **Verification gate:** `ai-review-preflight` (or doctor) reports pin match; a tampered digest refuses with a clear error. For Muse Linux pin: coordinate with recurrence-repair Step 3–5 rather than a second re-pin PR.

#### Step 6 — Windows spawn/env (C5)

- **What:** On edge-dev, fix shell spawn (`ChildProcess.spawn NotFound`, Git Bash path to wscript, `spawn E2BIG`, `Codex command not found` resolution). Prefer door/common fixes over per-provider patches. **Do not use an AI reviewer as a gate** for this host's repair (owner constraint on the sibling plan). Focused offline tests + CI + live smoke.
- **Files:** `bin/ai-stepfun`, `bin/ai-stepfun-windows-shell`, `bin/ai-glm`, `bin/ai-muse`, `bin/ai-codex-review`, `bin/ai-review*`, `tools/reviewer_*.py`, `config/task-gates.json` — these are **protected `reviewer-safety`**; the sibling plan says do not edit them under *that* programme without escalating. This programme **may** edit them under a declared `reviewer-safety` class with the normal gates, or land door/common fixes only if the defect lives there.
- **Depends on:** sibling plan ownership — reconcile on #1822 before overlapping.
- **Verification gate:** `bash tests/test-ai-review-preflight.sh` (or successor) + a Windows smoke that `ai-stepfun` / `ai-glm` **start** and emit a structured error or a real review — not a spawn NotFound. Record on the issue checklist.

### Phase C — Hangs, secrets, backlog

#### Step 7 — Timeout/hang owned-process recovery (C4)

- **What:** Provider `finish=error` / 429 must be terminal within a bounded window (not 25m SIGTERM). Cancel/reap **only** owned children. Suite `windows-reviewer-fallback-grok` must not run for hours; diagnose worker/run collision first (recurrence-repair step 6 owns diagnosis — do not duplicate).
- **Files:** wrappers' wait/poll loops in `tools/lib/review-doors/*`, `tests/test-ai-review-engine.sh` timeout cases; CI suite selection `config/ci-suite-manifest.json` only if step 6 evidence says so.
- **Verification gate:** Offline mock that returns `finish=error` and asserts bounded exit with specific code; concurrent fixture still alive after reap.

**Adversarial cases:**

| External input | Hostile case | Test |
|---|---|---|
| Provider API | 429 then silence | Bounded exit; no SIGTERM-after-25m |
| Child process | Hangs forever | Reap owned only; sibling mock still alive |
| Shared machine | Concurrent CI on another job | No broad kill (regression named in recurrence-repair) |

#### Step 8 — Secrets/1Password out of review path (C6)

- **What:** Formal review must not call 1Password (incidents: Muse/DeepSeek "would invoke 1Password"; Qwen key refresh lock). Credentials come from file/env preload only; refuse otherwise.
- **Files:** door credential load (`require_credentials`), `tools/lib/review-doors/*`, tests for refusal.
- **Verification gate:** Test that review start with only `op` available and no cred file **refuses** and does not spawn `op`.

#### Step 9 — Disposition backlog by class (C1–C6)

- **What:** On each host, `ai-reviewer-issue list` + `show`; map every open ID to class C1–C6; resolve/partially-resolve with evidence when a class fix lands; carry-forward with owner when not. **One loop is not 47 bugs** — link duplicates to the class fix. Follow `log-reviewer-issue` maintenance rules (`maintenance show` first).
- **Verification gate:** Each host has zero open maintained-provider incidents without class + owner + disposition row in `tests/verification/reviewer-stability-24h/README.md` (create dir).

#### Step 10 — 24-hour live observation

- **What:** After Phases A–C are installed on edge-dev3 (and edge-dev smoke for C5), observe **≥24 real hours** with at least three genuine reviews per maintained provider plus ordinary traffic. Record counts, failures, timeouts, refusals separately. Honest denominators. Provider outage is an availability limit, not invented code metrics.
- **Verification gate:** `tests/verification/reviewer-stability-24h/README.md` with timestamps, sample matrix, and per-provider usable-review counts. Checklist item `- [ ] live proof` on **#1822** until this exists.

#### Step 11 — Closeout

- Update this STATUS table with artifacts (not bare counts). Finish #1822 checklist. Retire the handoff only when no carried obligation remains. Do not open a leftover-proof issue.

## 10. Tests required

| Suite / test | Purpose |
|---|---|
| `bash tests/test-ai-review-preflight.sh` (or current equivalent — verify on source) | Requal skip vs require; pin match |
| `bash tests/test-ai-review-lifecycle.sh` | Terminal verdict contract cases (Step 2 adversarial table) |
| `bash tests/test-ai-review-engine.sh` | Doors call shared helper; adapter bits preserved |
| `bash tests/test-ai-review-packet.sh` / `test-ai-review-sandbox*.sh` | C3 path/receipt identity |
| `bash tests/test-reviewer-events-isolation.sh` | Synthetic tests never write live incident outcomes |
| `bash tests/test-ai-review-sandbox-delete-guard.sh` / `self-cleanup` | Stay green |
| New: Windows spawn smoke (named in Step 6 STATUS) | C5 |
| New: bounded-error hang test (Step 7) | C4 |
| New: no-`op`-in-review test (Step 8) | C6 secrets |

Never invent a pass for a missing suite — check existence on current source first. Use `bin/ai-test-local --check-collision` before full local series.

## 11. Constraints, standing rules, and gotchas

- **Branch:** feature branch + PR; never push `main`; merge queue. Installed checkout: **never** `git pull`/merge.
- **Task class:** declare before work. Reviewer wrappers/doors/lifecycle/safety tests = `reviewer-safety` (protected). Ordinary docs = `prose`.
- **edge-dev programme constraint:** no AI reviewer as a gate for that host's repair; this programme's shared-layer changes still need the gates their class requires.
- **No capability removal**, no weakened CI, no silent failures, no band-aids on symptoms (e.g. do not hide requal by deleting the requal code path without identity design).
- **Secrets:** 1Password vault `vibe_coding` only; never print values; review path must not call `op`.
- **Incidents:** record with computer name; resolve with evidence; no Markdown archive of resolved IDs.
- **Do not** restart bulk ScaleDown raw-transcript extract without an explicit token budget on #1822.
- **Serialize** edits to shared lifecycle/packet with the sibling plans' owners.
- **Times in EST (America/New_York)** in all human-facing notes.
- **Sign GitHub posts** with `Posted by MiMo chat <id> on <machine>`.

## 12. Access and environment

| Need | Where |
|---|---|
| Hosts | `edge-dev` (Windows, Git Bash), `edge-dev3` (Linux, SSH `edge-dev3`) |
| Repo | `popcre/ai-devops`; worktrees from `origin/main`; canonical checkout landing-only |
| Issue | [#1822](https://github.com/popcre/ai-devops/issues/1822) |
| Incident store | `ai-reviewer-issue path` on each host (private; do not commit bodies) |
| Provider CLIs | Machine-local; pins in `config/` as on source |
| Secrets | 1Password vault `vibe_coding` by **item title only** (e.g. `scaledown.ai API key for testing`) — never values |
| GitHub | `bin/ai-gh` (not bare `gh` loops); `bin/ai-pr-wait` with explicit timeout |
| Tests | `bash tests/<name>.sh` via Git Bash on Windows; `bin/ai-test-local --check-collision` first |

## 13. Definition of done + risks and open questions

### Definition of done

- [ ] C1: Unrelated `update.sh` does not trigger provider requalification (test evidence).
- [ ] C2: Terminal-verdict contract tests all green (adversarial table).
- [ ] C3: Receipt/sandbox fixtures pass; no open receipt-conflict incidents without disposition.
- [ ] C4: Bounded error exits; owned-process-only reap; no multi-hour fallback suite.
- [ ] C5: edge-dev spawn smoke passes without reviewer gate; edge-dev3 pin/Muse path coordinated with recurrence-repair.
- [ ] C6: No 1Password in review path; pin mismatch refuses.
- [ ] Backlog: every open local incident has class + disposition row.
- [ ] Live proof: ≥24h observation matrix on #1822 checklist; STATUS rows cite artifacts.
- [ ] Tests named above green on the landed commit; PR merged via queue (or docs-only admin if truly prose-only).
- [ ] Handoff retired only when nothing carried remains.

### Risks

| Risk | Mitigation |
|---|---|
| Overlap with sibling plans on shared files | Serialize; reconcile ownership on #1822 first |
| Requal freeze hides a real identity change | Deliberate pin bump path still requals |
| Verdict contract too strict → false BLOCKED | Prefer honest BLOCKED over silent APPROVE; tune only with evidence |
| 24h quiet window proves nothing | Require minimum review sample counts |
| Token waste recurrence | Hard budget rule in §4 / §11 |

### Open questions

- Exact requal trigger mechanism (§8 open) — decide at Step 1 with a failing test first.
- Whether C3 is mostly packet or door work — decide at Step 4 with the fixture.
- GLM `external_directory` permission failures (2 recent) — treat as C5/C6 adjacency if they block completion; otherwise leave to GLM-specific plans ([plan_glm_own_output_recovery.md](plan_glm_own_output_recovery.md), [plan_glm-permission-failures.md](plan_glm-permission-failures.md)).

---

## Self-audit (mandatory — Mode A)

1. **Could a brand-new AI session with no project knowledge execute this plan without asking anything?**  
   **Yes.** §2 defines the repo/hosts/stack; §5 states current state and where siblings own work; §9 names files, behavior, depends-on, and a verification gate per step; §12 lists access; §11 lists standing rules including edge-dev's no-reviewer gate. Gap found earlier: requal file list might be incomplete — §9 Step 1 tells the implementer to **discover** install/update/preflight paths rather than assuming a fixed list.

2. **Does the plan carry background, nuance, and rejected approaches?**  
   **Yes.** §3 trigger and diagnosis provenance; §6 class table with counts and examples; §7 rejected approaches including the failed ScaleDown bulk extract; §8 locked vs open decisions (including owner quotes referenced by date).

3. **Is the ultimate goal clear enough for judgment calls?**  
   **Yes.** §1 states stability ≥24h and "goal wins" override; §13 open questions name criteria (failing test first; honest BLOCKED; sample counts).

**Checklist:** 13 sections present · goal first · no-question implementability · rejected approaches · concrete files + gates · adversarial table in Step 2/7 · locked/open decisions · out-of-scope · named tests · terms defined · secrets by location · DoD includes merge/CI/live proof · handoff link above and reciprocal in `HANDOFF.d/`.

**Self-audit passed 2026-10-16.** Comprehensive because every diagnosis class maps to an owned step with a verification gate, and every already-owned programme is referenced instead of rewritten.
