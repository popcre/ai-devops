---
issue: 1714
status: OPEN
owner: mimo/edge-dev
---

# HANDOFF — review-waste skip-rule decision & implementation (2026-10-13T2120Z, edge-dev/MiMo)

This is a **write-once** session handoff. Do not edit it later; create a new file for follow-on work.

**Owner decision doc (read first):**
https://github.com/popcre/ai-devops/blob/main/docs/review-waste-recommendation-2026-10-13.md

---

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

1. **Approve, narrow, or reject the review skip-rule** in the recommendation §3 / §7 (options 1–4). Evidence is complete; policy change is Albert's alone.
2. **Override semantics** — how easy should “review anyway” be on a skipped change?
3. **30-day re-measurement** — whether to keep measuring after a policy cut.

---

## 1. What this application is

`popcre/ai-devops` — Albert's public AI workflow toolkit (reviewer wrappers, task gates, Jev probes). No app, no DB, no UI. GitHub `main` is protected. Work landed by branch + PR + merge queue.

---

## 2. What we set out to do this session, and why

Execute `plan_jev-review-waste-mining.md`, then (at Albert's request) scale to the full transcript archive, document skip/keep patterns, per-reviewer quality, and a data-backed recommendation. Finally re-check Jev labels with MiMo v2.6 Flash. Session output is **evidence and docs only** — no review policy change.

---

## 3. Current state — what is true right now

All of the following is on `origin/main`:

- https://github.com/popcre/ai-devops/blob/main/docs/review-waste-analysis-2026-10-13.md — patterns (repo, review mode, caller)
- https://github.com/popcre/ai-devops/blob/main/docs/review-waste-recommendation-2026-10-13.md — **the recommendation to approve**
- https://github.com/popcre/ai-devops/blob/main/tests/verification/jev/review-waste-report-20261013T162000Z.md — full archive, events-joined
- https://github.com/popcre/ai-devops/blob/main/tests/verification/jev/review-waste-reviewer-detail-20261013.md — per-reviewer tables
- https://github.com/popcre/ai-devops/blob/main/tests/verification/jev/review-waste-flash-verify-20261013.md — Flash 98% confirm of `none` labels
- https://github.com/popcre/ai-devops/blob/main/tests/verification/jev/review-waste-inventory-20261012T162801Z.md — inventory + cost
- Shared Jev client: `tools/lib/jev-client.sh` + `config/jev-decisions.json` (pin `jev-1.13.0`)

Headline numbers (discretionary decided, n≈492): **92% of reviews added nothing**; **8% found a real problem**. Strongest separators: **review mode** (plan/diff/final-check = 1–3% yield) and **caller** (codex=3% vs claude/mimo/zcode=28–56%). Keep-list: `shared-db` + non-Codex (deepseek @ shared-db 67% high).

**Not started (owner decision pending):** encoding the skip-rule into routing / task gates.

---

## 4. Everything we tried that did NOT work

- Large Jev chunk-filter pass over 290k chunks: 53% errors from rate limits; value-score stage failed on oversized arcs (402 credits then request size). Fixed with 80KB arc cap + retries; events-joined path is the one that worked.
- Git push hung repeatedly on Windows (GCM / stuck git processes). Worked around with `gh auth token` + `credential.helper=` + URL token push. Do not assume `git push` works without that.
- `mimo` CLI is not on PATH on edge-dev; Flash verification used actor subagents with `model=mimo-desktop/mimo-v2.6-flash`.

---

## 5. Root causes and key findings

Jev labels; it does not reason. Value is ordered (Score). Safety-gate “nothing added” is assurance, not waste. Waste is concentrated in **Codex × final-check/diff/plan-review** on tooling/dflow/oracle. Real findings live on **shared-db** with muse/grok/qwen/deepseek. Flash re-read: 176/180 `none` labels confirmed (2 disputed per 180). Full narrative: docs linked in §3.

---

## 6. Exact next steps

1. Albert reads https://github.com/popcre/ai-devops/blob/main/docs/review-waste-recommendation-2026-10-13.md and picks option 1–4.
2. If option 1 or 2: implement the skip-rule as **optional discretionary dispatch** (not a silent gate bypass), with an explicit override. Start a **new** worktree from current `origin/main`. Declare `ai-task-gates start --class code` (or `reviewer-safety` if touching reviewer wrappers). Do **not** change `reviewer-safety` gates.
3. If option 4 (deepen): re-read more arcs; this session already did a 218-arc Flash pass.
4. After any policy cut, re-run the measurement in 30 days (tools under `tools/jev_review_waste_*.py` on main).

---

## 7. Constraints and gotchas in force

- Evidence only until Albert approves a policy change. Jev never opens gates.
- Public repo: no raw transcript text. Aggregates only.
- One shared Jev client (`tools/lib/jev-client.sh`); pinned model `jev-1.13.0`.
- Safety-gate bucket stays separate forever in this workstream.
- Branch + PR + merge queue; `git var GIT_COMMITTER_IDENT` must show Albert's identity.
- Windows Git push workaround is in §4.

---

## 8. Access and environment

Machine `edge-dev` (Windows). Transcript archive: local Dropbox path (do not commit). Events: `~/.local/state/ai-devops/reviewer-events/events.jsonl`. Jev key: 1Password `vibe_coding` / `typesafe.ai API` via `op run`. Analysis worktrees may still exist: `C:/repos/ai-devops-wt-jev-sweep2` (optional; all deliverables are on main).

---

## 9. Open questions and risks

Open: owner's choice among recommendation options 1–4. Risk: skip-rule without override could hide a rare real finding (~2% of `none`s). Guard: override + 30-day re-measure (recommendation §6).

---

## Self-audit

1. **Standalone?** Yes — §1–3, 5–6 carry goal, findings, URLs, and next action.
2. **All reasoning carried?** Yes — rejected approaches in §4; scale and separators in §5; docs URLs in §3.
3. **Goal clear for judgment calls?** Yes — Albert picks the policy option; implementer never changes safety gates.
