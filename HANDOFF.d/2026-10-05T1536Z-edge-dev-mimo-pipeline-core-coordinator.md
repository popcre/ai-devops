---
issue: 1110
status: OPEN
owner: mimo/pipeline-core-coordinator
---

# HANDOFF — reviewer-pipeline-core coordinator dispatch (finish the program)

handoff-id: 2026-10-05T1536Z-edge-dev-mimo-pipeline-core-coordinator
machine: edge-dev
agent: mimo
session: ses_ffe5ef6aa4094ffeeYYbNwbl1w
repo: popcre/ai-devops
workstream: reviewer-pipeline-core (parent GitHub issue #1110)
predecessor: HANDOFF.d/2026-10-04T2339Z-edge-dev-mimo-reviewer-pipeline-core-closeout.md

---

## 0. ⚠️ DECISIONS ONLY THE OWNER CAN MAKE

**None blocking.** The program code is landed. Remaining work is two leftover
live proofs and Phase E metrics — operational, not product-shape.

**Already settled — do NOT re-ask:**

- 2026-09-30 — GLM is back in rotation; Claude is out; Kimi is out (no credit).
- 2026-09-28 — Never ask a human to approve technical actions; assigned AI
  reviewers gate them.
- 2026-10-04 — One unproven outcome per session; do not bundle leftover proofs.
- 2026-10-05 — Phase E must not delete duplicated helpers before the measured
  clean window (14 days or 50 reviews with zero missing-packet incidents).

**If a live proof cannot be paid for** (provider credit), that is an owner spend
decision — do not invent a substitute proof. Raise it here.

**Wrong-guess-is-recoverable:** none. Sequence and scope are already decided.

**Outside this workstream, nobody is on it:** 44 shared-db reviewer leases are
stale-reclaimable (capacity reports keep growing). Not this repo's bug. Optional
hygiene only — do not let it delay #1110.

Put this whole section to the owner in one message before starting work, only if
something new appears. Nothing above needs a reply today.

---

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery and operating toolkit for a
multi-model AI workflow: reviewer wrappers, evidence packets, lifecycle
accounting, skills, policy, and offline tests. GitHub is source of truth.
Protected target `main` via merge queue. Canonical checkout `C:\repos\ai-devops`
is landing-only. Write-capable tasks use their own worktrees.

The reviewer-pipeline-core program (parent #1110) made reviews leave durable
evidence, kept last-good qualifications, routed formal reviews through one
runner, and split provider outages from code defects.

## 2. What we set out to do this session, and why

Business goal: finish leftover live proofs for the landed pipeline so the
program can close honestly (plan §1 / parent #1110).

This session: pick ONE leftover proof, prove it live, close that issue, stop.
Picked **#1257** (live review through `bin/ai-review-engine` on edge-dev).
Albert then asked for a coordinator prompt so a future session can finish the
whole program with subagents and no direct work.

## 3. Current state — what is true right now

### Landed (all merged to origin/main with independent exact-head APPROVE)

| Child | PR | Leftover proof | Proof status |
|---|---|---|---|
| #1111 evidence retention | #1135 | issue #1163 | **OPEN** — not proven live |
| #1112 requal last good | #1201 | issue #1204 | **OPEN** — not proven live |
| #1114 runner + doors | #1209 + #1225 | issue #1257 | **CLOSED 2026-10-05** — live proof done |
| #1115 outage vs code | #1218 | (suite covers) | covered |

- Plan STATUS on main via docs PR #1259.
- Phase A–D code done. Phase E (retire copies + metrics proof) **open by design**.

### This session's proof (#1257) — DONE

One real Grok review through `bin/ai-review-engine` (door `tools/lib/review-doors/grok.sh`),
run `20261005T014515-151480-20815`, head `9b64b3a9cb5734a0cb01b408956510e2a4067ac7`,
base `86726d4b2335298dcbf979faadb7d2b2247d477d`, verdict **APPROVE** bound to head.

| Artifact | Value |
|---|---|
| Packet sha256 | `b403eeebb0fb867b0887cade4e3784a3616b8aa68910d55c60d8fc012203d10b` |
| Report sha256 | `625a6676de35e149bbe60b4112d4ec0dc59ceeea30257bcc4f5122684c52da17` |
| Lifecycle state | `C:/Users/ahazan/.local/state/ai-devops/review-lifecycle/runs/4f09a1a507678570aa6c6b414021875a79038ab90865c9c97920623777170f00/grok/mimo/20261005T014515-151480-20815.json` |
| Issue comment | https://github.com/popcre/ai-devops/issues/1257#issuecomment-5986842736 |

Status on the lifecycle record: `completed`, `packet_sha256` present, runner
stamp `review-lifecycle-core/1`. Issue #1257 is closed.

**Note:** the proof worktree `C:/repos/ai-devops-wt-1257-live` was later removed
by other machine activity. The packet/report paths in the issue comment point
into that worktree and will not open now. The lifecycle JSON + issue comment
remain the surviving evidence. Do not "recover" the worktree just to close this —
the proof is already closed on GitHub. If a later audit needs the packet bytes,
treat them as gone and re-prove only if the owner asks.

### Not started / remaining

1. Live proof **#1163** (durable packet on remove path) — OPEN.
2. Live proof **#1204** (requal keeps last good under real hash drift) — OPEN.
3. **Phase E** — measure clean window, record metrics, then retire duplicated helpers.

## 4. Everything we tried that did NOT work

- First engine review: Grok `stopReason: cancelled` after 4 turns
  (`cancellation_category: permission_cancelled`) — concurrent
  `run_terminal_command` permission requests; one resolved `cancelled` and the
  turn died. Door correctly refused a non-terminal stop.
- `--assert-head` abbreviated SHA → `source-head-mismatch`. Full 40-hex required.
- Preflight `check` hung / `provider-timeout`: `ai-grok-review doctor` often
  exceeds the default 10s `CHECK_TIMEOUT` (catalogue probe + version checks).
  Later runs used `AI_REVIEW_PREFLIGHT_TIMEOUT=45`.
- Detached `nohup` / `Start-Process` / `start /b` launches were killed by the
  tool layer (`ChildProcess.kill`) or died on MSYS fork failures under load.
- Worktree polluted with `1257-run.out/err` → sandbox inventory failure
  (`ai-review-sandbox: could not read the complete review-visible source
  inventory`). Keep the review worktree **clean** before dispatch.
- Accidental double-launch of the same run name created duplicate preflight
  sandboxes. One run at a time per name.
- Machine was heavily loaded by other sessions (codex/muse/qwen/preflight
  swarm). Expect slowness and `Resource temporarily unavailable` on fork.

## 5. Root causes and key findings

- Shared delete path must store-before-delete the **full** managed packet
  (already landed; #1163 is the live proof of that).
- Requalification must keep last good until canary passes (landed; #1204 live proof).
- Engine success path (what #1257 needed): `packet-store` → durable path under
  `.ai/reviews/packets/` → `lifecycle-finish` with `--packet-sha256`.
- Grok door model pin is `grok-4.5` / `grok-4.5-build`; wrapper doctor may show
  a different default — do not "fix" the door to match doctor.
- `timeout` on Git Bash does not always kill native Windows children quickly;
  budget real wall time for doctor + sandbox + packet on edge-dev.
- Identity/packet tools want full SHAs and a clean worktree.
- Verdict must name the reviewed head under a literal `## Verdict` heading.

## 6. Exact next steps (coordinator — do no proof work yourself)

The successor session is a **coordinator only**. It does not run reviews, does
not edit wrappers, and does not take a leftover proof as its own outcome. It
dispatches one subagent per unproven outcome and verifies their reports.

1. Confirm parent #1110 is still open and read this file + predecessor
   `HANDOFF.d/2026-10-04T2339Z-edge-dev-mimo-reviewer-pipeline-core-closeout.md`.
2. Dispatch **subagent A** — live proof #1163 only. Wait for its report + issue
   comment + close. Do not start #1204 until A is closed.
3. Dispatch **subagent B** — live proof #1204 only. Same gate.
4. After both proofs close, check the clean window for Phase E (plan §9 Phase E):
   14 days since packet-store landing **or** 50 engine reviews with zero
   missing-packet incidents. If the window is not met, stop with that as the
   sole remaining wait; do not retire helpers early.
5. When the window is met, dispatch **subagent C** for Phase E metrics (commands
   + artifacts, not bare numbers). Then a separate reviewed change may retire
   duplicated helpers (reviewer-safety class; independent exact-head final
   review before merge).
6. When proofs + Phase E are done, comment the closeout on parent #1110 and
   close it. Retire this handoff and the predecessor under the successor rule.

**You'll know each step worked when:** the named GitHub issue is closed with
artifact paths in a comment (proofs), or the plan STATUS cites a metrics record
with file paths (Phase E).

## 7. Constraints and gotchas in force

- **One unproven outcome per session/subagent. Never bundle #1163 + #1204.**
- Reviewer-safety class: independent exact-head final review before merge of
  wrappers, evidence tools, safety tests, or installed routing.
- Never edit `bin/ai-gemini` / `bin/ai-qwen` wrapper bytes without a requal plan.
- GitHub only via `bin/ai-gh`; PR waits via `bin/ai-pr-wait`. Git Bash on
  Windows: `C:\Program Files\Git\bin\bash.exe` (`ai-gh.cmd` can fail if
  `%ProgramFiles%` is unset — call bash with a full path).
- Landing tree `C:\repos\ai-devops` is landing-only; write work uses worktrees.
- Windows packet/sandbox/engine suites can take 240–500s; short timeouts false-hang.
- This repository is **public** — no private quotes, hostnames, billing, Dropbox
  paths, or tailnet addresses in commits or issues.
- Do not require `--verdict` on scoreboard without re-scoping existing tests.
- Subagents report a verdict + evidence line; the coordinator decides. Never
  delegate a merge decision.

## 8. Access and environment

- Host: **edge-dev** (Windows). Git Bash at `C:\Program Files\Git\bin\bash.exe`.
- GitHub: `popcre/ai-devops` via `bin/ai-gh` (machine-wide lock).
- Engine: `bin/ai-review-engine` + `tools/lib/review-lifecycle-core.sh`; Grok door
  registered in `config/review-runner-doors.json`.
- Reviewer registry: `config/reviewer-registry.json` (rotation: deepseek, gemini,
  glm, grok, muse, qwen; stepfun Linux-only; codex approval-gate only).
- Lifecycle state: `~/.local/state/ai-devops/review-lifecycle/`.
- Secrets: 1Password vault `vibe_coding` only, via `op run` — never print values.
- Shared-db operational checkout `C:\repos\shared-db` (not this repo).

## 9. Open questions and risks

- Phase E window clock: confirm whether it starts at PR #1135 merge / first
  durable retain, and count engine reviews from the scoreboard/lifecycle store.
  Date the decision in the plan STATUS when known (2026-10-05 still open).
- edge-dev is shared with many concurrent review agents; preflight and sandbox
  I/O can flake under load. Retry once; do not treat load flakes as code defects.
- Grok headless permission race (`permission_cancelled`) may still hit long
  reviews. Prefer small diffs and "no shell commands" prompts for proofs.
- Windows CI runners (Blacksmith/WarpBuild) remain flaky — unrelated to these
  proofs unless a helper-retire PR needs the queue.
- Predecessor handoff stays until this workstream is fully closed (successor
  rule not yet met).

---

## Mandatory self-audit gate

- [x] Business decisions section present and honest (none blocking; settled list)
- [x] Application described in one paragraph
- [x] Session goal stated with why
- [x] Current state names every landed artifact (PR/SHA/issue) + #1257 evidence
- [x] Failures and what did not work are listed
- [x] Root causes / findings recorded
- [x] Exact next steps a coordinator can execute cold (dispatch A, then B, then E)
- [x] Constraints/gotchas listed
- [x] Access/environment listed
- [x] Open questions/risks listed
- [x] Leftover proofs named as GitHub issues

### Self-audit answers (handoff-writer Mode A)

1. **Cold-start complete?** Yes — §1 app, §3 table of every child/proof, §6
   ordered dispatch steps with gates.
2. **As effective as this session?** Yes — §4 dead ends (permission cancel,
   preflight timeout, dirty worktree, tool kills) are the expensive lessons.
3. **Every relevant detail?** Yes — SHAs, paths, issue URLs, constraints,
   payment/spend rule, public-repo boundary.
4. **Section 0 has every owner ask?** Yes — sweep found only the spend-if-unpaid
   case and optional shared-db leases; both listed with recommendation. No other
   sentence in §1–§9 requires the owner.
