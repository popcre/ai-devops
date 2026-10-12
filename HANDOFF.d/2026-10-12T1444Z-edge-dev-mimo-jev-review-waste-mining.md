# HANDOFF — Jev review-waste mining plan (2026-10-12T1444Z, edge-dev/MiMo)

This is a **write-once** session handoff. Do not edit it later; create a new file for follow-on work.

**Implementation plan (the build spec — read it first):**
[`plan_jev-review-waste-mining.md`](../plan_jev-review-waste-mining.md)

---

## 0. ⚠️ BUSINESS DECISIONS ONLY THE OWNER CAN MAKE

1. **What to do about low-value review traffic.** This work only produces evidence. Any change to which reviews are sent, which are mandatory, or who reviews what is Albert's decision after he reads the waste report.
2. **Definition of "negative value"** if the transcript arc cannot decide it (pushback-and-was-right vs. fix-later-reverted). Plan §8 open table gives the preferred rule and abstain default; contested cases go to Albert.
3. **Whether to keep bulk derived data** after the report (plan Step 6.2).

---

## 1. What this application is

`popcre/ai-devops` — Albert's public AI workflow toolkit (reviewer wrappers, task gates, Jev probes). No app, no DB, no UI. GitHub `main` is protected. Jev = TypeSafe decision model (`https://api.typesafe.ai/v1/systemone`), typed answers only (`Noul` / `Choice` / `Score`).

Related plans: `plan_typesafe-jev-decision-layer.md`, `plan_typesafe-jev-advisory-integrations.md`, `plan_typesafe-jev-spend-reduction.md`, `plan_reviewer-spend-waste.md`.

---

## 2. What we set out to do this session, and why

Albert wants to know whether some subset of work we send to reviewers rarely produces a correction or improvement — i.e. wasted review money. He wants a cheap model (Jev) to mark and label the relevant transcript portions so a frontier LLM only reads what matters. Value is an **ordered five-level scale**, not yes/no. Session output is **this plan + handoff only**; no implementation yet.

---

## 3. Current state — what is true right now

- Plan written at `plan_jev-review-waste-mining.md` with STATUS table (all rows open).
- Worktree `C:/repos/ai-devops-wt-jev-waste`, branch `mimo/jev-review-waste-plan`, base `ae490d6d`.
- `tools/lib/jev-client.sh` and `config/jev-decisions.json` still missing (advisory §9.2 open).
- `bin/ai-jev-probe` and `bin/ai-jev-completion-shadow` exist; they use `jev-latest` and must move onto the shared client.
- Owner ruled 2026-10-12: transcripts are redacted, no longer private — may go to TypeSafe for this analysis; raw text still never commits to the public repo.

---

## 4. Everything we tried that did NOT work

This session wrote only the plan. Design approaches already ruled out (do not retry): keyword/grep mining (2026-09-27 false positives), binary value yes/no, treating "problem without fix" as non-value, `Choice` for value (needs `Score`), separate Jev run for reviewer segmentation, counting every safety-gate "nothing added" as waste, `fast-jev-compaction`, `jev-latest` for calibration.

---

## 5. Root causes and key findings

Jev labels, it does not reason. Mentions ≠ paid reviews — join `events.jsonl`. Value is ordered (`Score`). Safety-gate reviews buy assurance and get their own bucket. Push classification to Jev; frontier model reads only marked slices. Full detail: plan §§6–8.

---

## 6. Exact next steps

1. Open `plan_jev-review-waste-mining.md` and read its STATUS table first.
2. Start Step 0.1 (worktree + task class) in a **new session**. Do not inherit this session's class.
3. Execute Phase 1 → 6 in order; re-read the plan at each phase cut.

---

## 7. Constraints and gotchas in force

Public repo (aggregates only), one shared Jev client, pinned model, abstain on uncertainty, Jev never opens gates, safety-gate bucket separate, branch+PR+merge queue, `git var GIT_COMMITTER_IDENT` must show Albert's identity, Jev key only via `op run` from 1Password `vibe_coding` / `typesafe.ai API`. Full list: plan §11.

---

## 8. Access and environment

Repo worktree as above. Transcript archive: local Dropbox path (`/home/ahazan/Dropbox/ai/chat_transcripts/` on Linux; Windows equivalent if synced); MiMo: `~/.local/share/mimocode/mimocode.db`. Reviewer events: `~/.local/state/ai-devops/reviewer-events/events.jsonl`. Jev: `bin/ai-jev-probe`. Windows uses Git Bash / `.cmd` launchers.

---

## 9. Open questions and risks

Open table in plan §8 (negative-value definition is the only Phase-4 blocker). Risks in plan §13 (false positives, scale disagreement, cost blow-up, model pin change, small cells, policy creep, raw-text leak).

---

## Self-audit

1. **Standalone?** Yes — plan §§1–2, 5, 9, 12 carry goal, definitions, current state, executable steps, and access; handoff links the plan first.
2. **All reasoning carried?** Yes — plan §§6–8 including rejected approaches and the 2026-10-12 owner rulings.
3. **Goal clear for judgment calls?** Yes — plan §1 business goal + "goal wins" instruction; policy change explicitly out of scope.
