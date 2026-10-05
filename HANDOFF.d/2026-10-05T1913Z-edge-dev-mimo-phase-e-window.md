---
issue: 1301
status: OPEN
owner: mimo/phase-e-window
---

# HANDOFF — Phase E clean window + metrics (reviewer-pipeline-core)

handoff-id: 2026-10-05T1913Z-edge-dev-mimo-phase-e-window
machine: edge-dev
agent: mimo
session: ses_ffe5ef3177187ffe2Tgs953Skx
repo: popcre/ai-devops
workstream: Phase E only (parent #1110 closed; card issue #1301)
predecessor: retired coordinator handoff `2026-10-05T1536Z-edge-dev-mimo-pipeline-core-coordinator.md` (PR #1300)

---

## 0. DECISIONS ONLY THE OWNER CAN MAKE

**None blocking.** Phase E is a timed/measured gate, not a product-shape choice.

**Already settled — do NOT re-ask:**
- Reviewers are the rotation fleet in `config/reviewer-registry.json`. Claude/Codex write/orchestrate.
- Never ask a human to approve technical actions; assigned AI reviewers gate them.
- One unproven outcome per session/subagent; never bundle leftover proofs.
- Phase E must not delete duplicated helpers before the measured clean window
  (14 days or 50 reviews with zero missing-packet incidents).
- Gemini uses Albert's Antigravity **subscription** allowance (weekly / 5-hour
  buckets), not a separate paid API key. Do not describe canaries as "API credit".

**If a future paid reviewer canary needs money**, that is an owner spend decision.

---

## 1. What this application is

`popcre/ai-devops` is POP Creations' public recovery/ops toolkit for a multi-model
AI workflow (reviewer wrappers, evidence packets, lifecycle accounting, policy).
GitHub is source of truth. Protected `main` via merge queue. Canonical checkout
`C:\repos\ai-devops` is landing-only. Write work uses its own worktree.

Program reviewer-pipeline-core (parent #1110) is **closed**: evidence retention,
versioned requalification, outage-vs-code split, and shared runner/doors all
landed and live-proven. Only Phase E remains.

## 2. What we set out to do this session, and why

Business: finish leftover live proofs and close the program honestly.

Coordinator session (no direct proof work): dispatched subagent A for #1163,
then B for #1204, verified their issue comments, closed both, measured the
Phase E clean window (NOT MET), closed parent #1110, retired the coordinator
handoff via PR #1300, opened issue #1301 as the Phase E card, and ran a Gemini
live canary at Albert's request (back to `installed-healthy` / `usable:true`).

## 3. Current state — what is true right now

| Item | State |
|---|---|
| Parent #1110 | **CLOSED** 2026-10-05 with closeout comment |
| #1163 leftover proof Phase A | **CLOSED** live run `20261005T164800-501907-21834`; `packet_sha256=375d493f4308f465246c5124d74333dfd8700683bb779c352e8c4ec09c2b4b3a` |
| #1204 leftover proof Phase B | **CLOSED** three gates live (failed canary kept last good; success published new version) |
| #1257 leftover proof Phase D | **CLOSED** earlier (run `20261005T014515-151480-20815`) |
| Phase E (this workstream) | **WAITING** on clean window — issue **#1301** |
| Plan STATUS | On `origin/main` via PR #1300 (`e10c559`) — row 5 says waiting on window |
| Gemini on edge-dev | **usable** after live canary 2026-10-05 (agy 1.2.17 recorded). One 503 flake retried; last-good kept. |
| Window measurement 2026-10-05T17:19Z | Elapsed 5.6/14 days since #1135 `a5bc30be` @ 2026-09-30T02:56:50Z. 20 non-null `packet_sha256` runs (need 50). 491 null since landing. Target date **2026-10-14**. |
| Measurement artifact | `~/.local/state/ai-devops/review-lifecycle/phase-e-window-20261005.txt` |

## 4. Everything we tried that did NOT work

- Named predecessor handoff `2026-10-04T2339Z-…-pipeline-core-closeout.md` was
  never in-repo (referenced only). Do not hunt for it.
- Leftover-proof issues #1163/#1204/#1257 were briefly closed by a residual
  tidy without live proof; they were reopened (or proven) and closed with
  evidence. Do not treat tidy-close as proof.
- First Gemini canary attempt: Antigravity eligibility `UNAVAILABLE (code 503)`.
  Not out of credit. Retry succeeded. Failed canary correctly kept last-good.
- Calling `ai-gemini qualify-live` alone would rewrite the qualification record
  and **drop version history**. Use `bin/ai-review-preflight qualify gemini`.

## 5. Root causes and key findings

- Phase E helper retirement is gated on a measured clean window (plan §9 Phase E).
- Window = (14 days since packet-store landing **OR** 50 reviews) **AND** zero
  missing-packet incidents. Last check: neither quantity nor time met.
- Many lifecycle rows still have `packet_sha256: null` (claude/codex orchestration
  and some provider paths). Counters must be re-run with the same commands, not
  guessed.
- Operational Gemini requal on Windows edge-dev:
  `AI_REVIEW_PREFLIGHT_TIMEOUT=45 AI_REVIEW_GEMINI_QUALIFY_TIMEOUT=1800 bin/ai-review-preflight qualify gemini`
  then `bin/ai-review-preflight status gemini`.
- Git Bash on this host: `& "C:\Program Files\Git\bin\bash.exe" -lc '...'` with
  single-quoted inner scripts. `ai-gh.cmd` can fail if `%ProgramFiles%` is unset.

## 6. Exact next steps

This is a **waiting** workstream. A future session should:

1. Open issue #1301 (the card). Do not reopen #1110.
2. Re-measure the window with the commands in
   `~/.local/state/ai-devops/review-lifecycle/phase-e-window-20261005.txt`
   (and the counters in §3). Record a new artifact path with the result.
3. If **NOT** met: stop. Leave #1301 open. Do not retire helpers.
4. If **met**: dispatch **one metrics subagent** for the Phase E before/after
   record (commands + artifact paths, not bare numbers): `*_captured: 0` count,
   quarantine events, outage-vs-code issue split, packet-store disk use.
5. **Separately** (never bundled with 4), a reviewer-safety change may retire
   duplicated helpers — independent exact-head final review before merge.
6. When metrics + retire (or explicit defer) are done, close #1301.

**You'll know each step worked when:** the issue is closed with a metrics record
cited by file path, or left open with a fresh measurement artifact saying the
window is still short.

## 7. Constraints and gotchas in force

- One unproven outcome per session/subagent. Never bundle metrics + helper-retire.
- Reviewer-safety class: independent exact-head final review before merge of
  wrappers, evidence tools, safety tests, or installed routing.
- Never edit `bin/ai-gemini` / `bin/ai-qwen` wrapper bytes without a requal plan.
- GitHub only via `bin/ai-gh`; PR waits via `bin/ai-pr-wait` with explicit timeout.
- Landing tree is landing-only; write work uses worktrees.
- Public repo: no hostnames, billing, secrets, tailnet IPs, private quotes.
- Do not require `--verdict` on scoreboard without re-scoping existing tests.
- Do not delete proof worktrees that still hold cited packet artifacts unless
  the issue evidence is already durable elsewhere.

## 8. Access and environment

- Host: **edge-dev** (Windows). Git Bash `C:\Program Files\Git\bin\bash.exe`.
- GitHub: `popcre/ai-devops` via `bin/ai-gh`.
- Qualification store: `~/.local/state/ai-devops/review-quarantine/gemini-live-qualified.json` (and qwen sibling).
- Lifecycle runs: `~/.local/state/ai-devops/review-lifecycle/runs/`.
- Gemini billing: Antigravity subscription allowance (`bin/ai-gemini-usage`).
- Secrets: 1Password vault `vibe_coding` via `op run` only — none needed for Phase E.

## 9. Open questions and risks

- Counter definition: are `packet_sha256: null` claude/codex rows in scope for
  "missing-packet incidents"? Re-measure with the same filters and say so in the
  metrics record. Date the decision when known.
- edge-dev is shared; preflight/sandbox I/O can flake under load. Retry once.
- Windows CI runners remain flaky — only matters if the helper-retire PR needs
  the queue.
- Proof worktrees `ai-devops-wt-1163-live` and `ai-devops-wt-1204-live` still
  exist with artifacts. Remove only after evidence is durable (issue comments
  already carry hashes/paths).

---

## Mandatory self-audit gate

1. **Cold-start complete?** Yes — §3 state table, §6 ordered steps, card #1301.
2. **As effective as this session?** Yes — §4 dead ends (tidy-close ≠ proof,
   qualify-live drops history, 503 retry).
3. **Every relevant detail?** Yes — window numbers, commands artifact path,
   Gemini requal line, constraints, worktree warning.
4. **Section 0 complete for the owner?** Yes — nothing blocking; subscription
   billing correction recorded so nobody re-asks for API credit.

**Audit: PASS** (2026-10-05T19:13Z).
